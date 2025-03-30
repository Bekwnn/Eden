const c = @import("../c.zig");

const vkUtil = @import("VulkanUtil.zig");
const ShaderEffect = @import("ShaderEffect.zig").ShaderEffect;
const RenderContext = @import("RenderContext.zig").RenderContext;

pub const ShaderPassError = error{
    FailedToCreatePipelineLayout,
    FailedToBuildPipeline,
};

// The built version of a ShaderEffect
pub const ShaderPass = struct {
    m_shaderEffect: *const ShaderEffect,
    m_pipelineLayout: c.VkPipelineLayout,
    m_pipeline: c.VkPipeline,

    pub fn BuildShaderPass(
        shaderEffect: *const ShaderEffect,
        topology: c.VkPrimitiveTopology,
        polygonMode: c.VkPolygonMode,
        bindingDescription: *const c.VkVertexInputBindingDescription,
        attribDescriptions: []const c.VkVertexInputAttributeDescription,
    ) !ShaderPass {
        var newShaderPass = ShaderPass{
            .m_shaderEffect = shaderEffect,
            .m_pipelineLayout = try CreatePipelineLayout(),
            .m_pipeline = undefined,
        };

        const rContext = try RenderContext.GetInstance();

        const vertexInputState = c.VkPipelineVertexInputStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = 1,
            .pVertexBindingDescriptions = bindingDescription,
            .vertexAttributeDescriptionCount = @intCast(attribDescriptions.len),
            .pVertexAttributeDescriptions = attribDescriptions.ptr,
            .pNext = null,
            .flags = 0,
        };

        const inputAssemblyState = c.VkPipelineInputAssemblyStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .pNext = null,
            .topology = topology,
            .primitiveRestartEnable = c.VK_FALSE,
        };

        const rasterizationState = c.VkPipelineRasterizationStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .depthClampEnable = c.VK_FALSE,
            .rasterizerDiscardEnable = c.VK_FALSE,
            .polygonMode = polygonMode,
            .lineWidth = 1.0,
            .cullMode = c.VK_CULL_MODE_BACK_BIT,
            .frontFace = c.VK_FRONT_FACE_COUNTER_CLOCKWISE,
            .depthBiasEnable = c.VK_FALSE,
            .depthBiasConstantFactor = 0.0,
            .depthBiasClamp = 0.0,
            .depthBiasSlopeFactor = 0.0,
            .pNext = null,
            .flags = 0,
        };

        const multisamplingState = c.VkPipelineMultisampleStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .sampleShadingEnable = c.VK_FALSE,
            .rasterizationSamples = rContext.m_msaaSamples,
            .minSampleShading = 1.0,
            .pSampleMask = null,
            .alphaToCoverageEnable = c.VK_FALSE,
            .alphaToOneEnable = c.VK_FALSE,
            .pNext = null,
            .flags = 0,
        };

        const colorBlendAttachment = c.VkPipelineColorBlendAttachmentState{
            .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT |
                c.VK_COLOR_COMPONENT_G_BIT |
                c.VK_COLOR_COMPONENT_B_BIT |
                c.VK_COLOR_COMPONENT_A_BIT,
            .blendEnable = c.VK_FALSE,
        };

        const depthStencilState = c.VkPipelineDepthStencilStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            .depthTestEnable = c.VK_TRUE,
            .depthWriteEnable = c.VK_TRUE,
            .pNext = null,
            .flags = 0,
        };

        const extent = &rContext.m_swapchain.m_extent;
        const viewport = c.VkViewport{
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(extent.width),
            .height = @floatFromInt(extent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };
        const scissor = c.VkRect2D{
            .offset = c.VkOffset2D{ .x = 0, .y = 0 },
            .extent = extent.*,
        };
        const viewportState = c.VkPipelineViewportStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .pViewports = &viewport,
            .scissorCount = 1,
            .pScissors = &scissor,
            .pNext = null,
            .flags = 0,
        };

        const colorBlendingState = c.VkPipelineColorBlendStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .logicOpEnable = c.VK_FALSE,
            .logicOp = c.VK_LOGIC_OP_COPY,
            .attachmentCount = 1,
            .pAttachments = &colorBlendAttachment,
            .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            .pNext = null,
            .flags = 0,
        };

        const pipelineInfo = c.VkGraphicsPipelineCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .stageCount = @intCast(shaderEffect.m_shaderStages.items.len),
            .pStages = @ptrCast(shaderEffect.m_shaderStages.items.ptr),
            .pVertexInputState = &vertexInputState,
            .pInputAssemblyState = &inputAssemblyState,
            .pViewportState = &viewportState,
            .pRasterizationState = &rasterizationState,
            .pTessellationState = null,
            .pMultisampleState = &multisamplingState,
            .pDepthStencilState = &depthStencilState,
            .pColorBlendState = &colorBlendingState,
            .pDynamicState = null,
            .layout = newShaderPass.m_pipelineLayout,
            .renderPass = rContext.m_renderPass,
            .subpass = 0,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
            .pNext = null,
            .flags = 0,
        };

        try vkUtil.CheckVkSuccess(
            c.vkCreateGraphicsPipelines(
                rContext.m_logicalDevice,
                null,
                1,
                &pipelineInfo,
                null,
                &newShaderPass.m_pipeline,
            ),
            ShaderPassError.FailedToBuildPipeline,
        );

        return newShaderPass;
    }
};

fn CreatePipelineLayout() !c.VkPipelineLayout {
    const rContext = try RenderContext.GetInstance();

    const pipelineLayoutInfo = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = rContext.m_descriptorSetLayouts.len,
        .pSetLayouts = &rContext.m_descriptorSetLayouts,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
        .flags = 0,
        .pNext = null,
    };

    var pipelineLayout: c.VkPipelineLayout = undefined;
    try vkUtil.CheckVkSuccess(
        c.vkCreatePipelineLayout(
            rContext.m_logicalDevice,
            &pipelineLayoutInfo,
            null,
            &pipelineLayout,
        ),
        ShaderPassError.FailedToCreatePipelineLayout,
    );

    return pipelineLayout;
}
