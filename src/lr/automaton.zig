const std = @import("std");

const grammars = @import("grammars");

const Symbol = grammars.Symbol;
const Grammar = grammars.Grammar;
const GrammarBuilder = grammars.GrammarBuilder;
const Rule = grammars.Rule;

const Item = @import("item.zig").Item;

pub const State = struct {
    items: []const Item,

    pub fn init(allocator: std.mem.Allocator, items: []const Item) !State {
        return State{
            .items = try allocator.dupe(Item, items),
        };
    }

    // pub inline fn from(items: []const Item) State {
    //     return State{
    //         .items = items,
    //     };
    // }

    pub fn deinit(self: *const State, allocator: std.mem.Allocator) void {
        allocator.free(self.items);
    }

    const Iter = struct {
        states: []State,
        idx: usize = 0,

        pub fn from(states: []State) Iter {
            return Iter{ .states = states, .idx = 0 };
        }

        pub fn next(self: *Iter) ?State {
            if (self.idx >= self.states.len) return null;
            const state = self.states[self.idx];
            self.idx += 1;
            return state;
        }
    };

    const ArrayListIter = struct {
        list: *std.ArrayList(State),
        idx: usize = 0,

        pub inline fn from(list: *std.ArrayList(State)) ArrayListIter {
            return ArrayListIter{ .list = list, .idx = 0 };
        }

        pub fn next(self: *ArrayListIter) ?State {
            while (self.idx < self.list.items.len) {
                const state = self.list.items[self.idx];
                self.idx += 1;
                return state;
            }
            return null;
        }
    };

    pub fn format(self: *const State, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("State\n", .{});
        for (self.items) |item| {
            try writer.print("  {any}\n", .{item});
        }
    }

    const HashContext = struct {
        pub fn hash(_: HashContext, key: State) u64 {
            var result: u64 = 0;
            for (key.items) |item| {
                const item_hash = (Item.HashContext{}).hash(item);
                if (item_hash == 0) {
                    result = item_hash;
                } else result ^= item_hash;
            }
            return result;
        }

        pub fn eql(hash_context: HashContext, a: State, b: State) bool {
            return hash_context.hash(a) == hash_context.hash(b);
        }
    };

    pub fn HashMap(comptime V: type) type {
        return std.HashMap(State, V, HashContext, std.hash_map.default_max_load_percentage);
    }
};

pub const Automaton = struct {
    allocator: std.mem.Allocator,
    grammar: Grammar,
    states: std.ArrayList(State),

    pub fn init(allocator: std.mem.Allocator, grammar: Grammar) Automaton {
        return Automaton{
            .allocator = allocator,
            .grammar = grammar,
            .states = std.ArrayList(State).init(allocator),
        };
    }

    pub fn deinit(self: *Automaton) void {
        self.states.deinit();
        self.grammar.deinit(self.allocator);
    }

    fn build(self: *Automaton) !void {
        // Augment the grammar
        var builder = try GrammarBuilder.fromOwnedGrammar(self.allocator, self.grammar);
        const augmented_grammar = try builder.toAugmentedGrammar();
        self.grammar = augmented_grammar;

        // Get the start rule
        const start_rule = try self.grammar.get_start_rule();
        const start_item = Item.from(start_rule);

        // Compute the initial closure
        const initial_items = try self.CLOSURE(&.{start_item}, self.allocator);
        // defer self.allocator.free(initial_items);

        const initial_state = try State.init(self.allocator, initial_items);
        defer initial_state.deinit(self.allocator);

        try self.states.append(initial_state);

        try self.build_states();
    }

    fn build_states(self: *Automaton) !void {
        var state_iter = State.ArrayListIter.from(&self.states);

        var state_hash_map = State.HashMap(void).init(self.allocator);
        defer state_hash_map.deinit();

        var i: usize = 0;
        std.debug.print("{d} {any}\n", .{ i, self.states.items[0] });
        i += 1;

        while (state_iter.next()) |state| {
            var unique_iter = Item.UniqueIter.init(self.allocator, state.items);
            defer unique_iter.deinit();
            while (try unique_iter.next()) |item| {
                const dot_symbol = item.dot_symbol() orelse continue;

                const goto_items = try self.GOTO(state.items, dot_symbol, self.allocator);
                // defer self.allocator.free(goto_items);

                const new_state = try State.init(self.allocator, goto_items);
                // defer new_state.deinit(self.allocator);
                std.debug.print("{d} {any}\n", .{ i, new_state });

                if (state_hash_map.contains(new_state)) continue;

                try state_hash_map.put(new_state, {});

                try self.states.append(new_state);

                i += 1;
            }
        }
    }

    /// CLOSURE computes the CLOSURE of a set of items.
    /// CLOSURE(I): For any item A -> α • B β in a state I (where B is a non-terminal),
    /// we add all of B's productions (B -> • γ) to the state.
    /// This is repeated until no new items can be added.
    ///
    /// Example: for the following grammar:
    /// S -> A a
    /// A -> B b
    /// B -> c
    ///
    /// CLOSURE(S -> • A a) would be:
    /// S -> • A a
    /// A -> • B b
    /// B -> • c
    fn CLOSURE(self: *Automaton, items: []const Item, allocator: std.mem.Allocator) std.mem.Allocator.Error![]Item {
        var closure_items = std.ArrayList(Item).init(allocator);
        var seen_symbols = Symbol.HashMap(void).init(allocator);
        defer seen_symbols.deinit();

        try closure_items.appendSlice(items);

        var item_iter = Item.IncompleteIter.from(&closure_items);
        while (item_iter.next()) |item| { // iter works as a work-list here
            const dot_symbol = item.dot_symbol().?; // item is not complete, so dot symbol is always present

            if (self.grammar.is_terminal(dot_symbol)) continue; // skip terminals, they don't have any productions

            if (seen_symbols.contains(dot_symbol)) continue;

            try seen_symbols.put(dot_symbol, {});

            var rule_iter = self.grammar.rulesForSymbol(dot_symbol);
            while (rule_iter.next()) |rule| {
                const new_item = Item.from(rule);
                try closure_items.append(new_item);
            }
        }

        return try closure_items.toOwnedSlice();
    }

    fn GOTO(self: *Automaton, items: []const Item, symbol: Symbol, allocator: std.mem.Allocator) std.mem.Allocator.Error![]Item {
        var goto_items = std.ArrayList(Item).init(allocator);
        defer goto_items.deinit();

        var item_iter = Item.FilterDotSymbolIter.from(items, symbol);
        while (item_iter.next()) |item| {
            // std.debug.print("{any}\n", .{item});
            const new_item = item.advance_dot_clone();
            try goto_items.append(new_item);
        }

        return try self.CLOSURE(goto_items.items, allocator);
    }
};

test "automaton" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const grammar = try grammars.examples.SimpleGrammar(arena_allocator);

    var automaton = Automaton.init(arena_allocator, grammar);
    defer automaton.deinit();

    try automaton.build();

    // try std.testing.expect(automaton.states.items.len == 1);

    // std.debug.print("automaton:\n{any}\n", .{automaton});
}

test "state_hash_map" {
    const allocator = std.testing.allocator;

    const state = try State.init(allocator, &.{
        Item.from(
            Rule.from(
                Symbol.from("S"),
                &.{Symbol.from("A")},
            ),
        ),
    });
    defer state.deinit(allocator);

    var hash_map = State.HashMap(void).init(allocator);
    defer hash_map.deinit();
    try hash_map.put(state, {});
    try std.testing.expectEqual(true, hash_map.contains(state));
}
