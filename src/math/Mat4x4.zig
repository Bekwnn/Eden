const std = @import("std");
const debug = std.debug;

const Mat3x3 = @import("Mat3x3.zig").Mat3x3;
const Quat = @import("Quat.zig").Quat;
const Vec3 = @import("Vec3.zig").Vec3;
const Transform = @import("Transform.zig").Transform;

//TODO is there some sort of better swap?
fn swap(lhs: *f32, rhs: *f32) void {
    const temp = lhs;
    lhs = rhs;
    rhs = temp;
}

// Row major
// For transforms matrix uses the following format:
// r11*Sx, r12*Sy, r13*Sz, tx
// r21*Sx, r22*Sy, r23*Sz, ty
// r31*Sx, r32*Sy, r33*Sz, tz
//      0,      0,      0,  1
pub const Mat4x4 = extern struct {
    m: [4][4]f32 = [4][4]f32{
        [4]f32{ 1.0, 0.0, 0.0, 0.0 },
        [4]f32{ 0.0, 1.0, 0.0, 0.0 },
        [4]f32{ 0.0, 0.0, 1.0, 0.0 },
        [4]f32{ 0.0, 0.0, 0.0, 1.0 },
    },

    pub const identity = Mat4x4{};
    pub const zero = Mat4x4{
        .m = [4][4]f32{
            [4]f32{ 0.0, 0.0, 0.0, 0.0 },
            [4]f32{ 0.0, 0.0, 0.0, 0.0 },
            [4]f32{ 0.0, 0.0, 0.0, 0.0 },
            [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        },
    };

    pub fn Equals(self: *const Mat4x4, other: *const Mat4x4) bool {
        return self.EqualsT(other, std.math.floatEps(f32));
    }

    pub fn EqualsT(self: *const Mat4x4, other: *const Mat4x4, tolerance: f32) bool {
        for (self.m, other.m) |selfRow, otherRow| {
            for (selfRow, otherRow) |selfVal, otherVal| {
                if (!std.math.approxEqAbs(f32, selfVal, otherVal, tolerance)) {
                    return false;
                }
            }
        }
        return true;
    }

    pub fn Mul(self: *const Mat4x4, other: *const Mat4x4) Mat4x4 {
        var returnMat = Mat4x4{};
        comptime var selfIter = 0;
        inline while (selfIter < 4) : (selfIter += 1) {
            comptime var otherIter = 0;
            inline while (otherIter < 4) : (otherIter += 1) {
                returnMat.m[selfIter][otherIter] =
                    self.m[selfIter][0] * other.m[0][otherIter] +
                    self.m[selfIter][1] * other.m[1][otherIter] +
                    self.m[selfIter][2] * other.m[2][otherIter] +
                    self.m[selfIter][3] * other.m[3][otherIter];
            }
        }
        return returnMat;
    }

    //TODO Pretends it's a vec4 with w=1, then tosses the w away at the end
    // but need to divide by w? or something
    pub fn MulVec3(self: *const Mat4x4, other: *const Vec3) Vec3 {
        return Vec3{
            .x = self.m[0][0] * other.x + self.m[0][1] * other.y + self.m[0][2] * other.z + self.m[0][3],
            .y = self.m[1][0] * other.x + self.m[1][1] * other.y + self.m[1][2] * other.z + self.m[1][3],
            .z = self.m[2][0] * other.x + self.m[2][1] * other.y + self.m[2][2] * other.z + self.m[2][3],
        };
    }

    pub fn Transpose(self: *const Mat4x4) Mat4x4 {
        return Mat4x4{
            .m = [4][4]f32{
                [4]f32{ self.m[0][0], self.m[1][0], self.m[2][0], self.m[3][0] },
                [4]f32{ self.m[0][1], self.m[1][1], self.m[2][1], self.m[3][1] },
                [4]f32{ self.m[0][2], self.m[1][2], self.m[2][2], self.m[3][2] },
                [4]f32{ self.m[0][3], self.m[1][3], self.m[2][3], self.m[3][3] },
            },
        };
    }

    pub fn TransposeSelf(self: *Mat4x4) void {
        swap(&self.m[0][1], &self.m[1][0]);
        swap(&self.m[0][2], &self.m[2][0]);
        swap(&self.m[0][3], &self.m[3][0]);
        swap(&self.m[1][2], &self.m[2][1]);
        swap(&self.m[1][3], &self.m[3][1]);
        swap(&self.m[2][3], &self.m[3][2]);
    }

    pub fn LookAt(eyePos: Vec3, lookDir: Vec3, up: Vec3) Mat4x4 {
        const lookNorm = lookDir.Normalized();
        const rightVec = up.Cross(lookNorm).Normalized();
        const cameraUp = lookNorm.Cross(rightVec);
        const lookAtMat = Mat4x4{
            .m = [4][4]f32{
                [_]f32{ rightVec.x, rightVec.y, rightVec.z, -rightVec.Dot(eyePos) },
                [_]f32{ cameraUp.x, cameraUp.y, cameraUp.z, -cameraUp.Dot(eyePos) },
                [_]f32{ lookNorm.x, lookNorm.y, lookNorm.z, -lookNorm.Dot(eyePos) },
                [_]f32{ 0.0, 0.0, 0.0, 1.0 },
            },
        };

        return lookAtMat;
    }

    pub fn GetPitch(self: *const Mat4x4) f32 {
        return std.math.asin(self.m[1][0]);
    }
    pub fn GetYaw(self: *const Mat4x4) f32 {
        return std.math.atan2(-self.m[2][0], self.m[0][0]);
    }
    pub fn GetRoll(self: *const Mat4x4) f32 {
        return std.math.atan2(-self.m[1][2], self.m[1][1]);
    }

    //x=Pitch, y=Yaw, z=Roll in Radians
    pub fn GetEulerAngles() Vec3 {
        return Vec3{
            .x = GetPitch(),
            .y = GetYaw(),
            .z = GetRoll(),
        };
    }

    pub fn Translation(translation: Vec3) Mat4x4 {
        return Mat4x4{
            .m = [4][4]f32{
                [4]f32{ 1.0, 0.0, 0.0, translation.x },
                [4]f32{ 0.0, 1.0, 0.0, translation.y },
                [4]f32{ 0.0, 0.0, 1.0, translation.z },
                [4]f32{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    //TODO testing
    pub fn GetRotationMat3x3(self: *const Mat4x4) Mat3x3 {
        var row0 = Vec3{ .x = self.m[0][0], .y = self.m[0][1], .z = self.m[0][2] };
        row0.NormalizeSelf();
        var row1 = Vec3{ .x = self.m[1][0], .y = self.m[1][1], .z = self.m[1][2] };
        row1.NormalizeSelf();
        var row2 = Vec3{ .x = self.m[2][0], .y = self.m[2][1], .z = self.m[2][2] };
        row2.NormalizeSelf();

        return Mat3x3{ .m = [3][3]f32{
            [3]f32{ row0.x, row0.y, row0.z },
            [3]f32{ row1.x, row1.y, row1.z },
            [3]f32{ row2.x, row2.y, row2.z },
        } };
    }

    //TODO testing
    pub fn GetRotationQuat(self: *const Mat4x4) Quat {
        const mat3x3 = self.GetRotationMat3x3();

        const trace = mat3x3.m[0][0] + mat3x3.m[1][1] + mat3x3.m[2][2];

        if (trace > 0.0) {
            const s = @sqrt(trace + 1.0) * 2.0;
            var retRot = Quat{
                .x = (mat3x3.m[2][1] - mat3x3.m[1][2]) / s,
                .y = (mat3x3.m[0][2] - mat3x3.m[2][0]) / s,
                .z = (mat3x3.m[1][0] - mat3x3.m[0][1]) / s,
                .w = 0.25 * s,
            };
            retRot.NormalizeSelf();
            return retRot;
        } else if (self.m[0][0] > self.m[1][1] and self.m[0][0] > self.m[2][2]) {
            const s = @sqrt(1.0 + mat3x3.m[0][0] - mat3x3.m[1][1] - mat3x3.m[2][2]) * 2.0;
            var retRot = Quat{
                .x = 0.25 * s,
                .y = (mat3x3.m[1][0] - mat3x3.m[0][1]) / s,
                .z = (mat3x3.m[0][2] - mat3x3.m[2][0]) / s,
                .w = (mat3x3.m[2][1] - mat3x3.m[1][2]) / s,
            };
            retRot.NormalizeSelf();
            return retRot;
        } else if (self.m[1][1] > self.m[2][2]) {
            const s = @sqrt(1.0 + mat3x3.m[1][1] - mat3x3.m[0][0] - mat3x3.m[2][2]) * 2.0;
            var retRot = Quat{
                .x = (self.m[1][0] - self.m[0][1]) / s,
                .y = 0.25 * s,
                .z = (self.m[2][1] - self.m[1][2]) / s,
                .w = (self.m[0][2] - self.m[2][0]) / s,
            };
            retRot.NormalizeSelf();
            return retRot;
        } else { // self.m[2][2] is greatest
            const s = @sqrt(1.0 + mat3x3.m[2][2] - mat3x3.m[0][0] - mat3x3.m[1][1]) * 2.0;
            var retRot = Quat{
                .x = (self.m[0][2] - self.m[2][0]) / s,
                .y = (self.m[2][1] - self.m[1][2]) / s,
                .z = 0.25 * s,
                .w = (self.m[1][0] - self.m[0][1]) / s,
            };
            retRot.NormalizeSelf();
            return retRot;
        }
    }

    pub fn Determinent(self: *const Mat4x4) f32 {
        const A2323 = self.m[2][2] * self.m[3][3] - self.m[2][3] * self.m[3][2];
        const A1323 = self.m[2][1] * self.m[3][3] - self.m[2][3] * self.m[3][1];
        const A1223 = self.m[2][1] * self.m[3][2] - self.m[2][2] * self.m[3][1];
        const A0323 = self.m[2][0] * self.m[3][3] - self.m[2][3] * self.m[3][0];
        const A0223 = self.m[2][0] * self.m[3][2] - self.m[2][2] * self.m[3][0];
        const A0123 = self.m[2][0] * self.m[3][1] - self.m[2][1] * self.m[3][0];

        // zig fmt: off
        return self.m[0][0] * (self.m[1][1] * A2323 - self.m[1][2] * A1323 + self.m[1][3] * A1223)
             - self.m[0][1] * (self.m[1][0] * A2323 - self.m[1][2] * A0323 + self.m[1][3] * A0223)
             + self.m[0][2] * (self.m[1][0] * A1323 - self.m[1][1] * A0323 + self.m[1][3] * A0123)
             - self.m[0][3] * (self.m[1][0] * A1223 - self.m[1][1] * A0223 + self.m[1][2] * A0123);
        // zig fmt: on
    }

    pub fn Inverse(self: *const Mat4x4) !Mat4x4 {
        const A2323 = self.m[2][2] * self.m[3][3] - self.m[2][3] * self.m[3][2];
        const A1323 = self.m[2][1] * self.m[3][3] - self.m[2][3] * self.m[3][1];
        const A1223 = self.m[2][1] * self.m[3][2] - self.m[2][2] * self.m[3][1];
        const A0323 = self.m[2][0] * self.m[3][3] - self.m[2][3] * self.m[3][0];
        const A0223 = self.m[2][0] * self.m[3][2] - self.m[2][2] * self.m[3][0];
        const A0123 = self.m[2][0] * self.m[3][1] - self.m[2][1] * self.m[3][0];
        const A2313 = self.m[1][2] * self.m[3][3] - self.m[1][3] * self.m[3][2];
        const A1313 = self.m[1][1] * self.m[3][3] - self.m[1][3] * self.m[3][1];
        const A1213 = self.m[1][1] * self.m[3][2] - self.m[1][2] * self.m[3][1];
        const A2312 = self.m[1][2] * self.m[2][3] - self.m[1][3] * self.m[2][2];
        const A1312 = self.m[1][1] * self.m[2][3] - self.m[1][3] * self.m[2][1];
        const A1212 = self.m[1][1] * self.m[2][2] - self.m[1][2] * self.m[2][1];
        const A0313 = self.m[1][0] * self.m[3][3] - self.m[1][3] * self.m[3][0];
        const A0213 = self.m[1][0] * self.m[3][2] - self.m[1][2] * self.m[3][0];
        const A0312 = self.m[1][0] * self.m[2][3] - self.m[1][3] * self.m[2][0];
        const A0212 = self.m[1][0] * self.m[2][2] - self.m[1][2] * self.m[2][0];
        const A0113 = self.m[1][0] * self.m[3][1] - self.m[1][1] * self.m[3][0];
        const A0112 = self.m[1][0] * self.m[2][1] - self.m[1][1] * self.m[2][0];

        // zig fmt: off
        var det = self.m[0][0] * (self.m[1][1] * A2323 - self.m[1][2] * A1323 + self.m[1][3] * A1223)
                - self.m[0][1] * (self.m[1][0] * A2323 - self.m[1][2] * A0323 + self.m[1][3] * A0223)
                + self.m[0][2] * (self.m[1][0] * A1323 - self.m[1][1] * A0323 + self.m[1][3] * A0123)
                - self.m[0][3] * (self.m[1][0] * A1223 - self.m[1][1] * A0223 + self.m[1][2] * A0123);
        // zig fmt: on
        const Mat4Error = error{NoInverse};
        if (det == 0.0) {
            return Mat4Error.NoInverse;
        }
        det = 1.0 / det;

        return Mat4x4{
            .m = [4][4]f32{
                [_]f32{
                    det * (self.m[1][1] * A2323 - self.m[1][2] * A1323 + self.m[1][3] * A1223),
                    det * -(self.m[0][1] * A2323 - self.m[0][2] * A1323 + self.m[0][3] * A1223),
                    det * (self.m[0][1] * A2313 - self.m[0][2] * A1313 + self.m[0][3] * A1213),
                    det * -(self.m[0][1] * A2312 - self.m[0][2] * A1312 + self.m[0][3] * A1212),
                },
                [_]f32{
                    det * -(self.m[1][0] * A2323 - self.m[1][2] * A0323 + self.m[1][3] * A0223),
                    det * (self.m[0][0] * A2323 - self.m[0][2] * A0323 + self.m[0][3] * A0223),
                    det * -(self.m[0][0] * A2313 - self.m[0][2] * A0313 + self.m[0][3] * A0213),
                    det * (self.m[0][0] * A2312 - self.m[0][2] * A0312 + self.m[0][3] * A0212),
                },
                [_]f32{
                    det * (self.m[1][0] * A1323 - self.m[1][1] * A0323 + self.m[1][3] * A0123),
                    det * -(self.m[0][0] * A1323 - self.m[0][1] * A0323 + self.m[0][3] * A0123),
                    det * (self.m[0][0] * A1313 - self.m[0][1] * A0313 + self.m[0][3] * A0113),
                    det * -(self.m[0][0] * A1312 - self.m[0][1] * A0312 + self.m[0][3] * A0112),
                },
                [_]f32{
                    det * -(self.m[1][0] * A1223 - self.m[1][1] * A0223 + self.m[1][2] * A0123),
                    det * (self.m[0][0] * A1223 - self.m[0][1] * A0223 + self.m[0][2] * A0123),
                    det * -(self.m[0][0] * A1213 - self.m[0][1] * A0213 + self.m[0][2] * A0113),
                    det * (self.m[0][0] * A1212 - self.m[0][1] * A0212 + self.m[0][2] * A0112),
                },
            },
        };
    }

    pub fn FromQuat(q: Quat) Mat4x4 {
        return Mat4x4{
            .m = [4][4]f32{
                [4]f32{ 1.0 - 2.0 * (q.y * q.y + q.z * q.z), 2.0 * (q.x * q.y - q.z * q.w), 2.0 * (q.x * q.z + q.y * q.w), 0.0 },
                [4]f32{ 2.0 * (q.x * q.y + q.z * q.w), 1.0 - 2.0 * (q.x * q.x + q.z * q.z), 2.0 * (q.y * q.z - q.x * q.w), 0.0 },
                [4]f32{ 2.0 * (q.x * q.z - q.y * q.w), 2.0 * (q.y * q.z + q.x * q.w), 1.0 - 2.0 * (q.x * q.x + q.y * q.y), 0.0 },
                [4]f32{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    pub fn FromTransform(transform: *const Transform) Mat4x4 {
        var returnMat = FromQuat(transform.m_rotation);

        returnMat.m[0][0] *= transform.m_scale.x;
        returnMat.m[0][1] *= transform.m_scale.x;
        returnMat.m[0][2] *= transform.m_scale.x;
        returnMat.m[0][3] = transform.m_position.x;

        returnMat.m[1][0] *= transform.m_scale.y;
        returnMat.m[1][1] *= transform.m_scale.y;
        returnMat.m[1][2] *= transform.m_scale.y;
        returnMat.m[1][3] = transform.m_position.y;

        returnMat.m[2][0] *= transform.m_scale.z;
        returnMat.m[2][1] *= transform.m_scale.z;
        returnMat.m[2][2] *= transform.m_scale.z;
        returnMat.m[2][3] = transform.m_position.z;

        return returnMat;
    }

    pub fn GetTranslation(self: *const Mat4x4) Vec3 {
        return Vec3{
            .x = self.m[0][3],
            .y = self.m[1][3],
            .z = self.m[2][3],
        };
    }

    pub fn SetTranslation(self: *Mat4x4, translation: Vec3) void {
        self.m[0][3] = translation.x;
        self.m[1][3] = translation.y;
        self.m[2][3] = translation.z;
    }

    pub fn GetScale(self: *const Mat4x4) Vec3 {
        return Vec3{
            .x = @sqrt(self.m[0][0] * self.m[0][0] + self.m[1][0] * self.m[1][0] + self.m[2][0] * self.m[2][0]),
            .y = @sqrt(self.m[0][1] * self.m[0][1] + self.m[1][1] * self.m[1][1] + self.m[2][1] * self.m[2][1]),
            .z = @sqrt(self.m[0][2] * self.m[0][2] + self.m[1][2] * self.m[1][2] + self.m[2][2] * self.m[2][2]),
        };
    }

    pub fn SetScale(self: *Mat4x4, scale: Vec3) void {
        const curScale = self.GetScale();

        // normalize and apply new scale
        self.m[0][0] = (self.m[0][0] / curScale.x) * scale.x;
        self.m[1][0] = (self.m[1][0] / curScale.x) * scale.x;
        self.m[2][0] = (self.m[2][0] / curScale.x) * scale.x;

        self.m[0][1] = (self.m[0][1] / curScale.y) * scale.y;
        self.m[1][1] = (self.m[1][1] / curScale.y) * scale.y;
        self.m[2][1] = (self.m[2][1] / curScale.y) * scale.y;

        self.m[0][2] = (self.m[0][2] / curScale.z) * scale.z;
        self.m[1][2] = (self.m[1][2] / curScale.z) * scale.z;
        self.m[2][2] = (self.m[2][2] / curScale.z) * scale.z;
    }

    //TODO proper fmt usage, line breaks? etc
    pub fn DebugLog(mat: *const Mat4x4, label: []const u8) void {
        debug.print("{s}: ", .{label});
        for (mat.m) |row| {
            debug.print("{{", .{});
            for (row) |val| {
                debug.print("{}, ", .{val});
            }
            debug.print("}},\n", .{});
        }
    }
};

test "Inverse" {
    // random matrix with a det != 0
    const m1 = Mat4x4{
        .m = [4][4]f32{
            [_]f32{ 1.0, 1.0, 3.0, 4.0 },
            [_]f32{ 0.0, 1.0, 2.0, 0.5 },
            [_]f32{ 0.0, 0.0, 1.0, 2.0 },
            [_]f32{ 0.5, 0.0, 0.0, 1.0 },
        },
    };
    const m1Inv = try m1.Inverse();
    const result = m1.Mul(&m1Inv);
    try TestMatEqual("inverseResult", &result, "Mat4x4.identity", &Mat4x4.identity);
}

test "Transpose" {
    const m2 = Mat4x4{
        .m = [4][4]f32{
            [_]f32{ 1.0, 0.0, 1.0, 4.0 },
            [_]f32{ 0.0, 2.0, 0.0, 2.0 },
            [_]f32{ 0.0, 0.0, 3.0, 0.0 },
            [_]f32{ 0.5, 0.0, 0.0, 4.0 },
        },
    };
    const transpose = Mat4x4{
        .m = [4][4]f32{
            [_]f32{ 1.0, 0.0, 0.0, 0.5 },
            [_]f32{ 0.0, 2.0, 0.0, 0.0 },
            [_]f32{ 1.0, 0.0, 3.0, 0.0 },
            [_]f32{ 4.0, 2.0, 0.0, 4.0 },
        },
    };
    const m2t = m2.Transpose();
    const m2tt = m2t.Transpose();
    try TestMatEqual("m2t", &m2t, "transpose", &transpose);
    try TestMatEqual("m2tt", &m2tt, "m2", &m2);
}

test "Rotation" {
    const q1 = Quat.FromEulerAngles(std.math.pi, 0.0, 0.0);
    const mFromQ = Mat4x4.FromQuat(q1);
    const oneVec180m = mFromQ.MulVec3(&Vec3.one);
    const oneVec180q = q1.Rotate(Vec3.one);
    const expectedVec = Vec3{ .x = -1.0, .y = 1.0, .z = -1.0 };
    try TestVec3Equal("oneVec180q", oneVec180q, "expectedVec", expectedVec);
    try TestVec3Equal("oneVec180m", oneVec180m, "expectedVec", expectedVec);
}

test "Decomposition" {
    const quatBefore = Quat.FromEulerAngles(
        20.0 * std.math.rad_per_deg,
        40.0 * std.math.rad_per_deg,
        80.0 * std.math.rad_per_deg,
    );
    const posBefore = Vec3{ .x = 1.0, .y = 2.0, .z = 4.0 };
    const scaleBefore = Vec3{ .x = 2.5, .y = 2.5, .z = 2.5 };
    const transformMat = Mat4x4.FromTransform(&Transform{
        .m_position = posBefore,
        .m_rotation = quatBefore,
        .m_scale = scaleBefore,
    });

    try TestVec3Equal("transformPos", transformMat.GetTranslation(), "posBefore", posBefore);
    const transformRot = transformMat.GetRotationQuat();
    try TestQuatEqual("transformRot", &transformRot, "quatBefore", &quatBefore);
    try TestVec3Equal("transformScale", transformMat.GetScale(), "scaleBefore", scaleBefore);
}

fn TestQuatEqual(lhsLabel: []const u8, lhs: *const Quat, rhsLabel: []const u8, rhs: *const Quat) !void {
    std.testing.expect(lhs.Equals(rhs)) catch |err| {
        debug.print("{any}\n", .{err});
        lhs.DebugLog(lhsLabel);
        debug.print("\n", .{});
        rhs.DebugLog(rhsLabel);
        debug.print("\n", .{});
        return err;
    };
}

fn TestVec3Equal(lhsLabel: []const u8, lhs: Vec3, rhsLabel: []const u8, rhs: Vec3) !void {
    std.testing.expect(lhs.Equals(rhs)) catch |err| {
        debug.print("{any}\n", .{err});
        lhs.DebugLog(lhsLabel);
        debug.print("\n", .{});
        rhs.DebugLog(rhsLabel);
        debug.print("\n", .{});
        return err;
    };
}

fn TestMatEqual(lhsLabel: []const u8, lhs: *const Mat4x4, rhsLabel: []const u8, rhs: *const Mat4x4) !void {
    std.testing.expect(lhs.Equals(rhs)) catch |err| {
        debug.print("{any}\n", .{err});
        lhs.DebugLog(lhsLabel);
        debug.print("\n", .{});
        rhs.DebugLog(rhsLabel);
        debug.print("\n", .{});
        return err;
    };
}
