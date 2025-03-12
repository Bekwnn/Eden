const std = @import("std");
const c = @import("../c.zig");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

const Camera = @import("Camera.zig").Camera;
const RenderObject = @import("RenderObject.zig").RenderObject;
const renderContext = @import("RenderContext.zig");
const RenderContext = @import("RenderContext.zig").RenderContext;

const mat4x4 = @import("../math/Mat4x4.zig");
const Mat4x4 = mat4x4.Mat4x4;
const Vec4 = @import("../math/Vec4.zig").Vec4;

pub const CameraError = error{
    NoCurrent,
    FailedToSet,
};

//TODO move probably
pub const GPUSceneData = struct {
    m_view: Mat4x4,
    m_projection: Mat4x4,
    m_viewProj: Mat4x4,
    m_ambientColor: Vec4,
    m_sunDirection: Vec4, // .w is sun power
    m_sunColor: Vec4,
};

pub const Scene = struct {
    m_cameras: StringHashMap(Camera) = StringHashMap(Camera).init(allocator),

    m_currentCamera: ?*Camera = null,
    m_defaultCamera: ?*Camera = null,

    pub fn CreateCamera(self: *Scene, name: []const u8) !void {
        try self.m_cameras.put(name, Camera{
            .m_name = name,
        });
        if (self.m_currentCamera == null) {
            self.m_currentCamera = self.m_cameras.getPtr(name);
        }
        if (self.m_defaultCamera == null) {
            self.m_defaultCamera = self.m_cameras.getPtr(name);
        }
    }

    pub fn GetCamera(self: *Scene, name: []const u8) ?*Camera {
        return self.m_cameras.get(name);
    }

    pub fn SetDefaultCamera(self: *Scene, name: []const u8) !void {
        var newDefault = self.m_cameras.getPtr(name);
        if (newDefault == null) {
            return CameraError.FailedToSet;
        } else {
            self.m_defaultCamera = &newDefault;
        }
    }

    pub fn SetCurrentCamera(self: *Scene, name: []const u8) !void {
        var newCurrent = self.m_cameras.getPtr(name);
        if (newCurrent == null) {
            return CameraError.FailedToSet;
        } else {
            self.m_currentCamera = &newCurrent;
        }
    }

    pub fn DrawScene(
        self: *Scene,
        cmd: c.VkCommandBuffer,
        renderObjects: []RenderObject,
    ) !void {
        if (self.m_currentCamera == null) {
            return CameraError.NoCurrent;
        }

        const rContext = try RenderContext.GetInstance();

        for (renderObjects, 0..) |*renderObject, i| {
            const meshBufferData = renderObject.m_mesh.m_bufferData orelse
                {
                std.debug.print("renderObject[{}] has no mesh buffer data.\n", .{i});
                continue;
            };

            const vertexBuffers = [_]c.VkBuffer{
                meshBufferData.m_vertexBuffer.m_buffer,
            };

            c.vkCmdBindPipeline(
                cmd,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                rContext.m_pipeline,
            );

            const offsets = [_]c.VkDeviceSize{0};
            c.vkCmdBindVertexBuffers(cmd, 0, 1, &vertexBuffers, &offsets);

            c.vkCmdBindIndexBuffer(
                cmd,
                meshBufferData.m_indexBuffer.m_buffer,
                0,
                c.VK_INDEX_TYPE_UINT32,
            );

            const currentFrameData = rContext.m_frameData[rContext.m_currentFrame];
            c.vkCmdBindDescriptorSets(
                cmd,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                rContext.m_pipelineLayout,
                0,
                1,
                &currentFrameData.m_descriptorSets[@intFromEnum(renderContext.DescriptorSetType.PerInstance)],
                0,
                null,
            );

            c.vkCmdDrawIndexed(
                cmd,
                @intCast(renderObject.m_mesh.m_indices.items.len),
                1,
                0,
                0,
                0,
            );
        }
    }
};
