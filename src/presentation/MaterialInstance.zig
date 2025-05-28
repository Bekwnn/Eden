const c = @import("../c.zig");
const Material = @import("Material.zig").Material;
const DescriptorAllocator = @import("DescriptorAllocator.zig").DescriptorAllocator;
const RenderContext = @import("RenderContext.zig").RenderContext;

pub const MaterialInstance = struct {
    const Self = @This();
    m_name: []const u8,
    m_parentMaterial: *Material,
    m_instanceDescriptorSet: ?c.VkDescriptorSet = null,

    pub fn AllocateDescriptorSet(
        self: *Self,
        dAllocator: *DescriptorAllocator,
        layout: c.VkDescriptorSetLayout,
    ) !void {
        const rContext = try RenderContext.GetInstance();
        self.m_instanceDescriptorSet = try dAllocator.Allocate(rContext.m_logicalDevice, layout);
    }

    // these should maybe return empty descriptor set layout instead of null

    // descriptor set bound for the parent material
    pub fn GetMaterialDescriptorSetLayout(self: *const Self) ?c.VkDescriptorSetLayout {
        return self.m_parentMaterial.m_shaderPass.m_shaderEffect.m_shaderDescriptorSetLayout;
    }

    // descriptor set bound on a per material-instance basis
    pub fn GetInstanceDescriptorSetLayout(self: *const Self) ?c.VkDescriptorSetLayout {
        return self.m_parentMaterial.m_shaderPass.m_shaderEffect.m_instanceDescriptorSetLayout;
    }

    // descriptor set bound on a per object/object-instance basis
    pub fn GetObjectDescriptorSetLayout(self: *const Self) ?c.VkDescriptorSetLayout {
        return self.m_parentMaterial.m_shaderPass.m_shaderEffect.m_objectDescriptorSetLayout;
    }
};
