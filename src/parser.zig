const std = @import("std");
const RuleSet = @import("ruleset.zig").RuleSet;
const PriorityQueue = std.PriorityQueue;
const ArrayList = std.ArrayList;

const Node = struct {
    rule: usize, //rule index in ruleset
    cursor: usize, //cursor index in buffer
};

pub const Parser = struct {
    ruleset: RuleSet,
    nodes: ArrayList(Node),

    master: ArrayList(usize), //index in .nodes of master node (where info is stored)
    caller: ArrayList(usize), //index in .nodes of caller to this rule
    returns: ArrayList(usize), //index in .nodes of return node for this rule
    crumbs: ArrayList(usize), //index in .nodes of crumbs (history)

    fn init(ruleset: RuleSet, allocator: *std.mem.Allocator) Parser {
        return .{
            .ruleset = ruleset,
            .nodes = ArrayList(Node).init(allocator),
        };
    }

    fn next_node(self: *Parser) usize {
        return self.nodes.items.len;
    }

    fn add_node(self: *Parser, node: Node) !usize {
        var idx = self.next_node();
        try self.nodes.append(node);
        return idx;
    }

    fn parse(self: *Parser, buffer: []const u8) !void {
        const allocator = std.heap.page_allocator;

        const Context = struct {
            parser: *Parser,
        };
        var context = Context{ .parser = self };

        var cmp = struct {
            fn cmp(a: usize, b: usize, c: *Context) bool {
                const node_a = c.parser.nodes.items[a];
                const node_b = c.parser.nodes.items[b];
                if (node_a.cursor == node_b.cursor)
                    return node_a.rule < node_b.rule;
                return node_a.cursor < node_b.cursor;
            }
        }.cmp;

        var queue = PriorityQueue(usize, *Context).init(
            allocator,
            cmp,
            &context,
        );

        var nodeid = try self.add_node(Node{ .rule = 0, .cursor = 0 });

        try queue.add(nodeid);

        while (queue.removeOrNull()) |index| {
            const node = self.nodes.items[index];
            const cursor = node.cursor;

            const rule = node.rule;
            const rulename = self.ruleset.names.items[rule];
            const ruletype = self.ruleset.types.items[rule];

            switch (ruletype) {
                .MATCH => {
                    const matcher = self.ruleset.matchers.items[rule].?;
                    const n_symbols_matched = matcher.match(buffer[cursor..]);
                    if (n_symbols_matched < 0)
                        break;

                    const nodeidx = try self.add_node(Node{ .cursor = cursor + @intCast(usize, n_symbols_matched), .rule = rule + 1 });
                    try queue.add(nodeidx);
                },
                .OPTION => {},
                .RETURN => {},
            }

            std.debug.warn("{}\n", .{node});
        } else {
            std.debug.warn("end\n", .{});
        }
    }
};

const testing = std.testing;
test "Boostrap Parse Test" {
    const allocator = std.heap.page_allocator;
    const warn = std.debug.warn;
    const ruleset_from_buffer = @import("bootstrap-parser.zig").bootstrap.ruleset_from_buffer;
    var buffer = "a 'sdf' 'asdf' | 'asdf' 'fds'\n" ++
        "b 'asdf'";
    var ruleset = try ruleset_from_buffer(buffer[0..]);

    var parser = Parser.init(ruleset, allocator);

    var text_buffer = "asdffds";
    try parser.parse(text_buffer[0..]);
}

test "PQueue" {
    const allocator = std.heap.page_allocator;
}
