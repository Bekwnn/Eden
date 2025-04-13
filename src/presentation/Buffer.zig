const c = @import("../c.zig");

const std = @import("std");

const vkUtil = @import("VulkanUtil.zig");
const RenderContext = @import("RenderContext.zig").RenderContext;
const VertexData = @import("Mesh.zig").VertexData;
const Mesh = @import("Mesh.zig").Mesh;

pub const BufferError = error{
    FailedToCreateBuffer,
    FailedToCreateIndexBuffer,
    FailedToCreateVertexBuffer,
    FailedToMapData,
    FailedToUnmapData,
};

pub const Buffer = struct {
    const Self = @This();

    m_buffer: c.VkBuffer,
    m_memory: c.VkDeviceMemory,
    m_mappedData: ?*anyopaque = null,

    //TODO Creating index/vertex buffers should probably
    // live in mesh or meshutil and this class be more generic
    pub fn CreateVertexBuffer(mesh: *const Mesh) !Buffer {
        const bufferSize: c.VkDeviceSize = mesh.m_vertexData.items.len * @sizeOf(VertexData);

        var newVertexBuffer = try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        );

        try newVertexBuffer.CopyStagingBuffer(@ptrCast(mesh.m_vertexData.items.ptr), bufferSize);

        return newVertexBuffer;
    }

    pub fn CreateIndexBuffer(mesh: *const Mesh) !Buffer {
        const bufferSize: c.VkDeviceSize =
            mesh.m_indices.items.len * @sizeOf(u32);

        var newIndexBuffer: Buffer = try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        );

        try newIndexBuffer.CopyStagingBuffer(@ptrCast(mesh.m_indices.items.ptr), bufferSize);

        return newIndexBuffer;
    }

    // creates a temporary staging buffer and copies inData to it, then uses a buffer copy command
    // required when using VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, which is memory not directly accessible
    // by the CPU
    pub fn CopyStagingBuffer(
        self: *Self,
        inData: *const anyopaque,
        bufferSize: c.VkDeviceSize,
    ) !void {
        const rContext = try RenderContext.GetInstance();
        var stagingBuffer: Buffer = try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
        defer stagingBuffer.DestroyBuffer(rContext.m_logicalDevice);

        var data: ?*anyopaque = null;
        try vkUtil.CheckVkSuccess(
            c.vkMapMemory(
                rContext.m_logicalDevice,
                stagingBuffer.m_memory,
                0,
                bufferSize,
                0,
                @ptrCast(&data),
            ),
            BufferError.FailedToMapData,
        );
        if (data) |*dataPtr| {
            @memcpy(
                @as([*]u8, @ptrCast(dataPtr))[0..bufferSize],
                @as([*]const u8, @ptrCast(inData))[0..bufferSize],
            );
        }

        c.vkUnmapMemory(rContext.m_logicalDevice, stagingBuffer.m_memory);

        try CopyBuffer(stagingBuffer.m_buffer, self.m_buffer, bufferSize);
    }

    // calls vkMapMemory to map the m_mappedData member of this buffer and then memcpy inData to the newly mapped data
    // use CopyStagingBuffer instead if this buffer is VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
    pub fn MapMemory(
        self: *Self,
        inData: *anyopaque,
        bufferSize: c.VkDeviceSize,
    ) !void {
        if (self.m_mappedData != null) {
            return BufferError.FailedToMapData;
        }

        const rContext = try RenderContext.GetInstance();
        try vkUtil.CheckVkSuccess(
            c.vkMapMemory(
                rContext.m_logicalDevice,
                self.m_memory,
                0,
                bufferSize,
                0,
                @ptrCast(&self.m_mappedData),
            ),
            BufferError.FailedToMapData,
        );
        @memcpy(
            @as([*]u8, @ptrCast(@alignCast(self.m_mappedData)))[0..bufferSize],
            @as([*]u8, @ptrCast(@alignCast(inData)))[0..bufferSize],
        );
    }

    // returns an error if memory already unmapped
    pub fn UnmapMemory(
        self: *const Self,
    ) !void {
        if (self.m_mappedData == null) {
            return BufferError.FailedToUnmapMemory;
        }

        const rContext = try RenderContext.GetInstance();
        c.vkUnmapMemory(rContext.m_logicalDevice, self.m_memory);
    }

    pub fn CreateBuffer(
        size: c.VkDeviceSize,
        usage: c.VkBufferUsageFlags,
        properties: c.VkMemoryPropertyFlags,
    ) !Buffer {
        const rContext = try RenderContext.GetInstance();
        var newBuffer: Buffer = undefined;
        const bufferInfo = c.VkBufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = size,
            .usage = usage,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
            .flags = 0,
            .pNext = null,
        };

        try vkUtil.CheckVkSuccess(
            c.vkCreateBuffer(
                rContext.m_logicalDevice,
                &bufferInfo,
                null,
                &newBuffer.m_buffer,
            ),
            BufferError.FailedToCreateBuffer,
        );
        var memRequirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(
            rContext.m_logicalDevice,
            newBuffer.m_buffer,
            &memRequirements,
        );

        const allocInfo = c.VkMemoryAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = memRequirements.size,
            .memoryTypeIndex = try vkUtil.FindMemoryType(memRequirements.memoryTypeBits, properties),
            .pNext = null,
        };

        try vkUtil.CheckVkSuccess(
            c.vkAllocateMemory(
                rContext.m_logicalDevice,
                &allocInfo,
                null,
                &newBuffer.m_memory,
            ),
            BufferError.FailedToCreateBuffer,
        );
        try vkUtil.CheckVkSuccess(
            c.vkBindBufferMemory(
                rContext.m_logicalDevice,
                newBuffer.m_buffer,
                newBuffer.m_memory,
                0,
            ),
            BufferError.FailedToCreateBuffer,
        );
        newBuffer.m_mappedData = null;
        return newBuffer;
    }

    pub fn DestroyBuffer(
        self: *Buffer,
        logicalDevice: c.VkDevice,
    ) void {
        c.vkDestroyBuffer(logicalDevice, self.m_buffer, null);
        c.vkFreeMemory(logicalDevice, self.m_memory, null);
    }
};

fn CopyBuffer(srcBuffer: c.VkBuffer, dstBuffer: c.VkBuffer, size: c.VkDeviceSize) !void {
    const commandBuffer = try vkUtil.BeginSingleTimeCommands();

    const copyRegion = c.VkBufferCopy{
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size,
    };
    c.vkCmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion);

    try vkUtil.EndSingleTimeCommands(commandBuffer);
}
