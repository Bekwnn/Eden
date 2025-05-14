const c = @import("../c.zig");

const Material = @import("Material.zig").Material;

pub const MaterialInstance = struct {
    m_parentMaterial: *Material,
    m_instanceDescriptorSet: ?c.VkDescriptorSet = null,
};
