const Symbol = @import("symbol.zig").Symbol;

/// Rule is a production rule in a context-free grammar
pub const Rule = struct {
    lhs: Symbol,
    rhs: []const Symbol,

    /// Create a new rule from a left-hand side symbol and a right-hand side sequence of symbols.
    pub fn from(lhs: Symbol, rhs: []const Symbol) Rule {
        return Rule{
            .lhs = lhs,
            .rhs = rhs,
        };
    }
};
