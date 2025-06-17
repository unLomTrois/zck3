/// This is a simple LR-parser for simple math expressions.
const std = @import("std");
const Lexer = @import("simple_lexer.zig").Lexer;
const Token = @import("simple_lexer.zig").Token;

// LR(1) Grammar:
// exp -> exp "+" term | term .
// term -> term "*" factor | factor .
// factor -> "(" exp ")" | number .

const Node = struct {
    kind: Kind,
    children: []Node,
    data: Data,

    const Kind = enum {
        // Non-terminal
        exp,
        term,
        factor,

        // Terminal
        number,
        plus,
        times,
        lparen,
        rparen,
    };

    const Data = union(enum) {
        number: usize,
        plus,
        times,
        lparen,
        rparen,

        fn from(token: Token) Data {
            return switch (token.kind) {
                .number => .{ .number = std.fmt.parseInt(usize, token.value, 10) catch unreachable },
                .plus => .plus,
                .times => .times,
                .lparen => .lparen,
                .rparen => .rparen,
                else => unreachable,
            };
        }
    };
};

const ParseError = error{ SyntaxError, OutOfMemory };

const Parser = struct {
    lexer: *Lexer,
    allocator: std.mem.Allocator,
    state_stack: std.ArrayList(u8),
    node_stack: std.ArrayList(Node),
    current_token: Token,
    lookahead_token: ?Token,

    const convert_map = std.StaticStringMap(Node.Kind).initComptime(.{
        .{ "exp", .exp },
        .{ "term", .term },
        .{ "factor", .factor },
        .{ "number", .number },
        .{ "plus", .plus },
        .{ "times", .times },
    });

    const State = u8;
    const Action = union(enum) {
        shift: State,
        reduce: u8,
        accept,
        err,
    };

    pub fn init(lexer: *Lexer, allocator: std.mem.Allocator) Parser {
        return .{
            .lexer = lexer,
            .allocator = allocator,
            .state_stack = std.ArrayList(State).init(allocator),
            .node_stack = std.ArrayList(Node).init(allocator),
            .current_token = lexer.next(),
            .lookahead_token = null,
        };
    }

    pub fn parse(self: *Parser) ParseError!Node {
        try self.state_stack.append(0);

        while (true) {
            const state = self.state_stack.items[self.state_stack.items.len - 1];
            const action = self.getAction(state, self.current_token.kind);

            switch (action) {
                .shift => |s| {
                    try self.node_stack.append(Node{
                        .kind = convert_map.get(@tagName(self.current_token.kind)) orelse unreachable,
                        .children = &.{},
                        .data = Node.Data.from(self.current_token),
                    });
                    try self.state_stack.append(s);
                    self.current_token = self.lexer.next();
                },
                .reduce => |prod| {
                    const production = productions[prod];
                    const children = try self.allocator.alloc(Node, production.rhs_len);
                    const start = self.node_stack.items.len - production.rhs_len;
                    @memcpy(children, self.node_stack.items[start..]);
                    self.node_stack.shrinkRetainingCapacity(start);
                    self.state_stack.shrinkRetainingCapacity(start + 1);

                    const new_node = Node{
                        .kind = production.lhs,
                        .children = children,
                        .data = undefined,
                    };
                    try self.node_stack.append(new_node);

                    const new_state = self.getGoto(self.state_stack.items[self.state_stack.items.len - 1], production.lhs);
                    try self.state_stack.append(new_state);
                },
                .accept => return self.node_stack.items[0],
                .err => return error.SyntaxError,
            }
        }
    }

    fn getAction(_: *Parser, state: State, token_kind: Token.Kind) Action {
        return switch (state) {
            0 => switch (token_kind) {
                .number => .{ .shift = 5 },
                .lparen => .{ .shift = 4 },
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            1 => switch (token_kind) {
                .plus => .{ .shift = 6 },
                .eof => .accept,
                .rparen => .{ .shift = 11 },
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            2 => switch (token_kind) {
                .plus => .{ .reduce = 1 },
                .times => .{ .shift = 7 },
                .rparen, .eof => .{ .reduce = 1 },
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            3 => switch (token_kind) {
                .plus, .times, .rparen, .eof => .{ .reduce = 3 },
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            4 => switch (token_kind) {
                .number => .{ .shift = 5 },
                .lparen => .{ .shift = 4 },
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            5 => switch (token_kind) {
                .plus, .times, .rparen, .eof => .{ .reduce = 5 },
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            6 => switch (token_kind) {
                .number => .{ .shift = 5 },
                .lparen => .{ .shift = 4 },
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            7 => switch (token_kind) {
                .number => .{ .shift = 5 },
                .lparen => .{ .shift = 4 },
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            8 => switch (token_kind) {
                .plus => .{ .shift = 6 },
                .rparen => .{ .shift = 11 },
                .eof => .accept,
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            9 => switch (token_kind) {
                .plus, .times, .rparen, .eof => .{ .reduce = 0 },
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            10 => switch (token_kind) {
                .plus, .times, .rparen, .eof => .{ .reduce = 2 },
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            11 => switch (token_kind) {
                .plus, .times, .rparen, .eof => .{ .reduce = 4 },
                else => blk: {
                    std.debug.print("State: {d}, Error: Unexpected token: {s}\n", .{ state, @tagName(token_kind) });
                    break :blk .err;
                },
            },
            else => blk: {
                std.debug.print("State: else, Error: Unexpected token: {s}\n", .{@tagName(token_kind)});
                break :blk .err;
            },
        };
    }

    fn getGoto(_: *Parser, state: State, nt: Node.Kind) State {
        return switch (state) {
            0 => switch (nt) {
                .exp => 1,
                .term => 2,
                .factor => 3,
                else => 0,
            },
            4 => switch (nt) {
                .exp => 8,
                .term => 2,
                .factor => 3,
                else => 0,
            },
            6 => switch (nt) {
                .term => 9,
                .factor => 3,
                else => 0,
            },
            7 => switch (nt) {
                .factor => 10,
                else => 0,
            },
            else => 0,
        };
    }
};

const Production = struct {
    lhs: Node.Kind,
    rhs_len: usize,
};

const productions = [_]Production{
    .{ .lhs = .exp, .rhs_len = 3 }, // 0: exp -> exp + term
    .{ .lhs = .exp, .rhs_len = 1 }, // 1: exp -> term
    .{ .lhs = .term, .rhs_len = 3 }, // 2: term -> term * factor
    .{ .lhs = .term, .rhs_len = 1 }, // 3: term -> factor
    .{ .lhs = .factor, .rhs_len = 3 }, // 4: factor -> ( exp )
    .{ .lhs = .factor, .rhs_len = 1 }, // 5: factor -> number
};

fn evaluateNode(node: Node) usize {
    // std.debug.print("Evaluating node: {any}\n\n", .{node});

    return switch (node.kind) {
        .exp => if (node.children.len == 1)
            evaluateNode(node.children[0])
        else
            evaluateNode(node.children[0]) + evaluateNode(node.children[2]),
        .term => if (node.children.len == 1)
            evaluateNode(node.children[0])
        else
            evaluateNode(node.children[0]) * evaluateNode(node.children[2]),
        .factor => if (node.children.len == 1)
            evaluateNode(node.children[0])
        else
            unreachable,
        .number => node.data.number,
        else => unreachable,
    };
}

test "Node.Data.from" {
    const token = Token{ .kind = .number, .value = "1" };
    const data = Node.Data.from(token);
    try std.testing.expectEqual(@as(usize, 1), data.number);
}

// Function that prints the tree using visitor pattern
fn printTree(node: Node) void {
    switch (node.kind) {
        .exp => {
            std.debug.print("exp\n", .{});
            if (node.children.len > 0) {
                printTree(node.children[0]);
            }
            if (node.children.len > 1) {
                printTree(node.children[1]);
            }
        },
        .term => {
            std.debug.print("term\n", .{});
            if (node.children.len > 0) {
                printTree(node.children[0]);
            }
        },
        .factor => {
            std.debug.print("factor\n", .{});
            if (node.children.len > 0) {
                printTree(node.children[0]);
            }
        },
        .number => {
            std.debug.print("number: {any}\n", .{node.data.number});
        },
        else => unreachable,
    }
}

test "1" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lexer = Lexer.init("1");
    var parser = Parser.init(&lexer, allocator);
    const result = try parser.parse();
    try std.testing.expectEqual(Node.Kind.exp, result.kind);

    printTree(result);

    std.debug.print("Result: {any}\n", .{result.children[0].children[0].children[0].data.number});

    // evaluate the result
    const value = evaluateNode(result);
    try std.testing.expectEqual(@as(usize, 1), value);
}

test "1+2" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lexer = Lexer.init("1+2");
    var parser = Parser.init(&lexer, allocator);
    const result = try parser.parse();
    try std.testing.expectEqual(@as(usize, 3), evaluateNode(result));
}

test "1*2" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lexer = Lexer.init("1*2");
    var parser = Parser.init(&lexer, allocator);
    const result = try parser.parse();
    try std.testing.expectEqual(@as(usize, 2), evaluateNode(result));
}

test "1+2*3" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lexer = Lexer.init("1+2*3");
    var parser = Parser.init(&lexer, allocator);
    const result = try parser.parse();
    try std.testing.expectEqual(@as(usize, 7), evaluateNode(result)); // Should be 1+(2*3) = 7
}

// test "(1+2)*3" {
//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();
//     const allocator = arena.allocator();

//     var lexer = Lexer.init("(1+2)*3");
//     var parser = Parser.init(&lexer, allocator);
//     const result = try parser.parse();
//     try std.testing.expectEqual(@as(usize, 9), evaluateNode(result)); // Should be (1+2)*3 = 9
// }
