const std = @import("std");
const ArrayList = std.mem.ArrayList;

const c = @import("../c.zig");

const DescriptorAllocator = @import("DescriptorAllocator.zig").DescriptorAllocator;
const MaterialParam = @import("MaterialParam.zig").MaterialParam;
const RenderContext = @import("RenderContext.zig").RenderContext;
const ShaderPass = @import("ShaderPass.zig").ShaderPass;

pub const Material = struct {
    const Self = @This();
    m_name: []const u8,
    m_shaderPass: ShaderPass = undefined,
    m_materialDescriptorSet: ?c.VkDescriptorSet = null,
    m_materialParams: ArrayList(MaterialParam),

    pub fn AllocateDescriptorSet(
        self: *Self,
        dAllocator: *DescriptorAllocator,
        layout: c.VkDescriptorSetLayout,
    ) !void {
        const rContext = try RenderContext.GetInstance();
        self.m_materialDescriptorSet = try dAllocator.Allocate(rContext.m_logicalDevice, layout);
    }
};
