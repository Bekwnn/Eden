const Mat4x4 = @import("Mat4x4.zig").Mat4x4;
const Vec3 = @import("Vec3.zig").Vec3;
const Quat = @import("Quat.zig").Quat;

pub const Transform = struct {
    m_position: Vec3 = Vec3.zero,
    m_rotation: Quat = Quat.identity,
    m_scale: Vec3 = Vec3.one,

    pub const default_tolerance: f32 = 0.00001;

    pub fn GetMat4x4(self: Transform) Mat4x4 {
        var returnVal = Mat4x4.FromQuat(self.m_rotation);
        returnVal.SetScale(self.m_scale);
        returnVal.SetTranslation(self.m_position);
        return returnVal;
    }

    pub fn Equals(self: Transform, lhs: Transform) bool {
        return self.EqualsT(lhs, default_tolerance);
    }

    pub fn EqualsT(self: Transform, lhs: Transform, tolerance: f32) bool {
        return self.m_position.EqualsT(lhs.m_position, tolerance) and
            self.m_rotation.EqualsT(lhs.m_rotation, tolerance) and
            self.m_scale.EqualsT(lhs.m_scale, tolerance);
    }
};

test "conversion" {
    const std = @import("std");
    const testing = std.testing;

    const transformBefore = Transform{
        .m_position = Vec3{ .x = 1.0, .y = 2.0, .z = 4.0 },
        .m_rotation = Quat.FromEulerAngles(20.0, 30.0, 40.0),
        .m_scale = Vec3{ .x = 2.5, .y = 2.5, .z = 2.5 },
    };
    const convertedToMat4 = transformBefore.GetMat4x4();
    const transformAfter = Transform{
        .m_position = convertedToMat4.GetTranslation(),
        .m_rotation = convertedToMat4.GetRotationQuat(),
        .m_scale = convertedToMat4.GetScale(),
    };

    testing.expect(transformBefore.Equals(transformAfter)) catch |err| {
        std.debug.print("{any}\n", .{err});
        transformBefore.m_position.DebugLog("before-position");
        std.debug.print("\n", .{});
        transformBefore.m_rotation.DebugLog("before-rotation");
        std.debug.print("\n", .{});
        transformBefore.m_scale.DebugLog("before-scale");
        std.debug.print("\n", .{});
        transformAfter.m_position.DebugLog("after-position");
        std.debug.print("\n", .{});
        transformAfter.m_rotation.DebugLog("after-rotation");
        std.debug.print("\n", .{});
        transformAfter.m_scale.DebugLog("after-scale");
        std.debug.print("\n", .{});
        return err;
    };
}
