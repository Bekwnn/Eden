const editor = @import("Editor.zig");

const renderContext = @import("../RenderContext.zig");
const RenderContext = renderContext.RenderContext;
const Texture = @import("../Texture.zig").Texture;
const vkUtil = @import("../VulkanUtil.zig");

const allocator = @import("../../coreutil/Allocators.zig").defaultAllocator;

const c = @import("../../c.zig").cLib;

const std = @import("std");

const ViewportError = error{
    FailedToInitialize,
};

//TODO resize texture on swapchain resize
pub const ViewportFrameData = struct {
    m_descriptorSet: c.VkDescriptorSet,
    m_colorTexture: Texture,
    m_depthTexture: Texture,
    m_sampler: c.VkSampler,

    pub fn GetId(self: *const ViewportFrameData) c.ImTextureID {
        return @as(c.ImTextureID, @intFromPtr(self.m_descriptorSet));
    }
};

var viewportFrameData: std.ArrayList(ViewportFrameData) = .empty;

pub fn Initialize() !void {
    const rContext = try RenderContext.GetInstance();
    const imageCount = rContext.m_swapchain.m_imageCount;

    try viewportFrameData.ensureTotalCapacity(allocator, imageCount);
    for (0..imageCount) |_| {
        const curViewportData = viewportFrameData.addOneAssumeCapacity();
        curViewportData.m_colorTexture = try Texture.CreateColorImage(
            rContext.m_logicalDevice,
            rContext.m_swapchain.m_extent.width,
            rContext.m_swapchain.m_extent.height,
            rContext.m_msaaSamples,
            rContext.m_swapchain.m_format.format,
            c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
                c.VK_IMAGE_USAGE_SAMPLED_BIT,
        );

        const depthFormat = try renderContext.FindDepthFormat();
        curViewportData.m_depthTexture = try Texture.CreateDepthImage(
            rContext.m_logicalDevice,
            rContext.m_swapchain.m_extent.width,
            rContext.m_swapchain.m_extent.height,
            rContext.m_msaaSamples,
            depthFormat,
        );

        const samplerInfo = c.VkSamplerCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
            .magFilter = c.VK_FILTER_LINEAR,
            .minFilter = c.VK_FILTER_LINEAR,
            .addressModeU = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
            .addressModeV = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
            .addressModeW = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
            .anisotropyEnable = c.VK_FALSE,
            .maxAnisotropy = 1,
            .borderColor = c.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
            .compareEnable = c.VK_FALSE,
            .compareOp = c.VK_COMPARE_OP_ALWAYS,
            .unnormalizedCoordinates = c.VK_FALSE,
            .mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR,
            .mipLodBias = 0.0,
            .minLod = -1000,
            .maxLod = 1000,
            .flags = 0,
            .pNext = null,
        };
        try vkUtil.CheckVkSuccess(
            c.vkCreateSampler(
                rContext.m_logicalDevice,
                &samplerInfo,
                null,
                &curViewportData.m_sampler,
            ),
            ViewportError.FailedToInitialize,
        );

        curViewportData.m_descriptorSet = c.ImGui_ImplVulkan_AddTexture(
            curViewportData.m_sampler,
            curViewportData.m_colorTexture.m_imageView,
            c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        );
    }
}

pub fn Deinit() void {
    const rContext = RenderContext.GetInstance() catch {
        @panic("!");
    };
    for (viewportFrameData.items) |*vpFrameData| {
        vpFrameData.m_colorTexture.FreeTexture(rContext.m_logicalDevice);
        c.vkDestroySampler(rContext.m_logicalDevice, vpFrameData.m_sampler, null);
        //TODO causing GPU crash:
        // message: vkFreeDescriptorSets(): descriptorPool was created with
        // VkDescriptorPoolCreateFl ags(0) (missing FREE_DESCRIPTOR_SET_BIT).
        // The Vulkan spec states: descriptorPool must have been created with
        // the VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT flag
        // (https://vulkan.lunarg.com/doc/view/1.4.309.0/window s/antora/spec/latest/chapters/descriptorsets.html#VUID-vkFreeDescriptorSets-descriptorPoo l-00312)
        //
        //c.ImGui_ImplVulkan_RemoveTexture(vpFrameData.m_descriptorSet);
    }
}

pub fn DrawViewport() !void {
    const window: *c.SDL_Window = try editor.GetMainWindow();
    var winSizeX: c_int = 0;
    var winSizeY: c_int = 0;
    c.SDL_GetWindowSize(window, &winSizeX, &winSizeY);
    c.igSetNextWindowPos(
        c.ImVec2{ .x = editor.leftTrayWidth, .y = editor.topBarHeight },
        c.ImGuiCond_None,
        c.ImVec2{ .x = 0.0, .y = 0.0 },
    );
    c.igSetNextWindowSize(
        c.ImVec2{
            .x = @as(f32, @floatFromInt(winSizeX)) - (editor.leftTrayWidth + editor.rightTrayWidth),
            .y = @as(f32, @floatFromInt(winSizeY)) - (editor.topBarHeight + editor.bottomTrayHeight),
        },
        c.ImGuiCond_None,
    );

    c.igPushStyleColor_Vec4(c.ImGuiCol_WindowBg, c.ImVec4{ .x = 0, .y = 0, .z = 0, .w = 1 });

    if (c.igBegin("Viewport", null, editor.fixedWindowFlags)) {
        const curViewportFrameData = try GetCurrentViewportFrameData();
        var contentRegionSize: c.ImVec2 = undefined;
        c.igGetContentRegionAvail(&contentRegionSize);
        const frameX: f32 = @floatFromInt(curViewportFrameData.m_colorTexture.m_extent.width);
        const frameY: f32 = @floatFromInt(curViewportFrameData.m_colorTexture.m_extent.height);
        const scaleToFitX = contentRegionSize.x / frameX;
        const scaleToFitY = contentRegionSize.y / frameY;
        const scaleToFit = @min(scaleToFitX, scaleToFitY);
        const imageSize = c.ImVec2{
            .x = frameX * scaleToFit,
            .y = frameY * scaleToFit,
        };

        // Add padding to start of horizontal or vertical
        if (scaleToFitX < scaleToFitY) {
            const yPadding = contentRegionSize.y - imageSize.y;
            c.igSetCursorPosY(c.igGetCursorPosY() + yPadding * 0.5);
        } else if (scaleToFitY < scaleToFitX) {
            const xPadding = contentRegionSize.x - imageSize.x;
            c.igSetCursorPosX(c.igGetCursorPosX() + xPadding * 0.5);
        }

        // Draw scene texture
        c.igImage(
            curViewportFrameData.GetId(),
            imageSize,
            c.ImVec2{ .x = 0.0, .y = 0.0 },
            c.ImVec2{ .x = 1.0, .y = 1.0 },
        );
    }

    c.igEnd();

    c.igPopStyleColor(1);
}

pub fn GetCurrentViewportFrameData() !*ViewportFrameData {
    const rContext = try RenderContext.GetInstance();
    return &viewportFrameData.items[rContext.m_currentFrame];
}

pub fn CopyImageToViewport(
    cmd: c.VkCommandBuffer,
    srcImage: c.VkImage,
    srcLayout: c.VkImageLayout,
) !void {
    const rContext = try RenderContext.GetInstance();
    const currentFrameData = &viewportFrameData.items[rContext.m_currentFrame];

    // Steps:
    // 1. transition both images to transfer_src/dst format
    // 2. perform copy
    // 3. transition images to ???

    //TODO make transition image layout util somewhere
    TransitionImageLayout(
        cmd,
        srcImage,
        srcLayout,
        c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
    );

    TransitionImageLayout(
        cmd,
        currentFrameData.m_colorTexture.m_image,
        c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
    );

    // Actual copy step
    c.vkCmdCopyImage(
        cmd,
        srcImage,
        c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        currentFrameData.m_colorTexture.m_image,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        1,
        &c.VkImageCopy{
            .srcOffset = c.VkOffset3D{ .x = 0, .y = 0, .z = 0 },
            .dstOffset = c.VkOffset3D{ .x = 0, .y = 0, .z = 0 },
            .srcSubresource = c.VkImageSubresourceLayers{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseArrayLayer = 0,
                .layerCount = 1,
                .mipLevel = 0,
            },
            .dstSubresource = c.VkImageSubresourceLayers{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseArrayLayer = 0,
                .layerCount = 1,
                .mipLevel = 0,
            },
            .extent = c.VkExtent3D{
                .width = rContext.m_swapchain.m_extent.width,
                .height = rContext.m_swapchain.m_extent.height,
                .depth = 1,
            },
        },
    );

    // Transition SRC and DST back
    TransitionImageLayout(
        cmd,
        srcImage,
        c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        srcLayout,
    );

    TransitionImageLayout(
        cmd,
        currentFrameData.m_colorTexture.m_image,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    );
}

//TODO we should have a nice robust way of doing this in a central location
fn TransitionImageLayout(
    cmd: c.VkCommandBuffer,
    image: c.VkImage,
    oldLayout: c.VkImageLayout,
    newLayout: c.VkImageLayout,
) void {
    const imageBarrier = c.VkImageMemoryBarrier2{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
        .srcStageMask = c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstStageMask = c.VK_PIPELINE_STAGE_2_TRANSFER_BIT,
        .srcAccessMask = 0,
        .dstAccessMask = c.VK_ACCESS_TRANSFER_READ_BIT,
        .oldLayout = oldLayout,
        .newLayout = newLayout,
        .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresourceRange = c.VkImageSubresourceRange{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseArrayLayer = 0,
            .layerCount = 1,
            .baseMipLevel = 0,
            .levelCount = 1,
        },
        .pNext = null,
    };

    //TODO double check _BITs used here against the spec
    c.vkCmdPipelineBarrier2(
        cmd,
        &c.VkDependencyInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEPENDENCY_INFO,
            .imageMemoryBarrierCount = 1,
            .pImageMemoryBarriers = &imageBarrier,
        },
    );
}
