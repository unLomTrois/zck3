//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const lexer_mod = @import("lexer.zig");
const Lexer = lexer_mod.Lexer;

fn openFile(filepath: []const u8) std.fs.File.OpenError!std.fs.File {
    return std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stdout = std.io.getStdOut().writer();

    const filepath = "hello_world.txt";
    const file = try openFile(filepath);
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(bytes);
    std.debug.assert(std.unicode.utf8ValidateSlice(bytes));

    var lexer = Lexer.init(bytes);
    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);

    for (tokens) |token| {
        try stdout.print("{s}: {s}\n", .{ @tagName(token.type), token.value });
    }
}
