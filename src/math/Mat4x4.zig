const debug = @import("std").debug;
const Vec3 = @import("Vec3.zig").Vec3;

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
        var returnMat = identity;
        returnMat.m[0][3] = translation.x;
        returnMat.m[1][3] = translation.y;
        returnMat.m[2][3] = translation.z;
        return returnMat;
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
