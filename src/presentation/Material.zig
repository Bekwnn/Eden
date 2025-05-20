const c = @import("../c.zig");
const ShaderPass = @import("ShaderPass.zig").ShaderPass;
const DescriptorAllocator = @import("DescriptorAllocator.zig").DescriptorAllocator;
const RenderContext = @import("RenderContext.zig").RenderContext;

pub const Material = struct {
    const Self = @This();
    m_shaderPass: ShaderPass = undefined,
    m_materialDescriptorSet: ?c.VkDescriptorSet = null,

    pub fn AllocateDescriptorSet(
        self: *Self,
        dAllocator: *DescriptorAllocator,
        layout: c.VkDescriptorSetLayout,
    ) !void {
        const rContext = try RenderContext.GetInstance();
        self.m_materialDescriptorSet = try dAllocator.Allocate(rContext.m_logicalDevice, layout);
    }
};
