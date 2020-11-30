const std = @import("std");
const RuleType = @import("rule.zig").RuleType;
const String = @import("basic.zig").String;
const Matcher = @import("matcher.zig").Matcher;

const RuleSet = struct {
    arena: std.heap.ArenaAllocator, //Main allocator for all stuf in the ruleset

    names: std.ArrayList(String), //rule names
    types: std.ArrayList(RuleType), //rule types
    options: std.ArrayList([]String), //argument for Options
    matchers: std.ArrayList(?Matcher), //adaptive string matchers interfaces
    options_indexed: std.ArrayList([]i64), //argument for Options, indexed

    fn init(self: *RuleSet, child_allocator: *std.mem.Allocator) void {
        // Setup memory arena
        self.arena = std.heap.ArenaAllocator.init(child_allocator);

        self.names = std.ArrayList(String).init(self.allocator());
        self.types = std.ArrayList(RuleType).init(self.allocator());
        self.options = std.ArrayList([]String).init(self.allocator());
        self.matchers = std.ArrayList(?Matcher).init(self.allocator());
        self.options_indexed = std.ArrayList([]i64).init(self.allocator());
    }

    // Function to add a rule
    // Arguments like the options or matcher are filled in later
    // This is needed, since names might not be known yet
    fn add_rule(self: *RuleSet, name: String, ruletype: RuleType) !void {
        try self.names.append(name);
        try self.types.append(ruletype);
        try self.options.append(undefined);
        try self.matchers.append(undefined);
    }

    fn name_index(self: *RuleSet, name: String) i64 {
        var i: usize = 0;
        while (i < self.names.items.len) : (i += 1) {
            if (std.mem.eql(u8, name, self.names.items[i]))
                return @intCast(i64, i);
        }
        return -1;
    }

    fn allocator(self: *RuleSet) *std.mem.Allocator {
        return &self.arena.allocator;
    }
};

fn bootstrap_to_ruleset(buffer: []u8) !RuleSet {
    const allocator = std.heap.page_allocator;
    const bootstrap_parse_buffer = @import("booststrap-parser.zig").bootstrap_parse_buffer;

    // Rule Map: std.StringHashMap([][][]u8)
    var rulemap = try bootstrap_parse_buffer(buffer);

    var it = rulemap.iterator();
    while (it.next()) |rule| {
        std.debug.warn("{}\n", .{rule.key});
    }

    var ruleset: RuleSet = undefined;
    ruleset.init(allocator);

    return ruleset;
}

test "Bootstrap Test" {
    const allocator = std.heap.page_allocator;

    var buffer = try std.fs.cwd().readFileAlloc(allocator, "../test/test.gram", 1 << 30);
    var ruleset = bootstrap_to_ruleset(buffer);
}

test "RuleSet Test" {
    var alloc = std.heap.page_allocator;
    var ruleset: RuleSet = undefined;
    ruleset.init(alloc);

    try ruleset.add_rule("hey", .OPTION);
    try ruleset.add_rule("heyo", .OPTION);

    std.testing.expect(ruleset.name_index("hey") == 0);
    std.testing.expect(ruleset.name_index("heyo") == 1);
    std.testing.expect(ruleset.name_index("he") == -1);
    std.testing.expect(ruleset.name_index("asdf") == -1);
}
