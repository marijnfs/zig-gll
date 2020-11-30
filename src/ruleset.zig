const std = @import("std");
const RuleType = @import("rule.zig").RuleType;
const String = @import("basic.zig").String;
const Matcher = @import("matcher.zig").Matcher;
const warn = std.debug.warn;

const RuleSet = struct {
    arena: std.heap.ArenaAllocator, //Main allocator for all stuf in the ruleset

    names: std.ArrayList(String), //rule names
    types: std.ArrayList(RuleType), //rule types
    options: std.ArrayList([]String), //argument for Options
    matchers: std.ArrayList(?*Matcher), //adaptive string matchers interfaces
    options_indexed: std.ArrayList([]usize), //argument for Options, indexed

    fn init(self: *RuleSet, child_allocator: *std.mem.Allocator) void {
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
    fn add_rule(self: *RuleSet, name: String, ruletype: RuleType) !usize {
        try self.names.append(try std.mem.dupe(self.allocator(), u8, name));
        try self.types.append(ruletype);
        try self.options.append(undefined);
        try self.matchers.append(undefined);
        try self.options_indexed.append(undefined);

        return self.names.items.len - 1;
    }

    fn set_single_option(self: *RuleSet, index: usize, name: String) !void {
        self.options.items[index] = try self.allocator().alloc(String, 1);
        self.options.items[index][0] = try std.mem.dupe(self.allocator(), u8, name);
    }

    fn set_matcher(self: *RuleSet, index: usize, match_string: String) !void {
        var matcher = try self.allocator().create(Matcher);
        try matcher.init(self.allocator(), match_string);
        self.matchers.items[index] = matcher;
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

    fn next_index(self: *RuleSet) usize {
        return self.names.items.len;
    }
};

fn bootstrap_to_ruleset(buffer: []const u8) !RuleSet {
    const allocator = std.heap.page_allocator;
    const bootstrap_parse_buffer = @import("booststrap-parser.zig").bootstrap_parse_buffer;

    // Rule Map: std.StringHashMap([][][]u8)
    var rulemap = try bootstrap_parse_buffer(buffer);

    // Prepare ruleset
    var ruleset: RuleSet = undefined;
    ruleset.init(allocator);

    _ = try ruleset.add_rule("ROOT", .OPTION);
    _ = try ruleset.add_rule("", .RETURN);

    // Iterate over rules
    var it = rulemap.iterator();
    while (it.next()) |rule| {
        std.debug.warn("Rule: {} {}\n", .{ rule.key, rule.value.len });

        var rulename = rule.key;
        var options = rule.value;

        // A rule might have several options: S a | b
        // or a single option: S a b
        // The single option doesn't need indirection so we handle it directly
        // var single_option = options.len == 1;

        var ruleindex = try ruleset.add_rule(rulename, .OPTION);
        _ = try ruleset.add_rule("", .RETURN);

        var spawn_indices = std.ArrayList(usize).init(ruleset.allocator());

        var i: usize = 0;
        while (i < options.len) : (i += 1) {
            // Add the option index to the spawn indices
            var option_index = ruleset.next_index();
            try spawn_indices.append(option_index);

            // Run through the options and create appropriate rules
            var n: usize = 0;
            while (n < options[i].len) : (n += 1) {
                if (rulemap.contains(options[i][n])) //If this is an existing rule name, we create an option
                {
                    var new_rule = try ruleset.add_rule("", .OPTION);
                    try ruleset.set_single_option(new_rule, options[i][n]);
                } else {
                    var new_rule = try ruleset.add_rule("", .MATCH);
                    try ruleset.set_matcher(new_rule, options[i][n]);
                }
            } else {
                // Finish off with a return
                _ = try ruleset.add_rule("", .RETURN);
            }
        }

        //set the spawn options of the main rule
        warn("{} {}\n", .{ ruleindex, ruleset.options_indexed.items.len });
        ruleset.options_indexed.items[ruleindex] = spawn_indices.toOwnedSlice();
    }

    return ruleset;
}

test "Bootstrap Test" {
    const allocator = std.heap.page_allocator;

    var buffer = "a 'sdf' 'asdf' | 'asdf' 'fds'\n" ++
        "b 'asdf'";
    var ruleset = bootstrap_to_ruleset(buffer[0..]);
}

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
