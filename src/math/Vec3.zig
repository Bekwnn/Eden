const std = @import("std");
const math = std.math;

const Quat = @import("Quat.zig").Quat;
const Vec2 = @import("Vec2.zig").Vec2;

pub const Vec3 = extern struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub const zero = Vec3{};
    pub const one = Vec3{ .x = 1.0, .y = 1.0, .z = 1.0 };
    pub const xAxis = Vec3{ .x = 1.0, .y = 0.0, .z = 0.0 };
    pub const yAxis = Vec3{ .x = 0.0, .y = 1.0, .z = 0.0 };
    pub const zAxis = Vec3{ .x = 0.0, .y = 0.0, .z = 1.0 };

    pub fn Negate(self: *const Vec3) Vec3 {
        return Vec3{
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
        };
    }

    pub fn Add(self: *const Vec3, rhs: Vec3) Vec3 {
        return Vec3{
            .x = self.x + rhs.x,
            .y = self.y + rhs.y,
            .z = self.z + rhs.z,
        };
    }

    pub fn Sub(self: *const Vec3, rhs: Vec3) Vec3 {
        return Vec3{
            .x = self.x - rhs.x,
            .y = self.y - rhs.y,
            .z = self.z - rhs.z,
        };
    }

    pub fn Mul(self: *const Vec3, rhs: Vec3) Vec3 {
        return Vec3{
            .x = self.x * rhs.x,
            .y = self.y * rhs.y,
            .z = self.z * rhs.z,
        };
    }

    pub fn Dot(self: *const Vec3, rhs: Vec3) f32 {
        return self.x * rhs.x + self.y * rhs.y + self.z * rhs.z;
    }

    pub fn Cross(self: *const Vec3, rhs: Vec3) Vec3 {
        return Vec3{
            .x = self.y * rhs.z - self.z * rhs.y,
            .y = self.z * rhs.x - self.x * rhs.z,
            .z = self.x * rhs.y - self.y * rhs.x,
        };
    }

    pub fn Min(self: *const Vec3, rhs: Vec3) Vec3 {
        return Vec3{
            .x = @min(self.x, rhs.x),
            .y = @min(self.y, rhs.y),
            .z = @min(self.z, rhs.z),
        };
    }

    pub fn Max(self: *const Vec3, rhs: Vec3) Vec3 {
        return Vec3{
            .x = @max(self.x, rhs.x),
            .y = @max(self.y, rhs.y),
            .z = @max(self.z, rhs.z),
        };
    }

    pub fn Equals(self: *const Vec3, rhs: Vec3) bool {
        return self.EqualsT(rhs, math.floatEps(f32));
    }

    pub fn EqualsT(self: *const Vec3, rhs: Vec3, tolerance: f32) bool {
        return math.approxEqAbs(f32, self.x, rhs.x, tolerance) and
            math.approxEqAbs(f32, self.y, rhs.y, tolerance) and
            math.approxEqAbs(f32, self.z, rhs.z, tolerance);
    }

    pub fn LengthSqrd(self: *const Vec3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn Length(self: *const Vec3) f32 {
        return math.sqrt(self.LengthSqrd());
    }

    pub fn DistSqrd(self: *const Vec3, rhs: Vec3) f32 {
        return self.Sub(rhs).LengthSqrd();
    }

    pub fn Dist(self: *const Vec3, rhs: Vec3) f32 {
        return self.Sub(rhs).Length();
    }

    pub fn ScaleSelf(self: *Vec3, scalar: f32) void {
        self.x *= scalar;
        self.y *= scalar;
        self.z *= scalar;
    }

    pub fn GetScaled(self: *const Vec3, scalar: f32) Vec3 {
        return Vec3{
            .x = self.x * scalar,
            .y = self.y * scalar,
            .z = self.z * scalar,
        };
    }

    //TODO panics in debug build only maybe?
    pub fn ScaleToSize(self: *Vec3, size: f32) void {
        const length = self.Length();
        if (length == 0.0) @panic("Trying to scale up a vector with length 0");
        const scaleAmount = size / length;
        self.ScaleSelf(scaleAmount);
    }

    pub fn GetScaledToSize(self: *Vec3, size: f32) Vec3 {
        const length = self.Length();
        if (length == 0.0) @panic("Trying to scale up a vector with length 0");
        const scaleAmount = size / length;
        return self.GetScaled(scaleAmount);
    }

    pub fn ClampToMinSize(self: *Vec3, size: f32) void {
        const lengthSqrd = self.LengthSqrd();
        const sizeSqrd = size * size;
        if (lengthSqrd < sizeSqrd) {
            if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
            const inv = size / math.sqrt(lengthSqrd);
            self.x *= inv;
            self.y *= inv;
            self.z *= inv;
        }
    }

    pub fn ClampToMaxSize(self: *Vec3, size: f32) void {
        const lengthSqrd = self.LengthSqrd();
        const sizeSqrd = size * size;
        if (lengthSqrd > sizeSqrd) {
            if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
            const inv = size / math.sqrt(lengthSqrd);
            self.x *= inv;
            self.y *= inv;
            self.z *= inv;
        }
    }

    pub fn GetClampedToMinSize(self: *const Vec3, size: f32) Vec3 {
        const lengthSqrd = self.LengthSqrd();
        const sizeSqrd = size * size;
        if (lengthSqrd < sizeSqrd) {
            if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
            const inv = size / math.sqrt(lengthSqrd);
            return Vec3{
                .x = self.x * inv,
                .y = self.y * inv,
                .z = self.z * inv,
            };
        }
    }

    pub fn GetClampedToMaxSize(self: *const Vec3, size: f32) Vec3 {
        const lengthSqrd = self.LengthSqrd();
        const sizeSqrd = size * size;
        if (lengthSqrd > sizeSqrd) {
            if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
            const inv = size / math.sqrt(lengthSqrd);
            return Vec3{
                .x = self.x * inv,
                .y = self.y * inv,
                .z = self.z * inv,
            };
        }
    }

    pub fn IsNormalized(self: *const Vec3) bool {
        return std.math.approxEqRel(f32, self.LengthSqrd(), 1.0, std.math.floatEps(f32));
    }

    pub fn Normalized(self: *const Vec3) Vec3 {
        const length = self.Length();
        if (length == 0.0) @panic("Normalizing vector with length 0");
        return Vec3{
            .x = self.x / length,
            .y = self.y / length,
            .z = self.z / length,
        };
    }

    pub fn NormalizeSelf(self: *Vec3) void {
        const length = self.Length();
        if (length == 0.0) @panic("Normalizing vector with length 0");
        self.x /= length;
        self.y /= length;
        self.z /= length;
    }

    pub fn RotatedByQuat(self: *const Vec3, q: Quat) Vec3 {
        const qxyz = Vec3{ .x = q.x, .y = q.y, .z = q.z };
        const t = qxyz.Cross(self.*).GetScaled(2.0);
        return self.Add(t.GetScaled(q.w)).Add(qxyz.Cross(t));
    }

    pub fn RotateByQuat(self: *Vec3, q: Quat) void {
        const qxyz = Vec3{ .x = q.x, .y = q.y, .z = q.z };
        const t = qxyz.Cross(self.*).GetScaled(2.0);
        self = self.Add(t.GetScaled(q.w).Add(qxyz.Cross(t)));
    }

    pub fn Vec3_xy0(v2: *const Vec2) Vec3 {
        return Vec3{ v2.x, v2.y, 0.0 };
    }

    pub fn Vec3_x0y(v2: *const Vec2) Vec3 {
        return Vec3{ v2.x, 0.0, v2.y };
    }

    pub fn Vec3_0xy(v2: *const Vec2) Vec3 {
        return Vec3{ 0.0, v2.x, v2.y };
    }

    pub fn DebugLog(self: *const Vec3, label: []const u8) void {
        std.debug.print("{s}: ({d:.2}, {d:.2}, {d:.2})", .{ label, self.x, self.y, self.z });
    }
};

//testing
const Vec3Test = struct {
    const testing = std.testing;
    const debug = std.debug;
    const testTolerance = 1e-6;

    test "Add" {
        const v1 = Vec3{ .x = 1.0, .y = 2.0, .z = 3.0 };
        const v2 = Vec3{ .x = 3.0, .y = 2.0, .z = 3.0 };
        const v3 = v1.Add(v2);
        try testing.expect(v3.x == 3.0 and v3.y == 4.0 and v3.z == 6.0);
    }

    test "Dot" {
        const v1 = Vec3{ .x = 1, .y = 2, .z = 3 };
        const v2 = Vec3{ .x = -1, .y = -2, .z = -3 };
        const v1x3 = Vec3{ .x = 3, .y = 6, .z = 9 };
        const testAResult = v1.Normalized().Dot(v2.Normalized());
        testing.expect(math.approxEqAbs(f32, testAResult, -1.0, testTolerance)) catch |err| {
            debug.print("v1.Dot(v2): {}", .{testAResult});
            return err;
        };
        const testBResult = v1.Normalized().Dot(v1x3.Normalized());
        testing.expect(math.approxEqAbs(f32, testBResult, 1.0, testTolerance)) catch |err| {
            debug.print("v1.Dot(v1x3): {}", .{testBResult});
            return err;
        };
    }
};
