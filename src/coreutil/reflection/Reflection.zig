const std = @import("std");

pub const Options = struct {

};

pub const Reflection = struct {


};

pub const Refl(comptime T: type, comptime options: Options) type {
    return .{
        // copy all fields and functions from Type
        pub var reflection = Reflection{};
    };
}
