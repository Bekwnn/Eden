const c = @import("../c.zig");

const VkError = error{
    FailedToFindMemoryType,
    FailedToRecordCommandBuffers,
    UnspecifiedError, // prefer creating new more specific errors
};

pub fn CheckVkSuccess(result: c.VkResult, errorToReturn: anyerror) !void {
    if (result != c.VK_SUCCESS) {
        return errorToReturn;
    }
}

fn HasStencilComponent(format: c.VkFormat) bool {
    return format == c.VK_FORMAT_D32_SFLOAT_S8_UINT or format == c.VK_FORMAT_D24_UNORM_S8_UINT;
}

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
    return vkUtil.VkError.FailedToFindMemoryType;
}

pub fn BeginSingleTimeCommands() !c.VkCommandBuffer {
    const rContext = try RenderContext.GetInstance();

    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = rContext.m_commandPool,
        .commandBufferCount = 1,
        .pNext = null,
    };

    var commandBuffer: c.VkCommandBuffer = undefined;
    try vkUtil.CheckVkSuccess(
        c.vkAllocateCommandBuffers(rContext.m_logicalDevice, &allocInfo, &commandBuffer),
        vkUtil.VkError.UnspecifiedError,
    );

    const beginInfo = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkBeginCommandBuffer(commandBuffer, &beginInfo),
        vkUtil.VkError.UnspecifiedError,
    );

    return commandBuffer;
}

pub fn EndSingleTimeCommands(commandBuffer: c.VkCommandBuffer) !void {
    try vkUtil.CheckVkSuccess(
        c.vkEndCommandBuffer(commandBuffer),
        vkUtil.VkError.UnspecifiedError,
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
    try vkUtil.CheckVkSuccess(
        c.vkQueueSubmit(rContext.m_graphicsQueue, 1, &submitInfo, null),
        vkUtil.VkError.UnspecifiedError,
    );
    try vkUtil.CheckVkSuccess(
        c.vkQueueWaitIdle(rContext.m_graphicsQueue),
        vkUtil.VkError.UnspecifiedError,
    );
}

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
        return vkUtil.VkError.UnspecifiedError;
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
