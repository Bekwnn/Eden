const c = @import("../c.zig");

const std = @import("std");
const allocator = std.heap.page_allocator;

const Mat4x4 = @import("../math/Mat4x4.zig").Mat4x4;

const Buffer = @import("Buffer.zig").Buffer;
const Material = @import("Material.zig").Material;
const MaterialInstance = @import("MaterialInstance.zig").MaterialInstance;
const Mesh = @import("Mesh.zig").Mesh;
const renderContext = @import("RenderContext.zig");
const RenderContext = renderContext.RenderContext;

pub const RenderObjError = error{
    NoMeshBufferData,
};

pub const RenderObject = struct {
    const Self = @This();

    m_materialInstance: *MaterialInstance,
    m_mesh: *Mesh,
    m_objectDescriptorSet: ?c.VkDescriptorSet = null,

    m_transform: Mat4x4 = Mat4x4.identity,

    pub fn Draw(self: Self, cmd: c.VkCommandBuffer) !void {
        if (self.m_mesh.m_bufferData) |*meshBufferData| {
            //bind pipeline
            //TODO sort render objs by material and move this out
            c.vkCmdBindPipeline(
                cmd,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                self.m_materialInstance.m_parentMaterial.m_shaderPass.m_pipeline,
            );

            //TODO bind per material and global descriptor sets outside this inner call
            const rContext = try RenderContext.GetInstance();
            const frameData = rContext.GetCurrentFrame();
            const descriptorSets = [_]c.VkDescriptorSet{
                frameData.m_gpuSceneDataDescriptorSet,
                self.m_materialInstance.m_parentMaterial.m_materialDescriptorSet orelse frameData.m_emptyDescriptorSet,
                self.m_materialInstance.m_instanceDescriptorSet orelse frameData.m_emptyDescriptorSet,
                self.m_objectDescriptorSet orelse frameData.m_emptyDescriptorSet,
            };
            c.vkCmdBindDescriptorSets(
                cmd,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                self.m_materialInstance.m_parentMaterial.m_shaderPass.m_pipelineLayout,
                0,
                @intCast(descriptorSets.len),
                &descriptorSets,
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
