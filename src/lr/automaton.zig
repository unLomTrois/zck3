const std = @import("std");

const grammars = @import("grammars");

const Symbol = grammars.Symbol;
const Grammar = grammars.Grammar;
const GrammarBuilder = grammars.GrammarBuilder;
const Rule = grammars.Rule;

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
    fn CLOSURE(self: *Automaton, items: []const Item) std.mem.Allocator.Error![]Item {
        var closure_items = std.ArrayList(Item).init(self.allocator);
        var seen_symbols = Symbol.HashMap.init(self.allocator);
        defer seen_symbols.deinit();

        try closure_items.appendSlice(items);

        var item_iter = Item.IncompleteIter.from(&closure_items);
        while (item_iter.next()) |item| { // iter works as a work-list here
            const dot_symbol = item.dot_symbol().?; // item is not complete, so dot symbol is always present

            if (self.grammar.is_terminal(dot_symbol)) continue; // skip terminals, they don't have any productions

            if (seen_symbols.contains(dot_symbol)) continue;

            try seen_symbols.put(dot_symbol, {});

            var rule_iter = Rule.LhsMatchIter.from(self.grammar.rules, dot_symbol);
            while (rule_iter.next()) |rule| {
                const new_item = Item.from(rule);
                try closure_items.append(new_item);
            }
        }

        return try closure_items.toOwnedSlice();
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
