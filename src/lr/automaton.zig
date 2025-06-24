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
        for (initial_items) |item| {
            std.debug.print("{any}\n", .{item});
        }

        std.debug.print("\nGOTO({any}, {any})\n", .{ initial_items, Symbol.from("exp") });
        const exp_items = try self.GOTO(initial_items, Symbol.from("exp"));
        defer self.allocator.free(exp_items);
        for (exp_items) |item| {
            std.debug.print("{any}\n", .{item});
        }

        std.debug.print("\nGOTO({any}, {any})\n", .{ exp_items, Symbol.from("+") });
        const plus_items = try self.GOTO(exp_items, Symbol.from("+"));
        defer self.allocator.free(plus_items);
        for (plus_items) |item| {
            std.debug.print("{any}\n", .{item});
        }

        std.debug.print("\nGOTO({any}, {any})\n", .{ plus_items, Symbol.from("(") });
        const lparen_items = try self.GOTO(plus_items, Symbol.from("("));
        defer self.allocator.free(lparen_items);
        for (lparen_items) |item| {
            std.debug.print("{any}\n", .{item});
        }

        // не забыть обернуть initial closure в State
        // Проходимся по всем итемам в closure, находим уникальные dot-symbolы,
        // применяем GOTO к каждому уникальному dot-symbolу,
        // (там мы сдвигаем dot на один символ вправо)
        // (получаем новый closure)
        // т.к. мы используем итератор, то не встретим дубликатов
        // итератор будет работать как work-list
        // результат GOTO(I, X) - если не пустой, добавляем в states
        // новый элемент в states будет обработан итератором

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

    try std.testing.expect(automaton.states.items.len == 0);

    // std.debug.print("automaton:\n{any}\n", .{automaton});
}
