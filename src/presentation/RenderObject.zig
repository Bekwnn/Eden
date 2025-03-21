const c = @import("../c.zig");

const std = @import("std");
const allocator = std.heap.page_allocator;

const mat4x4 = @import("../math/Mat4x4.zig");
const Mat4x4 = mat4x4.Mat4x4;

const Mesh = @import("Mesh.zig").Mesh;
const Material = @import("Material.zig").Material;
const Buffer = @import("Buffer.zig").Buffer;

pub const RenderObject = struct {
    m_indexCount: u32,
    m_firstIndex: u32,
    m_indexBuffer: Buffer,

    m_material: *Material,

    m_transform: Mat4x4 = mat4x4.identity,
    m_vertBufferAddress: c.VkDeviceAddress,
};
