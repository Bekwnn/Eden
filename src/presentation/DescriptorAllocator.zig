const c = @import("../c.zig");

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const vkUtil = @import("VulkanUtil.zig");

pub const DescriptorAllocatorError = error{
    FailedToAllocateDescriptorSets,
    FailedToCreateDescriptorPool,
    FailedToResetDescriptorPool,
};

// Manages descriptor pools
pub const DescriptorAllocator = struct {
    const Self = @This();

    pub const PoolSizeRatio = struct {
        m_descriptorType: c.VkDescriptorType,
        m_ratio: f32,
    };

    m_poolRatios: ArrayList(PoolSizeRatio),
    m_fullPools: ArrayList(c.VkDescriptorPool),
    m_readyPools: ArrayList(c.VkDescriptorPool),
    m_setsPerPool: u32,
    m_allocator: Allocator,

    pub fn init(allocator: Allocator, device: c.VkDevice, initialSets: u32, poolRatios: []const PoolSizeRatio) !Self {
        var newDescriptorAllocator = Self{
            .m_poolRatios = ArrayList(PoolSizeRatio).init(allocator),
            .m_fullPools = ArrayList(c.VkDescriptorPool).init(allocator),
            .m_readyPools = ArrayList(c.VkDescriptorPool).init(allocator),
            .m_setsPerPool = @intFromFloat(@as(f32, @floatFromInt(initialSets)) * 1.5),
            .m_allocator = allocator,
        };

        try newDescriptorAllocator.m_poolRatios.appendSlice(poolRatios);

        try newDescriptorAllocator.m_readyPools.append(try newDescriptorAllocator.CreatePool(device, initialSets, poolRatios));

        return newDescriptorAllocator;
    }

    pub fn ClearPools(self: *Self, device: c.VkDevice) !void {
        for (self.m_readyPools.items) |pool| {
            try vkUtil.CheckVkSuccess(
                c.vkResetDescriptorPool(device, pool, 0),
                DescriptorAllocatorError.FailedToResetDescriptorPool,
            );
        }
        for (self.m_fullPools.items) |pool| {
            try vkUtil.CheckVkSuccess(
                c.vkResetDescriptorPool(device, pool, 0),
                DescriptorAllocatorError.FailedToResetDescriptorPool,
            );
            try self.m_readyPools.append(pool);
        }
        self.m_fullPools.clearRetainingCapacity();
    }

    pub fn deinit(self: *Self, device: c.VkDevice) void {
        for (self.m_readyPools.items) |pool| {
            c.vkDestroyDescriptorPool(device, pool, null);
        }
        for (self.m_fullPools.items) |pool| {
            c.vkDestroyDescriptorPool(device, pool, null);
        }
        self.m_poolRatios.deinit();
        self.m_fullPools.deinit();
        self.m_readyPools.deinit();
    }

    // TODO should maybe be able to pass a pNext
    pub fn Allocate(self: *Self, device: c.VkDevice, layout: c.VkDescriptorSetLayout) !c.VkDescriptorSet {
        var poolToUse = try self.GetPool(device);

        var allocInfo = c.VkDescriptorSetAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .descriptorPool = poolToUse,
            .descriptorSetCount = 1,
            .pSetLayouts = &layout,
            .pNext = null,
        };

        var descriptorSet: c.VkDescriptorSet = undefined;
        const result = c.vkAllocateDescriptorSets(device, &allocInfo, &descriptorSet);

        // allocation failed, store pool in full pools and create new one
        if (result == c.VK_ERROR_OUT_OF_POOL_MEMORY or result == c.VK_ERROR_FRAGMENTED_POOL) {
            try self.m_fullPools.append(poolToUse);

            poolToUse = try self.GetPool(device);
            allocInfo.descriptorPool = poolToUse;

            // if this one fails something is wrong
            try vkUtil.CheckVkSuccess(
                c.vkAllocateDescriptorSets(device, &allocInfo, &descriptorSet),
                DescriptorAllocatorError.FailedToAllocateDescriptorSets,
            );
        }

        try self.m_readyPools.append(poolToUse);
        return descriptorSet;
    }

    fn GetPool(self: *Self, device: c.VkDevice) !c.VkDescriptorPool {
        var newPool: c.VkDescriptorPool = undefined;
        if (self.m_readyPools.pop()) |poppedPool| {
            newPool = poppedPool;
        } else {
            newPool = try self.CreatePool(device, self.m_setsPerPool, self.m_poolRatios.items);
            self.m_setsPerPool = @as(u32, @intFromFloat(@as(f32, @floatFromInt(self.m_setsPerPool)) * 1.5));

            // max sets per pool
            if (self.m_setsPerPool > 4092) {
                self.m_setsPerPool = 4092;
            }
        }

        return newPool;
    }

    fn CreatePool(self: *Self, device: c.VkDevice, setCount: u32, poolRatios: []const PoolSizeRatio) !c.VkDescriptorPool {
        var poolSizes = ArrayList(c.VkDescriptorPoolSize).init(self.m_allocator);
        for (poolRatios) |poolRatio| {
            try poolSizes.append(c.VkDescriptorPoolSize{
                .type = poolRatio.m_descriptorType,
                .descriptorCount = @intFromFloat(poolRatio.m_ratio * @as(f32, @floatFromInt(setCount))),
            });
        }

        const poolCreateInfo = c.VkDescriptorPoolCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            .maxSets = setCount,
            .poolSizeCount = @intCast(poolSizes.items.len),
            .pPoolSizes = poolSizes.items.ptr,
            .flags = 0,
            .pNext = null,
        };

        var newPool: c.VkDescriptorPool = undefined;
        try vkUtil.CheckVkSuccess(
            c.vkCreateDescriptorPool(device, &poolCreateInfo, null, &newPool),
            DescriptorAllocatorError.FailedToCreateDescriptorPool,
        );
        return newPool;
    }
};
