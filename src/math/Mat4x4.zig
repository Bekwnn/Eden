const debug = @import("std").debug;
const Vec3 = @import("Vec3.zig").Vec3;

//TODO is there some sort of better swap?
fn swap(lhs: *f32, rhs: *f32) void {
    const temp = lhs;
    lhs = rhs;
    rhs = temp;
}

pub const identity = Mat4x4{};
pub const zero = Mat4x4{
    .m = [4][4]f32{
        [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        [4]f32{ 0.0, 0.0, 0.0, 0.0 },
    },
};

pub const Mat4x4 = packed struct {
    m: [4][4]f32 = [4][4]f32{
        [4]f32{ 1.0, 0.0, 0.0, 0.0 },
        [4]f32{ 0.0, 1.0, 0.0, 0.0 },
        [4]f32{ 0.0, 0.0, 1.0, 0.0 },
        [4]f32{ 0.0, 0.0, 0.0, 1.0 },
    },

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
};

pub fn LookDirMat4x4(from: Vec3, direction: Vec3, up: Vec3) Mat4x4 {
    const lookAtVec = direction.Normalized();
    const rightVec = up.Cross(lookAtVec).Normalized();
    const lookAtMat1 = Mat4x4{ //TODO may need transposing
        .m = [4][4]f32{
            [_]f32{ rightVec.x, rightVec.y, rightVec.z, 0.0 },
            [_]f32{ up.x, up.y, up.z, 0.0 },
            [_]f32{ lookAtVec.x, lookAtVec.y, lookAtVec.z, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 1.0 },
        },
    };
    const lookAtMat2 = Mat4x4{
        .m = [4][4]f32{
            [_]f32{ 1.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 1.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 1.0, 0.0 },
            [_]f32{ -from.x, -from.y, -from.z, 1.0 },
        },
    };

    return lookAtMat1.Mul(&lookAtMat2);
}

pub fn TranslationMat4x4(translation: Vec3) Mat4x4 {
    var returnMat = identity;
    returnMat.m[0][3] = translation.x;
    returnMat.m[1][3] = translation.y;
    returnMat.m[2][3] = translation.z;
    return returnMat;
}

//TODO proper fmt usage
pub fn DebugLogMat4x4(mat: *const Mat4x4) void {
    for (mat.m) |row| {
        debug.print("{{", .{});
        for (row) |val| {
            debug.print("{}, ", .{val});
        }
        debug.print("}},\n", .{});
    }
}
