const std = @import("std");

pub const Symbol = struct {
    name: []const u8,

    /// Inline wrapper for literal symbol creation
    /// deprecated: use fromAlloc instead
    /// prefer fromAlloc for all cases, it's more explicit and safer.
    /// Inlined symbols may not outlive the scope they are created in.
    pub inline fn from(name: []const u8) Symbol {
        return Symbol{ .name = name };
    }

    /// fromAlloc creates a symbol from a passed string, but also allocates the string inside the symbol
    /// It returns an unmanaged symbol, caller is responsible for freeing the string.
    /// Generally, you would use arena allocator for all three: grammar, rule, and symbol allocation.
    /// This is useful for creating symbols that are not known at compile time, but are known at runtime
    /// E.g. when parsing a grammar from a file
    pub fn fromAlloc(alloc: std.mem.Allocator, name: []const u8) !Symbol {
        return Symbol{ .name = try alloc.dupe(u8, name) };
    }

    pub fn deinit(self: *const Symbol, alloc: std.mem.Allocator) void {
        alloc.free(self.name);
    }

    /// Formats the struct as a string into a writer.
    /// E.g. std.fmt.allocPrint, std.io.getStdOut().writer(), etc.
    /// Not intended to be used directly. Instead provide symbol into args of std.fmt.allocPrint, etc.
    ///
    /// e.g. S
    /// Returns "S"
    pub fn format(self: *const Symbol, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s}", .{self.name});
    }

    /// eql compares two symbols by their name.
    pub fn eql(a: Symbol, b: Symbol) bool {
        return std.mem.eql(u8, a.name, b.name);
    }

    pub fn eqlTo(self: *const Symbol, other: Symbol) bool {
        return self.eql(other);
    }
};

test "symbol_from" {
    const symbol = try Symbol.fromAlloc(std.testing.allocator, "S");
    defer symbol.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(symbol.name, "S");
}

test "symbol_format" {
    const symbol = try Symbol.fromAlloc(std.testing.allocator, "S");
    defer symbol.deinit(std.testing.allocator);

    const str = try std.fmt.allocPrint(std.testing.allocator, "{s}", .{symbol});
    defer std.testing.allocator.free(str);

    try std.testing.expectEqualStrings(str, "S");
}

test "symbol_eql" {
    const symbol1 = try Symbol.fromAlloc(std.testing.allocator, "S");
    defer symbol1.deinit(std.testing.allocator);

    const symbol2 = try Symbol.fromAlloc(std.testing.allocator, "S");
    defer symbol2.deinit(std.testing.allocator);

    try std.testing.expect(Symbol.eql(symbol1, symbol2)); // equivalent to:
    try std.testing.expect(symbol1.eqlTo(symbol2));
}

test "symbol_fromAlloc" {
    const symbol = try Symbol.fromAlloc(std.testing.allocator, "S");
    defer symbol.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(symbol.name, "S");
}

/// Caller is responsible for freeing the symbol.
fn outOfScopeSymbol(alloc: std.mem.Allocator) !Symbol {
    const S = try Symbol.fromAlloc(alloc, "S");

    return S;
}

test "out of scope symbol" {
    const symbol = try outOfScopeSymbol(std.testing.allocator);
    defer symbol.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("S", symbol.name);
}

fn outOfScopeSlice(alloc: std.mem.Allocator) ![]const Symbol {
    const S = try Symbol.fromAlloc(alloc, "S");
    const A = try Symbol.fromAlloc(alloc, "A");
    const B = try Symbol.fromAlloc(alloc, "B");

    return try alloc.dupe(Symbol, &.{ S, A, B });
}

test "out of scope slice" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const syms = try outOfScopeSlice(alloc);

    for (syms) |sym| {
        std.debug.print("{s}\n", .{sym.name});
    }
}

// TODO: move following tests to rules.zig
const RuleLike = struct {
    lhs: Symbol,
    rhs: []const Symbol,

    fn from(lhs: Symbol, rhs: []const Symbol) RuleLike {
        return RuleLike{ .lhs = lhs, .rhs = rhs };
    }

    fn fromAlloc(alloc: std.mem.Allocator, lhs: Symbol, rhs: []const Symbol) !RuleLike {
        return RuleLike{ .lhs = lhs, .rhs = try alloc.dupe(Symbol, rhs) };
    }
};

fn outOfScopeRule(alloc: std.mem.Allocator) !RuleLike {
    const S = try Symbol.fromAlloc(alloc, "S");
    const A = try Symbol.fromAlloc(alloc, "A");
    const B = try Symbol.fromAlloc(alloc, "B");

    return try RuleLike.fromAlloc(alloc, S, &.{ A, B });
}

test "not failing out of scope rule" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const symbol_wrapper = try outOfScopeRule(alloc);

    try std.testing.expectEqualStrings("S", symbol_wrapper.lhs.name);
    try std.testing.expectEqualStrings("A", symbol_wrapper.rhs[0].name);
    try std.testing.expectEqualStrings("B", symbol_wrapper.rhs[1].name); // NOT SEGFAULT
}
