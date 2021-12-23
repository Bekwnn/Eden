const c = @import("../c.zig");
const std = @import("std");

const Vec3 = @import("../math/Vec3.zig").Vec3;
const Vec2 = @import("../math/Vec2.zig").Vec2;
const mat4x4 = @import("../math/Mat4x4.zig");
const Mat4x4 = mat4x4.Mat4x4;

const Camera = @import("Camera.zig").Camera;

const ArrayList = std.ArrayList;

//TODO still useful post gl->vulkan changes? should maybe be defined in some util file w/ better name
const noPointerOffset: ?*const anyopaque = @intToPtr(?*anyopaque, 0);

const vertexDataDesc = [_]c.VkVertexInputAttributeDescription{
    c.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 0,
        .format = c.VK_FORMAT_R32G32B32_SFLOAT,
        .offset = @offsetOf(VertexData, "m_pos"),
    },
    c.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 1,
        .format = c.VK_FORMAT_R32G32B32_SFLOAT,
        .offset = @offsetOf(VertexData, "m_normal"),
    },
    c.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 2,
        .format = c.VK_FORMAT_R32G32_SFLOAT,
        .offset = @offsetOf(VertexData, "m_uvCoord"),
    },
};

pub const VertexData = struct {
    m_pos: Vec3,
    m_normal: Vec3,
    m_uvCoord: Vec2,
};

pub const Mesh = struct {
    m_name: []const u8,

    m_vertexData: ArrayList(VertexData),
    m_indices: ArrayList(u32),

    //pub fn Draw(self: *const Mesh, camera: *Camera) void {}

    pub fn GetBindingDescription() c.VkVertexInputBindingDescription {
        return c.VkVertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(VertexData),
            .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
        };
    }

    pub fn GetAttributeDescriptions() []const c.VkVertexInputAttributeDescription {
        //const theSlice: []const c.VkVertexInputAttributeDescription = vertexDataDesc[0..];
        //return theSlice;
        return vertexDataDesc[0..];
    }
};
