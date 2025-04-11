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
};

pub const Buffer = struct {
    const Self = @This();

    m_buffer: c.VkBuffer,
    m_memory: c.VkDeviceMemory,

    //TODO Creating index/vertex buffers should probably
    // live in mesh or meshutil and this class be more generic
    pub fn CreateVertexBuffer(mesh: *const Mesh) !Buffer {
        const bufferSize: c.VkDeviceSize = mesh.m_vertexData.items.len * @sizeOf(VertexData);

        const rContext = try RenderContext.GetInstance();
        var stagingBuffer: Buffer = try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
        defer stagingBuffer.DestroyBuffer(rContext.m_logicalDevice);

        var data: [*]VertexData = undefined;
        try vkUtil.CheckVkSuccess(
            c.vkMapMemory(
                rContext.m_logicalDevice,
                stagingBuffer.m_memory,
                0,
                bufferSize,
                0,
                @ptrCast(&data),
            ),
            BufferError.FailedToCreateVertexBuffer,
        );
        @memcpy(data, mesh.m_vertexData.items);
        c.vkUnmapMemory(rContext.m_logicalDevice, stagingBuffer.m_memory);

        const newVertexBuffer = try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        );

        try CopyBuffer(stagingBuffer.m_buffer, newVertexBuffer.m_buffer, bufferSize);

        return newVertexBuffer;
    }

    pub fn CreateIndexBuffer(mesh: *const Mesh) !Buffer {
        const bufferSize: c.VkDeviceSize =
            mesh.m_indices.items.len * @sizeOf(u32);

        const rContext = try RenderContext.GetInstance();
        var stagingBuffer: Buffer = try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
        defer stagingBuffer.DestroyBuffer(rContext.m_logicalDevice);

        var data: [*]u32 = undefined;
        try vkUtil.CheckVkSuccess(
            c.vkMapMemory(
                rContext.m_logicalDevice,
                stagingBuffer.m_memory,
                0,
                bufferSize,
                0,
                @ptrCast(&data),
            ),
            BufferError.FailedToCreateIndexBuffer,
        );
        @memcpy(data, mesh.m_indices.items);
        c.vkUnmapMemory(rContext.m_logicalDevice, stagingBuffer.m_memory);

        const newIndexBuffer: Buffer = try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        );

        try CopyBuffer(stagingBuffer.m_buffer, newIndexBuffer.m_buffer, bufferSize);

        return newIndexBuffer;
    }

    pub fn MapData(
        self: *Self,
        inData: *anyopaque,
        bufferSize: c.VkDeviceSize,
    ) !void {
        const rContext = try RenderContext.GetInstance();
        var stagingBuffer: Buffer = try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
        defer stagingBuffer.DestroyBuffer(rContext.m_logicalDevice);

        var mappedData: [*]u8 = undefined;
        try vkUtil.CheckVkSuccess(
            c.vkMapMemory(
                rContext.m_logicalDevice,
                stagingBuffer.m_memory,
                0,
                bufferSize,
                0,
                @ptrCast(&mappedData),
            ),
            BufferError.FailedToMapData,
        );
        @memcpy(
            @as([*]u8, @ptrCast(mappedData))[0..bufferSize],
            @as([*]u8, @ptrCast(inData))[0..bufferSize],
        );
        c.vkUnmapMemory(rContext.m_logicalDevice, stagingBuffer.m_memory);

        try CopyBuffer(stagingBuffer.m_buffer, self.m_buffer, bufferSize);
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
