const std = @import("std");

// TODO: look at other tokenizers for inspiration how to handle errors
// TODO: for now, maybe add invalid token type as Zig tokenizer does

// SIMD vector size - 16 bytes works well for most processors
const SIMD_SIZE = 16;
const SimdVector = @Vector(SIMD_SIZE, u8);

// Comptime constants for character classification
const CHAR_VECTORS = struct {
    const lower_a = @as(SimdVector, @splat('a'));
    const lower_z = @as(SimdVector, @splat('z'));
    const upper_a = @as(SimdVector, @splat('A'));
    const upper_z = @as(SimdVector, @splat('Z'));
    const underscore = @as(SimdVector, @splat('_'));
    const digit_0 = @as(SimdVector, @splat('0'));
    const digit_9 = @as(SimdVector, @splat('9'));
    const space = @as(SimdVector, @splat(' '));
    const tab = @as(SimdVector, @splat('\t'));
    const newline = @as(SimdVector, @splat('\n'));
    const cr = @as(SimdVector, @splat('\r'));
    const quote = @as(SimdVector, @splat('"'));
    const hash = @as(SimdVector, @splat('#'));
};

// Comptime lookup table for single-character classification
const CHAR_CLASS_TABLE = blk: {
    var table: [256]u8 = [_]u8{0} ** 256;

    // Set bits for different character classes
    const ALPHA_LOWER = 1;
    const ALPHA_UPPER = 2;
    const DIGIT = 4;
    const UNDERSCORE = 8;
    const WHITESPACE = 16;

    for ('a'..('z' + 1)) |c| table[c] |= ALPHA_LOWER;
    for ('A'..('Z' + 1)) |c| table[c] |= ALPHA_UPPER;
    for ('0'..('9' + 1)) |c| table[c] |= DIGIT;
    table['_'] |= UNDERSCORE;
    table[' '] |= WHITESPACE;
    table['\t'] |= WHITESPACE;
    table['\n'] |= WHITESPACE;
    table['\r'] |= WHITESPACE;

    break :blk table;
};

// Comptime function to check if character is identifier char
inline fn isIdentifierCharComptime(c: u8) bool {
    return (CHAR_CLASS_TABLE[c] & 15) != 0; // ALPHA_LOWER | ALPHA_UPPER | DIGIT | UNDERSCORE
}

// Comptime function to check if character is whitespace
inline fn isWhitespaceComptime(c: u8) bool {
    return (CHAR_CLASS_TABLE[c] & 16) != 0; // WHITESPACE
}

pub const Token = struct {
    tag: Tag,
    start: usize, // Start position in source
    end: usize, // End position in source

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        // Boolean literals (special values, not identifiers)
        .{ "yes", .literal_boolean },
        .{ "no", .literal_boolean },

        // Language constructs only
        .{ "scripted_effect", .keyword_scripted_effect },
        .{ "scripted_trigger", .keyword_scripted_trigger },
        .{ "namespace", .keyword_namespace },
    });

    pub fn getKeyword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        identifier,

        // Keywords (language constructs only)
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

    /// SIMD-optimized whitespace skipping with comptime constants
    fn skipWhitespace(self: *Lexer) void {
        // Fast path: use SIMD for bulk scanning
        while (self.pos + SIMD_SIZE <= self.buffer.len) {
            const chunk = self.loadSimdChunk();

            // Use comptime constants
            const is_space = chunk == CHAR_VECTORS.space;
            const is_tab = chunk == CHAR_VECTORS.tab;
            const is_newline = chunk == CHAR_VECTORS.newline;
            const is_cr = chunk == CHAR_VECTORS.cr;
            const is_whitespace = @select(bool, is_space, @as(@Vector(SIMD_SIZE, bool), @splat(true)), @select(bool, is_tab, @as(@Vector(SIMD_SIZE, bool), @splat(true)), @select(bool, is_newline, @as(@Vector(SIMD_SIZE, bool), @splat(true)), @select(bool, is_cr, @as(@Vector(SIMD_SIZE, bool), @splat(true)), @as(@Vector(SIMD_SIZE, bool), @splat(false))))));

            // Find first non-whitespace character
            const mask = @select(bool, is_whitespace, @as(@Vector(SIMD_SIZE, bool), @splat(false)), @as(@Vector(SIMD_SIZE, bool), @splat(true)));
            const first_non_ws = std.simd.firstTrue(mask);

            if (first_non_ws) |offset| {
                self.pos += offset;
                return;
            } else {
                // All characters in this chunk are whitespace
                self.pos += SIMD_SIZE;
            }
        }

        // Fallback using comptime lookup table
        while (!self.isAtEnd() and isWhitespaceComptime(self.peek())) {
            _ = self.advance();
        }
    }

    /// SIMD-optimized identifier scanning
    fn lexIdentifier(self: *Lexer) Token.Tag {
        const start = self.pos - 1; // We've already consumed the first character

        // Fast path: use SIMD for bulk scanning
        while (self.pos + SIMD_SIZE <= self.buffer.len) {
            const chunk = self.loadSimdChunk();
            const mask = self.createIdentifierMask(chunk);

            // Find first non-identifier character
            const non_id_mask = @select(bool, mask, @as(@Vector(SIMD_SIZE, bool), @splat(false)), @as(@Vector(SIMD_SIZE, bool), @splat(true)));
            const first_non_id = std.simd.firstTrue(non_id_mask);

            if (first_non_id) |offset| {
                self.pos += offset;
                break;
            } else {
                // All characters in this chunk are identifier characters
                self.pos += SIMD_SIZE;
            }
        }

        // Fallback for remaining characters
        while (isIdentifierCharComptime(self.peek())) {
            _ = self.advance();
        }

        // Fast path: eliminate most identifiers by checking first character
        // Keywords only start with 'y', 'n', or 's'
        const first_char = self.buffer[start];
        if (first_char == 'y' or first_char == 'n' or first_char == 's') {
            const identifier = self.buffer[start..self.pos];
            if (Token.getKeyword(identifier)) |tag| {
                return tag;
            }
        }

        return .identifier;
    }

    /// SIMD-optimized number scanning
    fn lexNumber(self: *Lexer) Token.Tag {
        // Fast path: use SIMD for bulk scanning
        while (self.pos + SIMD_SIZE <= self.buffer.len) {
            const chunk = self.loadSimdChunk();
            const mask = self.createDigitMask(chunk);

            // Find first non-digit character
            const non_digit_mask = @select(bool, mask, @as(@Vector(SIMD_SIZE, bool), @splat(false)), @as(@Vector(SIMD_SIZE, bool), @splat(true)));
            const first_non_digit = std.simd.firstTrue(non_digit_mask);

            if (first_non_digit) |offset| {
                self.pos += offset;
                return .literal_number;
            } else {
                // All characters in this chunk are digits
                self.pos += SIMD_SIZE;
            }
        }

        // Fallback for remaining characters
        while (self.peek() >= '0' and self.peek() <= '9') {
            _ = self.advance();
        }
        return .literal_number;
    }

    /// SIMD-optimized string scanning with comptime constants
    fn lexString(self: *Lexer) error{UnterminatedString}!Token.Tag {
        // Fast path: use SIMD to find quote character
        while (self.pos + SIMD_SIZE <= self.buffer.len) {
            const chunk = self.loadSimdChunk();
            const is_quote = chunk == CHAR_VECTORS.quote;

            const first_quote = std.simd.firstTrue(is_quote);
            if (first_quote) |offset| {
                self.pos += offset;
                _ = self.advance(); // consume closing quote
                return .literal_string;
            } else {
                self.pos += SIMD_SIZE;
            }
        }

        // Fallback for remaining characters
        while (self.peek() != '"' and !self.isAtEnd()) {
            _ = self.advance();
        }
        if (self.isAtEnd()) {
            return error.UnterminatedString;
        }
        _ = self.advance(); // consume closing quote

        return .literal_string;
    }

    /// SIMD-optimized comment skipping with comptime constants
    fn skipComment(self: *Lexer) void {
        // Fast path: use SIMD to find newline
        while (self.pos + SIMD_SIZE <= self.buffer.len) {
            const chunk = self.loadSimdChunk();
            const is_newline = chunk == CHAR_VECTORS.newline;

            const first_newline = std.simd.firstTrue(is_newline);
            if (first_newline) |offset| {
                self.pos += offset;
                return;
            } else {
                self.pos += SIMD_SIZE;
            }
        }

        // Fallback for remaining characters
        while (!self.isAtEnd() and self.peek() != '\n') {
            _ = self.advance();
        }
    }

    /// Load a SIMD-sized chunk from the current position
    inline fn loadSimdChunk(self: *Lexer) SimdVector {
        std.debug.assert(self.pos + SIMD_SIZE <= self.buffer.len);
        const chunk_bytes = self.buffer[self.pos .. self.pos + SIMD_SIZE];

        // Use unaligned load to avoid alignment issues
        var result: SimdVector = undefined;
        const result_bytes = @as([*]u8, @ptrCast(&result))[0..SIMD_SIZE];
        @memcpy(result_bytes, chunk_bytes);
        return result;
    }

    /// Create a mask for identifier characters using SIMD with comptime constants
    fn createIdentifierMask(self: *Lexer, chunk: SimdVector) @Vector(SIMD_SIZE, bool) {
        _ = self; // suppress unused parameter warning

        // Use comptime constants for better optimization
        const is_lower = @select(bool, chunk >= CHAR_VECTORS.lower_a, chunk <= CHAR_VECTORS.lower_z, @as(@Vector(SIMD_SIZE, bool), @splat(false)));
        const is_upper = @select(bool, chunk >= CHAR_VECTORS.upper_a, chunk <= CHAR_VECTORS.upper_z, @as(@Vector(SIMD_SIZE, bool), @splat(false)));
        const is_underscore = chunk == CHAR_VECTORS.underscore;
        const is_digit = @select(bool, chunk >= CHAR_VECTORS.digit_0, chunk <= CHAR_VECTORS.digit_9, @as(@Vector(SIMD_SIZE, bool), @splat(false)));

        return @select(bool, is_lower, @as(@Vector(SIMD_SIZE, bool), @splat(true)), @select(bool, is_upper, @as(@Vector(SIMD_SIZE, bool), @splat(true)), @select(bool, is_underscore, @as(@Vector(SIMD_SIZE, bool), @splat(true)), @select(bool, is_digit, @as(@Vector(SIMD_SIZE, bool), @splat(true)), @as(@Vector(SIMD_SIZE, bool), @splat(false))))));
    }

    /// Create a mask for digit characters using SIMD with comptime constants
    fn createDigitMask(self: *Lexer, chunk: SimdVector) @Vector(SIMD_SIZE, bool) {
        _ = self; // suppress unused parameter warning

        return @select(bool, chunk >= CHAR_VECTORS.digit_0, chunk <= CHAR_VECTORS.digit_9, @as(@Vector(SIMD_SIZE, bool), @splat(false)));
    }
};

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
    try testTokenize("scope:father", &.{
        .identifier, .colon, .identifier,
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

test "Language constructs and event targets" {
    // Event targets should be parsed as identifiers
    try testTokenize("scope:father", &.{
        .identifier, .colon, .identifier,
    });
    try testTokenize("root.father", &.{
        .identifier, .dot, .identifier,
    });
    try testTokenize("prev.culture", &.{
        .identifier, .dot, .identifier,
    });

    // Language constructs should be keywords
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
