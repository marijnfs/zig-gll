const std = @import("std");
const RuleType = @import("ruletype.zig").RuleType;
const String = @import("basic.zig").String;
const Matcher = @import("matcher.zig").Matcher;
const warn = std.debug.warn;

pub const RuleSet = struct {
    arena: std.heap.ArenaAllocator, //Main allocator for all stuf in the ruleset

    names: std.ArrayList(String), //rule names
    types: std.ArrayList(RuleType), //rule types
    options: std.ArrayList([]String), //argument for Options
    matchers: std.ArrayList(?*Matcher), //adaptive string matchers interfaces
    options_indexed: std.ArrayList([]usize), //argument for Options, indexed

    pub fn init(self: *RuleSet, child_allocator: *std.mem.Allocator) void {
        // Setup memory arena
        self.arena = std.heap.ArenaAllocator.init(child_allocator);

        self.names = std.ArrayList(String).init(self.allocator());
        self.types = std.ArrayList(RuleType).init(self.allocator());
        self.options = std.ArrayList([]String).init(self.allocator());
        self.matchers = std.ArrayList(?*Matcher).init(self.allocator());
        self.options_indexed = std.ArrayList([]usize).init(self.allocator());
    }

    // Function to add a rule
    // Arguments like the options or matcher are filled in later
    // This is needed, since names might not be known yet
    pub fn add_rule(self: *RuleSet, name: String, ruletype: RuleType) !usize {
        try self.names.append(try std.mem.dupe(self.allocator(), u8, name));
        try self.types.append(ruletype);
        try self.options.append(undefined);
        try self.matchers.append(undefined);
        try self.options_indexed.append(undefined);

        return self.names.items.len - 1;
    }

    pub fn set_single_option(self: *RuleSet, index: usize, name: String) !void {
        self.options.items[index] = try self.allocator().alloc(String, 1);
        self.options.items[index][0] = try std.mem.dupe(self.allocator(), u8, name);
    }

    pub fn set_matcher(self: *RuleSet, index: usize, match_string: String) !void {
        var matcher = try self.allocator().create(Matcher);
        try matcher.init(self.allocator(), match_string);
        self.matchers.items[index] = matcher;
    }

    pub fn name_index(self: *RuleSet, name: String) i64 {
        var i: usize = 0;
        while (i < self.names.items.len) : (i += 1) {
            if (std.mem.eql(u8, name, self.names.items[i]))
                return @intCast(i64, i);
        }
        return -1;
    }

    pub fn next_index(self: *RuleSet) usize {
        return self.names.items.len;
    }

    pub fn allocator(self: *RuleSet) *std.mem.Allocator {
        return &self.arena.allocator;
    }
};

test "RuleSet Test" {
    var alloc = std.heap.page_allocator;
    var ruleset: RuleSet = undefined;
    ruleset.init(alloc);

    _ = try ruleset.add_rule("hey", .OPTION);
    _ = try ruleset.add_rule("heyo", .OPTION);

    std.testing.expect(ruleset.name_index("hey") == 0);
    std.testing.expect(ruleset.name_index("heyo") == 1);
    std.testing.expect(ruleset.name_index("he") == -1);
    std.testing.expect(ruleset.name_index("asdf") == -1);
}
