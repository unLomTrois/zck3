const std = @import("std");

pub const TokenType = enum {
    Keyword,
    Identifier,
    Literal,
    Operator,
    Delimiter,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,
};

pub const Lexer = struct {
    source: []const u8,
    pos: usize,

    pub fn init(source_code: []const u8) Lexer {
        return Lexer{
            .source = source_code,
            .pos = 0,
        };
    }

    /// Caller owns the returned slice and must free it with the same allocator.
    pub fn lex(self: *Lexer, allocator: std.mem.Allocator) ![]const Token {
        var tokens = std.ArrayList(Token).init(allocator);
        while (!self.isAtEnd()) {
            const start_pos = self.pos;
            const c = self.advance();
            const token_type = switch (c) {
                'a'...'z', 'A'...'Z', '_' => self.lexIdentifier(),
                '=' => TokenType.Operator,
                ' ', '\t', '\n', '\r' => {
                    continue;
                },
                else => {
                    std.log.err("Unknown character: {c} at {}", .{ c, self.pos });
                    return error.UnknownCharacter;
                },
            };

            const token = Token{
                .type = token_type,
                .value = self.source[start_pos..self.pos],
            };

            try tokens.append(token);
        }
        return try tokens.toOwnedSlice();
    }

    inline fn isAtEnd(self: *Lexer) bool {
        return self.pos >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        defer self.pos += 1;
        std.debug.assert(self.pos < self.source.len);
        return self.source[self.pos];
    }

    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) {
            return 0;
        }
        return self.source[self.pos];
    }

    fn lexIdentifier(self: *Lexer) TokenType {
        while (isIdentifierChar(self.peek())) {
            _ = self.advance();
        }
        return TokenType.Identifier;
    }
};

fn isIdentifierChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

test "Lexer" {
    const source_code = "key = value";
    var lexer = Lexer.init(source_code);

    const allocator = std.testing.allocator;
    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);

    try std.testing.expectEqual(3, tokens.len);

    for (tokens) |token| {
        std.debug.print("{s}: {s}\n", .{ @tagName(token.type), token.value });
    }

    try std.testing.expectEqualDeep(Token{
        .type = TokenType.Identifier,
        .value = "key",
    }, tokens[0]);
    try std.testing.expectEqualDeep(Token{
        .type = TokenType.Operator,
        .value = "=",
    }, tokens[1]);
    try std.testing.expectEqualDeep(Token{
        .type = TokenType.Identifier,
        .value = "value",
    }, tokens[2]);
}
