const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const c = @import("../c.zig");

const Buffer = @import("Buffer.zig").Buffer;
const DescriptorAllocator = @import("DescriptorAllocator.zig").DescriptorAllocator;
const DescriptorWriter = @import("DescriptorWriter.zig").DescriptorWriter;
const Mat4x4 = @import("../math/Mat4x4.zig").Mat4x4;
const Material = @import("Material.zig").Material;
const MaterialInstance = @import("MaterialInstance.zig").MaterialInstance;
const MaterialParam = @import("MaterialParam.zig").MaterialParam;
const Mesh = @import("Mesh.zig").Mesh;
const RenderContext = @import("RenderContext.zig").RenderContext;

pub const RenderObjError = error{
    NoMeshBufferData,
};

pub const RenderObject = struct {
    const Self = @This();

    m_name: []const u8,
    m_materialInstance: *MaterialInstance,
    m_mesh: *Mesh,
    m_objectDescriptorSet: ?c.VkDescriptorSet = null,

    //TODO switch to an actual pos/rot/scale transform and construct mat4 before rendering
    m_transform: Mat4x4 = Mat4x4.identity,
    m_objectMaterialParams: ArrayList(MaterialParam),

    //TODO create a default material/material instance
    pub fn init(allocator: Allocator, name: []const u8, mesh: *Mesh, materialInst: *MaterialInstance) RenderObject {
        return RenderObject{
            .m_name = name,
            .m_mesh = mesh,
            .m_materialInstance = materialInst,
            .m_objectMaterialParams = ArrayList(MaterialParam).init(allocator),
        };
    }

    pub fn AllocateDescriptorSet(
        self: *Self,
        dAllocator: *DescriptorAllocator,
        layout: c.VkDescriptorSetLayout,
    ) !void {
        const rContext = try RenderContext.GetInstance();
        self.m_objectDescriptorSet = try dAllocator.Allocate(rContext.m_logicalDevice, layout);
    }

    pub fn WriteDescriptorSet(self: *Self, allocator: Allocator) !void {
        if (self.m_objectDescriptorSet) |*descSet| {
            const rContext = try RenderContext.GetInstance();
            var writer = DescriptorWriter.init(allocator);
            for (self.m_objectMaterialParams.items) |*materialParam| {
                try materialParam.WriteDescriptor(&writer);
            }
            if (self.m_objectMaterialParams.items.len != 0) {
                writer.UpdateSet(rContext.m_logicalDevice, descSet.*);
            }
        }
    }

    pub fn BindPerObjectData(self: *Self, cmd: c.VkCommandBuffer) !void {
        const rContext = try RenderContext.GetInstance();
        const frameData = rContext.GetCurrentFrame();
        c.vkCmdBindDescriptorSets(
            cmd,
            c.VK_PIPELINE_BIND_POINT_GRAPHICS,
            self.m_materialInstance.m_parentMaterial.m_shaderPass.m_pipelineLayout,
            3,
            1,
            &(self.m_objectDescriptorSet orelse frameData.m_emptyDescriptorSet),
            0,
            null,
        );

        c.vkCmdPushConstants(
            cmd,
            self.m_materialInstance.m_parentMaterial.m_shaderPass.m_pipelineLayout,
            c.VK_SHADER_STAGE_VERTEX_BIT,
            0,
            @sizeOf(Mat4x4),
            &self.m_transform,
        );
    }
};
