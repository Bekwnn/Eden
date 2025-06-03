const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const c = @import("../c.zig");

const DescriptorAllocator = @import("DescriptorAllocator.zig").DescriptorAllocator;
const DescriptorWriter = @import("DescriptorWriter.zig").DescriptorWriter;
const Material = @import("Material.zig").Material;
const MaterialParam = @import("MaterialParam.zig").MaterialParam;
const RenderContext = @import("RenderContext.zig").RenderContext;

pub const MaterialInstance = struct {
    const Self = @This();
    m_name: []const u8,
    m_parentMaterial: *Material,
    m_instanceDescriptorSet: ?c.VkDescriptorSet = null,
    m_materialInstanceParams: ArrayList(MaterialParam),

    pub fn init(allocator: Allocator, name: []const u8, parentMaterial: *Material) MaterialInstance {
        return MaterialInstance{
            .m_name = name,
            .m_parentMaterial = parentMaterial,
            .m_materialInstanceParams = ArrayList(MaterialParam).init(allocator),
        };
    }

    pub fn AllocateDescriptorSet(
        self: *Self,
        dAllocator: *DescriptorAllocator,
        layout: c.VkDescriptorSetLayout,
    ) !void {
        const rContext = try RenderContext.GetInstance();
        self.m_instanceDescriptorSet = try dAllocator.Allocate(rContext.m_logicalDevice, layout);
    }

    pub fn WriteDescriptorSet(self: *Self, allocator: Allocator) !void {
        if (self.m_instanceDescriptorSet) |*descSet| {
            const rContext = try RenderContext.GetInstance();
            var writer = DescriptorWriter.init(allocator);
            for (self.m_materialInstanceParams.items) |*materialParam| {
                try materialParam.WriteDescriptor(&writer);
            }
            if (self.m_materialInstanceParams.items.len != 0) {
                writer.UpdateSet(rContext.m_logicalDevice, descSet.*);
            }
        }
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
