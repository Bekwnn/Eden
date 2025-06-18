const std = @import("std");
const ArrayList = std.ArrayList;
const allocator = std.heap.page_allocator;

const c = @import("../c.zig");
const Vec2 = @import("../math/Vec2.zig").Vec2;
const Vec3 = @import("../math/Vec3.zig").Vec3;
const Buffer = @import("Buffer.zig").Buffer;
const RenderContext = @import("RenderContext.zig").RenderContext;

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
const vertexInputBindingDesc = c.VkVertexInputBindingDescription{
    .binding = 0,
    .stride = @sizeOf(VertexData),
    .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
};

pub const VertexData = extern struct {
    m_pos: Vec3,
    m_normal: Vec3,
    m_uvCoord: Vec2,
};

pub const MeshBuffers = struct {
    m_vertexBuffer: Buffer,
    m_indexBuffer: Buffer,
};

pub const Mesh = struct {
    m_name: []const u8,
    m_vertexData: ArrayList(VertexData),
    m_indices: ArrayList(u32),

    m_bounds: Bounds = Bounds{},

    m_bufferData: ?MeshBuffers,

    pub const Bounds = struct {
        m_origin: Vec3 = Vec3.zero,
        m_sphereRadius: f32 = 0.0,
        m_extents: Vec3 = Vec3.one,
    };

    pub fn GetBindingDescription() *const c.VkVertexInputBindingDescription {
        return &vertexInputBindingDesc;
    }

    pub fn GetAttributeDescriptions() []const c.VkVertexInputAttributeDescription {
        return vertexDataDesc[0..];
    }

    // To be called after the vertex/index arrays are filled
    // TODO make this all one step and less error prone
    pub fn InitMesh(self: *Mesh) !void {
        self.m_bufferData = MeshBuffers{
            .m_vertexBuffer = try Buffer.CreateVertexBuffer(self),
            .m_indexBuffer = try Buffer.CreateIndexBuffer(self),
        };
        self.UpdateBounds();
    }

    pub fn UpdateBounds(self: *Mesh) void {
        var minPos = self.m_vertexData.items[0].m_pos;
        var maxPos = self.m_vertexData.items[0].m_pos;
        for (self.m_vertexData.items) |vertData| {
            minPos = minPos.Min(vertData.m_pos);
            maxPos = maxPos.Max(vertData.m_pos);
        }
        self.m_bounds.m_origin = minPos.Add(maxPos).GetScaled(0.5);
        self.m_bounds.m_extents = maxPos.Sub(minPos).GetScaled(0.5);
        self.m_bounds.m_sphereRadius = self.m_bounds.m_extents.Length();
    }

    pub fn DestroyMesh(self: *Mesh) void {
        self.m_vertexData.deinit();
        self.m_indices.deinit();

        const rContext = RenderContext.GetInstance() catch @panic("!");

        self.m_meshBuffers.m_vertexBuffer.DestroyBuffer(rContext.m_logicalDevice);
        self.m_meshBuffers.m_indexBuffer.DestroyBuffer(rContext.m_logicalDevice);
    }
};
