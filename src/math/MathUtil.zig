pub usingnamespace @import("std").math;

pub inline fn EqualWithinTolerance(comptime T: type, a: T, b: T, tolerance: T) bool {
    return @fabs(a - b) <= tolerance;
}

pub const twoPi = tau;

pub const degToRad: comptime f32 = pi / 180.0;
pub const radToDeg: comptime f32 = 1.0 / degToRadians;
