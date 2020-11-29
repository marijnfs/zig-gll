const std = @import("std");
const RuleType = @import("rule.zig").RuleType;
const String = @import("basic.zig").String;
const Matcher = @import("matcher.zig").Matcher;

const RuleSet = struct {
    names: std.ArrayList(String), //rule names
    types: std.ArrayList(RuleType), //rule types
    options: std.ArrayList([]String), //argument for Options
    matchers: std.ArrayList(?Matcher), //adaptive string matchers interfaces

    arena: std.heap.ArenaAllocator, //Main allocator for all stuf in the ruleset

    fn init(allocator: *std.mem.Allocator) RuleSet {
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .names = std.ArrayList(String).init(allocator),
            .types = std.ArrayList(RuleType).init(allocator),
            .options = std.ArrayList([]String).init(allocator),
            .matchers = std.ArrayList(?Matcher).init(allocator),
        };
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

    fn string_index(self: *RuleSet, name: String) i64 {
        var i: usize = 0;
        while (i < self.names.items.len) : (i += 1) {
            if (std.mem.eql(u8, name, self.names.items[i]))
                return @intCast(i64, i);
        }
        return -1;
    }
};

test "RuleSet Test" {
    var alloc = std.heap.page_allocator;
    var ruleset = RuleSet.init(alloc);

    try ruleset.add_rule("hey", .OPTION);
    try ruleset.add_rule("heyo", .OPTION);

    std.testing.expect(ruleset.string_index("hey") == 0);
    std.testing.expect(ruleset.string_index("heyo") == 1);
    std.testing.expect(ruleset.string_index("he") == -1);
    std.testing.expect(ruleset.string_index("asdf") == -1);
}
