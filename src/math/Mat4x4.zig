const debug = @import("std").debug;
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
                [4]f32{ 1.0 - 2.0 * (q.y * q.y + q.y * q.y), 2.0 * (q.x * q.y - q.z * q.w), 2.0 * (q.x * q.z + q.y * q.w), 0.0 },
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

//TODO testing
