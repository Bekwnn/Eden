const c = @import("../c.zig");
const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const builderAllocator = std.heap.page_allocator;

const RenderContext = @import("RenderContext.zig");
const vkUtil = @import("VulkanUtil.zig");

const PipelineBuildError = error{
    FailedToBuildPipeline,
};

// Usage:
// 1. InitializeBuilder() and AddShaderStage() as appropriate
// 2. Call BuildPipeline()
pub const PipelineBuilder = struct {
    m_shaderStages: ArrayList(c.VkPipelineShaderStageCreateInfo) =
        ArrayList(c.VkPipelineShaderStageCreateInfo).init(builderAllocator),
    m_vertexInputInfo: c.VkPipelineVertexInputStateCreateInfo = undefined,
    m_inputAssembly: c.VkPipelineInputAssemblyStateCreateInfo = undefined,
    m_viewport: c.VkViewport = undefined,
    m_scissor: c.VkRect2D = undefined,
    m_rasterizerState: c.VkPipelineRasterizationStateCreateInfo = undefined,
    m_colorBlendAttachment: c.VkPipelineColorBlendAttachmentState = undefined,
    m_multisamplingState: c.VkPipelineMultisampleStateCreateInfo = undefined,
    m_pipelineLayout: c.VkPipelineLayout = undefined,
    m_depthStencilState: c.VkDepthStencilState = undefined,

    pub fn AddShaderStage(
        self: *PipelineBuilder,
        stage: c.VkShaderStageFlagBits,
        shaderModule: c.VkShaderModule,
    ) void {
        self.m_shaderStages.append(c.VkPipelineShaderStageCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = stage,
            .module = shaderModule,
            .pName = "main",
            .pSpecializationInfo = null,
            .pNext = null,
            .flags = 0,
        });
    }

    pub fn ClearShaderStages(self: *PipelineBuilder) void {
        self.m_shaderStages.clearRetainingCapacity();
    }

    pub fn InitializeBuilder(
        self: *PipelineBuilder,
        topology: c.VkPrimitiveTopology,
        polygonMode: *c.VkPolygonMode,
        bindingDescription: *const c.VkVertexInputBindingDescription,
        attribDescriptions: []const c.VkVertexInputAttributeDescription,
    ) !void {
        self.InitVertexInputInfo(bindingDescription, attribDescriptions);
        self.InitInputAssembly(topology);
        self.InitRasterizationState(polygonMode);
        try self.InitMultisamplingState();
        self.InitColorBlendAttachment();
        self.InitDepthStencilState();
    }

    fn InitVertexInputInfo(
        self: *PipelineBuilder,
        bindingDescription: *const c.VkVertexInputBindingDescription,
        attribDescriptions: []const c.VkVertexInputAttributeDescription,
    ) void {
        self.m_vertexInputInfo = c.VkPipelineVertexInputStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = 1,
            .pVertexBindingDescriptions = bindingDescription,
            .vertexAttributeDescriptionCount = @intCast(u32, attribDescriptions.len),
            .pVertexAttributeDescriptions = attribDescriptions.ptr,
            .pNext = null,
            .flags = 0,
        };
    }

    fn InitInputAssembly(
        self: *PipelineBuilder,
        topology: c.VkPrimitiveTopology,
    ) void {
        self.m_inputAssembly = c.VkPipelineInputAssemblyStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .pNext = null,
            .topology = topology,
            .primitiveRestartEnable = c.VK_FALSE,
        };
    }

    fn InitRasterizationState(
        self: *PipelineBuilder,
        polygonMode: *c.VkPolygonMode,
    ) void {
        self.m_rasterizer = c.VkPipelineRasterizationStateCreateInfo{
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
    }

    fn InitMultisamplingState(
        self: *PipelineBuilder,
    ) !void {
        const rContext = try RenderContext.GetInstance();
        self.m_multisampling = c.VkPipelineMultisampleStateCreateInfo{
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
    }

    fn InitColorBlendAttachment(
        self: *PipelineBuilder,
    ) void {
        self.m_colorBlendAttachment = c.VkPipelineColorBlendAttachmentState{
            .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT |
                c.VK_COLOR_COMPONENT_G_BIT |
                c.VK_COLOR_COMPONENT_B_BIT |
                c.VK_COLOR_COMPONENT_A_BIT,
            .blendEnable = c.VK_FALSE,
        };
    }

    fn InitDepthStencilState(
        self: *PipelineBuilder,
    ) void {
        self.m_depthStencilState = c.VkPipelineDepthStencilStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .depthTestEnable = c.VK_TRUE,
            .depthWriteEnable = c.VK_TRUE,
            .pNext = null,
            .flags = 0,
        };
    }

    pub fn BuildPipeline(
        self: *const PipelineBuilder,
    ) !c.VkPipeline {
        const rContext = try RenderContext.GetInstance();
        const extent = &rContext.m_swapchain.m_extent;
        const viewport = c.VkViewport{
            .x = 0.0,
            .y = 0.0,
            .width = @intToFloat(f32, extent.width),
            .height = @intToFloat(f32, extent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };
        const scissor = c.VkRect2D{
            .offset = c.VkOffset2D{ .x = 0, .y = 0 },
            .extent = extent,
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
            .pAttachments = &self.m_colorBlendAttachment,
            .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            .pNext = null,
            .flags = 0,
        };

        const pipelineInfo = c.VkGraphicsPipelineCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .stageCount = self.m_shaderStages.len,
            .pStages = &self.m_shaderStages,
            .pVertexInputState = &self.m_vertexInputState,
            .pInputAssemblyState = &self.m_inputAssemblyState,
            .pViewportState = &viewportState,
            .pRasterizationState = &self.m_rasterizationState,
            .pTessellationState = null,
            .pMultisampleState = &self.m_multisamplingState,
            .pDepthStencilState = &self.m_depthStencilState,
            .pColorBlendState = &colorBlendingState,
            .pDynamicState = null,
            .layout = rContext.m_pipelineLayout,
            .renderPass = rContext.m_renderPass,
            .subpass = 0,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
            .pNext = null,
            .flags = 0,
        };

        var newPipeline: c.VkPipeline = undefined;
        try vkUtil.CheckVkSuccess(
            c.vkCreateGraphicsPipelines(
                rContext.m_logicalDevice,
                null,
                1,
                &pipelineInfo,
                null,
                &newPipeline,
            ),
            PipelineBuildError.FailedToBuildPipeline,
        );
        return newPipeline;
    }
};
