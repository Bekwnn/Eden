const Vec3 = @import("Vec3.zig").Vec3;

// represents a plane and positive direction
// m_normal must be a normalized vector
pub const Plane = struct {
    m_origin: Vec3,
    m_normal: Vec3,

    pub const default_tolerance = 0.00001;

    // returns a positive value if it's in the direction of m_normal, negative if "behind" the plane
    pub fn GetSignedDistance(self: Plane, pos: Vec3) f32 {
        const originToPos = pos.Sub(self.m_origin);
        return originToPos.Dot(self.m_normal);
    }

    // check if a point is on the plane or on the side of the plane the normal is pointing
    pub fn IsOnPositiveSide(self: Plane, pos: Vec3) bool {
        return self.GetSignedDistance(pos) >= 0.0;
    }

    // returns point on the plane closest to pos
    pub fn ProjectToPlane(self: Plane, pos: Vec3) Vec3 {
        const distanceFromPlane = self.GetSignedDistance(pos);
        return pos.Add(self.m_normal.GetScaled(-distanceFromPlane));
    }
};

test {
    const testing = @import("std").testing;
    const math = @import("std").math;

    const testPoint = Vec3{ .x = 1.0, .y = 2.0, .z = 4.0 };
    const negativeOnePlane = Plane{
        .m_origin = Vec3.zero,
        .m_normal = Vec3.one.Negate(),
    };
    const tolerance = 0.00001;

    const xPlane = Plane{
        .m_origin = Vec3.zero,
        .m_normal = Vec3.xAxis,
    };
    try testing.expect(math.approxEqAbs(f32, xPlane.GetSignedDistance(&testPoint), 1.0, tolerance));
    try TestVec3Equal("result", xPlane.ProjectToPlane(&testPoint), "expected", Vec3{ .x = 0.0, .y = 2.0, .z = 4.0 });
    try testing.expect(xPlane.IsOnPositiveSide(&testPoint));

    const yPlane = Plane{
        .m_origin = Vec3.zero,
        .m_normal = Vec3.yAxis,
    };
    try testing.expect(math.approxEqAbs(f32, yPlane.GetSignedDistance(&testPoint), 2.0, tolerance));
    try TestVec3Equal("result", yPlane.ProjectToPlane(&testPoint), "expected", Vec3{ .x = 1.0, .y = 0.0, .z = 4.0 });
    try testing.expect(yPlane.IsOnPositiveSide(&testPoint));

    const zPlane = Plane{
        .m_origin = Vec3.zero,
        .m_normal = Vec3.zAxis,
    };
    try testing.expect(math.approxEqAbs(f32, zPlane.GetSignedDistance(&testPoint), 4.0, tolerance));
    try TestVec3Equal("result", zPlane.ProjectToPlane(&testPoint), "expected", Vec3{ .x = 1.0, .y = 2.0, .z = 0.0 });
    try testing.expect(zPlane.IsOnPositiveSide(&testPoint));

    const testPointDirPlane = Plane{
        .m_origin = Vec3.zero,
        .m_normal = testPoint.Normalized(),
    };
    try testing.expect(math.approxEqAbs(f32, testPointDirPlane.GetSignedDistance(&testPoint), testPoint.Length(), tolerance));
    try TestVec3Equal("result", testPointDirPlane.ProjectToPlane(&testPoint), "expected", Vec3.zero);
    try testing.expect(testPointDirPlane.IsOnPositiveSide(&testPoint));

    try testing.expect(!negativeOnePlane.IsOnPositiveSide(&testPoint));
}

// TODO make a math testing util file
fn TestVec3Equal(lhsLabel: []const u8, lhs: Vec3, rhsLabel: []const u8, rhs: Vec3) !void {
    const debug = @import("std").debug;
    const testing = @import("std").testing;
    testing.expect(lhs.Equals(rhs)) catch |err| {
        debug.print("{any}\n", .{err});
        lhs.DebugLog(lhsLabel);
        debug.print("\n", .{});
        rhs.DebugLog(rhsLabel);
        debug.print("\n", .{});
        return err;
    };
}
