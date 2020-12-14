const vec3 = @import("Vec3.zig");
const quat = @import("Quat.zig");
const Vec3 = vec3.Vec3;
const Quat = quat.Quat;

pub const Transform = struct {
    m_scale = vec3.one,
    m_rotation = quat.identity,
    m_position = vec3.zero,
};
