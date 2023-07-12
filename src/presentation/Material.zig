const c = @import("../c.zig");
const std = @import("std");
const allocator = std.heap.page_allocator;

const vkUtil = @import("VulkanUtil.zig");
const texture = @import("Texture.zig");
const Texture = texture.Texture;
const RenderContext = @import("RenderContext.zig").RenderContext;

//TODO we want material instancing such that a material is made up of two members: a pointer to instance data (texture, etc) and a pointer to shader constants (descriptor layout, etc)
// really we might want it to be more flexible than that, and support multiple textures, etc. For now, hardcoded to one texture
pub const Material = struct {
    m_name: []const u8,

    //m_textureImage: ?Texture = null, //TODO move to material instance data
    //m_textureSampler: ?c.VkSampler = null,

    //TODO per material descriptors not yet implemented
    // should potentially live in the RenderContext and be set by materials
    m_perMaterialSetLayout: c.VkDescriptorSetLayout,
    m_perMaterialDescriptorSet: c.VkDescriptorSet,

    pub fn CreateMaterial(
        materialName: []const u8,
        vertShaderPath: []const u8,
        fragShaderPath: []const u8,
        texturePath: []const u8,
    ) !Material {
        _ = vertShaderPath; //TODO UNUSED FIX
        _ = fragShaderPath; //TODO UNUSED FIX

        std.debug.print("Creating Material {}...\n", .{materialName});
        var newMaterial = Material{
            .m_name = materialName,
            .m_uboLayoutBinding = undefined,

            .m_textureImage = undefined,
            .m_textureSampler = undefined,
        };

        try texture.CreateTextureSampler(&newMaterial.m_textureSampler);

        newMaterial.m_textureImage = try Texture.CreateTexture(texturePath);
    }

    pub fn DestroyMaterial(self: *Material) void {
        const rContext = try RenderContext.GetInstance();

        defer c.vkDestroyDescriptorSetLayout(
            rContext.m_logicalDevice,
            rContext.m_descriptorSetLayout,
            null,
        );
        defer self.m_textureImage.FreeTexture(rContext.m_logicalDevice);
        defer c.vkDestroySampler(
            rContext.m_logicalDevice,
            self.m_textureSampler,
            null,
        );
    }
};
