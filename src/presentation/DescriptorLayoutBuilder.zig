const c = @import("../c.zig");

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const vkUtil = @import("VulkanUtil.zig");

pub const DescriptorLayoutError = error{
    FailedToCreateDescriptorSetLayout,
};

pub const DescriptorLayoutBuilder = struct {
    const Self = @This();

    m_bindings: ArrayList(c.VkDescriptorSetLayoutBinding),

    pub fn init(allocator: Allocator) Self {
        return Self{
            .m_bindings = ArrayList(c.VkDescriptorSetLayoutBinding).init(allocator),
        };
    }

    pub fn AddBinding(self: *Self, binding: u32, descriptorType: c.VkDescriptorType) void {
        const newBind = c.VkDescriptorSetLayoutBinding{
            .binding = binding,
            .descriptorCount = 1,
            .descriptorType = descriptorType,
            .pImmutableSamplers = null,
            .stageFlags = 0,
        };

        self.m_bindings.append(newBind);
    }

    pub fn Clear(self: *Self) void {
        self.m_bindings.clearAndFree();
    }

    //TODO add pNext and DescriptorSetLayoutCreateFlags?
    pub fn Build(self: *Self, device: c.VkDevice, shaderStages: c.VkShaderStageFlags) !c.VkDescriptorSetLayout {
        // set the shader stage flags all at once
        for (self.m_bindings) |binding| {
            binding.stageFlags |= shaderStages;
        }

        const layoutInfo = c.VkDescriptorSetLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .bindingCount = @intCast(self.m_bindings.items.len),
            .pBindings = &self.m_bindings.items,
            .flags = 0,
            .pNext = null,
        };

        var descriptorSetLayout: c.VkDescriptorSetLayout = undefined;
        try vkUtil.CheckVkSuccess(
            c.vkCreateDescriptorSetLayout(device, &layoutInfo, null, &descriptorSetLayout),
            DescriptorLayoutError.FailedToCreateDescriptorSetLayout,
        );
        return descriptorSetLayout;
    }
};
