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
                '"' => try self.lexString(),
                '=', '.', ':' => TokenType.Operator,
                ' ', '\t', '\n', '\r' => {
                    continue;
                },
                '{', '}' => TokenType.Delimiter,
                '0'...'9' => self.lexNumber(),
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

    fn lexNumber(self: *Lexer) TokenType {
        while (std.ascii.isDigit(self.peek())) {
            _ = self.advance();
        }
        return TokenType.Literal;
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

        return TokenType.Literal;
    }
};

fn isIdentifierChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

test "Field assignment" {
    const source_code = "key = value";
    var lexer = Lexer.init(source_code);
    const allocator = std.testing.allocator;
    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);
    const expected = [_]Token{
        .{ .type = TokenType.Identifier, .value = "key" },
        .{ .type = TokenType.Operator, .value = "=" },
        .{ .type = TokenType.Identifier, .value = "value" },
    };
    try std.testing.expectEqual(expected.len, tokens.len);
    for (expected, tokens) |exp, got| {
        try std.testing.expectEqualDeep(exp, got);
    }
}

test "Numbers" {
    const source_code = "123 456";
    var lexer = Lexer.init(source_code);
    const allocator = std.testing.allocator;
    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);
    const expected = [_]Token{
        .{ .type = TokenType.Literal, .value = "123" },
        .{ .type = TokenType.Literal, .value = "456" },
    };
    try std.testing.expectEqual(expected.len, tokens.len);
    for (expected, tokens) |exp, got| {
        try std.testing.expectEqualDeep(exp, got);
    }
}

test "Strings" {
    const source_code = "\"test string\"";
    var lexer = Lexer.init(source_code);
    const allocator = std.testing.allocator;
    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);
    const expected = [_]Token{
        .{ .type = TokenType.Literal, .value = "\"test string\"" },
    };
    try std.testing.expectEqual(expected.len, tokens.len);
    for (expected, tokens) |exp, got| {
        try std.testing.expectEqualDeep(exp, got);
    }
}

test "Blocks" {
    const source_code = "{ }";
    var lexer = Lexer.init(source_code);
    const allocator = std.testing.allocator;
    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);
    const expected = [_]Token{
        .{ .type = TokenType.Delimiter, .value = "{" },
        .{ .type = TokenType.Delimiter, .value = "}" },
    };
    try std.testing.expectEqual(expected.len, tokens.len);
    for (expected, tokens) |exp, got| {
        try std.testing.expectEqualDeep(exp, got);
    }
}

test "Dot notation" {
    const source_code = "test_events.1";
    var lexer = Lexer.init(source_code);
    const allocator = std.testing.allocator;
    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);
    const expected = [_]Token{
        .{ .type = TokenType.Identifier, .value = "test_events" },
        .{ .type = TokenType.Operator, .value = "." },
        .{ .type = TokenType.Literal, .value = "1" },
    };
    try std.testing.expectEqual(expected.len, tokens.len);
    for (expected, tokens) |exp, got| {
        try std.testing.expectEqualDeep(exp, got);
    }
}

test "Colon notation" {
    const source_code = "scope:father";
    var lexer = Lexer.init(source_code);
    const allocator = std.testing.allocator;
    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);
    const expected = [_]Token{
        .{ .type = TokenType.Identifier, .value = "scope" },
        .{ .type = TokenType.Operator, .value = ":" },
        .{ .type = TokenType.Identifier, .value = "father" },
    };
    try std.testing.expectEqual(expected.len, tokens.len);
    for (expected, tokens) |exp, got| {
        try std.testing.expectEqualDeep(exp, got);
    }
}

test "Complex input" {
    const source_code =
        \\namespace = "test_events"
        \\test_events.1 = { 
        \\  title = "Test Event"
        \\}
    ;

    var lexer = Lexer.init(source_code);
    const allocator = std.testing.allocator;
    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);

    const expected = [_]Token{
        .{ .type = TokenType.Identifier, .value = "namespace" },
        .{ .type = TokenType.Operator, .value = "=" },
        .{ .type = TokenType.Literal, .value = "\"test_events\"" },
        .{ .type = TokenType.Identifier, .value = "test_events" },
        .{ .type = TokenType.Operator, .value = "." },
        .{ .type = TokenType.Literal, .value = "1" },
        .{ .type = TokenType.Operator, .value = "=" },
        .{ .type = TokenType.Delimiter, .value = "{" },
        .{ .type = TokenType.Identifier, .value = "title" },
        .{ .type = TokenType.Operator, .value = "=" },
        .{ .type = TokenType.Literal, .value = "\"Test Event\"" },
        .{ .type = TokenType.Delimiter, .value = "}" },
    };

    try std.testing.expectEqual(expected.len, tokens.len);
    for (expected, tokens) |exp, got| {
        try std.testing.expectEqualDeep(exp, got);
    }
}
