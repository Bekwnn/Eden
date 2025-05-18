const c = @import("../c.zig");
const ShaderPass = @import("ShaderPass.zig").ShaderPass;

pub const Material = struct {
    m_shaderPass: ShaderPass = undefined,
    m_materialDescriptorSet: ?c.VkDescriptorSet = null,
};
