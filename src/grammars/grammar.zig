const std = @import("std");

pub const Symbol = @import("symbol.zig").Symbol;
pub const Rule = @import("rules.zig").Rule;
pub const examples = @import("examples.zig");

const GrammarError = error{
    /// The start symbol was not found in the rules.
    /// E.g. the start symbol is S, but there is no rule that starts with S.
    StartSymbolNotFoundInRules,

    /// The start symbol is not a non-terminal.
    StartSymbolIsNotNonTerminal,
};

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

    pub fn init(terminals: []const Symbol, non_terminals: []const Symbol, rules: []const Rule, start_symbol: Symbol) GrammarError!Grammar {
        try check_start_rule(rules, start_symbol);
        try check_start_symbol(non_terminals, start_symbol);

        return Grammar{
            .terminals = terminals,
            .non_terminals = non_terminals,
            .rules = rules,
            .start_symbol = start_symbol,
        };
    }

    /// Checks that the start symbol exists in the rules.
    fn check_start_rule(rules: []const Rule, start_symbol: Symbol) !void {
        for (rules) |rule| {
            if (rule.lhs.eql(start_symbol)) {
                return;
            }
        }
        return GrammarError.StartSymbolNotFoundInRules;
    }

    fn check_start_symbol(non_terminals: []const Symbol, start_symbol: Symbol) !void {
        for (non_terminals) |non_terminal| {
            if (non_terminal.eql(start_symbol)) {
                return;
            }
        }
        return GrammarError.StartSymbolIsNotNonTerminal;
    }
};

test "grammar" {
    const S = Symbol.from("S");
    const A = Symbol.from("A");
    const a = Symbol.from("a");
    const b = Symbol.from("b");

    const grammar = try Grammar.init(&.{
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
