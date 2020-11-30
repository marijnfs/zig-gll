// String matcher interface and implementation
const std = @import("std");
const String = @import("basic.zig").String;

pub const Matcher = struct {
    pub fn init(self: *Matcher, allocator: *std.mem.Allocator, match_string: []const u8) !void {
        self.* = .{ .match_string = try std.mem.dupe(allocator, u8, match_string) };
    }

    pub fn match(self: Matcher, buf: []const u8) i64 {
        if (buf.len < self.match_string.len)
            return -1;
        if (std.mem.eql(u8, self.match_string, buf[0..self.match_string.len]))
            return @intCast(i64, self.match_string.len);
        return -1;
    }

    match_string: []u8
};

test "Test Matcher" {
    var allocator = std.heap.page_allocator;
    var matcher = try allocator.create(Matcher);
    try matcher.init(allocator, "hello");

    std.testing.expect(matcher.match("hello") == 5);
    std.testing.expect(matcher.match("hell") == -1);
    std.testing.expect(matcher.match("helloo") == 5);

    const hhello = "hhello";
    std.testing.expect(matcher.match(hhello[1..]) == 5);
}
