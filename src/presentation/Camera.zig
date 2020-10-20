const Vec3 = @import("../math/Vec3.zig").Vec3;

pub const Camera = struct {
    m_eye: Vec3,
    m_target: Vec3,
    m_up: Vec3,

    m_fovY: f32,
    m_aspectRatio: f32,
    m_nearPlane: f32,
};
