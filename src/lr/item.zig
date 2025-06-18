const std = @import("std");
const grammar = @import("grammar");

const Symbol = grammar.Symbol;
const Rule = grammar.Rule;

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

    pub fn is_complete(self: Item) bool {
        return self.dot_pos >= self.rule.rhs.len;
    }

    pub fn next_symbol(self: Item) ?Symbol {
        if (self.is_complete()) {
            return null;
        }

        return self.rule.rhs[self.dot_pos];
    }

    /// e.g. S -> A b
    pub fn format(self: Item, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s} ->", .{self.rule.lhs.name});

        for (self.rule.rhs, 0..) |sym, i| {
            if (i == self.dot_pos) {
                try writer.print(" •", .{});
            }
            try writer.print(" {s}", .{sym.name});
        }

        if (self.dot_pos == self.rule.rhs.len) {
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
    item.dot_pos += 1;

    try std.testing.expectEqual(item.next_symbol(), B);
    // try std.testing.expectEqual(item.next_symbol(), null);
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
