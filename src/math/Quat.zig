const em = @import("Math.zig");
const stdm = @import("std").math;

pub const identity = Quat{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 };

pub const Quat = packed struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    w: f32 = 0.0,

    pub fn Equals(lhs: *const Quat, rhs: *const Quat) bool {
        return em.EqualWithinTolerance(f32, lhs.x, rhs.x, em.f32_epsilon);
    }

    // Roll
    pub fn GetXEuler(self: *const Quat) f32 {
        return stdm.atan(2.0 * (self.y * self.z + self.x * self.w), 1 - (2 * (self.x * self.x + self.y * self.y)));
    }

    // Pitch
    pub fn GetYEuler(self: *const Quat) f32 {
        return stdm.asin(2.0 * (self.x * self.z - self.y * self.w));
    }

    // Yaw
    pub fn GetZEuler(self: *const Quat) f32 {
        return stdm.atan(2.0 * (self.w * self.z + self.x * self.y), 1 - (2 * (self.y * self.y + self.z * self.z)));
    }

    pub fn GetEulerAngles(self: *const Quat) em.Vec3 {
        return em.Vec3{ .x = self.GetXEuler(), .y = self.GetYEuler(), .z = self.GetZEuler() };
    }

    pub fn GetInverse(self: *const Quat) Quat {
        return Quat{ .x = -self.x, .y = -self.y, .z = -self.z, .w = self.w };
    }

    pub fn Inverse(self: *Quat) void {
        self.x = -self.x;
        self.y = -self.y;
        self.z = -self.z;
    }

    pub fn Length(self: *const Quat) f32 {
        return stdm.sqrt(self.LengthSqrd());
    }

    pub fn LengthSqrd(self: *const Quat) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w;
    }

    pub fn Normalized(self: *const Quat) Quat {
        const length = self.Length();
        if (length == 0.0) @panic("Normalizing quaternion with length 0");
        return Quat{
            .x = self.x / length,
            .y = self.y / length,
            .z = self.z / length,
            .w = self.w / length,
        };
    }

    pub fn NormalizeSelf(self: *Quat) void {
        const length = self.Length();
        if (length == 0.0) @panic("Normalizing quaternion with length 0");
        self.x /= length;
        self.y /= length;
        self.z /= length;
        self.w /= length;
    }

    pub fn FromToRotation(lhs: *const Quat, rhs: *const Quat) Quat {
        return Mul(lhs.GetInverse(), rhs);
    }

    pub fn Mul(lhs: *const Quat, rhs: *const Quat) Quat {
        return Quat{
            .x = lhs.w * rhs.x + lhs.x * rhs.w - lhs.y * rhs.z + lhs.z * rhs.y,
            .y = lhs.w * rhs.y + lhs.x * rhs.z + lhs.y * rhs.w - lhs.z * rhs.x,
            .z = lhs.w * rhs.z - lhs.x * rhs.y + lhs.y * rhs.x + lhs.z * rhs.w,
            .w = lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,
        };
    }

    //TODO
    //pub  fn AngleBetween(lhs: *const Quat, rhs: *const Quat) f32 {}

    //TODO lerp

    //TODO slerp
};

//TODO testing
