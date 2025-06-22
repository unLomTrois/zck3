const std = @import("std");
const Symbol = @import("symbol.zig").Symbol;

/// Rule is a production rule in a context-free grammar
pub const Rule = struct {
    lhs: Symbol,
    rhs: []const Symbol,

    /// Inline wrapper for rule creation
    pub inline fn from(lhs: Symbol, rhs: []const Symbol) Rule {
        return Rule{
            .lhs = lhs,
            .rhs = rhs,
        };
    }

    // pub fn fromAlloc(alloc: std.mem.Allocator, lhs: Symbol, rhs: []Symbol) !Rule {
    //     return Rule{
    //         .lhs = lhs,
    //         .rhs = try alloc.dupe(Symbol, rhs),
    //     };
    // }

    /// from const (static) slice to owned slice
    pub fn fromSlice(alloc: std.mem.Allocator, rules: []const Rule) ![]Rule {
        return try alloc.dupe(Rule, rules);
    }

    /// Formats the struct as a string into a writer.
    /// E.g. std.fmt.allocPrint, std.io.getStdOut().writer(), etc.
    /// Not intended to be used directly. Instead provide rule into args of std.fmt.allocPrint, etc.
    ///
    /// e.g. S -> A A
    /// Returns "S -> A A"
    pub fn format(self: *const Rule, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s} -> ", .{self.lhs});
        for (self.rhs, 0..) |symbol, i| {
            try writer.print("{s}", .{symbol});
            if (i < self.rhs.len - 1) {
                try writer.print(" ", .{});
            }
        }
    }
};

test "rule" {
    const rule = Rule.from(Symbol.from("S"), &.{ Symbol.from("A"), Symbol.from("A") });
    const str = try std.fmt.allocPrint(std.testing.allocator, "{s}", .{rule});
    defer std.testing.allocator.free(str);
    try std.testing.expectEqualStrings("S -> A A", str);
}
