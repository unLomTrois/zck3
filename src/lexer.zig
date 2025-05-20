const std = @import("std");

pub const TokenType = enum {
    keyword,
    identifier,
    literal_number,
    literal_string,
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
    eof,
};

pub const Token = struct {
    type: TokenType,
    start: usize, // Start position in source
    end: usize, // End position in source

    pub fn getValue(self: Token, source: []const u8) []const u8 {
        return source[self.start..self.end];
    }
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

    pub fn next(self: *Lexer) Token {
        self.skipWhitespace();
        if (self.isAtEnd()) {
            return Token{
                .type = .eof,
                .start = self.pos,
                .end = self.pos,
            };
        }

        const start_pos = self.pos;
        const c = self.advance();

        const token_type: TokenType = switch (c) {
            'a'...'z', 'A'...'Z', '_' => self.lexIdentifier(),
            '"' => self.lexString() catch .eof, // Return EOF on error for now
            '=' => .equal,
            '.' => .dot,
            ':' => .colon,
            '@' => .at,
            '{' => .l_brace,
            '}' => .r_brace,
            '[' => .l_bracket,
            ']' => .r_bracket,
            '0'...'9' => self.lexNumber(),
            '#' => {
                self.skipComment();
                return self.next(); // Skip comment and return next token
            },
            else => {
                // Skip unknown characters for now and return next token
                std.log.err("Unknown character: {c} at {}", .{ c, self.pos - 1 });
                return self.next();
            },
        };

        return Token{
            .type = token_type,
            .start = start_pos,
            .end = self.pos,
        };
    }

    inline fn isAtEnd(self: *Lexer) bool {
        return self.pos >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        defer self.pos += 1;
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
        return .literal_number;
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

        return .literal_string;
    }

    fn skipWhitespace(self: *Lexer) void {
        while (!self.isAtEnd() and std.ascii.isWhitespace(self.peek())) {
            _ = self.advance();
        }
    }

    fn skipComment(self: *Lexer) void {
        while (!self.isAtEnd() and self.peek() != '\n') {
            _ = self.advance();
        }
    }
};

fn isIdentifierChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

/// Helper function for testing the lexer without boilerplate code.
fn testTokenize(source_code: []const u8, expected: []const TokenType) !void {
    var lexer = Lexer.init(source_code);

    for (expected) |expected_token_type| {
        const token = lexer.next();
        try std.testing.expectEqual(expected_token_type, token.type);
    }

    // Last token should always be EOF
    const last_token = lexer.next();
    try std.testing.expectEqual(TokenType.eof, last_token.type);
}

test "Numbers" {
    try testTokenize("123 456", &.{
        .literal_number, .literal_number,
    });
}

test "Strings" {
    try testTokenize("\"test string\"", &.{
        .literal_string,
    });
}

test "Field assignment" {
    try testTokenize("key = value", &.{
        .identifier, .equal, .identifier,
    });
}

test "Block assignment" {
    try testTokenize("key = { }", &.{
        .identifier, .equal, .l_brace, .r_brace,
    });
}

test "Literal assignment" {
    try testTokenize("key = 123", &.{
        .identifier, .equal, .literal_number,
    });
    try testTokenize("namespace = \"test_events\"", &.{
        .identifier, .equal, .literal_string,
    });
}

test "Dot notation" {
    try testTokenize("test_events.1", &.{
        .identifier, .dot, .literal_number,
    });
}

test "Colon notation" {
    try testTokenize("scope:father", &.{
        .identifier, .colon, .identifier,
    });
}

test "Complex input" {
    try testTokenize("namespace = \"test_events\"", &.{
        .identifier, .equal, .literal_string,
    });
    try testTokenize(
        \\test_events.1 = {
        \\  title = "Test Event"
        \\}
    , &.{
        .identifier, .dot,            .literal_number,
        .equal,      .l_brace,        .identifier,
        .equal,      .literal_string, .r_brace,
    });
}

test "@At-constants" {
    try testTokenize("@knight = \"path/to/file\"", &.{
        .at, .identifier, .equal, .literal_string,
    });
    try testTokenize("icon = @knight", &.{
        .identifier, .equal, .at, .identifier,
    });
}

test "@At-compute" {
    try testTokenize("@key = @[value]", &.{
        .at,        .identifier, .equal,     .at,
        .l_bracket, .identifier, .r_bracket,
    });
}

test "Comments" {
    try testTokenize("# This is a comment\nkey = value#inline-comment", &.{
        .identifier, .equal, .identifier,
    });
}
