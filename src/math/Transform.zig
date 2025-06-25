const Mat4x4 = @import("Mat4x4.zig").Mat4x4;
const Vec3 = @import("Vec3.zig").Vec3;
const Quat = @import("Quat.zig").Quat;

pub const Transform = struct {
    m_position: Vec3 = Vec3.zero,
    m_rotation: Quat = Quat.identity,
    m_scale: Vec3 = Vec3.one,

    pub fn GetMat4x4(self: *const Transform) Mat4x4 {
        var returnVal = Mat4x4.FromQuat(self.m_rotation);
        returnVal.SetScale(self.m_scale);
        returnVal.SetTranslation(self.m_position);
        return returnVal;
    }

    pub fn Equals(self: *const Transform, lhs: *const Transform) bool {
        return self.m_position.Equals(lhs.m_position) and
            self.m_rotation.Equals(&lhs.m_rotation) and
            self.m_scale.Equals(lhs.m_scale);
    }
};

//test "Convert to Mat4" {
//    const testing = @import("std").testing;
//
//    const transformBefore = Transform{
//        .m_position = Vec3{ .x = 1.0, .y = 2.0, .z = 4.0 },
//        .m_rotation = Quat.FromEulerAngles(20.0, 30.0, 40.0),
//        .m_scale = Vec3{ .x = 2.5, .y = 2.5, .z = 2.5 },
//    };
//    const convertedToMat4 = transformBefore.GetMat4x4();
//    const transformAfter = Transform{
//        .m_position = convertedToMat4.GetTranslation(),
//        .m_rotation = convertedToMat4.GetRotationQuat(),
//        .m_scale = convertedToMat4.GetScale(),
//    };
//
//    try testing.expect(transformBefore.Equals(&transformAfter));
//}
