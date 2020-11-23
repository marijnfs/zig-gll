const std = @import("std");
const mem = std.mem;
const os = std.os;

const Mode = enum { BLANK = 0, READ = 1, ESCAPESINGLE = 2, ESCAPEDOUBLE = 3 };

fn bootstrap_parse_buffer(buffer: []u8) void {
    var mode: Mode = .BLANK;

    var it = mem.tokenize(buffer, "\r\n");

    while (it.next()) |line| {}
}

test "TestBootstrap" {
    const allocator = std.heap.page_allocator;

    var buffer = try std.fs.cwd().readFileAlloc(allocator, "./test.txt", 1 >> 30);

    bootstrap_parse_buffer(buffer);
}
