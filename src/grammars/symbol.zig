const std = @import("std");

pub const Symbol = struct {
    name: []const u8,

    /// Inline wrapper for symbol creation
    /// deprecated: use fromAlloc instead
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

    /// Formats the struct as a string into a writer.
    /// E.g. std.fmt.allocPrint, std.io.getStdOut().writer(), etc.
    /// Not intended to be used directly. Instead provide symbol into args of std.fmt.allocPrint, etc.
    ///
    /// e.g. S
    /// Returns "S"
    pub fn format(self: *const Symbol, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s}", .{self.name});
    }

    pub fn eql(self: *const Symbol, other: Symbol) bool {
        return std.mem.eql(u8, self.name, other.name);
    }

    pub fn hash(self: *const Symbol) u64 {
        return std.hash.RapidHash.hash(0, self.name);
    }

    pub fn eqlHash(self: *const Symbol, other: Symbol) bool {
        return self.hash() == other.hash();
    }
};

test "symbol_from" {
    const symbol = Symbol.from("S");
    try std.testing.expectEqualStrings(symbol.name, "S");
}

test "symbol_format" {
    const symbol = Symbol.from("S");
    const str = try std.fmt.allocPrint(std.testing.allocator, "{s}", .{symbol});
    defer std.testing.allocator.free(str);
    try std.testing.expectEqualStrings(str, "S");
}

test "symbol_eql" {
    const symbol1 = Symbol.from("S");
    const symbol2 = Symbol.from("S");
    try std.testing.expect(symbol1.eql(symbol2));
}

test "symbol_hash" {
    const symbol = Symbol.from("S");
    const symbol2 = Symbol.from("S");
    try std.testing.expect(symbol.eqlHash(symbol2));
}

test "symbol_allocFrom" {
    const symbol = try Symbol.fromAlloc(std.testing.allocator, "S");
    defer std.testing.allocator.free(symbol.name);
    try std.testing.expectEqualStrings(symbol.name, "S");
}

fn outOfScope(alloc: std.mem.Allocator) !Symbol {
    const S = try Symbol.fromAlloc(alloc, "S");

    return S;
}

test "symbol_allocOutOfScope" {
    const alloc = std.testing.allocator;
    const symbol = try outOfScope(alloc);
    defer alloc.free(symbol.name);

    try std.testing.expectEqualStrings("S", symbol.name);
}

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

fn not_failingOutOfScope(alloc: std.mem.Allocator) !RuleLike {
    const S = try Symbol.fromAlloc(alloc, "S");
    const A = try Symbol.fromAlloc(alloc, "A");
    const B = try Symbol.fromAlloc(alloc, "B");

    return try RuleLike.fromAlloc(alloc, S, &.{ A, B });
}

test "not failingOutOfScope" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const symbol_wrapper = try not_failingOutOfScope(alloc);

    try std.testing.expectEqualStrings("A", symbol_wrapper.rhs[0].name);
    try std.testing.expectEqualStrings("B", symbol_wrapper.rhs[1].name); // NOT SEGFAULT
}

fn symbols(alloc: std.mem.Allocator) ![]const Symbol {
    const S = try Symbol.fromAlloc(alloc, "S");
    const A = try Symbol.fromAlloc(alloc, "A");
    const B = try Symbol.fromAlloc(alloc, "B");

    return try alloc.dupe(Symbol, &.{ S, A, B });
}

test "symbols" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const syms = try symbols(alloc);

    for (syms) |sym| {
        std.debug.print("{s}\n", .{sym.name});
    }
}
