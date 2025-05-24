const std = @import("std");

// TODO: look at other tokenizers for inspiration how to handle errors
// TODO: for now, maybe add invalid token type as Zig tokenizer does

pub const Token = struct {
    tag: Tag,
    start: usize, // Start position in source
    end: usize, // End position in source

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "yes", .literal_boolean },
        .{ "no", .literal_boolean },
        .{ "scope", .keyword_scope },
        .{ "root", .keyword_root },
        .{ "prev", .keyword_prev },
        .{ "this", .keyword_this },
        .{ "scripted_effect", .keyword_scripted_effect },
        .{ "scripted_trigger", .keyword_scripted_trigger },
        .{ "namespace", .keyword_namespace },
    });

    pub fn getKeyword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        identifier,

        // Keywords
        keyword_scope,
        keyword_root,
        keyword_prev,
        keyword_this,
        keyword_scripted_effect,
        keyword_scripted_trigger,
        keyword_namespace,

        // Literals
        literal_number,
        literal_string,
        literal_boolean,
        // Delimiters
        l_brace, // {
        r_brace, // }
        l_bracket, // [
        r_bracket, // ]

        // Arithmetic operators
        plus, // +
        minus, // -
        multiply, // *
        divide, // /

        // Comparison operators
        greater_than, // >
        greater_equal, // >=
        less_than, // <
        less_equal, // <=

        // Assignment operators
        equal, // =

        // Equality operators
        equal_equal, // ==
        not_equal, // !=
        question_equal, // ?=

        // Scope resolution operators
        dot, // .
        colon, // :
        at, // @

        comment,
        invalid, // Used for lexical errors
        eof,
    };

    pub fn getValue(self: Token, source: []const u8) []const u8 {
        return source[self.start..self.end];
    }
};

// TODO: think about to rewrite as a finite state machine
pub const Lexer = struct {
    buffer: []const u8,
    pos: usize,

    pub fn init(buffer: []const u8) Lexer {
        return Lexer{
            .buffer = buffer,
            // Skip the UTF-8 BOM if present.
            .pos = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0,
        };
    }

    pub fn next(self: *Lexer) Token {
        self.skipWhitespace();
        if (self.isAtEnd()) {
            return Token{
                .tag = .eof,
                .start = self.pos,
                .end = self.pos,
            };
        }

        const start_pos = self.pos;
        const c = self.advance();

        const tag: Token.Tag = switch (c) {
            'a'...'z', 'A'...'Z', '_' => self.lexIdentifier(),
            '"' => self.lexString() catch |err| {
                switch (err) {
                    error.UnterminatedString => {
                        // Return invalid token for unterminated string
                        return Token{
                            .tag = .invalid,
                            .start = start_pos,
                            .end = self.pos,
                        };
                    },
                    else => unreachable,
                }
            },
            '=' => blk: {
                if (self.peek() == '=') {
                    _ = self.advance(); // consume the second '='
                    break :blk .equal_equal;
                } else {
                    break :blk .equal; // just a single '='
                }
            },
            '!' => blk: {
                if (self.peek() == '=') {
                    _ = self.advance(); // consume '='
                    break :blk .not_equal;
                } else {
                    break :blk .invalid; // Lone '!' is invalid
                }
            },
            '>' => blk: {
                if (self.peek() == '=') {
                    _ = self.advance(); // consume '='
                    break :blk .greater_equal;
                } else {
                    break :blk .greater_than;
                }
            },
            '<' => blk: {
                if (self.peek() == '=') {
                    _ = self.advance(); // consume '='
                    break :blk .less_equal;
                } else {
                    break :blk .less_than;
                }
            },
            '?' => blk: {
                if (self.peek() == '=') {
                    _ = self.advance(); // consume '='
                    break :blk .question_equal;
                } else {
                    break :blk .invalid; // Lone '?' is invalid
                }
            },
            '.' => .dot,
            ':' => .colon,
            '@' => .at,
            '{' => .l_brace,
            '}' => .r_brace,
            '[' => .l_bracket,
            ']' => .r_bracket,
            '+' => .plus,
            '-' => .minus,
            '*' => .multiply,
            '/' => .divide,
            '0'...'9' => self.lexNumber(),
            '#' => {
                self.skipComment();
                return self.next(); // Skip comment and return next token
            },
            else => {
                // std.log.err("Unknown character: {c} at {}", .{ c, self.pos - 1 });
                // Return invalid token for unknown character
                return Token{
                    .tag = .invalid,
                    .start = start_pos,
                    .end = self.pos,
                };
            },
        };

        return Token{
            .tag = tag,
            .start = start_pos,
            .end = self.pos,
        };
    }

    inline fn isAtEnd(self: *Lexer) bool {
        return self.pos >= self.buffer.len;
    }

    fn advance(self: *Lexer) u8 {
        std.debug.assert(self.pos < self.buffer.len);
        const c = self.buffer[self.pos];
        self.pos += 1;
        return c;
    }

    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) {
            return 0;
        }
        return self.buffer[self.pos];
    }

    fn lexIdentifier(self: *Lexer) Token.Tag {
        const start = self.pos - 1; // We've already consumed the first character

        while (isIdentifierChar(self.peek())) {
            _ = self.advance();
        }

        // Check if the identifier is a special token
        const identifier = self.buffer[start..self.pos];
        if (Token.getKeyword(identifier)) |tag| {
            return tag;
        }

        return .identifier;
    }

    fn lexNumber(self: *Lexer) Token.Tag {
        while (std.ascii.isDigit(self.peek())) {
            _ = self.advance();
        }
        return .literal_number;
    }

    fn lexString(self: *Lexer) error{UnterminatedString}!Token.Tag {
        while (self.peek() != '"' and !self.isAtEnd()) {
            _ = self.advance();
        }
        if (self.isAtEnd()) {
            //std.log.err("Unterminated string at {}", .{self.pos});
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
fn testTokenize(source_code: []const u8, expected: []const Token.Tag) !void {
    var lexer = Lexer.init(source_code);

    for (expected) |expected_token_type| {
        const token = lexer.next();
        try std.testing.expectEqual(expected_token_type, token.tag);
    }

    // Last token should always be EOF
    const last_token = lexer.next();
    try std.testing.expectEqual(.eof, last_token.tag);
}

test "UTF-8 BOM" {
    const source = "\xEF\xBB\xBFkey = value";
    try testTokenize(source, &.{
        .identifier, .equal, .identifier,
    });
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
    try testTokenize("key = { key2 = value }", &.{
        .identifier, .equal, .l_brace, .identifier, .equal, .identifier, .r_brace,
    });

    try testTokenize("key = { r g b }", &.{
        .identifier, .equal, .l_brace, .identifier, .identifier, .identifier, .r_brace,
    });
}

test "Literal assignment" {
    try testTokenize("key = 123", &.{
        .identifier, .equal, .literal_number,
    });
    try testTokenize("namespace = \"test_events\"", &.{
        .keyword_namespace, .equal, .literal_string,
    });
}

test "Dot notation" {
    try testTokenize("test_events.1", &.{
        .identifier, .dot, .literal_number,
    });
}

test "Colon notation" {
    // TODO: "scope" probably needs to be a keyword
    try testTokenize("scope:father", &.{
        .keyword_scope, .colon, .identifier,
    });
}

test "Complex input" {
    try testTokenize("namespace = \"test_events\"", &.{
        .keyword_namespace, .equal, .literal_string,
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
    // AST: ConstantDeclaration(name, LiteralString)
    try testTokenize("@knight = \"path/to/file\"", &.{
        .at, .identifier, .equal, .literal_string,
    });
    // AST: field with AtConstantReference value
    try testTokenize("icon = @knight", &.{
        .identifier, .equal, .at, .identifier,
    });
}

test "@At-compute" {
    // AST: ConstantDeclaration(name, AtExpression(Identifier))
    try testTokenize("@key = @[value]", &.{
        .at,        .identifier, .equal,     .at,
        .l_bracket, .identifier, .r_bracket,
    });
}

test "@At-compute with arithmetic" {
    // AST: ConstantDeclaration(name, AtExpression(BinaryOperation))
    try testTokenize("@total = @[1+2]", &.{
        .at,        .identifier,     .equal, .at,
        .l_bracket, .literal_number, .plus,  .literal_number,
        .r_bracket,
    });

    try testTokenize("@result = @[10-5*2/1]", &.{
        .at,        .identifier,     .equal,  .at,
        .l_bracket, .literal_number, .minus,  .literal_number,
        .multiply,  .literal_number, .divide, .literal_number,
        .r_bracket,
    });
}

test "Comments" {
    try testTokenize("# This is a comment\nkey = value#inline-comment", &.{
        .identifier, .equal, .identifier,
    });
}

test "Token.getValue" {
    const source = "key = value";
    var lexer = Lexer.init(source);
    try std.testing.expectEqualStrings("key", lexer.next().getValue(source));
    try std.testing.expectEqualStrings("=", lexer.next().getValue(source));
    try std.testing.expectEqualStrings("value", lexer.next().getValue(source));
}

test "Invalid characters" {
    try testTokenize("key $= value", &.{
        .identifier, .invalid, .equal, .identifier,
    });
}

test "Unterminated string" {
    try testTokenize("key = \"unterminated", &.{
        .identifier, .equal, .invalid,
    });
}

test "Comparison and Equality Operators" {
    try testTokenize("a > b", &.{
        .identifier, .greater_than, .identifier,
    });
    try testTokenize("a >= b", &.{
        .identifier, .greater_equal, .identifier,
    });
    try testTokenize("x < y", &.{
        .identifier, .less_than, .identifier,
    });
    try testTokenize("x <= y", &.{
        .identifier, .less_equal, .identifier,
    });
    try testTokenize("val1 == val2", &.{
        .identifier, .equal_equal, .identifier,
    });
    try testTokenize("val1 != val2", &.{
        .identifier, .not_equal, .identifier,
    });
    try testTokenize("check ?= default", &.{
        .identifier, .question_equal, .identifier,
    });
    try testTokenize("a!b", &.{
        .identifier, .invalid, .identifier, // Lone ! is invalid
    });
    try testTokenize("a?b", &.{
        .identifier, .invalid, .identifier, // Lone ? is invalid
    });
    try testTokenize("! cmd", &.{
        .invalid, .identifier, // Lone ! is invalid
    });
    try testTokenize("? arg", &.{
        .invalid, .identifier, // Lone ? is invalid
    });
}

test "Boolean literals" {
    try testTokenize("yes", &.{
        .literal_boolean,
    });
    try testTokenize("no", &.{
        .literal_boolean,
    });
    try testTokenize("key = yes", &.{
        .identifier, .equal, .literal_boolean,
    });
    try testTokenize("key = no", &.{
        .identifier, .equal, .literal_boolean,
    });
}

test "Keywords" {
    try testTokenize("scope:father", &.{
        .keyword_scope, .colon, .identifier,
    });
    try testTokenize("root.father", &.{
        .keyword_root, .dot, .identifier,
    });
    try testTokenize("prev.culture", &.{
        .keyword_prev, .dot, .identifier,
    });
    try testTokenize("scripted_effect add_gold_effect = {", &.{
        .keyword_scripted_effect, .identifier, .equal, .l_brace,
    });
    try testTokenize("scripted_trigger has_enough_gold = {", &.{
        .keyword_scripted_trigger, .identifier, .equal, .l_brace,
    });
    try testTokenize("namespace = \"test_events\"", &.{
        .keyword_namespace, .equal, .literal_string,
    });
}
