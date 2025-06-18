const std = @import("std");
const grammars = @import("grammars");

const Symbol = grammars.Symbol;
const Rule = grammars.Rule;

/// Item represents an LR parsing item.
/// It is a production rule with a dot position.
/// The dot position indicates the position of the next symbol to be parsed.
/// The dot position is 0 for the first symbol of the production rule.
pub const Item = struct {
    rule: Rule,
    dot_pos: usize,

    pub fn init(rule: Rule, dot_pos: usize) Item {
        return Item{
            .rule = rule,
            .dot_pos = dot_pos,
        };
    }

    /// The item is complete if the dot is at the end of the rule
    ///
    /// e.g. S -> A B •
    pub fn is_complete(self: Item) bool {
        return self.dot_pos >= self.rule.rhs.len;
    }

    /// The next symbol is the symbol after the dot.
    /// Also advances the dot position.
    ///
    /// e.g. in "S -> A • B", the next symbol is B
    pub fn next_symbol(self: *Item) ?Symbol {
        if (self.is_complete()) {
            return null;
        }

        defer self.dot_pos += 1;

        return self.rule.rhs[self.dot_pos];
    }

    /// Formats the struct as a string into a writer.
    /// E.g. std.fmt.allocPrint, std.io.getStdOut().writer(), etc.
    /// Not intended to be used directly. Instead provide item into args of std.fmt.allocPrint, etc.
    ///
    /// e.g. S -> A B •
    /// Returns "S -> A B •"
    pub fn format(self: *const Item, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s} ->", .{self.rule.lhs.name});

        for (self.rule.rhs, 0..) |sym, i| {
            if (i == self.dot_pos) {
                try writer.print(" •", .{});
            }
            try writer.print(" {s}", .{sym.name});
        }

        if (self.is_complete()) {
            try writer.print(" •", .{});
        }
    }
};

test "next symbol" {
    const S = Symbol.from("S");
    const A = Symbol.from("A");
    const B = Symbol.from("B");

    // S -> A B
    const rule = Rule.from(S, &[_]Symbol{ A, B });
    var item = Item.init(rule, 0);

    try std.testing.expectEqual(item.next_symbol(), A);
    try std.testing.expectEqual(item.next_symbol(), B);
    try std.testing.expectEqual(item.next_symbol(), null);
}

test "item_format" {
    const S = Symbol.from("S");
    const A = Symbol.from("A");
    const B = Symbol.from("B");

    // S -> A B
    const rule = Rule.from(S, &[_]Symbol{ A, B });
    var item = Item.init(rule, 0);

    const cases = [_][]const u8{ "S -> • A B", "S -> A • B", "S -> A B •" };

    const allocator = std.testing.allocator;
    for (cases) |case| {
        const str = try std.fmt.allocPrint(allocator, "{s}", .{item});
        defer allocator.free(str);
        defer item.dot_pos += 1;
        try std.testing.expectEqualStrings(case, str);
    }
}
