const c = @import("../c.zig");

const std = @import("std");
const allocator = std.heap.page_allocator;

const mat4x4 = @import("../math/Mat4x4.zig");
const Mat4x4 = mat4x4.Mat4x4;

const Buffer = @import("Buffer.zig").Buffer;
const Material = @import("Material.zig").Material;
const Mesh = @import("Mesh.zig").Mesh;
const RenderContext = @import("RenderContext.zig").RenderContext;

pub const RenderObjError = error{
    NoMeshBufferData,
};

pub const RenderObject = struct {
    const Self = @This();

    m_material: *Material,
    m_mesh: *Mesh,

    m_transform: Mat4x4 = mat4x4.identity,

    pub fn Draw(self: Self, cmd: c.VkCommandBuffer) !void {
        if (self.m_mesh.m_bufferData) |*meshBufferData| {
            const rContext = try RenderContext.GetInstance();

            //bind pipeline
            //TODO sort render objs by material and move this out
            c.vkCmdBindPipeline(
                cmd,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                self.m_material.m_shaderPass.m_pipeline,
            );

            //bind scene data
            //TODO move this out and only bind global scene data once
            const currentFrameData = rContext.GetCurrentFrame();
            @memcpy(currentFrameData.m_gpuSceneDataBuffer.m_memory, currentFrameData.m_gpuSceneData);
            c.vkCmdBindDescriptorSets(
                cmd,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                self.m_material.m_shaderPass.m_pipelineLayout,
                0,
                1,
                self.m_material.m_shaderPass.m_descriptors,
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

            //bind per object descriptor sets
            //TODO make this push constants later
            c.vkCmdBindDescriptorSets(
                cmd,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                self.m_materialInstance.m_material.m_shaderPass.m_pipelineLayout,
                0,
                1,
                self.m_materialInstance.m_shaderPass.m_descriptors,
                0,
                null,
            );

            c.vkCmdDrawIndexed(
                cmd,
                self.m_mesh.m_indices.items.len,
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
