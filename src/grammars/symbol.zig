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
    pub fn format(self: Symbol, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s}", .{self.name});
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
