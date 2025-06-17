const std = @import("std");

const Symbol = @import("symbol.zig").Symbol;
const Rule = @import("rules.zig").Rule;

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
