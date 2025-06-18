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
    terminals: []const Symbol,
    non_terminals: []const Symbol,
    rules: []const Rule,
    start_symbol: Symbol,

    pub fn init(terminals: []const Symbol, non_terminals: []const Symbol, rules: []const Rule, start_symbol: Symbol) Grammar {
        return Grammar{
            .terminals = terminals,
            .non_terminals = non_terminals,
            .rules = rules,
            .start_symbol = start_symbol,
        };
    }
};

test "grammar" {
    const S = Symbol.from("S");
    const A = Symbol.from("A");
    const a = Symbol.from("a");
    const b = Symbol.from("b");

    const grammar = Grammar.init(&.{
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

    try std.testing.expectEqual(S, grammar.start_symbol);
}
