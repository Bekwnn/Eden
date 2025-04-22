const Vec3 = @import("Vec3.zig").Vec3;
const Quat = @import("Quat.zig").Quat;

pub const Transform = struct {
    m_scale: Vec3 = Vec3.one,
    m_rotation: Quat = Quat.identity,
    m_position: Vec3 = Vec3.zero,
};
