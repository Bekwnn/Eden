const std = @import("std");
const allocator = std.heap.page_allocator;

const Buffer = @import("Buffer.zig").Buffer;
const c = @import("../c.zig");
const DescriptorAllocator = @import("DescriptorAllocator.zig").DescriptorAllocator;
const Mat4x4 = @import("../math/Mat4x4.zig").Mat4x4;
const Material = @import("Material.zig").Material;
const MaterialInstance = @import("MaterialInstance.zig").MaterialInstance;
const Mesh = @import("Mesh.zig").Mesh;
const RenderContext = @import("RenderContext.zig").RenderContext;

pub const RenderObjError = error{
    NoMeshBufferData,
};

pub const RenderObject = struct {
    const Self = @This();

    m_materialInstance: *MaterialInstance,
    m_mesh: *Mesh,
    m_objectDescriptorSet: ?c.VkDescriptorSet = null,

    m_transform: Mat4x4 = Mat4x4.identity,

    pub fn AllocateDescriptorSet(
        self: *Self,
        dAllocator: *DescriptorAllocator,
        layout: c.VkDescriptorSetLayout,
    ) !void {
        const rContext = try RenderContext.GetInstance();
        self.m_objectDescriptorSet = try dAllocator.Allocate(rContext.m_logicalDevice, layout);
    }

    pub fn Draw(self: *Self, cmd: c.VkCommandBuffer) !void {
        if (self.m_mesh.m_bufferData) |*meshBufferData| {
            //bind pipeline
            //TODO sort render objs by material and move this out
            const rContext = try RenderContext.GetInstance();
            const frameData = rContext.GetCurrentFrame();
            c.vkCmdBindDescriptorSets(
                cmd,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                self.m_materialInstance.m_parentMaterial.m_shaderPass.m_pipelineLayout,
                3,
                1,
                &(self.m_objectDescriptorSet orelse frameData.m_emptyDescriptorSet),
                0,
                null,
            );

            //bind vertex and index buffers
            const offsets = [_]c.VkDeviceSize{0};
            const vertexBuffers = [_]c.VkBuffer{
                meshBufferData.m_vertexBuffer.m_buffer,
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
                meshBufferData.m_indexBuffer.m_buffer,
                0,
                c.VK_INDEX_TYPE_UINT32,
            );

            c.vkCmdDrawIndexed(
                cmd,
                @intCast(self.m_mesh.m_indices.items.len),
                1,
                0,
                0,
                0,
            );
        } else {
            return RenderObjError.NoMeshBufferData;
        }
    }
};
