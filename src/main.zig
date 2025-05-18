//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const bom = @import("bom.zig");

fn openFile(filepath: []const u8) std.fs.File.OpenError!std.fs.File {
    return std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
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

    const filepath = "kek.txt";
    const file = try openFile(filepath);
    defer file.close();

    // todo: optimize using buffered reader
    const raw_bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(raw_bytes);
    std.debug.assert(std.unicode.utf8ValidateSlice(raw_bytes));

    const bytes = bom.stripUtf8Bom(raw_bytes);

    var utf8 = (try std.unicode.Utf8View.init(bytes)).iterator();
    while (utf8.nextCodepointSlice()) |codepoint| {
        try stdout.print("{s}", .{codepoint});
    }
    try stdout.writeByte('\n');
}
