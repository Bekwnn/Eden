const debug = @import("std").debug;
const Vec3 = @import("Vec3.zig").Vec3;

fn swap(lhs: *f32, rhs: *f32) void {
    const temp = lhs;
    lhs = rhs;
    rhs = temp;
}

pub const identity = Mat3x3{};
pub const zero = Mat3x3{
    .m = [3][3]f32{
        [3]f32{ 0.0, 0.0, 0.0 },
        [3]f32{ 0.0, 0.0, 0.0 },
        [3]f32{ 0.0, 0.0, 0.0 },
    },
};

pub const Mat3x3 = extern struct {
    m: [3][3]f32 = [3][3]f32{
        [3]f32{ 1.0, 0.0, 0.0 },
        [3]f32{ 0.0, 1.0, 0.0 },
        [3]f32{ 0.0, 0.0, 1.0 },
    },

    pub fn Mul(self: *const Mat3x3, other: *const Mat3x3) Mat3x3 {
        var returnMat = Mat3x3{};
        comptime var selfIter = 0;
        inline while (selfIter < 3) : (selfIter += 1) {
            comptime var otherIter = 0;
            inline while (otherIter < 3) : (otherIter += 1) {
                returnMat.m[selfIter][otherIter] =
                    self.m[selfIter][0] * other.m[0][otherIter] +
                    self.m[selfIter][1] * other.m[1][otherIter] +
                    self.m[selfIter][2] * other.m[2][otherIter];
            }
        }
        return returnMat;
    }

    pub fn Rotate(self: *const Mat3x3, vec: *const Vec3) Vec3 {
        return Vec3{
            .x = self.m[0][0] * vec.x + self.m[0][1] * vec.y + self.m[0][2] * vec.z,
            .y = self.m[1][0] * vec.x + self.m[1][1] * vec.y + self.m[1][2] * vec.z,
            .z = self.m[2][0] * vec.x + self.m[2][1] * vec.y + self.m[2][2] * vec.z,
        };
    }

    pub fn GetForwardVec(self: *const Mat3x3) Vec3 {
        return self.Rotate(Vec3.zAxis);
    }

    pub fn GetRightVec(self: *const Mat3x3) Vec3 {
        return self.Rotate(Vec3.xAxis);
    }

    pub fn GetUpVec(self: *const Mat3x3) Vec3 {
        return self.Rotate(Vec3.yAxis);
    }

    pub fn Transpose(self: *const Mat3x3) Mat3x3 {
        return Mat3x3{
            .m = [3][3]f32{
                [3]f32{ self.m[0][0], self.m[1][0], self.m[2][0] },
                [3]f32{ self.m[0][1], self.m[1][1], self.m[2][1] },
                [3]f32{ self.m[0][2], self.m[1][2], self.m[2][2] },
            },
        };
    }

    pub fn TransposeSelf(self: *Mat3x3) void {
        swap(&self.m[0][1], &self.m[1][0]);
        swap(&self.m[0][2], &self.m[2][0]);
        swap(&self.m[1][2], &self.m[2][1]);
    }

    pub fn LookDirMat3x3(direction: Vec3, up: Vec3) Mat3x3 {
        const lookAtVec = direction.Normalized();
        const rightVec = up.Cross(lookAtVec).Normalized();
        //TODO result may need transposing
        return Mat3x3{
            .m = [3][3]f32{
                [3]f32{ rightVec.x, rightVec.y, rightVec.z },
                [3]f32{ up.x, up.y, up.z },
                [3]f32{ lookAtVec.x, lookAtVec.y, lookAtVec.z },
            },
        };
    }

    //TODO proper fmt usage, line breaks? etc
    pub fn DebugLogMat3x3(mat: *const Mat3x3) void {
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
//test "Eden.Math.Mat3x3" {
//}
