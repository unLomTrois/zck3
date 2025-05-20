const std = @import("std");

pub const TokenType = enum {
    keyword,
    identifier,
    literal,
    // Operators
    equal, // =
    dot, // .
    colon, // :
    at, // @
    // Delimiters
    l_brace, // {
    r_brace, // }
    l_bracket, // [
    r_bracket, // ]
    comment,
};

// TODO: add position tracking
pub const Token = struct {
    type: TokenType,
    value: []const u8,
};

// TODO: apply iterator pattern to make it more efficient (allocation-free)
// TODO: rewrite to a Finite State Machine
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
            const token_type: TokenType = switch (c) {
                'a'...'z', 'A'...'Z', '_' => self.lexIdentifier(),
                '"' => try self.lexString(),
                '=' => .equal,
                '.' => .dot,
                ':' => .colon,
                '@' => .at,
                '{' => .l_brace,
                '}' => .r_brace,
                '[' => .l_bracket,
                ']' => .r_bracket,
                '0'...'9' => self.lexNumber(),
                else => {
                    if (std.ascii.isWhitespace(c)) {
                        self.skipWhitespace();
                        continue;
                    } else if (c == '#') {
                        self.skipComment();
                        continue;
                    }

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
        return .identifier;
    }

    fn lexNumber(self: *Lexer) TokenType {
        while (std.ascii.isDigit(self.peek())) {
            _ = self.advance();
        }
        return .literal;
    }

    fn lexString(self: *Lexer) !TokenType {
        while (self.peek() != '"' and !self.isAtEnd()) {
            _ = self.advance();
        }
        if (self.isAtEnd()) {
            std.log.err("Unterminated string at {}", .{self.pos});
            return error.UnterminatedString;
        }
        _ = self.advance(); // consume closing quote

        return .literal;
    }

    fn skipWhitespace(self: *Lexer) void {
        while (std.ascii.isWhitespace(self.peek())) {
            _ = self.advance();
        }
    }

    fn skipComment(self: *Lexer) void {
        while (self.peek() != '\n' and !self.isAtEnd()) {
            _ = self.advance();
        }
    }
};

fn isIdentifierChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

/// Helper function for testing the lexer without boilerplate code.
fn expectTokens(source_code: []const u8, expected: []const TokenType) !void {
    var lexer = Lexer.init(source_code);
    const allocator = std.testing.allocator;
    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);
    try std.testing.expectEqual(expected.len, tokens.len);

    try std.testing.expectEqual(expected.len, tokens.len);
    for (expected, tokens) |exp, got| {
        try std.testing.expectEqual(exp, got.type);
    }
}

test "Numbers" {
    try expectTokens("123 456", &.{
        .literal, .literal,
    });
}

test "Strings" {
    try expectTokens("\"test string\"", &.{
        .literal,
    });
}

test "Field assignment" {
    try expectTokens("key = value", &.{
        .identifier, .equal, .identifier,
    });
}

test "Block assignment" {
    try expectTokens("key = { }", &.{
        .identifier, .equal, .l_brace, .r_brace,
    });
}

test "Literal assignment" {
    try expectTokens("key = 123", &.{
        .identifier, .equal, .literal,
    });
    try expectTokens("namespace = \"test_events\"", &.{
        .identifier, .equal, .literal,
    });
}

test "Dot notation" {
    try expectTokens("test_events.1", &.{
        .identifier, .dot, .literal,
    });
}

test "Colon notation" {
    try expectTokens("scope:father", &.{
        .identifier, .colon, .identifier,
    });
}

test "Complex input" {
    try expectTokens("namespace = \"test_events\"", &.{
        .identifier, .equal, .literal,
    });
    try expectTokens(
        \\test_events.1 = {
        \\  title = "Test Event"
        \\}
    , &.{
        .identifier, .dot,     .literal,
        .equal,      .l_brace, .identifier,
        .equal,      .literal, .r_brace,
    });
}

test "@At-constants" {
    try expectTokens("@knight = \"path/to/file\"", &.{
        .at, .identifier, .equal, .literal,
    });
    try expectTokens("icon = @knight", &.{
        .identifier, .equal, .at, .identifier,
    });
}

test "@At-compute" {
    try expectTokens("@key = @[value]", &.{
        .at,        .identifier, .equal,     .at,
        .l_bracket, .identifier, .r_bracket,
    });
}

test "Comments" { // TODO: add comments support
    try expectTokens("# This is a comment\nkey = value#inline-comment", &.{
        .identifier, .equal, .identifier,
    });
}

test "Unknown character" { // TODO: add error handling
    try std.testing.expect(true);
}
