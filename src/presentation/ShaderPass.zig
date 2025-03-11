const c = @import("c.zig");
const Shader = @import("Shader.zig").Shader;

pub const ShaderPass = struct {
    m_shader: *Shader,
    m_pipelineLayout: c.VkPipelineLayout = c.VK_NULL_HANDLE,
    m_pipeline: c.VkPipeline = c.VK_NULL_HANDLE,
};
