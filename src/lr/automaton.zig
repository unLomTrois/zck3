const std = @import("std");

pub const Item = @import("item.zig");

pub const Automaton = struct {
    items: []Item,
};

pub fn init(items: []Item) Automaton {
    return Automaton{
        .items = items,
    };
}

test "automaton" {
    _ = Automaton{
        .items = &[_]Item{},
    };

    try std.testing.expect(true);
}
