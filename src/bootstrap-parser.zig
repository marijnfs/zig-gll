const std = @import("std");
const mem = std.mem;
const os = std.os;

const warn = std.debug.warn;

const RuleSet = @import("ruleset.zig").RuleSet;

const Mode = enum { BLANK, READFIRST, READ, ESCAPESINGLE, ESCAPEDOUBLE };

// const RuleMap = std.AutoHashMap([]const u8, [][][]const u8);
const RuleMap = std.StringHashMap([][][]u8);

pub fn bootstrap_parse_buffer(buffer: []const u8) !RuleMap {
    var heap_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    errdefer heap_allocator.deinit();

    var allocator = &heap_allocator.allocator;

    var rule_map = RuleMap.init(allocator);

    var it = mem.tokenize(buffer, "\r\n");

    while (it.next()) |line| {
        var rulename = std.ArrayList(u8).init(allocator);
        var token = std.ArrayList(u8).init(allocator);
        var sequence = std.ArrayList([]u8).init(allocator);
        var options = std.ArrayList([][]u8).init(allocator);

        std.debug.warn("{}\n", .{line});

        var state: Mode = .READFIRST;
        const slice = line[0..];
        var index: usize = 0;

        while (index < slice.len) : (index += 1) {
            const b = slice[index];

            switch (state) {
                Mode.READFIRST => switch (b) {
                    ' ' => {
                        state = Mode.BLANK;
                    },
                    else => {
                        try rulename.append(b);
                    },
                },
                Mode.BLANK => switch (b) {
                    '|' => {
                        if (sequence.items.len == 0) {
                            return error.InvalidToken;
                        }

                        try options.append(sequence.toOwnedSlice());
                    },
                    ' ' => {},
                    else => {
                        index -= 1;
                        state = Mode.READ;
                    },
                },
                Mode.READ => switch (b) {
                    ' ' => { //End read
                        if (token.items.len > 0) {
                            try sequence.append(token.toOwnedSlice());
                        } else {
                            return error.InvalidToken;
                        }
                    },
                    '\'' => {
                        state = Mode.ESCAPESINGLE;
                    },
                    '\"' => {
                        state = Mode.ESCAPEDOUBLE;
                    },
                    else => {
                        try token.append(b);
                    },
                },
                Mode.ESCAPESINGLE => switch (b) {
                    '\'' => { //end
                        try sequence.append(token.toOwnedSlice());
                        state = Mode.BLANK;
                    },
                    else => {
                        try token.append(b);
                    },
                },
                Mode.ESCAPEDOUBLE => switch (b) {
                    '\"' => { //end
                        try sequence.append(token.toOwnedSlice());
                        state = Mode.BLANK;
                    },
                    else => {
                        try token.append(b);
                    },
                },
            }
        } else {
            switch (state) {
                Mode.ESCAPESINGLE => {
                    return error.UnendedEscape;
                },
                Mode.ESCAPEDOUBLE => {
                    return error.UnendedEscape;
                },
                else => {
                    if (token.items.len > 0) {
                        try sequence.append(token.toOwnedSlice());
                    }
                    if (sequence.items.len > 0) {
                        try options.append(sequence.toOwnedSlice());
                    }
                },
            }
        }

        if (options.items.len > 0 and rulename.items.len > 0) {
            var owned_slice = rulename.toOwnedSlice();
            warn("owned: '{}'\n", .{owned_slice});
            try rule_map.put(owned_slice, options.toOwnedSlice());
        }
    }

    return rule_map;
}

fn bootstrap_to_ruleset(buffer: []const u8) !RuleSet {
    const allocator = std.heap.page_allocator;

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

            // Run through the options and create appropriate sub-rules
            var n: usize = 0;
            while (n < options[i].len) : (n += 1) {
                if (rulemap.contains(options[i][n])) //If this is an existing rule name, we create an option
                {
                    var new_rule_index = try ruleset.add_rule("", .OPTION);
                    try ruleset.set_single_option(new_rule_index, options[i][n]);
                } else {
                    var new_rule_index = try ruleset.add_rule("", .MATCH);
                    try ruleset.set_matcher(new_rule_index, options[i][n]);
                }
            } else {
                // Finish off with a return
                _ = try ruleset.add_rule("", .RETURN);
            }
        }

        //set the spawn options of the current rule
        warn("{} {}\n", .{ ruleindex, ruleset.options_indexed.items.len });
        ruleset.options_indexed.items[ruleindex] = spawn_indices.toOwnedSlice();
    }

    return ruleset;
}

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "TestBootstrap" {
    const allocator = std.heap.page_allocator;

    var buffer = @embedFile("../test/test.gram");

    var rule_map = try bootstrap_parse_buffer(buffer);

    expect(rule_map.count() == 3);

    var s: []const u8 = "S";
    var x: []const u8 = "X";
    var z: []const u8 = "Z";
    var q: []const u8 = "Q";

    expect(rule_map.contains(s));
    expect(rule_map.contains(x));
    expect(rule_map.contains(z));
    expect(!rule_map.contains(q));
}

test "Bootstrap Ruleset Test" {
    const allocator = std.heap.page_allocator;

    var buffer = "a 'sdf' 'asdf' | 'asdf' 'fds'\n" ++
        "b 'asdf'";
    var ruleset = bootstrap_to_ruleset(buffer[0..]);
}
