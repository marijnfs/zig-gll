const std = @import("std");
const mem = std.mem;
const os = std.os;

const warn = std.debug.warn;

const Mode = enum { BLANK, READFIRST, READ, ESCAPESINGLE, ESCAPEDOUBLE };

// const RuleMap = std.AutoHashMap([]const u8, [][][]const u8);
const RuleMap = std.StringHashMap(u8);

fn bootstrap_parse_buffer(buffer: []u8) !RuleMap {
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
            try rule_map.put(owned_slice, 3); //options.toOwnedSlice());
        }
    }

    return rule_map;
}

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "TestBootstrap" {
    const allocator = std.heap.page_allocator;

    var buffer = try std.fs.cwd().readFileAlloc(allocator, "test/test.gram", 1 << 30);

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
