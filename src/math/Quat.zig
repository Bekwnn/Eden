const em = @import("Math.zig");
const std = @import("std");
const stdm = std.math;
const Vec3 = em.Vec3;

pub const Quat = extern struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    w: f32 = 0.0,

    pub const identity = Quat{
        .x = 0.0,
        .y = 0.0,
        .z = 0.0,
        .w = 1.0,
    };

    pub fn Equals(lhs: *const Quat, rhs: *const Quat) bool {
        inline for (std.meta.fields(@TypeOf(Quat))) |field| {
            if (field.type == @TypeOf(f32) and !stdm.approxEqAbs(f32, lhs.x, rhs.x, stdm.floatEps(f32))) {
                return false;
            }
        }
        return true;
    }

    // Pitch - returns Radians
    pub fn GetPitch(self: *const Quat) f32 {
        return stdm.asin(2.0 * (self.y * self.w - self.z * self.x));
    }

    // Roll - returns Radians
    pub fn GetRoll(self: *const Quat) f32 {
        return stdm.atan2(
            2.0 * (self.z * self.y + self.w * self.x),
            1.0 - 2.0 * (self.x * self.x + self.y * self.y),
        );
    }

    // Yaw - returns Radians
    pub fn GetYaw(self: *const Quat) f32 {
        return stdm.atan2(
            2.0 * (self.w * self.z + self.x * self.y),
            -1.0 + 2.0 * (self.w * self.w + self.x * self.x),
        );
    }

    // x=Roll, y=Pitch, z=Yaw in Radians
    pub fn GetEulerAngles(self: *const Quat) Vec3 {
        return Vec3{
            .x = self.GetRoll(),
            .y = self.GetPitch(),
            .z = self.GetYaw(),
        };
    }

    pub fn FromEulerAngles(rollRad: f32, pitchRad: f32, yawRad: f32) Quat {
        const cosRoll = @cos(rollRad * 0.5);
        const sinRoll = @sin(rollRad * 0.5);
        const cosPitch = @cos(pitchRad * 0.5);
        const sinPitch = @sin(pitchRad * 0.5);
        const cosYaw = @cos(yawRad * 0.5);
        const sinYaw = @sin(yawRad * 0.5);

        return Quat{
            .x = sinRoll * cosPitch * cosYaw - cosRoll * sinPitch * sinYaw,
            .y = cosRoll * sinPitch * cosYaw + sinRoll * cosPitch * sinYaw,
            .z = cosRoll * cosPitch * sinYaw - sinRoll * sinPitch * cosYaw,
            .w = cosRoll * cosPitch * cosYaw + sinRoll * sinPitch * sinYaw,
        };
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

    // creates a rotation around an axis
    pub fn GetAxisRotation(axis: Vec3, rotationDeg: f32) Quat {
        const axisNorm = axis.Normalized();
        const halfAngleRad = rotationDeg * em.util.degToRad * 0.5;
        const sinHalfAngle = @sin(halfAngleRad);
        const cosHalfAngle = @cos(halfAngleRad);
        return Quat{
            .x = axisNorm.x * sinHalfAngle,
            .y = axisNorm.y * sinHalfAngle,
            .z = axisNorm.z * sinHalfAngle,
            .w = cosHalfAngle,
        };
    }

    pub fn FromToRotationQuat(lhs: Quat, rhs: Quat) Quat {
        return Mul(lhs.GetInverse(), rhs);
    }

    // pass in world up to use as ortho?
    pub fn FromToRotationVec(from: Vec3, to: Vec3) Quat {
        const aNorm = from.Normalized();
        const bNorm = to.Normalized();

        const aDotB = aNorm.Dot(bNorm);
        if (aDotB > 0.9999) {
            // from and to directions are roughly equal
            return identity;
        }

        // vectors are almost exact opposite directions
        if (aDotB < -0.9999) {
            var ortho = Vec3.zAxis.Cross(aNorm); // do we want/need to take in a world up vector?
            if (ortho.Length() < 1e-6) {
                // parallel to zAxis; choose another axis
                ortho = Vec3.yAxis.Cross(aNorm);
            }
            const axis = aNorm.Cross(ortho).Normalized();
            return Quat{
                .x = axis.x,
                .y = axis.y,
                .z = axis.z,
                .w = 0, //w = cos(theta / 2), 180deg = pi Radians, and cos(pi/2) = 0
            };
        }

        const axis = aNorm.Cross(bNorm);
        const s = @sqrt((1 + aDotB) * 2.0);
        const invS = 1.0 / s;

        return Quat{
            .x = axis.x * invS,
            .y = axis.y * invS,
            .z = axis.z * invS,
            .w = s * 0.5,
        };
    }

    pub fn LookAt(lookDir: Vec3) Quat {
        return Quat.FromToRotationVec(Vec3.zAxis, lookDir);
    }

    pub fn Mul(lhs: Quat, rhs: Quat) Quat {
        return Quat{
            .x = lhs.w * rhs.x + lhs.x * rhs.w - lhs.y * rhs.z + lhs.z * rhs.y,
            .y = lhs.w * rhs.y + lhs.x * rhs.z + lhs.y * rhs.w - lhs.z * rhs.x,
            .z = lhs.w * rhs.z - lhs.x * rhs.y + lhs.y * rhs.x + lhs.z * rhs.w,
            .w = lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,
        };
    }

    pub fn Rotate(self: *const Quat, vec: Vec3) Vec3 {
        var uv = Vec3{
            .x = self.y * vec.z - self.z * vec.y,
            .y = self.z * vec.x - self.x * vec.z,
            .z = self.x * vec.y - self.y * vec.x,
        };
        var uuv = Vec3{
            .x = self.y * uv.z - self.z * uv.y,
            .y = self.z * uv.x - self.x * uv.z,
            .z = self.x * uv.y - self.y * uv.x,
        };

        uv.x *= 2.0 * self.w;
        uv.y *= 2.0 * self.w;
        uv.z *= 2.0 * self.w;

        uuv.x *= 2.0;
        uuv.y *= 2.0;
        uuv.z *= 2.0;

        return Vec3{
            .x = vec.x + uv.x + uuv.x,
            .y = vec.y + uv.y + uuv.y,
            .z = vec.z + uv.z + uuv.z,
        };
    }

    pub fn GetForwardVec(self: *const Quat) Vec3 {
        return self.Rotate(Vec3.zAxis);
    }

    pub fn GetRightVec(self: *const Quat) Vec3 {
        return self.Rotate(Vec3.xAxis);
    }

    pub fn GetUpVec(self: *const Quat) Vec3 {
        return self.Rotate(Vec3.yAxis);
    }

    //pub fn AngleBetween(lhs: *const Quat, rhs: *const Quat) f32 {}

    //TODO slerp
};

test {
    const r1Euler = Vec3{
        .x = 10.0 * em.util.degToRad,
        .y = 25.0 * em.util.degToRad,
        .z = 45.0 * em.util.degToRad,
    };
    const r1 = Quat.FromEulerAngles(r1Euler.x, r1Euler.y, r1Euler.z);
    const r1RecreatedEuler = r1.GetEulerAngles();
    try std.testing.expect(r1Euler.Equals(r1RecreatedEuler));
}
