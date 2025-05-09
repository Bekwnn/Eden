// rename to EdenMath.zig?

pub const Vec3 = @import("Vec3.zig").Vec3;
pub const Vec2 = @import("Vec2.zig").Vec2;
pub const Quat = @import("Quat.zig").Quat;
pub const Mat3x3 = @import("Mat3x3.zig").Mat3x3;
pub const Mat4x4 = @import("Mat4x4.zig").Mat4x4;
pub const transform = @import("Transform.zig").Transform;

test "Eden.Math" {
    @import("std").testing.refAllDecls(@This());
}
