const mat4x4 = @import("../math/Mat4x4.zig");
const Mat4x4 = mat4x4.Mat4x4;

pub const FrameUBO = struct {
    m_view: Mat4x4,
    m_projection: Mat4x4,
    m_viewProjection: Mat4x4,
};

pub fn CreateFrameUBO(view: Mat4x4, projection: Mat4x4) FrameUBO {
    return FrameUBO{
        .m_view = view,
        .m_projection = projection,
        .m_viewProjection = view.Mul(projection), //TODO order correct?
    };
}
