//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

/// Returns the slice with a leading UTF-8 BOM (EF BB BF) stripped off.
/// If there is no BOM the original slice is returned unchanged.
inline fn stripUtf8Bom(bytes: []const u8) []const u8 {
    if (bytes.len >= 3 and
        bytes[0] == 0xEF and
        bytes[1] == 0xBB and
        bytes[2] == 0xBF)
    {
        return bytes[3..];
    }
    return bytes;
}

test "stripUtf8Bom bom" {
    const raw_bytes = [_]u8{ 0xEF, 0xBB, 0xBF, 'l', 'o', 'l' };

    const bytes: []const u8 = stripUtf8Bom(&raw_bytes);

    try std.testing.expectEqual(bytes[0], 'l');
    try std.testing.expectEqual(bytes[1], 'o');
    try std.testing.expectEqual(bytes[2], 'l');
}

test "stripUtf8Bom no bom" {
    const raw_bytes = [_]u8{ 'l', 'o', 'l' };

    const bytes: []const u8 = stripUtf8Bom(&raw_bytes);

    try std.testing.expectEqual(bytes[0], 'l');
    try std.testing.expectEqual(bytes[1], 'o');
    try std.testing.expectEqual(bytes[2], 'l');
}

test "stripUtf8Bom bom and empty" {
    const raw_bytes = [_]u8{ 0xEF, 0xBB, 0xBF };
    const bytes: []const u8 = stripUtf8Bom(&raw_bytes);
    try std.testing.expect(bytes.len == 0);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // var args = try std.process.argsAlloc(allocator);
    // defer std.process.argsFree(allocator, args);

    // const exename = args[0];
    // args = args[1..];

    // try std.io.getStdOut().writer().print("{s}\n", .{exename});
    const stdout = std.io.getStdOut().writer();

    const file = try std.fs.cwd().openFile("kek.txt", .{});
    defer file.close();

    // todo: optimize using buffered reader
    const raw_bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(raw_bytes);
    std.debug.assert(std.unicode.utf8ValidateSlice(raw_bytes));

    const bytes = stripUtf8Bom(raw_bytes);

    const view = try std.unicode.Utf8View.init(bytes);
    var iterator = view.iterator();

    while (iterator.nextCodepoint()) |codepoint| {
        // '{c}' formats a u21 (Unicode scalar value) back to UTF-8
        try stdout.print("{u}\n", .{codepoint});
    }
}
