const std = @import("std");
const debug = std.debug;

const Vec3 = @import("Vec3.zig").Vec3;
const Quat = @import("Quat.zig").Quat;

//TODO is there some sort of better swap?
fn swap(lhs: *f32, rhs: *f32) void {
    const temp = lhs;
    lhs = rhs;
    rhs = temp;
}

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

    // Pretends it's a vec4 with w=1, then tosses the w away at the end
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

    //TODO proper fmt usage, line breaks? etc
    pub fn DebugLog(mat: *const Mat4x4) void {
        for (mat.m) |row| {
            debug.print("{{", .{});
            for (row) |val| {
                debug.print("{}, ", .{val});
            }
            debug.print("}},\n", .{});
        }
    }
};

test {
    // Inverse testing
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
    try std.testing.expect(result.Equals(&Mat4x4.identity));

    // Transpose testing
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
    try std.testing.expect(m2t.Equals(&transpose));
    try std.testing.expect(m2tt.Equals(&m2));

    // quat conversion
    const q1 = Quat.FromEulerAngles(std.math.pi, 0.0, 0.0);
    const mFromQ = Mat4x4.FromQuat(q1);
    const oneVec180m = mFromQ.MulVec3(&Vec3.one);
    const oneVec180q = q1.Rotate(Vec3.one);
    const expectedVec = Vec3{ .x = -1.0, .y = 1.0, .z = -1.0 };
    std.testing.expect(oneVec180q.Equals(expectedVec)) catch |err| {
        oneVec180q.DebugLog("oneVec180quat");
        expectedVec.DebugLog("expectedVec");
        return err;
    };
    std.testing.expect(oneVec180m.Equals(expectedVec)) catch |err| {
        oneVec180m.DebugLog("oneVec180mat");
        expectedVec.DebugLog("expectedVec");
        return err;
    };
}
