const Vec3 = @import("Vec3.zig").Vec3;
const Vec3 = @import("Quat.zig").Quat;

pub const Transform = struct {
    m_scale: Vec3,
    m_rotation: Quat,
    m_position: Vec3,
};
