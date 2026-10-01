const Buffer = @import("../Buffer.zig");
const c = @import("../../c.zig").cLib;

const VulkanBuffer = struct {
    //TODO move device out
    device: *c.VkDevice,
    buffer: c.VkBuffer,
    memory: c.VkDeviceMemory,
    size: usize,
    usage: Buffer.Usage,
    mapped_data: ?[]u8 = null,

    pub fn interface(self: *VulkanBuffer) Buffer {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable: Buffer.VTable = .{
        .deinit = deinit,
        .size = size,
        .usage = usage,
        .map = map,
        .unmap = unmap,
        .read = read,
        .write = write,
    };

    fn deinit(ctx: *anyopaque) void {
        const self: *VulkanBuffer = @ptrCast(@alignCast(ctx));

        //TODO this needs store the device or pull on the device from the context to destroy the buffer.
    }

    fn size(ctx: *anyopaque) usize {
        const self: *VulkanBuffer = @ptrCast(@alignCast(ctx));

        return self.size;
    }
    fn usage(ctx: *anyopaque) Buffer.Usage {
        const self: *VulkanBuffer = @ptrCast(@alignCast(ctx));

        return self.usage;
    }

    fn map(ctx: *anyopaque, offset: usize, length: usize) Buffer.BufferError![]u8 {
        const self: *VulkanBuffer = @ptrCast(@alignCast(ctx));

        if (offset + length > self.size) {
            return Buffer.BufferError.FailedToMap;
        }

        if (self.mapped_data != null) {
            return Buffer.BufferError.FailedToMap;
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
    }

    fn unmap(ctx: *anyopaque) void {
        const self: *VulkanBuffer = @ptrCast(@alignCast(ctx));
    }

    fn read(ctx: *anyopaque) void {
        const self: *VulkanBuffer = @ptrCast(@alignCast(ctx));
    }

    fn write(self: Buffer, offset: usize, data: []const u8) Buffer.BufferError!void {
        const self: *VulkanBuffer = @ptrCast(@alignCast(ctx));

        @memcpy(
            @as([*]u8, @ptrCast(@alignCast(self.m_mappedData)))[offset..data.len],
            @as([*]u8, @ptrCast(@alignCast(data)))[0..bufferSize],
        );
    }
};
