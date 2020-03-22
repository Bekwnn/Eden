const std = @import("std");

pub const Vec2 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,

    pub inline fn Scale(self: *Vec2, scalar: f32) void {
        self.x *= scalar;
        self.y *= scalar;
    }

    pub inline fn GetScaled(self: *const Vec2, scalar: f32) Vec2 {
        return Vec2{
            .x = self.x * scalar,
            .y = self.y * scalar,
        };
    }

    pub inline fn Add(self: *const Vec2, rhs: Vec2) Vec2 {
        return Vec2{
            .x = self.x + rhs.x,
            .y = self.y + rhs.y,
        };
    }

    pub inline fn Sub(self: *const Vec2, rhs: Vec2) Vec2 {
        return Vec2{
            .x = self.x - rhs.x,
            .y = self.y - rhs.y,
        };
    }

    pub inline fn Dot(self: *const Vec2, rhs: Vec2) Vec2 {
        return Vec2{
            .x = self.x * rhs.x,
            .y = self.y * rhs.y,
        };
    }

    const epsilonf32Sqrd: comptime f32 = std.math.f32_epsilon * std.math.f32_epsilon;
    // equals with a default tolerance of f32_epsilon
    pub inline fn Equals(self: *const Vec2, rhs: Vec2) bool {
        return self.Sub(rhs).LengthSqrd() <= epsilonf32Sqrd;
    }

    pub inline fn EqualsT(self: *const Vec2, rhs: Vec2, tolerance: comptime f32) bool {
        return self.Sub(rhs).LengthSqrd() <= tolerance * tolerance;
    }

    pub inline fn LengthSqrd(self: *const Vec2) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub inline fn Length(self: *const Vec2) f32 {
        return std.math.sqrt(self.LengthSqrd);
    }

    pub inline fn DistSqrd(self: *const Vec2, rhs: Vec2) f32 {
        return self.Sub(rhs).LengthSqrd();
    }

    pub inline fn Dist(self: *const Vec2, rhs: Vec2) f32 {
        return self.Sub(rhs).Length();
    }

    //TODO panics in debug build only maybe?

    pub inline fn ClampToMinSize(self: *Vec2, size: f32) void {
        const lengthSqrd = self.LengthSqrd();
        const sizeSqrd = size * size;
        if (lengthSqrd < sizeSqrd) {
            if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
            const inv = size / std.math.sqrt(lengthSqrd);
            self.x *= inv;
            self.y *= inv;
        }
    }

    pub inline fn ClampToMaxSize(self: *Vec2, size: f32) void {
        const lengthSqrd = self.LengthSqrd();
        const sizeSqrd = size * size;
        if (lengthSqrd > sizeSqrd) {
            if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
            const inv = size / std.math.sqrt(lengthSqrd);
            self.x *= inv;
            self.y *= inv;
        }
    }

    pub inline fn GetClampedToMinSize(self: *const Vec2, size: f32) Vec2 {
        const lengthSqrd = self.LengthSqrd();
        const sizeSqrd = size * size;
        if (lengthSqrd < sizeSqrd) {
            if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
            const inv = size / std.math.sqrt(lengthSqrd);
            return Vec2{
                .x = self.x * inv,
                .y = self.y * inv,
            };
        }
    }

    pub inline fn GetClampedToMaxSize(self: *const Vec2, size: f32) Vec2 {
        const lengthSqrd = self.LengthSqrd();
        const sizeSqrd = size * size;
        if (lengthSqrd > sizeSqrd) {
            if (lengthSqrd == 0.0) @panic("Clamping vector with length 0");
            const inv = size / std.math.sqrt(lengthSqrd);
            return Vec2{
                .x = self.x * inv,
                .y = self.y * inv,
            };
        }
    }

    pub inline fn ScaleToSize(self: *Vec2, size: f32) void {
        const length = self.Length();
        if (length == 0.0) @panic("Trying to scale up a vector with length 0");
        const scaleAmount = size / length;
        self.Scale(scaleAmount);
    }

    pub inline fn GetScaledToSize(self: *Vec2, size: f32) Vec2 {
        const length = self.Length();
        if (length == 0.0) @panic("Trying to scale up a vector with length 0");
        const scaleAmount = size / length;
        return self.GetScaled(scaleAmount);
    }

    pub inline fn Normalized(self: *Vec2) Vec2 {
        const length = self.Length();
        if (length == 0.0) @panic("Normalizing vector with length 0");
        return Vec2{
            .x = self.x / length,
            .y = self.y / length,
        };
    }

    pub inline fn NormalizeSelf(self: *Vec2) void {
        const length = self.Length();
        if (length == 0.0) @panic("Normalizing vector with length 0");
        self.x /= length;
        self.y /= length;
    }
};

//TODO testing
