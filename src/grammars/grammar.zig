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

    pub fn deinit(self: *const Grammar, allocator: std.mem.Allocator) void {
        allocator.free(self.terminals);
        allocator.free(self.non_terminals);

        if (self.start_symbol.eql(Symbol.from("S'"))) {
            allocator.free(self.rules[0].rhs);
            self.start_symbol.deinit(allocator);
        }

        allocator.free(self.rules);
    }
};

pub const GrammarBuilder = struct {
    allocator: std.mem.Allocator,
    terminals: std.ArrayList(Symbol),
    non_terminals: std.ArrayList(Symbol),
    rules: std.ArrayList(Rule),
    start_symbol: Symbol,

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
        self.terminals.deinit();
        self.non_terminals.deinit();
        self.rules.deinit();
    }

    /// Returns a new static grammar. View does not own anything.
    pub fn View(self: *const GrammarBuilder) Grammar {
        return Grammar{
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
    pub fn toAugmented(self: *GrammarBuilder) error{OutOfMemory}!Grammar {
        const s_prime = try Symbol.fromAlloc(self.allocator, "S'");
        try self.non_terminals.insert(0, s_prime);

        const augmented_rule = Rule.from(
            s_prime,
            try Symbol.fromSlice(self.allocator, &.{self.start_symbol}),
        );
        try self.rules.insert(0, augmented_rule);

        self.start_symbol = s_prime;

        return self.toOwnedGrammar();
    }
};

test "grammar builder" {
    std.debug.print("grammar builder to static grammar\n", .{});
    const allocator = std.testing.allocator;

    const S = Symbol.from("S");
    const A = Symbol.from("A");
    const a = Symbol.from("a");
    const b = Symbol.from("b");

    const base_grammar = StaticGrammar.from(
        S,
        &.{ a, b },
        &.{ S, A },
        &.{Rule.from(S, &.{ A, A })},
    );

    var builder = try GrammarBuilder.fromStatic(allocator, base_grammar);
    defer builder.deinit();

    std.debug.print("before:\n{any}\n", .{builder.View()});

    try builder.non_terminals.insert(0, Symbol.from("S'"));
    try builder.rules.insert(0, Rule.from(Symbol.from("S'"), &.{S}));

    std.debug.print("after:\n{any}\n", .{builder.View()});
}

test "full conversion cycle: static → builder → owned → builder → static" {
    std.debug.print("\nfull conversion cycle test\n", .{});
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

    std.debug.print("1. Original static grammar: {any}\n", .{original_static});

    // Convert static → builder
    var builder1 = try GrammarBuilder.fromStatic(allocator, original_static);
    std.debug.print("2. After static → builder: {any}\n", .{builder1.View()});

    // Convert builder → owned
    const owned = try builder1.toOwnedGrammar();
    std.debug.print("3. After builder → owned: {any}\n", .{owned});

    // Convert owned → builder (by treating owned as static)
    var builder2 = try GrammarBuilder.fromOwned(allocator, owned);
    std.debug.print("4. After owned → builder: {any}\n", .{builder2.View()});

    // Convert builder → static
    const final_static = builder2.View();
    std.debug.print("5. Final static grammar: {any}\n", .{final_static});

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

    std.debug.print("✓ Full conversion cycle completed successfully!\n", .{});
}

// fn expressionGrammar(allocator: std.mem.Allocator) !Grammar {
//     const exp = try Symbol.fromAlloc(allocator, "exp");
//     const term = try Symbol.fromAlloc(allocator, "term");
//     const factor = try Symbol.fromAlloc(allocator, "factor");

//     const number = try Symbol.fromAlloc(allocator, "number");
//     const plus = try Symbol.fromAlloc(allocator, "+");
//     const times = try Symbol.fromAlloc(allocator, "*");
//     const lparen = try Symbol.fromAlloc(allocator, "(");
//     const rparen = try Symbol.fromAlloc(allocator, ")");

//     const terminals = try Symbol.fromSlice(allocator, &.{
//         number,
//         plus,
//         times,
//         lparen,
//         rparen,
//     });

//     const non_terminals = try Symbol.fromSlice(allocator, &.{ exp, term, factor });

//     const rules = try Rule.fromSlice(allocator, &.{
//         Rule.from(exp, try Symbol.fromSlice(allocator, &.{ exp, plus, term })),
//         Rule.from(exp, try Symbol.fromSlice(allocator, &.{term})),
//         Rule.from(term, try Symbol.fromSlice(allocator, &.{ term, times, factor })),
//         Rule.from(term, try Symbol.fromSlice(allocator, &.{factor})),
//     });

//     return Grammar{
//         .start_symbol = exp,
//         .terminals = terminals,
//         .non_terminals = non_terminals,
//         .rules = rules,
//     };
// }

test "expression grammar" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const grammar = try examples.ExpressionGrammar(allocator);

    std.debug.print("expression grammar:\n{any}\n", .{grammar});

    var builder = try GrammarBuilder.fromOwned(allocator, grammar);
    const augmented_grammar = try builder.toAugmented();

    std.debug.print("augmented grammar:\n{any}\n", .{augmented_grammar});
}

pub const GrammarError = error{
    /// The start symbol was not found in the rules.
    /// E.g. the start symbol is S, but there is no rule that starts with S.
    StartSymbolNotFoundInRules,

    /// The start symbol is not a non-terminal.
    StartSymbolIsNotNonTerminal,

    EmptyTerminals,
    EmptyNonTerminals,
    EmptyRules,

    DuplicateTerminal,
    DuplicateNonTerminal,
    OverlapBetweenSets,

    LhsIsTerminal,
    LhsIsNotNonTerminal,
    UnknownSymbolInRhs,

    UnreachableNonTerminal,
    NonProductiveNonTerminal,
} || std.mem.Allocator.Error; // OutOfMemory

pub const GrammarValidator = struct {
    const Self = @This();

    fn validate(grammar: *const StaticGrammar) GrammarError!void {
        try Self.validate_sets(grammar);
        try Self.validate_start_symbol(grammar);
    }

    fn validate_sets(grammar: *const StaticGrammar) error{
        EmptyTerminals,
        EmptyNonTerminals,
        EmptyRules,
    }!void {
        if (grammar.terminals.len == 0) {
            return GrammarError.EmptyTerminals;
        }
        if (grammar.non_terminals.len == 0) {
            return GrammarError.EmptyNonTerminals;
        }
        if (grammar.rules.len == 0) {
            return GrammarError.EmptyRules;
        }
    }

    fn validate_start_symbol(grammar: *const StaticGrammar) error{
        StartSymbolNotFoundInRules,
        StartSymbolIsNotNonTerminal,
    }!void {
        // First make sure at least one rule has the start symbol on the LHS.
        const found_in_rules = blk: {
            for (grammar.rules) |rule| {
                if (rule.lhs.eql(grammar.start_symbol)) {
                    break :blk true;
                }
            }
            break :blk false;
        };

        if (!found_in_rules) {
            return GrammarError.StartSymbolNotFoundInRules;
        }

        const found_in_non_terminals = blk: {
            for (grammar.non_terminals) |non_terminal| {
                if (non_terminal.eql(grammar.start_symbol)) {
                    break :blk true;
                }
            }
            break :blk false;
        };

        if (!found_in_non_terminals) {
            return GrammarError.StartSymbolIsNotNonTerminal;
        }
    }
};

test "GrammarError.StartSymbolNotFoundInRules" {
    const S = Symbol.from("S");
    const A = Symbol.from("A");
    const a = Symbol.from("a");

    const failing_grammar = StaticGrammar.from(
        S,
        &.{a},
        &.{ S, A },
        &.{
            // Rule.from(S, &.{A}), // This is missing
            Rule.from(A, &.{a}),
        },
    );

    GrammarValidator.validate(&failing_grammar) catch |err| {
        try std.testing.expectEqual(GrammarError.StartSymbolNotFoundInRules, err);
        return;
    };
}

test "GrammarError.StartSymbolIsNotNonTerminal" {
    const S = Symbol.from("S");
    const A = Symbol.from("A");
    const a = Symbol.from("a");

    const failing_grammar = StaticGrammar.from(
        S,
        &.{a},
        &.{
            // S, // This is missing
            A,
        },
        &.{
            Rule.from(S, &.{ A, A }),
            Rule.from(A, &.{a}),
        },
    );

    GrammarValidator.validate(&failing_grammar) catch |err| {
        try std.testing.expectEqual(GrammarError.StartSymbolIsNotNonTerminal, err);
        return;
    };
}
