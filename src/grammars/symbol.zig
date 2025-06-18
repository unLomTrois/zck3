const std = @import("std");

pub const Symbol = struct {
    name: []const u8,

    /// Create a new symbol from an arbitrary string.
    pub fn from(name: []const u8) Symbol {
        return Symbol{ .name = name };
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
