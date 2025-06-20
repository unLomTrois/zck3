const std = @import("std");

const grammars = @import("grammars");

const Symbol = grammars.Symbol;
const Grammar = grammars.Grammar;

pub const Item = @import("item.zig");

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

    fn build(self: *Automaton) !void {
        const start_rule = self.grammar.start_rule();
        const start_item = Item.from(start_rule);
        const closure = Closure.from(self.allocator, &.{start_item});
        const state = State.from(self.allocator, &.{closure});
        try self.states.append(state);
    }
};

// test "automaton" {
//     const grammar = try grammars.examples.ExpressionGrammar(std.testing.allocator);

//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();
//     const allocator = arena.allocator();
//     const automaton = Automaton.init(allocator, grammar);

//     try std.testing.expect(automaton.states.items.len == 0);
// }
