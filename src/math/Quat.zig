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

    // Yaw - returns Radians
    pub fn GetYaw(self: *const Quat) f32 {
        return stdm.atan2(
            2.0 * (self.w * self.y + self.x * self.z),
            1.0 - 2.0 * (self.y * self.y + self.x * self.x),
        );
    }

    // Pitch - returns Radians
    pub fn GetPitch(self: *const Quat) f32 {
        const sinPitch = 2.0 * (self.w * self.x - self.y * self.z);
        if (@abs(sinPitch) >= 1.0) {
            return if (sinPitch > 0.0) std.math.pi / 2.0 else -std.math.pi / 2.0;
        } else {
            return stdm.asin(sinPitch);
        }
    }

    // Roll - returns Radians
    pub fn GetRoll(self: *const Quat) f32 {
        return stdm.atan2(
            2.0 * (self.w * self.z + self.x * self.y),
            1.0 - 2.0 * (self.x * self.x + self.z * self.z),
        );
    }

    // x=Pitch, y=Yaw, z=Roll in Radians
    pub fn GetEulerAngles(self: *const Quat) Vec3 {
        return Vec3{
            .x = self.GetPitch(),
            .y = self.GetYaw(),
            .z = self.GetRoll(),
        };
    }

    pub fn FromEulerAngles(yawRad: f32, pitchRad: f32, rollRad: f32) Quat {
        const cosY = @cos(yawRad * 0.5);
        const sinY = @sin(yawRad * 0.5);
        const cosX = @cos(pitchRad * 0.5);
        const sinX = @sin(pitchRad * 0.5);
        const cosZ = @cos(rollRad * 0.5);
        const sinZ = @sin(rollRad * 0.5);

        // YXZ yaw, pitch, roll rotation order
        return Quat{
            .x = cosY * sinX * cosZ + sinY * cosX * sinZ,
            .y = sinY * cosX * cosZ - cosY * sinX * sinZ,
            .z = cosY * cosX * sinZ - sinY * sinX * cosZ,
            .w = cosY * cosX * cosZ + sinY * sinX * sinZ,
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
    pub fn GetAxisRotation(axis: Vec3, rotationRad: f32) Quat {
        const axisNorm = axis.Normalized();
        const halfAngleRad = rotationRad * 0.5;
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

    pub fn Mul(lhs: *const Quat, rhs: Quat) Quat {
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
        .x = 10.0 * std.math.rad_per_deg,
        .y = 25.0 * std.math.rad_per_deg,
        .z = 45.0 * std.math.rad_per_deg,
    };
    const r1 = Quat.FromEulerAngles(r1Euler.y, r1Euler.x, r1Euler.z);
    const r1RecreatedEuler = r1.GetEulerAngles();
    std.testing.expect(r1Euler.Equals(r1RecreatedEuler)) catch |err| {
        std.debug.print("\nr1Euler: ", .{});
        r1Euler.DebugLog();
        std.debug.print("\nr1RecreatedEuler: ", .{});
        r1RecreatedEuler.DebugLog();
        return err;
    };

    const roll180 = Quat.FromEulerAngles(0.0, 0.0, std.math.pi);
    const rollRotatedVec = roll180.Rotate(Vec3.one);
    const rollExpectedVec = Vec3{ .x = -1.0, .y = -1.0, .z = 1.0 };
    std.testing.expect(rollRotatedVec.Equals(rollExpectedVec)) catch |err| {
        std.debug.print("\nrollRotatedVec: ", .{});
        rollRotatedVec.DebugLog();
        std.debug.print("\nrollExpectedVec: ", .{});
        rollExpectedVec.DebugLog();
        return err;
    };

    const pitch180 = Quat.FromEulerAngles(0.0, std.math.pi, 0.0);
    const pitchRotatedVec = pitch180.Rotate(Vec3.one);
    const pitchExpectedVec = Vec3{ .x = 1.0, .y = -1.0, .z = -1.0 };
    std.testing.expect(pitchRotatedVec.Equals(pitchExpectedVec)) catch |err| {
        std.debug.print("\npitchRotatedVec: ", .{});
        pitchRotatedVec.DebugLog();
        std.debug.print("\npitchExpectedVec: ", .{});
        pitchExpectedVec.DebugLog();
        return err;
    };

    const yaw180 = Quat.FromEulerAngles(std.math.pi, 0.0, 0.0);
    const yawRotatedVec = yaw180.Rotate(Vec3.one);
    const yawExpectedVec = Vec3{ .x = -1.0, .y = 1.0, .z = -1.0 };
    std.testing.expect(yawRotatedVec.Equals(yawExpectedVec)) catch |err| {
        std.debug.print("\nyawRotatedVec: ", .{});
        yawRotatedVec.DebugLog();
        std.debug.print("\nyawExpectedVec: ", .{});
        yawExpectedVec.DebugLog();
        return err;
    };
}
