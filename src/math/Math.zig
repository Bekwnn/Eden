// rename to EdenMath.zig?

pub const color = @import("Color.zig");
pub const Mat3x3 = @import("Mat3x3.zig").Mat3x3;
pub const Mat4x4 = @import("Mat4x4.zig").Mat4x4;
pub const Plane = @import("Plane.zig").Plane;
pub const Quat = @import("Quat.zig").Quat;
pub const Transform = @import("Transform.zig").Transform;
pub const Vec2 = @import("Vec2.zig").Vec2;
pub const Vec3 = @import("Vec3.zig").Vec3;
pub const Vec4 = @import("Vec3.zig").Vec3;

test "Eden.Math" {
    @import("std").testing.refAllDecls(@This());
}
