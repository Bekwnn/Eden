const c = @import("c.zig");
const std = @import("std");
const allocator = std.heap.page_allocator;

const vkUtil = @import("VulkanUtil.zig");
const texture = @import("Texture.zig");
const Texture = texture.Texture;
const RenderContext = @import("RenderContext.zig").RenderContext;

//TODO we want material instancing such that a material is made up of two members: a pointer to instance data (texture, etc) and a pointer to shader constants (descriptor layout, etc)
// really we might want it to be more flexible than that, and support multiple textures, etc. For now, hardcoded to one texture
pub const Material = struct {
    m_name: []u8,
    m_uboLayoutBinding: c.VkDescriptorSetLayoutBinding,

    m_textureImage: Texture, //TODO move to material instance data
    m_textureSampler: c.VkSampler,

    m_pipeline: c.VkPipeline,
    m_pipelineLayout: c.VkPipelineLayout,

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

        try newMaterial.CreateDescriptorPool();
        try newMaterial.CreateDescriptorSets();
    }

    pub fn DestroyMaterial(self: *Material) void {
        const rContext = try RenderContext.GetInstance();

        defer c.vkDestroyDescriptorSetLayout(
            rContext.m_logicalDevice,
            descriptorSetLayout,
            null,
        );

        defer textureImage.FreeTexture(rContext.m_logicalDevice);

        defer c.vkDestroySampler(rContext.m_logicalDevice, self.m_textureSampler, null);

        defer c.vkDestroyPipelineLayout(
            rContext.m_logicalDevice,
            rContext.m_pipelineLayout,
            null,
        );

        defer c.vkDestroyPipeline(rContext.m_logicalDevice, rContext.m_graphicsPipeline, null);
    }
};

fn CreateDescriptorPool() !void {
    const rContext = try RenderContext.GetInstance();
    const uboSize = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = @intCast(u32, rContext.swapchain.m_images.len),
    };
    const imageSamplerSize = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = @intCast(u32, rContext.swapchain.m_images.len),
    };

    const poolSizes = [_]c.VkDescriptorPoolSize{ uboSize, imageSamplerSize };
    const poolInfo = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = poolSizes.len,
        .pPoolSizes = &poolSizes,
        .maxSets = @intCast(u32, rContext.swapchain.m_images.len),
        .flags = 0,
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkCreateDescriptorPool(
            rContext.m_logicalDevice,
            &poolInfo,
            null,
            &descriptorPool,
        ),
        vkUtil.VkError.FailedToCreateDescriptorPool,
    );
}

fn CreateDescriptorSets() !void {
    const rContext = RenderContext.GetInstance();
    var layouts = try allocator.alloc(
        c.VkDescriptorSetLayout,
        rContext.swapchain.m_images.len,
    );
    for (layouts) |*layout| {
        layout.* = descriptorSetLayout;
    }

    const allocInfo = c.VkDescriptorSetAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = descriptorPool,
        .descriptorSetCount = @intCast(u32, rContext.swapchain.m_images.len),
        .pSetLayouts = layouts.ptr,
        .pNext = null,
    };

    descriptorSets = try allocator.alloc(c.VkDescriptorSet, rContext.swapchain.m_images.len);
    try vkUtil.CheckVkSuccess(
        c.vkAllocateDescriptorSets(
            rContext.m_logicalDevice,
            &allocInfo,
            descriptorSets.ptr,
        ),
        vkUtil.VkError.FailedToCreateDescriptorSets,
    );

    var i: u32 = 0;
    while (i < swapchain.m_images.len) : (i += 1) {
        const bufferInfo = c.VkDescriptorBufferInfo{
            .buffer = uniformBuffers[i].m_buffer,
            .offset = 0,
            .range = @sizeOf(MeshUBO),
        };
        const imageInfo = c.VkDescriptorImageInfo{
            .imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            .imageView = textureImage.m_imageView,
            .sampler = textureSampler,
        };
        const uboDescriptorWrite = c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = descriptorSets[i],
            .dstBinding = 0,
            .dstArrayElement = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .pBufferInfo = &bufferInfo,
            .pImageInfo = null,
            .pTexelBufferView = null,
            .pNext = null,
        };
        const textureSamplerDescriptorWrite = c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = descriptorSets[i],
            .dstBinding = 1,
            .dstArrayElement = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            .descriptorCount = 1,
            .pBufferInfo = null,
            .pImageInfo = &imageInfo,
            .pTexelBufferView = null,
            .pNext = null,
        };
        const descriptorWrites = [_]c.VkWriteDescriptorSet{
            uboDescriptorWrite,
            textureSamplerDescriptorWrite,
        };
        c.vkUpdateDescriptorSets(
            rContext.m_logicalDevice,
            descriptorWrites.len,
            &descriptorWrites,
            0,
            null,
        );
    }
}

pub fn CreateMaterialPipeline(
    vertShaderRelativePath: []const u8,
    fragShaderRelativePath: []const u8,
) !void {
    var shader = try Shader.CreateBasicShader(
        allocator,
        vertShaderRelativePath,
        fragShaderRelativePath,
    );
    defer shader.FreeShader();

    const vertPipelineCreateInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = shader.m_vertShader.?,
        .pName = "main",
        .pSpecializationInfo = null,
        .pNext = null,
        .flags = 0,
    };
    const fragPipelineCreateInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = shader.m_fragShader.?,
        .pName = "main",
        .pSpecializationInfo = null,
        .pNext = null,
        .flags = 0,
    };

    const shaderStages = [_]c.VkPipelineShaderStageCreateInfo{
        vertPipelineCreateInfo,
        fragPipelineCreateInfo,
    };

    const bindingDescription = Mesh.GetBindingDescription();
    const attribDescriptions = Mesh.GetAttributeDescriptions();

    const vertexInputState = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &bindingDescription,
        .vertexAttributeDescriptionCount = @intCast(u32, attribDescriptions.len),
        .pVertexAttributeDescriptions = attribDescriptions.ptr,
        .pNext = null,
        .flags = 0,
    };

    const inputAssemblyState = c.VkPipelineInputAssemblyStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
        .pNext = null,
        .flags = 0,
    };

    const viewport = c.VkViewport{
        .x = 0.0,
        .y = 0.0,
        .width = @intToFloat(f32, swapchain.m_extent.width),
        .height = @intToFloat(f32, swapchain.m_extent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };
    const scissor = c.VkRect2D{
        .offset = c.VkOffset2D{ .x = 0, .y = 0 },
        .extent = swapchain.m_extent,
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
    const rasterizationState = c.VkPipelineRasterizationStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
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

    const rContext = try RenderContext.GetInstance();
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
    const depthStencilState = c.VkPipelineDepthStencilStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .depthTestEnable = c.VK_TRUE,
        .depthWriteEnable = c.VK_TRUE,
        .depthCompareOp = c.VK_COMPARE_OP_LESS,
        .depthBoundsTestEnable = c.VK_FALSE,
        .stencilTestEnable = c.VK_FALSE,
        .minDepthBounds = 0.0,
        .maxDepthBounds = 1.0,
        .front = c.VkStencilOpState{
            .failOp = c.VK_STENCIL_OP_KEEP,
            .passOp = c.VK_STENCIL_OP_KEEP,
            .depthFailOp = c.VK_STENCIL_OP_KEEP,
            .compareOp = c.VK_COMPARE_OP_NEVER,
            .compareMask = 0,
            .writeMask = 0,
            .reference = 0,
        },
        .back = c.VkStencilOpState{
            .failOp = c.VK_STENCIL_OP_KEEP,
            .passOp = c.VK_STENCIL_OP_KEEP,
            .depthFailOp = c.VK_STENCIL_OP_KEEP,
            .compareOp = c.VK_COMPARE_OP_NEVER,
            .compareMask = 0,
            .writeMask = 0,
            .reference = 0,
        },
        .flags = 0,
        .pNext = null,
    };

    const colorBlending = c.VkPipelineColorBlendAttachmentState{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT |
            c.VK_COLOR_COMPONENT_G_BIT |
            c.VK_COLOR_COMPONENT_B_BIT |
            c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_FALSE,
        .srcColorBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };
    const colorBlendingState = c.VkPipelineColorBlendStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &colorBlending,
        .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        .pNext = null,
        .flags = 0,
    };

    const pipelineLayoutState = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptorSetLayout,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
        .pNext = null,
        .flags = 0,
    };

    try vkUtil.CheckVkSuccess(
        c.vkCreatePipelineLayout(rContext.m_logicalDevice, &pipelineLayoutState, null, &pipelineLayout),
        vkUtil.VkError.FailedToCreateLayout,
    );

    const pipelineInfo = c.VkGraphicsPipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = shaderStages.len,
        .pStages = &shaderStages,
        .pVertexInputState = &vertexInputState,
        .pInputAssemblyState = &inputAssemblyState,
        .pViewportState = &viewportState,
        .pRasterizationState = &rasterizationState,
        .pTessellationState = null,
        .pMultisampleState = &multisamplingState,
        .pDepthStencilState = &depthStencilState,
        .pColorBlendState = &colorBlendingState,
        .pDynamicState = null,
        .layout = pipelineLayout,
        .renderPass = renderPass,
        .subpass = 0,
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
        .pNext = null,
        .flags = 0,
    };
    try vkUtil.CheckVkSuccess(
        c.vkCreateGraphicsPipelines(rContext.m_logicalDevice, null, 1, &pipelineInfo, null, &graphicsPipeline),
        vkUtil.VkError.FailedToCreatePipeline,
    );
}
