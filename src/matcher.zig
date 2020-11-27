// String matcher interface and implementation
const std = @import("std");
const String = @import("basic.zig").String;

pub const Matcher = struct {
    callbackfn: fn match([]const u8) int,
};

pub const StringMatcher = struct {
    fn match(self: StringMatcher, []const u8) int {
        return true;
    }
};

test "Test Matcher" {
    var allocator = std.heap.page_allocator;
    var matcher = StringMatcher.init(allocator, "");
}
