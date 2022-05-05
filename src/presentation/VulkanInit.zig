//TODO WIP initial vulkan implementation
// shout out to Alexander Overvoorde for his vulkan tutorial book

const c = @import("../c.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const PresentationInstance = @import("PresentationInstance.zig").PresentationInstance;
const Buffer = @import("Buffer.zig").Buffer;
const Mesh = @import("Mesh.zig").Mesh;
const Texture = @import("Texture.zig").Texture;
const VertexData = @import("Mesh.zig").VertexData;
const Camera = @import("Camera.zig").Camera;
const Shader = @import("Shader.zig").Shader;
const Swapchain = @import("Swapchain.zig").Swapchain;

const mat4x4 = @import("../math/Mat4x4.zig");
const Mat4x4 = mat4x4.Mat4x4;

const imageFileUtil = @import("../coreutil/ImageFileUtil.zig");

//TODO: Gradually wrap these vk structs into structs that then handle creation, destruction, etc.

//TODO the renderer should be some big optional "render world" that can be initialized/torn down/rebuilt

// PIPELINE START
const applicationName = "Eden Demo";
const applicationVersion = c.VK_MAKE_API_VERSION(0, 1, 0, 0);

pub const BUFFER_FRAMES = 2;

pub var swapchain: Swapchain = undefined;

pub var renderPass: c.VkRenderPass = undefined;
pub var descriptorSetLayout: c.VkDescriptorSetLayout = undefined;
pub var pipelineLayout: c.VkPipelineLayout = undefined;
pub var graphicsPipeline: c.VkPipeline = undefined;
pub var pipelineCache: c.VkPipelineCache = undefined;
pub var commandPool: c.VkCommandPool = undefined;
pub var commandBuffers: []c.VkCommandBuffer = undefined;

pub var imageAvailableSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var renderFinishedSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var inFlightFences: [BUFFER_FRAMES]c.VkFence = undefined;

//PIPELINE END

pub var curMesh: ?Mesh = null;
pub var curCamera = Camera{};

// Mesh
pub var vertexBuffer: Buffer = undefined;
pub var indexBuffer: Buffer = undefined;
// Mesh mvp
pub var uniformBuffers: []Buffer = undefined;
pub var descriptorPool: c.VkDescriptorPool = undefined;
pub var descriptorSets: []c.VkDescriptorSet = undefined;

pub var textureImage: Texture = undefined;
pub var textureSampler: c.VkSampler = undefined;

const VKInitError = error{
    FailedToCreateCommandBuffers,
    FailedToCreateCommandPool,
    FailedToCreateDescriptorPool,
    FailedToCreateDescriptorSets,
    FailedToCreateFences,
    FailedToCreateImageView,
    FailedToCreateLayout,
    FailedToCreatePipeline,
    FailedToCreateRenderPass,
    FailedToCreateSemaphores,
    FailedToFindMemoryType,
    FailedToRecordCommandBuffers,
    FailedToUpdateUniformBuffer,
    MissingCurMesh, //TODO delete after testing
    MissingValidationLayer,
    NoAvailableSwapSurfaceFormat,
    VKError, //TODO anything with this error should be replaced with a more specific error
};

//TODO used a lot everywhere vulkan is used; could have a better home
pub fn CheckVkSuccess(result: c.VkResult, errorToReturn: anyerror) !void {
    if (result != c.VK_SUCCESS) {
        return errorToReturn;
    }
}

pub const SwapchainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR,
    formats: []c.VkSurfaceFormatKHR,
    presentModes: []c.VkPresentModeKHR,
};

pub fn VulkanInit(window: *c.SDL_Window) !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("CreateVKInstance()...\n", .{});
    try PresentationInstance.Initialize(
        allocator,
        window,
        applicationName,
        applicationVersion,
    );
    const presInstance = try PresentationInstance.GetInstance();

    std.debug.print("CreateSwapchain()...\n", .{});
    try CreateSwapchain(allocator, presInstance);

    std.debug.print("CreateRenderPass()...\n", .{});
    try CreateRenderPass();

    std.debug.print("CreateDescriptorSetLayout()...\n", .{});
    try CreateDescriptorSetLayout();

    std.debug.print("CreateGraphicsPipeline()...\n", .{});
    try CreateGraphicsPipeline(
        allocator,
        "src/shaders/compiled/basic_mesh-vert.spv",
        "src/shaders/compiled/basic_mesh-frag.spv",
    );

    std.debug.print("CreateCommandPool()...\n", .{});
    try CreateCommandPool();

    std.debug.print("CreateColorAndDepthResources()...\n", .{});
    try swapchain.CreateColorAndDepthResources(presInstance.m_logicalDevice, presInstance.m_msaaSamples);

    std.debug.print("CreateFrameBuffers()...\n", .{});
    try swapchain.CreateFrameBuffers(allocator, presInstance.m_logicalDevice, renderPass);

    const testImagePath = "test-assets\\test.png";
    std.debug.print("CreateTexture()...\n", .{});
    textureImage = try Texture.CreateTexture(testImagePath);

    std.debug.print("CreateTextureImageView()...\n", .{});
    try CreateTextureImageView();

    std.debug.print("CreateTextureSampler()...\n", .{});
    try CreateTextureSampler();

    if (curMesh) |*mesh| {
        std.debug.print("CreateVertexBuffer()...\n", .{});
        vertexBuffer = try Buffer.CreateVertexBuffer(mesh);

        std.debug.print("CreateIndexBuffer()...\n", .{});
        indexBuffer = try Buffer.CreateIndexBuffer(mesh);
    } else {
        return VKInitError.MissingCurMesh;
    }

    std.debug.print("CreateUniformBuffers()...\n", .{});
    try CreateUniformBuffers(allocator);

    std.debug.print("CreateDescriptorPool()...\n", .{});
    try CreateDescriptorPool();

    std.debug.print("CreateDescriptorSets()...\n", .{});
    try CreateDescriptorSets(allocator);

    std.debug.print("CreateCommandBuffers()...\n", .{});
    try CreateCommandBuffers(allocator);

    std.debug.print("CreateFencesAndSemaphores()...\n", .{});
    try CreateFencesAndSemaphores();
}

//TODO really we don't want this to be able to return an error
pub fn VulkanCleanup() !void {
    const presInstance = try PresentationInstance.GetInstance();

    // defer so execution happens in unwinding order--easier to compare with
    // init order above
    defer PresentationInstance.Shutdown();

    defer c.vkDestroyCommandPool(presInstance.m_logicalDevice, commandPool, null);

    defer {
        var i: usize = 0;
        while (i < BUFFER_FRAMES) : (i += 1) {
            c.vkDestroySemaphore(presInstance.m_logicalDevice, imageAvailableSemaphores[i], null);
            c.vkDestroySemaphore(presInstance.m_logicalDevice, renderFinishedSemaphores[i], null);
            c.vkDestroyFence(presInstance.m_logicalDevice, inFlightFences[i], null);
        }
    }

    defer vertexBuffer.DestroyBuffer(presInstance.m_logicalDevice);
    defer indexBuffer.DestroyBuffer(presInstance.m_logicalDevice);

    defer c.vkDestroyDescriptorSetLayout(presInstance.m_logicalDevice, descriptorSetLayout, null);

    defer textureImage.FreeTexture(presInstance.m_logicalDevice);

    defer c.vkDestroySampler(presInstance.m_logicalDevice, textureSampler, null);

    defer CleanupSwapchain();
}

pub fn RecreateSwapchain(allocator: Allocator) !void {
    const presInstance = try PresentationInstance.GetInstance();
    try CheckVkSuccess(
        c.vkDeviceWaitIdle(presInstance.m_logicalDevice),
        VKInitError.VKError,
    );

    std.debug.print("Recreating Swapchain...\n", .{});
    CleanupSwapchain();

    try CreateSwapchain(allocator, presInstance);
    try CreateRenderPass();
    try CreateGraphicsPipeline(
        allocator,
        "src/shaders/compiled/basic_mesh-vert.spv",
        "src/shaders/compiled/basic_mesh-frag.spv",
    );
    try swapchain.CreateColorAndDepthResources(presInstance.m_logicalDevice, presInstance.m_msaaSamples);
    try swapchain.CreateFrameBuffers(allocator, presInstance.m_logicalDevice, renderPass);
    try CreateUniformBuffers(allocator);
    try CreateDescriptorPool();
    try CreateDescriptorSets(allocator);
    try CreateCommandBuffers(allocator);
}

fn CreateSwapchain(allocator: Allocator, presInstance: *const PresentationInstance) !void {
    if (presInstance.m_graphicsQueueIdx == null or presInstance.m_presentQueueIdx == null) {
        return VKInitError.VKError;
    }
    swapchain = try Swapchain.CreateSwapchain(
        allocator,
        presInstance.m_logicalDevice,
        presInstance.m_physicalDevice,
        presInstance.m_surface,
        presInstance.m_graphicsQueueIdx.?,
        presInstance.m_presentQueueIdx.?,
    );
}

//TODO rename? make swapchain struct include more things?
fn CleanupSwapchain() void {
    const presInstance = PresentationInstance.GetInstance() catch @panic("!");

    defer {
        for (uniformBuffers) |*uniformBuffer| {
            uniformBuffer.DestroyBuffer(presInstance.m_logicalDevice);
        }
        c.vkDestroyDescriptorPool(presInstance.m_logicalDevice, descriptorPool, null);
    }

    defer swapchain.FreeSwapchain(presInstance.m_logicalDevice);

    defer c.vkDestroyRenderPass(presInstance.m_logicalDevice, renderPass, null);
    defer c.vkDestroyPipelineLayout(presInstance.m_logicalDevice, pipelineLayout, null);
    defer c.vkDestroyPipeline(presInstance.m_logicalDevice, graphicsPipeline, null);

    defer swapchain.CleanupFrameBuffers(presInstance.m_logicalDevice);

    defer c.vkFreeCommandBuffers(presInstance.m_logicalDevice, commandPool, @intCast(u32, commandBuffers.len), commandBuffers.ptr);

    defer swapchain.CleanupDepthAndColorImages(presInstance.m_logicalDevice);
}

//TODO shared function, where should this live?
pub fn QuerySwapchainSupport(allocator: Allocator, physDevice: c.VkPhysicalDevice, s: c.VkSurfaceKHR) !SwapchainSupportDetails {
    var details: SwapchainSupportDetails = undefined;

    try CheckVkSuccess(
        c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physDevice, s, &details.capabilities),
        VKInitError.VKError,
    );

    {
        var formatCount: u32 = 0;
        try CheckVkSuccess(
            c.vkGetPhysicalDeviceSurfaceFormatsKHR(physDevice, s, &formatCount, null),
            VKInitError.VKError,
        );
        details.formats = try allocator.alloc(c.VkSurfaceFormatKHR, formatCount);
        try CheckVkSuccess(
            c.vkGetPhysicalDeviceSurfaceFormatsKHR(physDevice, s, &formatCount, details.formats.ptr),
            VKInitError.VKError,
        );
    }

    {
        var presentModeCount: u32 = 0;
        try CheckVkSuccess(
            c.vkGetPhysicalDeviceSurfacePresentModesKHR(physDevice, s, &presentModeCount, null),
            VKInitError.VKError,
        );
        details.presentModes = try allocator.alloc(c.VkPresentModeKHR, presentModeCount);
        try CheckVkSuccess(
            c.vkGetPhysicalDeviceSurfacePresentModesKHR(physDevice, s, &presentModeCount, details.presentModes.ptr),
            VKInitError.VKError,
        );
    }

    return details;
}

fn CreateRenderPass() !void {
    const presInstance = try PresentationInstance.GetInstance();
    const colorAttachment = c.VkAttachmentDescription{
        .format = swapchain.m_format.format,
        .samples = presInstance.m_msaaSamples,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        .flags = 0,
    };
    const colorAttachmentRef = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };
    const colorAttachmentResolve = c.VkAttachmentDescription{
        .format = swapchain.m_format.format,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
        .flags = 0,
    };
    const colorAttachmentResolveRef = c.VkAttachmentReference{
        .attachment = 2,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };
    const depthAttachment = c.VkAttachmentDescription{
        .format = try FindDepthFormat(),
        .samples = presInstance.m_msaaSamples,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        .flags = 0,
    };
    const depthAttachmentRef = c.VkAttachmentReference{
        .attachment = 1,
        .layout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };
    const subpass = c.VkSubpassDescription{
        .flags = 0,
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .inputAttachmentCount = 0,
        .pInputAttachments = null,
        .colorAttachmentCount = 1,
        .pColorAttachments = &colorAttachmentRef,
        .pResolveAttachments = &colorAttachmentResolveRef,
        .pDepthStencilAttachment = &depthAttachmentRef,
        .preserveAttachmentCount = 0,
        .pPreserveAttachments = null,
    };
    const dependency = c.VkSubpassDependency{
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        .dependencyFlags = 0,
    };
    const attachments = [_]c.VkAttachmentDescription{ colorAttachment, depthAttachment, colorAttachmentResolve };
    const renderPassInfo = c.VkRenderPassCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .attachmentCount = attachments.len,
        .pAttachments = &attachments,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,
    };

    try CheckVkSuccess(
        c.vkCreateRenderPass(presInstance.m_logicalDevice, &renderPassInfo, null, &renderPass),
        VKInitError.FailedToCreateRenderPass,
    );
}

pub fn CreateDescriptorSetLayout() !void {
    const mvpUniformDescriptor = c.VkDescriptorSetLayoutBinding{
        .binding = 0,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
        .pImmutableSamplers = null,
    };
    const samplerLayoutBinding = c.VkDescriptorSetLayoutBinding{
        .binding = 1,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .pImmutableSamplers = null,
    };

    const bindings = [_]c.VkDescriptorSetLayoutBinding{ mvpUniformDescriptor, samplerLayoutBinding };
    const layoutInfo = c.VkDescriptorSetLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = bindings.len,
        .pBindings = &bindings,
        .pNext = null,
        .flags = 0,
    };

    const presInstance = try PresentationInstance.GetInstance();
    try CheckVkSuccess(
        c.vkCreateDescriptorSetLayout(presInstance.m_logicalDevice, &layoutInfo, null, &descriptorSetLayout),
        VKInitError.FailedToCreateDescriptorSets,
    );
}

pub fn CreateGraphicsPipeline(
    allocator: Allocator,
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

    const presInstance = try PresentationInstance.GetInstance();
    const multisamplingState = c.VkPipelineMultisampleStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = c.VK_FALSE,
        .rasterizationSamples = presInstance.m_msaaSamples,
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

    try CheckVkSuccess(
        c.vkCreatePipelineLayout(presInstance.m_logicalDevice, &pipelineLayoutState, null, &pipelineLayout),
        VKInitError.FailedToCreateLayout,
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
    try CheckVkSuccess(
        c.vkCreateGraphicsPipelines(presInstance.m_logicalDevice, null, 1, &pipelineInfo, null, &graphicsPipeline),
        VKInitError.FailedToCreatePipeline,
    );
}

fn CreateCommandPool() !void {
    const presInstance = try PresentationInstance.GetInstance();

    if (presInstance.m_graphicsQueueIdx == null) {
        return VKInitError.FailedToCreateCommandPool;
    }
    const poolInfo = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = presInstance.m_graphicsQueueIdx.?,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .pNext = null,
    };

    try CheckVkSuccess(
        c.vkCreateCommandPool(presInstance.m_logicalDevice, &poolInfo, null, &commandPool),
        VKInitError.FailedToCreateCommandPool,
    );
}

//TODO shared function; should this live here?
pub fn FindDepthFormat() !c.VkFormat {
    return FindSupportedFormat(
        &[_]c.VkFormat{ c.VK_FORMAT_D32_SFLOAT, c.VK_FORMAT_D32_SFLOAT_S8_UINT, c.VK_FORMAT_D24_UNORM_S8_UINT },
        c.VK_IMAGE_TILING_OPTIMAL,
        c.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT,
    );
}

//TODO shared function; should this live here?
pub fn FindSupportedFormat(
    candidates: []const c.VkFormat,
    tiling: c.VkImageTiling,
    features: c.VkFormatFeatureFlags,
) !c.VkFormat {
    const presInstance = try PresentationInstance.GetInstance();
    for (candidates) |format| {
        var properties: c.VkFormatProperties = undefined;
        c.vkGetPhysicalDeviceFormatProperties(presInstance.m_physicalDevice, format, &properties);
        if (tiling == c.VK_IMAGE_TILING_LINEAR and
            (properties.linearTilingFeatures & features) == features)
        {
            return format;
        } else if (tiling == c.VK_IMAGE_TILING_OPTIMAL and
            (properties.optimalTilingFeatures & features) == features)
        {
            return format;
        }
    }
    return VKInitError.VKError;
}

fn HasStencilComponent(format: c.VkFormat) bool {
    return format == c.VK_FORMAT_D32_SFLOAT_S8_UINT or format == c.VK_FORMAT_D24_UNORM_S8_UINT;
}

//TODO shared function; where should it live?
pub fn CreateImageView(
    image: c.VkImage,
    format: c.VkFormat,
    aspectFlags: c.VkImageAspectFlags,
    mipLevels: u32,
) !c.VkImageView {
    const presInstance = try PresentationInstance.GetInstance();
    const imageViewInfo = c.VkImageViewCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = image,
        .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
        .format = format,
        .components = c.VkComponentMapping{
            .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
        },
        .subresourceRange = c.VkImageSubresourceRange{
            .aspectMask = aspectFlags,
            .baseMipLevel = 0,
            .levelCount = mipLevels,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .flags = 0,
        .pNext = null,
    };

    var imageView: c.VkImageView = undefined;
    try CheckVkSuccess(
        c.vkCreateImageView(presInstance.m_logicalDevice, &imageViewInfo, null, &imageView),
        VKInitError.FailedToCreateImageView,
    );

    return imageView;
}

fn CreateTextureImageView() !void {
    textureImage.m_imageView = try CreateImageView(
        textureImage.m_image,
        c.VK_FORMAT_R8G8B8A8_SRGB,
        c.VK_IMAGE_ASPECT_COLOR_BIT,
        textureImage.m_mipLevels,
    );
}

fn CreateTextureSampler() !void {
    const samplerInfo = c.VkSamplerCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .magFilter = c.VK_FILTER_LINEAR,
        .minFilter = c.VK_FILTER_LINEAR,
        .addressModeU = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeV = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeW = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .anisotropyEnable = c.VK_TRUE,
        .maxAnisotropy = 16,
        .borderColor = c.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
        .unnormalizedCoordinates = c.VK_FALSE,
        .compareEnable = c.VK_FALSE,
        .compareOp = c.VK_COMPARE_OP_ALWAYS,
        .mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR,
        .mipLodBias = 0.0,
        .minLod = 0.0,
        .maxLod = @intToFloat(f32, textureImage.m_mipLevels),
        .flags = 0,
        .pNext = null,
    };

    const presInstance = try PresentationInstance.GetInstance();
    try CheckVkSuccess(
        c.vkCreateSampler(presInstance.m_logicalDevice, &samplerInfo, null, &textureSampler),
        VKInitError.VKError,
    );
}

//TODO shared function; where should it live?
pub fn FindMemoryType(typeFilter: u32, properties: c.VkMemoryPropertyFlags) !u32 {
    const presInstance = try PresentationInstance.GetInstance();
    var memProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(presInstance.m_physicalDevice, &memProperties);

    var i: u5 = 0;
    while (i < memProperties.memoryTypeCount) : (i += 1) {
        if ((typeFilter & @shlExact(@intCast(u32, 1), i)) != 0 and
            (memProperties.memoryTypes[i].propertyFlags & properties) == properties)
        {
            return i;
        }
    }
    return VKInitError.FailedToFindMemoryType;
}

//TODO shared function; where should it live?
pub fn BeginSingleTimeCommands() !c.VkCommandBuffer {
    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = commandPool,
        .commandBufferCount = 1,
        .pNext = null,
    };

    const presInstance = try PresentationInstance.GetInstance();
    var commandBuffer: c.VkCommandBuffer = undefined;
    try CheckVkSuccess(
        c.vkAllocateCommandBuffers(presInstance.m_logicalDevice, &allocInfo, &commandBuffer),
        VKInitError.VKError,
    );

    const beginInfo = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
        .pNext = null,
    };

    try CheckVkSuccess(
        c.vkBeginCommandBuffer(commandBuffer, &beginInfo),
        VKInitError.VKError,
    );

    return commandBuffer;
}

pub fn EndSingleTimeCommands(commandBuffer: c.VkCommandBuffer) !void {
    try CheckVkSuccess(
        c.vkEndCommandBuffer(commandBuffer),
        VKInitError.VKError,
    );

    const submitInfo = c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &commandBuffer,
        .pNext = null,
        .waitSemaphoreCount = 0,
        .pWaitSemaphores = null,
        .pWaitDstStageMask = null,
        .signalSemaphoreCount = 0,
        .pSignalSemaphores = null,
    };

    const presInstance = try PresentationInstance.GetInstance();
    try CheckVkSuccess(
        c.vkQueueSubmit(presInstance.m_graphicsQueue, 1, &submitInfo, null),
        VKInitError.VKError,
    );
    try CheckVkSuccess(
        c.vkQueueWaitIdle(presInstance.m_graphicsQueue),
        VKInitError.VKError,
    );
}

//TODO shared function; where should it live?
pub fn TransitionImageLayout(
    image: c.VkImage,
    format: c.VkFormat,
    oldLayout: c.VkImageLayout,
    newLayout: c.VkImageLayout,
    mipLevels: u32,
) !void {
    var commandBuffer = try BeginSingleTimeCommands();

    var barrier = c.VkImageMemoryBarrier{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .oldLayout = oldLayout,
        .newLayout = newLayout,
        .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresourceRange = c.VkImageSubresourceRange{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = mipLevels,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .srcAccessMask = 0, //assigned later
        .dstAccessMask = 0, //assigned later
        .pNext = null,
    };

    if (newLayout == c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL) {
        barrier.subresourceRange.aspectMask = c.VK_IMAGE_ASPECT_DEPTH_BIT;

        if (HasStencilComponent(format)) {
            barrier.subresourceRange.aspectMask |= c.VK_IMAGE_ASPECT_STENCIL_BIT;
        }
    }

    var srcStage: c.VkPipelineStageFlags = undefined;
    var dstStage: c.VkPipelineStageFlags = undefined;
    if (oldLayout == c.VK_IMAGE_LAYOUT_UNDEFINED and newLayout == c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;

        srcStage = c.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        dstStage = c.VK_PIPELINE_STAGE_TRANSFER_BIT;
    } else if (oldLayout == c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and newLayout == c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
        barrier.srcAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = c.VK_ACCESS_SHADER_READ_BIT;

        srcStage = c.VK_PIPELINE_STAGE_TRANSFER_BIT;
        dstStage = c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
    } else if (oldLayout == c.VK_IMAGE_LAYOUT_UNDEFINED and newLayout == c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL) {
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT | c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;

        srcStage = c.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        dstStage = c.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
    } else {
        return VKInitError.VKError;
    }

    c.vkCmdPipelineBarrier(
        commandBuffer,
        srcStage,
        dstStage,
        0,
        0,
        null,
        0,
        null,
        1,
        &barrier,
    );

    try EndSingleTimeCommands(commandBuffer);
}

const MeshUBO = packed struct {
    model: Mat4x4,
    view: Mat4x4,
    projection: Mat4x4,
};

fn CreateUniformBuffers(allocator: Allocator) !void {
    var bufferSize: c.VkDeviceSize = @sizeOf(MeshUBO);

    uniformBuffers = try allocator.alloc(Buffer, swapchain.m_images.len);

    var i: u32 = 0;
    while (i < swapchain.m_images.len) : (i += 1) {
        uniformBuffers[i] = try Buffer.CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
    }
}

pub fn UpdateUniformBuffer(camera: *Camera, currentFrame: usize) !void {
    var bufferSize: c.VkDeviceSize = @sizeOf(MeshUBO);

    var cameraMVP = MeshUBO{
        .model = mat4x4.identity,
        .view = camera.GetViewMatrix(),
        .projection = camera.GetProjectionMatrix(),
    };

    var data: [*]u8 = undefined;
    const presInstance = try PresentationInstance.GetInstance();
    try CheckVkSuccess(
        c.vkMapMemory(
            presInstance.m_logicalDevice,
            uniformBuffers[currentFrame].m_memory,
            0,
            bufferSize,
            0,
            @ptrCast([*c]?*anyopaque, &data),
        ),
        VKInitError.FailedToUpdateUniformBuffer,
    );
    @memcpy(data, @ptrCast([*]u8, &cameraMVP), bufferSize);
    c.vkUnmapMemory(presInstance.m_logicalDevice, uniformBuffers[currentFrame].m_memory);
}

fn CreateDescriptorPool() !void {
    const uboSize = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = @intCast(u32, swapchain.m_images.len),
    };
    const imageSamplerSize = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = @intCast(u32, swapchain.m_images.len),
    };

    const poolSizes = [_]c.VkDescriptorPoolSize{ uboSize, imageSamplerSize };
    const poolInfo = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = poolSizes.len,
        .pPoolSizes = &poolSizes,
        .maxSets = @intCast(u32, swapchain.m_images.len),
        .flags = 0,
        .pNext = null,
    };

    const presInstance = try PresentationInstance.GetInstance();
    try CheckVkSuccess(
        c.vkCreateDescriptorPool(presInstance.m_logicalDevice, &poolInfo, null, &descriptorPool),
        VKInitError.FailedToCreateDescriptorPool,
    );
}

fn CreateDescriptorSets(allocator: Allocator) !void {
    var layouts = try allocator.alloc(c.VkDescriptorSetLayout, swapchain.m_images.len);
    for (layouts) |*layout| {
        layout.* = descriptorSetLayout;
    }

    const allocInfo = c.VkDescriptorSetAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = descriptorPool,
        .descriptorSetCount = @intCast(u32, swapchain.m_images.len),
        .pSetLayouts = layouts.ptr,
        .pNext = null,
    };

    descriptorSets = try allocator.alloc(c.VkDescriptorSet, swapchain.m_images.len);
    const presInstance = try PresentationInstance.GetInstance();
    try CheckVkSuccess(
        c.vkAllocateDescriptorSets(presInstance.m_logicalDevice, &allocInfo, descriptorSets.ptr),
        VKInitError.FailedToCreateDescriptorSets,
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
        const descriptorWrites = [_]c.VkWriteDescriptorSet{ uboDescriptorWrite, textureSamplerDescriptorWrite };
        c.vkUpdateDescriptorSets(presInstance.m_logicalDevice, descriptorWrites.len, &descriptorWrites, 0, null);
    }
}

fn CreateCommandBuffers(allocator: Allocator) !void {
    commandBuffers = try allocator.alloc(c.VkCommandBuffer, swapchain.m_frameBuffers.len);
    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = commandPool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = @intCast(u32, commandBuffers.len),
        .pNext = null,
    };

    const presInstance = try PresentationInstance.GetInstance();
    try CheckVkSuccess(
        c.vkAllocateCommandBuffers(presInstance.m_logicalDevice, &allocInfo, commandBuffers.ptr),
        VKInitError.FailedToCreateCommandBuffers,
    );

    var i: usize = 0;
    while (i < commandBuffers.len) : (i += 1) {
        var beginInfo = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pInheritanceInfo = null,
            .flags = 0,
            .pNext = null,
        };

        try CheckVkSuccess(
            c.vkBeginCommandBuffer(commandBuffers[i], &beginInfo),
            VKInitError.FailedToCreateCommandBuffers,
        );

        const clearColor = c.VkClearValue{
            .color = c.VkClearColorValue{ .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 } },
        };
        const clearDepth = c.VkClearValue{
            .depthStencil = c.VkClearDepthStencilValue{ .depth = 1.0, .stencil = 0 },
        };
        const clearValues = [_]c.VkClearValue{ clearColor, clearDepth };
        const renderPassInfo = c.VkRenderPassBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = renderPass,
            .framebuffer = swapchain.m_frameBuffers[i],
            .renderArea = c.VkRect2D{
                .offset = c.VkOffset2D{
                    .x = 0,
                    .y = 0,
                },
                .extent = swapchain.m_extent,
            },
            .clearValueCount = 2,
            .pClearValues = &clearValues,
            .pNext = null,
        };

        c.vkCmdBeginRenderPass(commandBuffers[i], &renderPassInfo, c.VK_SUBPASS_CONTENTS_INLINE);
        {
            c.vkCmdBindPipeline(commandBuffers[i], c.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);

            const vertexBuffers = [_]c.VkBuffer{vertexBuffer.m_buffer};
            const offsets = [_]c.VkDeviceSize{0};
            c.vkCmdBindVertexBuffers(commandBuffers[i], 0, 1, &vertexBuffers, &offsets);

            c.vkCmdBindIndexBuffer(commandBuffers[i], indexBuffer.m_buffer, 0, c.VK_INDEX_TYPE_UINT32);

            c.vkCmdBindDescriptorSets(commandBuffers[i], c.VK_PIPELINE_BIND_POINT_GRAPHICS, pipelineLayout, 0, 1, &descriptorSets[i], 0, null);

            //TODO testing mesh
            if (curMesh) |*meshPtr| {
                c.vkCmdDrawIndexed(commandBuffers[i], @intCast(u32, meshPtr.m_indices.items.len), 1, 0, 0, 0);
            } else {
                return VKInitError.MissingCurMesh;
            }
        }
        c.vkCmdEndRenderPass(commandBuffers[i]);

        try CheckVkSuccess(
            c.vkEndCommandBuffer(commandBuffers[i]),
            VKInitError.FailedToRecordCommandBuffers,
        );
    }
}

fn CreateFencesAndSemaphores() !void {
    const semaphoreInfo = c.VkSemaphoreCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .flags = 0,
        .pNext = null,
    };

    const fenceInfo = c.VkFenceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = 0,
        .pNext = null,
    };

    const presInstance = try PresentationInstance.GetInstance();
    var i: usize = 0;
    while (i < BUFFER_FRAMES) : (i += 1) {
        try CheckVkSuccess(
            c.vkCreateSemaphore(presInstance.m_logicalDevice, &semaphoreInfo, null, &renderFinishedSemaphores[i]),
            VKInitError.FailedToCreateSemaphores,
        );
        try CheckVkSuccess(
            c.vkCreateSemaphore(presInstance.m_logicalDevice, &semaphoreInfo, null, &imageAvailableSemaphores[i]),
            VKInitError.FailedToCreateSemaphores,
        );
        try CheckVkSuccess(
            c.vkCreateFence(presInstance.m_logicalDevice, &fenceInfo, null, &inFlightFences[i]),
            VKInitError.FailedToCreateFences,
        );
    }
}
