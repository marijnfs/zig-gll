const String = @import("basic.zig").String;

pub const RuleType = enum {
    OPTION, MATCH, RETURN //Let's try without End, Return can be an end
    // OPTION, MATCH, RETURN, END
};
