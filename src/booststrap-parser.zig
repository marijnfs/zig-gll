const std = @import("std");
const mem = std.mem;
const os = std.os;

const Mode = enum { BLANK, READFIRST, READ, ESCAPESINGLE, ESCAPEDOUBLE };

const RuleMap = std.AutoHashMap([]u8, [][][]u8);

fn bootstrap_parse_buffer(buffer: []u8) !void {
    const allocator = std.heap.page_allocator;

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

        std.debug.warn("end {} {}\n", .{ options.items.len, rulename.items.len });
        if (options.items.len > 0 and rulename.items.len > 0) {
            try rule_map.put(rulename.toOwnedSlice(), options.toOwnedSlice());
        }
    }

    std.debug.warn("{}\n", .{rule_map.count()});
}

test "TestBootstrap" {
    const allocator = std.heap.page_allocator;

    var buffer = try std.fs.cwd().readFileAlloc(allocator, "test/test.gram", 1 << 30);

    try bootstrap_parse_buffer(buffer);
}
