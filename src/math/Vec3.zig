const std = @import("std");

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
};

//TODO inlining?

pub fn Scale(self: *Vec3, scalar: f32) void {
    self.x *= scalar;
    self.y *= scalar;
    self.z *= scalar;
}

pub fn GetScaled(self: *Vec3, scalar: f32) Vec3 {
    return Vec3{
        .x = self.x * scalar,
        .y = self.y * scalar,
        .z = self.z * scalar,
    };
}

pub fn Add(lhs: *Vec3, rhs: *Vec3) Vec3 {
    return Vec3{
        .x = lhs.x + rhs.x,
        .y = lhs.y + rhs.y,
        .z = lhs.z + rhs.z,
    };
}

pub fn Sub(lhs: *Vec3, rhs: *Vec3) Vec3 {
    return Vec3{
        .x = lhs.x - rhs.x,
        .y = lhs.y - rhs.y,
        .z = lhs.z - rhs.z,
    };
}

pub fn Dot(lhs: *Vec3, rhs: *Vec3) Vec3 {
    return Vec3{
        .x = lhs.x * rhs.x,
        .y = lhs.y * rhs.y,
        .z = lhs.z * rhs.z,
    };
}

pub fn Cross(lhs: *Vec3, rhs: *Vec3) Vec3 {
    return Vec3{
        .x = lhs.y * rhs.z - lhs.z * rhs.y,
        .y = lhs.z * rhs.x - lhs.x * rhs.z,
        .z = lhs.x * rhs.y - lhs.y * rhs.x,
    };
}

const epsilonf32Sqrd: comptime f32 = std.math.f32_epsilon * std.math.f32_epsilon;
// equals with a default tolerance of f32_epsilon
pub fn Equals(lhs: *Vec3, rhs: *Vec3) bool {
    return lhs.Sub(rhs).LengthSqrd() <= epsilonf32Sqrd;
}

pub fn EqualsTolerance(lhs: *Vec3, rhs: *Vec3, tolerance: comptime f32) bool {
    return lhs.Sub(rhs).LengthSqrd() <= tolerance * tolerance;
}

pub fn LengthSqrd(self: *Vec3) f32 {
    return self.x * self.x + self.y * self.y + self.z * self.z;
}

pub fn Length(self: *Vec3) f32 {
    return std.math.sqrt(self.LengthSqrd);
}

pub fn DistSqrd(lhs: *Vec3, rhs: *Vec3) f32 {
    return lhs.Sub(rhs).LengthSqrd();
}

pub fn Dist(lhs: *Vec3, rhs: *Vec3) f32 {
    return lhs.Sub(rhs).Length();
}

//TODO panics in debug build only maybe?

pub fn ClampToMinSize(self: *Vec3, size: f32) void {
    var lengthSqrd = self.LengthSqrd();
    const sizeSqrd = size * size;
    if (lengthSqrd < sizeSqrd) {
        if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
        const inv = size / std.math.sqrt(lengthSqrd);
        self.x *= inv;
        self.y *= inv;
        self.z *= inv;
    }
}

pub fn ClampToMaxSize(self: *Vec3, size: f32) void {
    var lengthSqrd = self.LengthSqrd();
    const sizeSqrd = size * size;
    if (lengthSqrd > sizeSqrd) {
        if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
        const inv = size / std.math.sqrt(lengthSqrd);
        self.x *= inv;
        self.y *= inv;
        self.z *= inv;
    }
}

pub fn GetClampedToMinSize(self: *Vec3, size: f32) Vec3 {
    var lengthSqrd = self.LengthSqrd();
    const sizeSqrd = size * size;
    if (lengthSqrd < sizeSqrd) {
        if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
        const inv = size / std.math.sqrt(lengthSqrd);
        return Vec3{
            .x = self.x * inv,
            .y = self.y * inv,
            .z = self.z * inv,
        };
    }
}

pub fn GetClampedToMaxSize(self: *Vec3, size: f32) Vec3 {
    var lengthSqrd = self.LengthSqrd();
    const sizeSqrd = size * size;
    if (lengthSqrd > sizeSqrd) {
        if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
        const inv = size / std.math.sqrt(lengthSqrd);
        return Vec3{
            .x = self.x * inv,
            .y = self.y * inv,
            .z = self.z * inv,
        };
    }
}

pub fn Normalized(self: *Vec3) Vec3 {
    const mag = self.Length();
    if (mag == 0.0) @panic("Normalizing vector with length 0");
    return Vec3{
        .x = self.x / mag,
        .y = self.y / mag,
        .z = self.z / mag,
    };
}

pub fn NormalizeSelf(self: *Vec3) void {
    const mag = self.Length();
    if (mag == 0.0) @panic("Normalizing vector with length 0");
    @panic(mag == 0.0);
    self.x /= mag;
    self.y /= mag;
    self.z /= mag;
}

//TODO testing
