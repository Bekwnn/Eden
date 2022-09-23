const std = @import("std");
const c = @import("c.zig");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

const Camera = @import("Camera.zig").Camera;

pub const CameraError = error{
    NoCurrent,
    FailedToSet,
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

    pub fn GetCurrentCamera(self: *Scene) ?*Camera {
        return self.m_currentCamera;
    }

    pub fn GetDefaultCamera(self: *Scene) ?*Camera {
        return self.m_defaultCamera;
    }

    pub fn DrawScene(
        self: *Scene,
        cmd: c.VkCommandBuffer,
        renderObjects: []RenderObjects,
    ) !void {
        if (m_currentCamera == null) {
            return CameraError.NoCurrent;
        }

        for (renderObjects) |*renderObject| {
            c.vkCmdBindPipeline(
                cmd,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                renderObject.m_material.m_pipeline,
            );

            const vertexBuffers = [_]c.VkBuffer{
                renderObject.m_mesh.m_vertexBuffer.m_buffer,
            };
            const offsets = [_]c.VkDeviceSize{0};
            c.vkCmdBindVertexBuffers(cmd, 0, 1, &vertexBuffers, &offsets);

            c.vkCmdBindIndexBuffer(
                cmd,
                renderObject.m_mesh.m_indexBuffer.m_buffer,
                0,
                c.VK_INDEX_TYPE_UINT32,
            );

            c.vkCmdBindDescriptorSets(
                cmd,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                renderObject.m_material.m_pipelineLayout,
                0,
                1,
                &descriptorSets[i],
                0,
                null,
            );

            c.vkCmdDrawIndexed(
                cmd,
                @intCast(u32, renderObject.m_mesh.m_indices.items.len),
                1,
                0,
                0,
                0,
            );
        }
    }
};
