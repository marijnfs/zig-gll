const String = @import("basic.zig").String;

const Matcher = void; //todo: define

const RuleType = enum {
    OPTION, MATCH, RETURN, END
};

const RuleSet = struct {
    names: []String, //rule names
    typed: []RuleType, //rule types
    arguments: [][]String, //argument for Options
    matchers: []Matcher, //adaptive string matchers interfaces
};

test "RuleTest" {}
