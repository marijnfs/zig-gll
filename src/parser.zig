const std = @import("std");
const RuleSet = @import("ruleset.zig").RuleSet;

const Parser = struct {
    ruleset: RuleSet,

    fn parse(buffer: []u8) void {}
};

test "Boostrap Parse Test" {
    const allocator = std.heap.page_allocator;
    const warn = std.debug.warn;
    const bootstrap_to_ruleset = @import("bootstrap-parser.zig").bootstrap_parse_buffer;
    var buffer = "a 'sdf' 'asdf' | 'asdf' 'fds'\n" ++
        "b 'asdf'";
    var ruleset = bootstrap_to_ruleset(buffer[0..]);

    warn("Test\n", .{});
}
