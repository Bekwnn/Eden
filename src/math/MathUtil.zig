const stdm = @import("std").math;

pub fn EqualWithinTolerance(comptime T: type, a: T, b: T, tolerance: T) bool {
    return @abs(a - b) <= tolerance;
}

pub const twoPi = stdm.tau;

pub const degToRad: f32 = stdm.pi / 180.0;
pub const radToDeg: f32 = 1.0 / degToRad;
