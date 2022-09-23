//TODO WIP initial vulkan implementation
// shout out to Alexander Overvoorde for his vulkan tutorial book

const c = @import("../c.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const RenderContext = @import("RenderContext.zig").RenderContext;
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

const applicationName = "Eden Demo";
const applicationVersion = c.VK_MAKE_API_VERSION(0, 1, 0, 0);

pub const BUFFER_FRAMES = 2;

// PIPELINE START
pub var commandPool: c.VkCommandPool = undefined;
pub var commandBuffers: []c.VkCommandBuffer = undefined;

pub var imageAvailableSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var renderFinishedSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var inFlightFences: [BUFFER_FRAMES]c.VkFence = undefined;
//PIPELINE END

const VKInitError = error{
    FailedToCreateCommandBuffers,
    FailedToCreateCommandPool,
    FailedToCreateFences,
    FailedToCreateImageView,
    FailedToCreateSemaphores,
    FailedToFindMemoryType,
    FailedToRecordCommandBuffers,
    VKError, // prefer creating new more specific errors
};

//TODO used a lot everywhere vulkan is used; could have a better home
pub fn CheckVkSuccess(result: c.VkResult, errorToReturn: anyerror) !void {
    if (result != c.VK_SUCCESS) {
        return errorToReturn;
    }
}

pub fn VulkanInit(window: *c.SDL_Window) !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("CreateVKInstance()...\n", .{});
    try RenderContext.Initialize(
        allocator,
        window,
        applicationName,
        applicationVersion,
    );

    std.debug.print("CreateCommandPool()...\n", .{});
    try CreateCommandPool();

    std.debug.print("CreateCommandBuffers()...\n", .{});
    try CreateCommandBuffers(allocator);

    std.debug.print("CreateFencesAndSemaphores()...\n", .{});
    try CreateFencesAndSemaphores();
}

//TODO really we don't want this to be able to return an error
pub fn VulkanCleanup() !void {
    const rContext = try RenderContext.GetInstance();

    // defer so execution happens in unwinding order--easier to compare with
    // init order above
    defer RenderContext.Shutdown();

    defer c.vkDestroyCommandPool(rContext.m_logicalDevice, commandPool, null);

    defer {
        var i: usize = 0;
        while (i < BUFFER_FRAMES) : (i += 1) {
            c.vkDestroySemaphore(rContext.m_logicalDevice, imageAvailableSemaphores[i], null);
            c.vkDestroySemaphore(rContext.m_logicalDevice, renderFinishedSemaphores[i], null);
            c.vkDestroyFence(rContext.m_logicalDevice, inFlightFences[i], null);
        }
    }
}

fn CreateCommandPool() !void {
    const rContext = try RenderContext.GetInstance();

    if (rContext.m_graphicsQueueIdx == null) {
        return VKInitError.FailedToCreateCommandPool;
    }
    const poolInfo = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = rContext.m_graphicsQueueIdx.?,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .pNext = null,
    };

    try CheckVkSuccess(
        c.vkCreateCommandPool(rContext.m_logicalDevice, &poolInfo, null, &commandPool),
        VKInitError.FailedToCreateCommandPool,
    );
}

fn HasStencilComponent(format: c.VkFormat) bool {
    return format == c.VK_FORMAT_D32_SFLOAT_S8_UINT or format == c.VK_FORMAT_D24_UNORM_S8_UINT;
}

//TODO shared function; where should it live?
pub fn FindMemoryType(typeFilter: u32, properties: c.VkMemoryPropertyFlags) !u32 {
    const rContext = try RenderContext.GetInstance();
    var memProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(rContext.m_physicalDevice, &memProperties);

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

    const rContext = try RenderContext.GetInstance();
    var commandBuffer: c.VkCommandBuffer = undefined;
    try CheckVkSuccess(
        c.vkAllocateCommandBuffers(rContext.m_logicalDevice, &allocInfo, &commandBuffer),
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

    const rContext = try RenderContext.GetInstance();
    try CheckVkSuccess(
        c.vkQueueSubmit(rContext.m_graphicsQueue, 1, &submitInfo, null),
        VKInitError.VKError,
    );
    try CheckVkSuccess(
        c.vkQueueWaitIdle(rContext.m_graphicsQueue),
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

fn CreateCommandBuffers(allocator: Allocator) !void {
    const rContext = try RenderContext.GetInstance();
    commandBuffers = try allocator.alloc(
        c.VkCommandBuffer,
        rContext.m_swapchain.m_frameBuffers.len,
    );
    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = commandPool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = @intCast(u32, commandBuffers.len),
        .pNext = null,
    };

    try CheckVkSuccess(
        c.vkAllocateCommandBuffers(rContext.m_logicalDevice, &allocInfo, commandBuffers.ptr),
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
            .renderPass = rContext.m_renderPass,
            .framebuffer = rContext.m_swapchain.m_frameBuffers[i],
            .renderArea = c.VkRect2D{
                .offset = c.VkOffset2D{
                    .x = 0,
                    .y = 0,
                },
                .extent = rContext.m_swapchain.m_extent,
            },
            .clearValueCount = 2,
            .pClearValues = &clearValues,
            .pNext = null,
        };

        c.vkCmdBeginRenderPass(
            commandBuffers[i],
            &renderPassInfo,
            c.VK_SUBPASS_CONTENTS_INLINE,
        );
        {
            //TODO scene.RenderObjects(commandBuffers[i], renderObjects);
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

    const rContext = try RenderContext.GetInstance();
    var i: usize = 0;
    while (i < BUFFER_FRAMES) : (i += 1) {
        try CheckVkSuccess(
            c.vkCreateSemaphore(rContext.m_logicalDevice, &semaphoreInfo, null, &renderFinishedSemaphores[i]),
            VKInitError.FailedToCreateSemaphores,
        );
        try CheckVkSuccess(
            c.vkCreateSemaphore(rContext.m_logicalDevice, &semaphoreInfo, null, &imageAvailableSemaphores[i]),
            VKInitError.FailedToCreateSemaphores,
        );
        try CheckVkSuccess(
            c.vkCreateFence(rContext.m_logicalDevice, &fenceInfo, null, &inFlightFences[i]),
            VKInitError.FailedToCreateFences,
        );
    }
}
