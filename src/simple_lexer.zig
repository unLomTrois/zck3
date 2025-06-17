/// This is a simple lexer for simple math expressions.
const std = @import("std");

pub const Token = struct {
    value: []const u8,
    kind: Kind,
    pub const Kind = enum {
        // Literals
        number, // 123
        lparen, // (
        rparen, // )

        // Operators
        plus, // +
        minus, // -
        times, // *
        divide, // /

        eof, // End of file
    };
};

// Uses iterator pattern and does not allocate memory.
pub const Lexer = struct {
    source: []const u8,
    pos: usize,

    pub fn init(source: []const u8) Lexer {
        return Lexer{ .source = source, .pos = 0 };
    }

    pub fn next(self: *Lexer) Token {
        // Skip whitespace
        while (self.pos < self.source.len and std.ascii.isWhitespace(self.source[self.pos])) {
            self.pos += 1;
        }

        if (self.pos >= self.source.len) {
            return Token{ .kind = .eof, .value = "" };
        }

        const start_pos = self.pos;
        const c = self.source[self.pos];

        const kind: Token.Kind = switch (c) {
            '0'...'9' => blk: {
                // Scan all consecutive digits
                while (self.pos < self.source.len and std.ascii.isDigit(self.source[self.pos])) {
                    self.pos += 1;
                }
                break :blk .number;
            },
            '(' => blk: {
                self.pos += 1;
                break :blk .lparen;
            },
            ')' => blk: {
                self.pos += 1;
                break :blk .rparen;
            },
            '+' => blk: {
                self.pos += 1;
                break :blk .plus;
            },
            '-' => blk: {
                self.pos += 1;
                break :blk .minus;
            },
            '*' => blk: {
                self.pos += 1;
                break :blk .times;
            },
            '/' => blk: {
                self.pos += 1;
                break :blk .divide;
            },
            else => unreachable,
        };

        return Token{ .kind = kind, .value = self.source[start_pos..self.pos] };
    }
};

fn testTokenize(source: []const u8, expected: []const Token.Kind) !void {
    var lexer = Lexer.init(source);

    for (expected) |expected_token_type| {
        const token = lexer.next();
        try std.testing.expectEqual(expected_token_type, token.kind);
    }

    // Last token should always be EOI (end of input)
    const last_token = lexer.next();
    try std.testing.expectEqual(Token{ .kind = .eof, .value = "" }, last_token);
}

test "1+2" {
    try testTokenize("1+2", &.{ .number, .plus, .number });
}

test "1*2" {
    try testTokenize("1*2", &.{ .number, .times, .number });
}

test "1+2*3" {
    std.testing.expect(false);

    try testTokenize("1+2*3", &.{ .number, .plus, .number, .times, .number });
}

test "(1+2)*3" {
    try testTokenize("(1+2)*3", &.{ .lparen, .number, .plus, .number, .rparen, .times, .number });
}
