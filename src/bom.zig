const std = @import("std");

// TODO: remove because the lexer now handles this.

/// Returns the slice with a leading UTF-8 BOM (EF BB BF) stripped off.
/// If there is no BOM the original slice is returned unchanged.
pub inline fn stripUtf8Bom(bytes: []const u8) []const u8 {
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
