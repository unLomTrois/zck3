const std = @import("std");

pub const Symbol = @import("symbol.zig").Symbol;
pub const Rule = @import("rules.zig").Rule;
pub const examples = @import("examples.zig");

/// Grammar is a deterministic context-free grammar. Written in Backus-Naur form.
/// The purpose of Grammar is to define a set of production rules,
/// which are used by a particular parser to construct its parse tables or automata.
///
/// It is defined by a set of terminals, non-terminals, rules, and a start symbol.
/// The start symbol is the symbol that is used to start the derivation.
///
/// The terminals are the symbols that cannot be expanded (e.g 5, +, *).
///
/// The non-terminals are the symbols that can be expanded (e.g. number, operator, etc).
///
pub const Grammar = struct {
    allocator: std.mem.Allocator,
    terminals: std.ArrayList(Symbol),
    non_terminals: std.ArrayList(Symbol),
    rules: std.ArrayList(Rule),
    start_symbol: Symbol,

    pub fn init(
        allocator: std.mem.Allocator,
        terminals: []const Symbol,
        non_terminals: []const Symbol,
        rules: []const Rule,
        start_symbol: Symbol,
    ) !Grammar {
        var g = Grammar{
            .allocator = allocator,
            .terminals = std.ArrayList(Symbol).init(allocator),
            .non_terminals = std.ArrayList(Symbol).init(allocator),
            .rules = std.ArrayList(Rule).init(allocator),
            .start_symbol = start_symbol,
        };

        try g.terminals.appendSlice(terminals);
        try g.non_terminals.appendSlice(non_terminals);
        try g.rules.appendSlice(rules);

        return g;
    }

    pub fn deinit(self: *const Grammar) void {
        self.terminals.deinit();
        self.non_terminals.deinit();
        self.rules.deinit();
    }

    const GrammarView = struct {
        terminals: []const Symbol,
        non_terminals: []const Symbol,
        rules: []const Rule,
        start_symbol: Symbol,
    };

    pub fn toView(self: *const Grammar) GrammarView {
        return GrammarView{
            .terminals = self.terminals.items,
            .non_terminals = self.non_terminals.items,
            .rules = self.rules.items,
            .start_symbol = self.start_symbol,
        };
    }

    pub fn toAugmented(self: *const Grammar) !Grammar {
        const s_prime = Symbol.from("S'");

        var g = Grammar{
            .allocator = self.allocator,
            .terminals = try self.terminals.clone(),
            .non_terminals = try self.non_terminals.clone(),
            .rules = try self.rules.clone(),
            .start_symbol = s_prime,
        };

        try g.non_terminals.insert(0, s_prime);
        try g.rules.insert(0, Rule.from(s_prime, &.{self.start_symbol}));

        return g;
    }
};

test "grammar" {
    const S = Symbol.from("S");
    const A = Symbol.from("A");
    const a = Symbol.from("a");
    const b = Symbol.from("b");

    const grammar = try Grammar.init(std.testing.allocator, &.{
        a,
        b,
    }, &.{
        S,
        A,
    }, &.{
        Rule.from(S, &.{ A, A }), // S -> A A
        Rule.from(A, &.{a}), // A -> a
        Rule.from(A, &.{b}), // A -> b
    }, S);

    defer grammar.deinit();

    try std.testing.expectEqual(S, grammar.start_symbol);
}

test "grammar view" {
    const grammar = try examples.ExpressionGrammar(std.testing.allocator);
    defer grammar.deinit();
    const view = grammar.toView();
    try std.testing.expectEqual(view.terminals.len, 5);
    try std.testing.expectEqual(view.non_terminals.len, 3);
    try std.testing.expectEqual(view.rules.len, 6);
    try std.testing.expectEqual(view.start_symbol, Symbol.from("exp"));
}

test "augmented grammar" {
    const allocator = std.testing.allocator;
    var grammar = try examples.ExpressionGrammar(allocator);
    defer grammar.deinit();
    try std.testing.expectEqual(Symbol.from("exp"), grammar.start_symbol);

    const augmented = try grammar.toAugmented();
    defer augmented.deinit();

    try std.testing.expectEqual(Symbol.from("S'"), augmented.start_symbol);

    std.debug.print("non_terminals:\n", .{});
    for (augmented.non_terminals.items) |non_terminal| {
        std.debug.print("{s}\n", .{non_terminal});
    }

    std.debug.print("rules:\n", .{});
    for (augmented.rules.items) |rule| {
        std.debug.print("{s}\n", .{rule});
    }
}
