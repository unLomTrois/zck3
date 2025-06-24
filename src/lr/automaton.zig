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

    pub inline fn from(items: []const Item) State {
        return State{
            .items = items,
        };
    }

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

        pub fn from(list: *std.ArrayList(State)) ArrayListIter {
            return ArrayListIter{ .list = list, .idx = 0 };
        }

        pub fn next(self: *ArrayListIter) ?State {
            if (self.idx >= self.list.items.len) return null;
            const state = self.list.items[self.idx];
            self.idx += 1;
            return state;
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
        const initial_items = try self.CLOSURE(&.{start_item});
        defer self.allocator.free(initial_items);

        const initial_state = try State.init(self.allocator, initial_items);
        defer initial_state.deinit(self.allocator);

        try self.states.append(initial_state);

        const result = try self.build_states(self.states.items);
        defer self.allocator.free(result);
    }

    fn build_states(self: *Automaton, states: []State) ![]State {
        var new_states = std.ArrayList(State).init(self.allocator);

        var state_iter = State.Iter.from(states);
        while (state_iter.next()) |state| {
            var unique_iter = Item.UniqueIter.init(self.allocator, state.items);
            defer unique_iter.deinit();

            while (try unique_iter.next()) |item| {
                const dot_symbol = item.dot_symbol().?;

                const goto_items = try self.GOTO(state.items, dot_symbol);
                defer self.allocator.free(goto_items);

                const new_state = try State.init(self.allocator, goto_items);
                defer new_state.deinit(self.allocator);

                try new_states.append(new_state);

                std.debug.print("{any}\n", .{new_state});
            }
        }

        return try new_states.toOwnedSlice();
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
    fn CLOSURE(self: *Automaton, items: []const Item) std.mem.Allocator.Error![]Item {
        var closure_items = std.ArrayList(Item).init(self.allocator);
        var seen_symbols = Symbol.HashMap(void).init(self.allocator);
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

    fn GOTO(self: *Automaton, items: []const Item, symbol: Symbol) std.mem.Allocator.Error![]Item {
        var goto_items = std.ArrayList(Item).init(self.allocator);
        defer goto_items.deinit();

        var item_iter = Item.FilterDotSymbolIter.from(items, symbol);
        while (item_iter.next()) |item| {
            // std.debug.print("{any}\n", .{item});
            const new_item = item.advance_dot_clone();
            try goto_items.append(new_item);
        }

        return try self.CLOSURE(goto_items.items);
    }
};

test "automaton" {
    const allocator = std.testing.allocator;
    const grammar = try grammars.examples.ExpressionGrammar(allocator);

    var automaton = Automaton.init(allocator, grammar);
    defer automaton.deinit();

    try automaton.build();

    // try std.testing.expect(automaton.states.items.len == 1);

    // std.debug.print("automaton:\n{any}\n", .{automaton});
}
