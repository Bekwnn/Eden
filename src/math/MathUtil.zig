pub inline fn EqualWithinTolerance(comptime T: type, a: T, b: T, tolerance: T) bool {
    return @fabs(a - b) <= tolerance;
}
