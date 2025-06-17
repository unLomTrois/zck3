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
        &[_]Symbol{ number, plus, times, lparen, rparen },
        &[_]Symbol{ exp, term, factor },
        &[_]Rule{
            Rule.from(exp, &[_]Symbol{ exp, plus, term }),
            Rule.from(exp, &[_]Symbol{term}),
            Rule.from(term, &[_]Symbol{ term, times, factor }),
            Rule.from(term, &[_]Symbol{factor}),
            Rule.from(factor, &[_]Symbol{ lparen, exp, rparen }),
            Rule.from(factor, &[_]Symbol{number}),
        },
        exp,
    );
}

test "expression grammar" {
    const grammar = ExpressionGrammar();
    try std.testing.expectEqual(grammar.terminals.len, 5);
}
