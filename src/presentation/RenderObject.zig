const c = @import("../c.zig");

const std = @import("std");
const allocator = std.heap.page_allocator;

const mat4x4 = @import("../math/Mat4x4.zig");
const Mat4x4 = mat4x4.Mat4x4;

const Mesh = @import("Mesh.zig").Mesh;
const Material = @import("Material.zig").Material;
const Buffer = @import("Buffer.zig").Buffer;

pub const RenderObject = struct {
    const Self = @This();

    m_indexBuffer: Buffer,
    m_vertBuffer: Buffer,

    m_material: *Material,
    m_mesh: *Mesh,

    m_transform: Mat4x4 = mat4x4.identity,

    pub fn Draw(self: Self, cmd: c.VkCommandBuffer) !void {
        //bind material descriptor sets

        //bind vertex and index buffers
        const offsets = [_]c.VkDeviceSize{0};
        const vertexBuffers = [_]c.VkBuffer{
            self.m_vertBuffer.m_buffer,
        };
        c.vkCmdBindVertexBuffers(
            cmd,
            0,
            1,
            &vertexBuffers,
            &offsets,
        );
        c.vkCmdBindIndexBuffer(
            cmd,
            self.m_indexBuffer.m_buffer,
            0,
            c.VK_INDEX_TYPE_UINT32,
        );

        //bind per object descriptor sets
        c.vkCmdBindDescriptorSets(
            cmd,
            c.VK_PIPELINE_BIND_POINT_GRAPHICS,
            self.m_material.m_shaderPass.m_pipelineLayout,
            0,
            1,
            self.m_material.m_shaderPass.m_shaderEffect.
            0,
            null,
        );
    }
};
