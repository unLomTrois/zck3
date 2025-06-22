const std = @import("std");

pub const Symbol = @import("symbol.zig").Symbol;
pub const Rule = @import("rules.zig").Rule;
pub const examples = @import("examples.zig");
pub const validator = @import("validator.zig");

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
pub const StaticGrammar = struct {
    start_symbol: Symbol,
    terminals: []const Symbol,
    non_terminals: []const Symbol,
    rules: []const Rule,

    /// Creates a new static grammar.
    /// To modify the grammar, use GrammarBuilder.
    pub fn from(
        start_symbol: Symbol,
        terminals: []const Symbol,
        non_terminals: []const Symbol,
        rules: []const Rule,
    ) StaticGrammar {
        return StaticGrammar{
            .start_symbol = start_symbol,
            .terminals = terminals,
            .non_terminals = non_terminals,
            .rules = rules,
        };
    }
};

pub const Grammar = struct {
    start_symbol: Symbol,
    terminals: []Symbol,
    non_terminals: []Symbol,
    rules: []Rule,
    is_augmented: bool = false,

    pub fn deinit(self: *const Grammar, allocator: std.mem.Allocator) void {
        allocator.free(self.terminals);
        allocator.free(self.non_terminals);
        if (self.is_augmented) {
            allocator.free(self.rules[0].rhs);
        }
        allocator.free(self.rules);
    }

    pub fn asStatic(self: *const Grammar) StaticGrammar {
        return StaticGrammar{
            .start_symbol = self.start_symbol,
            .terminals = self.terminals,
            .non_terminals = self.non_terminals,
            .rules = self.rules,
        };
    }
};

pub const GrammarBuilder = struct {
    allocator: std.mem.Allocator,
    terminals: std.ArrayList(Symbol),
    non_terminals: std.ArrayList(Symbol),
    rules: std.ArrayList(Rule),
    start_symbol: Symbol,
    was_moved: bool = false, // If the GrammarBuilder was moved, we don't need to free the memory.

    pub fn fromStatic(
        allocator: std.mem.Allocator,
        base_grammar: StaticGrammar,
    ) error{OutOfMemory}!GrammarBuilder {
        // Copy slices to owned memory.
        const terminals = try Symbol.fromSlice(allocator, base_grammar.terminals);
        const non_terminals = try Symbol.fromSlice(allocator, base_grammar.non_terminals);
        const rules = try Rule.fromSlice(allocator, base_grammar.rules);

        return GrammarBuilder{
            .allocator = allocator,
            .terminals = std.ArrayList(Symbol).fromOwnedSlice(allocator, terminals),
            .non_terminals = std.ArrayList(Symbol).fromOwnedSlice(allocator, non_terminals),
            .rules = std.ArrayList(Rule).fromOwnedSlice(allocator, rules),
            .start_symbol = base_grammar.start_symbol,
        };
    }

    pub fn fromOwned(
        allocator: std.mem.Allocator,
        base_grammar: Grammar,
    ) error{OutOfMemory}!GrammarBuilder {
        return GrammarBuilder{
            .allocator = allocator,
            .terminals = std.ArrayList(Symbol).fromOwnedSlice(allocator, base_grammar.terminals),
            .non_terminals = std.ArrayList(Symbol).fromOwnedSlice(allocator, base_grammar.non_terminals),
            .rules = std.ArrayList(Rule).fromOwnedSlice(allocator, base_grammar.rules),
            .start_symbol = base_grammar.start_symbol,
        };
    }

    pub fn deinit(self: *const GrammarBuilder) void {
        if (self.was_moved) {
            std.log.warn("GrammarBuilder data was moved, no need to deinit\n", .{});
        }

        self.terminals.deinit();
        self.non_terminals.deinit();
        self.rules.deinit();
    }

    /// Returns a new static grammar. View does not own anything.
    pub fn View(self: *const GrammarBuilder) StaticGrammar {
        return StaticGrammar{
            .start_symbol = self.start_symbol,
            .terminals = self.terminals.items,
            .non_terminals = self.non_terminals.items,
            .rules = self.rules.items,
        };
    }

    /// Grammar takes ownership of the underlying memory of the GrammarBuilder.
    /// Caller must free the memory.
    pub fn toOwnedGrammar(self: *GrammarBuilder) !Grammar {
        return Grammar{
            .start_symbol = self.start_symbol,
            .terminals = try self.terminals.toOwnedSlice(),
            .non_terminals = try self.non_terminals.toOwnedSlice(),
            .rules = try self.rules.toOwnedSlice(),
        };
    }

    /// Adds a new start symbol S' and a new rule S' -> S.
    /// Returns a new StaticGrammar that takes ownership of the underlying memory of the GrammarBuilder.
    /// Caller must free the memory.
    pub inline fn toAugmented(self: *GrammarBuilder) error{OutOfMemory}!Grammar {
        self.was_moved = true;

        const s_prime = Symbol.from("S'");
        try self.non_terminals.insert(0, s_prime);

        const augmented_rule = Rule.from(s_prime, try Symbol.fromSlice(
            self.allocator,
            &.{self.start_symbol},
        ));
        try self.rules.insert(0, augmented_rule);
        self.start_symbol = s_prime;

        return Grammar{
            .start_symbol = self.start_symbol,
            .terminals = try self.terminals.toOwnedSlice(),
            .non_terminals = try self.non_terminals.toOwnedSlice(),
            .rules = try self.rules.toOwnedSlice(),
            .is_augmented = true,
        };
    }
};

test "full conversion cycle: static → builder → owned → builder → static" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Start with a static grammar
    const S = Symbol.from("S");
    const A = Symbol.from("A");
    const a = Symbol.from("a");
    const b = Symbol.from("b");

    const original_static = StaticGrammar.from(
        S,
        &.{ a, b },
        &.{ S, A },
        &.{
            Rule.from(S, &.{ A, A }),
            Rule.from(A, &.{a}),
            Rule.from(A, &.{b}),
        },
    );

    // Convert static → builder
    var builder1 = try GrammarBuilder.fromStatic(allocator, original_static);
    // Convert builder → owned
    const owned = try builder1.toOwnedGrammar();
    // Convert owned → builder (by treating owned as static)
    var builder2 = try GrammarBuilder.fromOwned(allocator, owned);
    // Convert builder → static
    const final_static = builder2.View();

    // Verify the cycle preserved the grammar structure
    try std.testing.expectEqual(original_static.start_symbol, final_static.start_symbol);
    try std.testing.expectEqual(original_static.terminals.len, final_static.terminals.len);
    try std.testing.expectEqual(original_static.non_terminals.len, final_static.non_terminals.len);
    try std.testing.expectEqual(original_static.rules.len, final_static.rules.len);

    // Verify terminal symbols are equivalent
    for (original_static.terminals, final_static.terminals) |orig, final| {
        try std.testing.expect(Symbol.eql(orig, final));
    }

    // Verify non-terminal symbols are equivalent
    for (original_static.non_terminals, final_static.non_terminals) |orig, final| {
        try std.testing.expect(Symbol.eql(orig, final));
    }
}

test "expression grammar" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const grammar = try examples.ExpressionGrammar(allocator);

    std.log.info("expression grammar:\n{any}\n", .{grammar});

    var builder = try GrammarBuilder.fromOwned(allocator, grammar);
    const augmented_grammar = try builder.toAugmented();

    std.log.info("augmented grammar:\n{any}\n", .{augmented_grammar});
}

test "grammar validation" {
    const allocator = std.testing.allocator;
    const grammar = try examples.ExpressionGrammar(allocator);
    defer grammar.deinit(allocator);

    validator.GrammarValidator.validate(&grammar.asStatic()) catch |err| {
        std.log.err("grammar validation failed: {any}\n", .{err});
        unreachable; // No error for a valid grammar.
    };
}
