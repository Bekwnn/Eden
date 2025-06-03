const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const c = @import("../c.zig");

const DescriptorAllocator = @import("DescriptorAllocator.zig").DescriptorAllocator;
const DescriptorWriter = @import("DescriptorWriter.zig").DescriptorWriter;
const MaterialParam = @import("MaterialParam.zig").MaterialParam;
const RenderContext = @import("RenderContext.zig").RenderContext;
const ShaderPass = @import("ShaderPass.zig").ShaderPass;

pub const Material = struct {
    const Self = @This();
    m_name: []const u8,
    m_shaderPass: ShaderPass = undefined,
    m_materialDescriptorSet: ?c.VkDescriptorSet = null,
    m_materialParams: ArrayList(MaterialParam),

    pub fn init(allocator: Allocator, name: []const u8) Material {
        return Material{
            .m_name = name,
            .m_materialParams = ArrayList(MaterialParam).init(allocator),
        };
    }

    pub fn AllocateDescriptorSet(
        self: *Self,
        dAllocator: *DescriptorAllocator,
        layout: c.VkDescriptorSetLayout,
    ) !void {
        const rContext = try RenderContext.GetInstance();
        self.m_materialDescriptorSet = try dAllocator.Allocate(rContext.m_logicalDevice, layout);
    }

    pub fn WriteDescriptorSet(self: *Self, allocator: Allocator) !void {
        if (self.m_materialDescriptorSet) |*descSet| {
            const rContext = try RenderContext.GetInstance();
            var writer = DescriptorWriter.init(allocator);

            for (self.m_materialParams.items) |*materialParam| {
                try materialParam.WriteDescriptor(&writer);
            }

            if (self.m_materialParams.items.len != 0) {
                writer.UpdateSet(rContext.m_logicalDevice, descSet.*);
            }
        }
    }
};
