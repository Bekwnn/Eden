const std = @import("std");
const ArrayList = std.ArrayList;

const mat4x4 = @import("math/Mat4x4");
const Mat4x4 = mat4x4.Mat4x4;

pub const VisualObject = struct {
    m_name: []const u8,

    m_mesh: ?*Mesh,
    m_material: ?*Material,
    m_transform: Mat4x4 = mat4x4.identity;
};
