const c = @import("../c.zig");

const std = @import("std");
const allocator = std.heap.page_allocator;

const mat4x4 = @import("../math/Mat4x4.zig");
const Mat4x4 = mat4x4.Mat4x4;

const vkUtil = @import("VulkanUtil.zig");
const RenderContext = @import("RenderContext.zig").RenderContext;
const Mesh = @import("Mesh.zig").Mesh;
const Material = @import("Material.zig").Material;
const Buffer = @import("Buffer.zig").Buffer;
const Camera = @import("Camera.zig").Camera;

const MvpUbo = packed struct {
    model: Mat4x4,
    view: Mat4x4,
    projection: Mat4x4,
};

const RenderObject = struct {
    m_mesh: *Mesh,
    m_material: *Material,
    m_transform: Mat4x4,

    // eentually we want material instancing (textures, etc) and per object
    // material data (position, etc)
    m_uniformBuffers: []Buffer,

    pub fn CreateRenderObject(mesh: *Mesh, material: *Material) !RenderObject {
        const rContext = try RenderContext.GetInstance();

        var newRenderObject = RenderObject{
            .m_mesh = &mesh,
            .m_material = &material,
            .transform = mat4x4.identity,
            .m_uniformBuffers = try allocator.alloc(Buffer, rContext.m_swapchain.m_images.len),
        };

        var bufferSize: c.VkDeviceSize = @sizeOf(MvpUbo);
        var i: u32 = 0;
        while (i < rContext.m_swapchain.m_images.len) : (i += 1) {
            newRenderObject.m_uniformBuffers[i] = try Buffer.CreateBuffer(
                bufferSize,
                c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                    c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            );
        }

        return newRenderObject;
    }

    // does not destroy the mesh or material instance the render object points to
    pub fn DestroyRenderObject(self: *RenderObject) void {
        var rContext = RenderContext.GetInstance() catch @panic("!");

        for (self.m_uniformBuffers) |*uniformBuffer| {
            uniformBuffer.DestroyBuffer(rContext.m_logicalDevice);
        }
    }

    pub fn UpdateUniformBuffer(self: *RenderObject, camera: *Camera, currentFrame: usize) !void {
        var bufferSize: c.VkDeviceSize = @sizeOf(MvpUbo);

        var cameraMvp = MvpUbo{
            .model = self.transform,
            .view = camera.GetViewMatrix(),
            .projection = camera.GetProjectionMatrix(),
        };

        var data: [*]u8 = undefined;
        const rContext = try RenderContext.GetInstance();
        try vkUtil.CheckVkSuccess(
            c.vkMapMemory(
                rContext.m_logicalDevice,
                self.m_uniformBuffers[currentFrame].m_memory,
                0,
                bufferSize,
                0,
                @ptrCast([*c]?*anyopaque, &data),
            ),
            vkUtil.VKError.UnspecifiedError,
        );
        @memcpy(data, @ptrCast([*]u8, &cameraMvp), bufferSize);
        c.vkUnmapMemory(rContext.m_logicalDevice, self.m_uniformBuffers[currentFrame].m_memory);
    }
};
