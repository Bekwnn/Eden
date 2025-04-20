const c = @import("../c.zig");

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const DescriptorWriter = struct {
    const Self = @This();

    m_imageInfos: ArrayList(c.VkDescriptorImageInfo),
    m_bufferInfos: ArrayList(c.VkDescriptorBufferInfo),
    m_writes: ArrayList(c.VkWriteDescriptorSet),

    pub fn init(allocator: Allocator) Self {
        return Self{
            .m_imageInfos = ArrayList(c.VkDescriptorImageInfo).init(allocator),
            .m_bufferInfos = ArrayList(c.VkDescriptorBufferInfo).init(allocator),
            .m_writes = ArrayList(c.VkWriteDescriptorSet).init(allocator),
        };
    }

    pub fn WriteImage(
        self: *Self,
        binding: u32,
        image: c.VkImageView,
        sampler: c.VkSampler,
        layout: c.VkImageLayout,
        descriptorType: c.VkDescriptorType,
    ) !void {
        try self.m_imageInfos.append(c.VkDescriptorImageInfo{
            .sampler = sampler,
            .imageView = image,
            .imageLayout = layout,
        });
        const imageInfo = &self.m_imageInfos.items[self.m_imageInfos.items.len - 1];

        const write = c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstBinding = binding,
            .dstSet = c.VK_NULL_HANDLE, //write later
            .dstArrayElement = 0,
            .descriptorCount = 1,
            .descriptorType = descriptorType,
            .pBufferInfo = &imageInfo,
            .pTexelBufferView = null,
            .pNext = null,
        };

        try self.m_writes.append(write);
    }

    pub fn WriteBuffer(
        self: *Self,
        binding: u32,
        buffer: c.VkBuffer,
        size: usize,
        offset: usize,
        descriptorType: c.VkDescriptorType,
    ) !void {
        try self.m_bufferInfos.append(c.VkDescriptorBufferInfo{
            .buffer = buffer,
            .offset = offset,
            .range = size,
        });
        const descriptorBufferInfo = &self.m_bufferInfos.items[self.m_bufferInfos.items.len - 1];

        const write = c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstBinding = binding,
            .dstSet = null, //write later when UpdateSet is called
            .dstArrayElement = 0,
            .descriptorCount = 1,
            .descriptorType = descriptorType,
            .pBufferInfo = descriptorBufferInfo,
            .pTexelBufferView = null,
            .pNext = null,
        };

        try self.m_writes.append(write);
    }

    pub fn Clear(self: *Self) void {
        self.m_imageInfos.clearAndFree();
        self.m_bufferInfos.clearAndFree();
        self.m_writes.clearAndFree();
    }

    pub fn UpdateSet(self: *Self, device: c.VkDevice, set: c.VkDescriptorSet) void {
        for (self.m_writes.items) |*write| {
            write.dstSet = set;
        }

        c.vkUpdateDescriptorSets(device, @intCast(self.m_writes.items.len), @ptrCast(&self.m_writes.items[0]), 0, null);
    }
};
