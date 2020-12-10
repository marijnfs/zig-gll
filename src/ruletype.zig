const String = @import("basic.zig").String;

pub const RuleType = enum {
    OPTION, MATCH, RETURN, END
};
