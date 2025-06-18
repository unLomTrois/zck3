const std = @import("std");
const Grammar = @import("grammar.zig").Grammar;
const Symbol = @import("symbol.zig").Symbol;
const Rule = @import("rules.zig").Rule;

pub fn ExpressionGrammar() Grammar {
    const number = Symbol.from("number");
    const plus = Symbol.from("+");
    const times = Symbol.from("*");
    const lparen = Symbol.from("(");
    const rparen = Symbol.from(")");
    const exp = Symbol.from("exp");
    const term = Symbol.from("term");
    const factor = Symbol.from("factor");

    return Grammar.init(
        &.{ number, plus, times, lparen, rparen },
        &.{ exp, term, factor },
        &.{
            Rule.from(exp, &.{ exp, plus, term }),
            Rule.from(exp, &.{term}),
            Rule.from(term, &.{ term, times, factor }),
            Rule.from(term, &.{factor}),
            Rule.from(factor, &.{ lparen, exp, rparen }),
            Rule.from(factor, &.{number}),
        },
        exp,
    );
}

test "expression grammar" {
    const grammar = ExpressionGrammar();
    try std.testing.expectEqual(grammar.terminals.len, 5);
}
