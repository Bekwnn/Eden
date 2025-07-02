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

    pub const default_tolerance = 0.00001;

    pub fn Equals(lhs: Quat, rhs: Quat) bool {
        return EqualsT(lhs, rhs, default_tolerance);
    }

    pub fn EqualsT(lhs: Quat, rhs: Quat, tolerance: f32) bool {
        return stdm.approxEqAbs(f32, lhs.x, rhs.x, tolerance) and
            stdm.approxEqAbs(f32, lhs.y, rhs.y, tolerance) and
            stdm.approxEqAbs(f32, lhs.z, rhs.z, tolerance) and
            stdm.approxEqAbs(f32, lhs.w, rhs.w, tolerance);
    }

    // Yaw - returns Radians
    pub fn GetYaw(self: Quat) f32 {
        return stdm.atan2(
            2.0 * (self.w * self.y + self.x * self.z),
            1.0 - 2.0 * (self.y * self.y + self.x * self.x),
        );
    }

    // Pitch - returns Radians
    pub fn GetPitch(self: Quat) f32 {
        const sinPitch = 2.0 * (self.w * self.x - self.y * self.z);
        if (@abs(sinPitch) >= 1.0) {
            return if (sinPitch > 0.0) std.math.pi / 2.0 else -std.math.pi / 2.0;
        } else {
            return stdm.asin(sinPitch);
        }
    }

    // Roll - returns Radians
    pub fn GetRoll(self: Quat) f32 {
        return stdm.atan2(
            2.0 * (self.w * self.z + self.x * self.y),
            1.0 - 2.0 * (self.x * self.x + self.z * self.z),
        );
    }

    // x=Pitch, y=Yaw, z=Roll in Radians
    pub fn GetEulerAngles(self: Quat) Vec3 {
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

    pub fn GetInverse(self: Quat) Quat {
        return Quat{ .x = -self.x, .y = -self.y, .z = -self.z, .w = self.w };
    }

    pub fn Inverse(self: *Quat) void {
        self.x = -self.x;
        self.y = -self.y;
        self.z = -self.z;
    }

    pub fn Length(self: Quat) f32 {
        return stdm.sqrt(self.LengthSqrd());
    }

    pub fn LengthSqrd(self: Quat) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w;
    }

    pub fn IsNormalized(self: Quat) bool {
        return std.math.approxEqRel(f32, self.LengthSqrd(), 1.0, std.math.floatEps(f32));
    }

    pub fn Normalized(self: Quat) Quat {
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
        var returnQuat = Quat{
            .x = axisNorm.x * sinHalfAngle,
            .y = axisNorm.y * sinHalfAngle,
            .z = axisNorm.z * sinHalfAngle,
            .w = cosHalfAngle,
        };
        returnQuat.NormalizeSelf();
        return returnQuat;
    }

    pub fn FromToRotationQuat(lhs: Quat, rhs: Quat) Quat {
        return Mul(lhs.GetInverse(), rhs);
    }

    // pass in world up to use as ortho?
    pub fn FromToRotationVec(from: Vec3, to: Vec3) Quat {
        const aNorm = from.Normalized();
        const bNorm = to.Normalized();

        const aDotB = aNorm.Dot(bNorm);
        if (aDotB >= 1.0 - std.math.floatEps(f32)) {
            // from and to directions are roughly equal
            return identity;
        }

        // vectors are almost exact opposite directions
        if (aDotB <= -1.0 + std.math.floatEps(f32)) {
            var axis = Vec3.yAxis.Cross(aNorm); // do we want/need to take in a world up vector?
            if (axis.Length() < 1e-6) {
                // parallel to yAxis; choose another axis
                std.debug.print("not up axis!", .{});
                axis = Vec3.xAxis.Cross(aNorm);
            }
            axis.NormalizeSelf();
            return Quat{
                .x = axis.x,
                .y = axis.y,
                .z = axis.z,
                .w = 0, //w = cos(theta / 2), 180deg = pi Radians, and cos(pi/2) = 0
            };
        }

        // left-handed
        const axis = aNorm.Cross(bNorm);
        const s = @sqrt((1.0 + aDotB) * 2.0);
        const invS = 1.0 / s;

        var returnQuat = Quat{
            .x = axis.x * invS,
            .y = axis.y * invS,
            .z = axis.z * invS,
            .w = s * 0.5,
        };
        returnQuat.NormalizeSelf();
        return returnQuat;
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

    pub fn Rotate(self: Quat, vec: Vec3) Vec3 {
        const qv = Vec3{
            .x = self.x,
            .y = self.y,
            .z = self.z,
        };
        const uv = qv.Cross(vec);
        const uuv = qv.Cross(uv);
        return vec.Add(uv.GetScaled(2.0 * self.w)).Add(uuv.GetScaled(2.0));
    }

    pub fn GetForwardVec(self: Quat) Vec3 {
        return self.Rotate(Vec3.zAxis);
    }

    pub fn GetRightVec(self: Quat) Vec3 {
        return self.Rotate(Vec3.xAxis);
    }

    pub fn GetUpVec(self: Quat) Vec3 {
        return self.Rotate(Vec3.yAxis);
    }

    //pub fn AngleBetween(lhs: Quat, rhs: Quat) f32 {}

    //TODO slerp

    // TODO: would be nice to pass precision
    pub fn DebugLog(self: Quat, label: []const u8) void {
        std.debug.print("{s}: ({d:.5}, {d:.5}, {d:.5}, {d:.5})", .{ label, self.x, self.y, self.z, self.w });
    }
};

test "EulerAngles" {
    {
        const r1Euler = Vec3{
            .x = 10.0 * std.math.rad_per_deg,
            .y = 25.0 * std.math.rad_per_deg,
            .z = 45.0 * std.math.rad_per_deg,
        };
        const r1 = Quat.FromEulerAngles(r1Euler.y, r1Euler.x, r1Euler.z);
        const r1RecreatedEuler = r1.GetEulerAngles();
        std.testing.expect(r1Euler.Equals(r1RecreatedEuler)) catch |err| {
            r1Euler.DebugLog("r1Euler");
            r1RecreatedEuler.DebugLog("r1RecreatedEuler");
            return err;
        };
    }

    {
        const roll180 = Quat.FromEulerAngles(0.0, 0.0, std.math.pi);
        const rollRotatedVec = roll180.Rotate(Vec3.one);
        const rollExpectedVec = Vec3{ .x = -1.0, .y = -1.0, .z = 1.0 };
        std.testing.expect(rollRotatedVec.Equals(rollExpectedVec)) catch |err| {
            rollRotatedVec.DebugLog("rollRotatedVec");
            rollExpectedVec.DebugLog("rollExpectedVec");
            return err;
        };
    }

    {
        const pitch180 = Quat.FromEulerAngles(0.0, std.math.pi, 0.0);
        const pitchRotatedVec = pitch180.Rotate(Vec3.one);
        const pitchExpectedVec = Vec3{ .x = 1.0, .y = -1.0, .z = -1.0 };
        std.testing.expect(pitchRotatedVec.Equals(pitchExpectedVec)) catch |err| {
            pitchRotatedVec.DebugLog("pitchRotatedVec");
            pitchExpectedVec.DebugLog("pitchExpectedVec");
            return err;
        };
    }

    {
        const yaw180 = Quat.FromEulerAngles(std.math.pi, 0.0, 0.0);
        const yawRotatedVec = yaw180.Rotate(Vec3.one);
        const yawExpectedVec = Vec3{ .x = -1.0, .y = 1.0, .z = -1.0 };
        std.testing.expect(yawRotatedVec.Equals(yawExpectedVec)) catch |err| {
            yawRotatedVec.DebugLog("yawRotatedVec");
            yawExpectedVec.DebugLog("yawExpectedVec");
            return err;
        };
    }
}

test "LookAt" {
    {
        const lookAtXAxis = Quat.LookAt(Vec3.xAxis);
        const xAxis = lookAtXAxis.GetForwardVec();
        std.testing.expect(xAxis.Equals(Vec3.xAxis)) catch |err| {
            lookAtXAxis.DebugLog("lookAtXAxisQuat");
            xAxis.DebugLog("recomputedXAxis");
            return err;
        };
    }

    {
        const lookAtYAxis = Quat.LookAt(Vec3.yAxis);
        const yAxis = lookAtYAxis.GetForwardVec();
        std.testing.expect(yAxis.Equals(Vec3.yAxis)) catch |err| {
            lookAtYAxis.DebugLog("lookAtYAxisQuat");
            yAxis.DebugLog("recomputedYAxis");
            return err;
        };
    }

    {
        const lookAtZAxis = Quat.LookAt(Vec3.zAxis);
        const zAxis = lookAtZAxis.GetForwardVec();
        std.testing.expect(zAxis.Equals(Vec3.zAxis)) catch |err| {
            lookAtZAxis.DebugLog("lookAtZAxisQuat");
            zAxis.DebugLog("recomputedZAxis");
            return err;
        };
    }

    {
        const lookAtOneVec = Quat.LookAt(Vec3.one);
        std.testing.expect(lookAtOneVec.IsNormalized()) catch |err| {
            lookAtOneVec.DebugLog("lookAtOneVecQuat");
            std.debug.print("\nmagnitude: {d:.2}\n", .{lookAtOneVec.Length()});
            return err;
        };
        const oneVec = lookAtOneVec.GetForwardVec();
        std.testing.expect(oneVec.IsNormalized()) catch |err| {
            oneVec.DebugLog("lookAtOneVec.GetForward()");
            std.debug.print("\n", .{});
            return err;
        };
        std.testing.expect(oneVec.Equals(Vec3.one.Normalized())) catch |err| {
            lookAtOneVec.DebugLog("lookAtOneVecQuat");
            std.debug.print("\n", .{});
            oneVec.DebugLog("lookAtOneVec.GetForward()");
            std.debug.print("\n", .{});
            Vec3.one.Normalized().DebugLog("Vec3.one.Normalized()");
            return err;
        };
    }
}

test "Rotate" {
    try std.testing.expect(Quat.identity.Rotate(Vec3.xAxis).Equals(Vec3.xAxis));
    try std.testing.expect(Quat.identity.Rotate(Vec3.yAxis).Equals(Vec3.yAxis));
    try std.testing.expect(Quat.identity.Rotate(Vec3.zAxis).Equals(Vec3.zAxis));

    try std.testing.expect(Quat.identity.Rotate(Vec3.xAxis).Equals(Vec3.xAxis));
    try std.testing.expect(Quat.identity.Rotate(Vec3.yAxis).Equals(Vec3.yAxis));
    try std.testing.expect(Quat.identity.Rotate(Vec3.zAxis).Equals(Vec3.zAxis));
}
