const std = @import("std");

const grammars = @import("grammars");

const Symbol = grammars.Symbol;
const Grammar = grammars.Grammar;
const GrammarBuilder = grammars.GrammarBuilder;

const Item = @import("item.zig").Item;

pub const State = struct {
    items: []Item,
    transitions: std.AutoHashMap(Symbol, usize),
};

pub const Closure = struct {
    items: std.ArrayList(Item),

    pub fn from(allocator: std.mem.Allocator, items: []Item) Closure {
        return Closure{
            .items = std.ArrayList(Item).init(allocator).appendSlice(items),
        };
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
        var builder = try GrammarBuilder.fromOwnedGrammar(self.allocator, self.grammar);
        const augmented_grammar = try builder.toAugmentedGrammar();
        self.grammar = augmented_grammar;

        const start_rule = try self.grammar.get_start_rule();

        std.debug.print("start rule:\n{any}\n", .{start_rule});
        const start_item = Item.from(start_rule);

        std.debug.print("start item:\n{any}\n", .{start_item});

        const initial_items = try self.CLOSURE(&.{start_item});
        std.debug.print("\nResulting closure:\n{any}\n", .{initial_items});

        defer self.allocator.free(initial_items);

        // const closure = Closure.from(self.allocator, &.{start_item});
        // const state = State.from(self.allocator, &.{closure});
        // try self.states.append(state);
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
    ///
    /// TODO: CLOSURE can be rewritten to avoid recursion
    ///
    fn CLOSURE(self: *Automaton, items: []const Item) ![]Item {
        var new_items = std.ArrayList(Item).init(self.allocator);
        var processed_symbols = std.StringHashMap(void).init(self.allocator);
        defer processed_symbols.deinit();

        std.debug.print("\n", .{});
        for (items) |item| {
            if (item.is_complete()) {
                continue;
            }

            std.debug.print("closure item: {any}\n", .{item});

            const dot_symbol = item.dot_symbol().?; // item is not complete, so dot symbol is always present
            std.debug.print("dot symbol: {any}\n", .{dot_symbol});
            if (self.grammar.is_terminal(dot_symbol)) { // skip terminals, they don't have any productions
                continue;
            }

            try processed_symbols.put(dot_symbol.name, {});

            for (self.grammar.rules) |rule| {
                if (!rule.lhs.eqlTo(dot_symbol)) {
                    continue;
                }

                const new_item = Item.from(rule);
                std.debug.print("new item: {any}\n", .{new_item});
                try new_items.append(new_item);

                // Filter out items which dot symbol were already processed
                // E.g. CLOSURE(S -> • E): E -> • E + T, E -> • T
                // We don't want to add E -> • E + T to the closure again
                const new_dot_symbol = new_item.dot_symbol() orelse unreachable;
                if (processed_symbols.contains(new_dot_symbol.name)) {
                    continue;
                }

                const sub_closure = try self.CLOSURE(&.{new_item});
                try new_items.appendSlice(sub_closure);
                self.allocator.free(sub_closure); // appendSlice copies sub_closure, so it's safe
            }
        }

        return try new_items.toOwnedSlice();
    }
};

test "automaton" {
    const allocator = std.testing.allocator;
    const grammar = try grammars.examples.ExpressionGrammar(allocator);

    var automaton = Automaton.init(allocator, grammar);
    defer automaton.deinit();

    try automaton.build();

    try std.testing.expect(automaton.states.items.len == 0);

    // std.debug.print("automaton:\n{any}\n", .{automaton});
}
