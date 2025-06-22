const std = @import("std");
const Grammar = @import("grammar.zig").Grammar;
const Symbol = @import("symbol.zig").Symbol;
const Rule = @import("rules.zig").Rule;
const GrammarBuilder = @import("grammar.zig").GrammarBuilder;
const StaticGrammar = @import("grammar.zig").StaticGrammar;

/// Caller must deinit the grammar.
pub fn ExpressionGrammar(allocator: std.mem.Allocator) !Grammar {
    const number = Symbol.from("number");
    const plus = Symbol.from("+");
    const times = Symbol.from("*");
    const lparen = Symbol.from("(");
    const rparen = Symbol.from(")");
    const exp = Symbol.from("exp");
    const term = Symbol.from("term");
    const factor = Symbol.from("factor");

    var builder = try GrammarBuilder.fromStatic(allocator, StaticGrammar.from(
        exp,
        &.{ number, plus, times, lparen, rparen },
        &.{ exp, term, factor },
        &.{
            Rule.from(exp, &.{ exp, plus, term }), // exp -> exp + term
            Rule.from(exp, &.{term}), // exp -> term
            Rule.from(term, &.{ term, times, factor }), // term -> term * factor
            Rule.from(term, &.{factor}), // term -> factor
            Rule.from(factor, &.{ lparen, exp, rparen }), // factor -> ( exp )
            Rule.from(factor, &.{number}), // factor -> number
        },
    ));

    return try builder.toOwnedGrammar();
}

test "expression grammar" {
    const allocator = std.testing.allocator;
    const grammar = try ExpressionGrammar(allocator);
    defer grammar.deinit(allocator);
    try std.testing.expectEqual(grammar.terminals.len, 5);
}

test "augmented expression grammar" {
    const allocator = std.testing.allocator;
    const grammar = try ExpressionGrammar(allocator);

    var builder = try GrammarBuilder.fromOwned(allocator, grammar);
    defer builder.deinit();

    const augmented_grammar = try builder.toAugmented();
    defer augmented_grammar.deinit(allocator);

    try std.testing.expect(augmented_grammar.start_symbol.eql(Symbol.from("S'")));
    try std.testing.expectEqual(5, augmented_grammar.terminals.len);
    try std.testing.expectEqual(4, augmented_grammar.non_terminals.len);
    try std.testing.expectEqual(7, augmented_grammar.rules.len);
}
