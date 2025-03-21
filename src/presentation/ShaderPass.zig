const c = @import("../c.zig");
const ShaderEffect = @import("Shader.zig").ShaderEffect;

pub const ShaderPass = struct {
    m_shader: *ShaderEffect,
    m_pipelineLayout: c.VkPipelineLayout = c.VK_NULL_HANDLE,
    m_pipeline: c.VkPipeline = c.VK_NULL_HANDLE,
};
