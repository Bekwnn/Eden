const c = @import("../c.zig");
const vk = @import("VulkanInit.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const SwapchainError = error{
    FailedToCreateSwapchain,
    FailedToGetImages,
    FailedToCreateFrameBuffers,
    NoAvailablePresentMode,
    NoAvailableSwapSurfaceFormat,
};

pub const Swapchain = struct {
    m_swapchain: c.VkSwapchainKHR,
    m_imageCount: u32,
    m_images: []c.VkImage,
    m_format: c.VkSurfaceFormatKHR,
    m_extent: c.VkExtent2D,
    m_imageViews: []c.VkImageView,
    m_frameBuffers: []c.VkFramebuffer,
    m_currentImageIndex: u32,
    m_depthImage: vk.GraphicsImage,
    m_colorImage: vk.GraphicsImage,

    pub fn CreateSwapchain(
        allocator: Allocator,
        logicalDevice: c.VkDevice,
        physicalDevice: c.VkPhysicalDevice,
        surface: c.VkSurfaceKHR,
        graphicsQueueIndex: u32,
        presentQueueIndex: u32,
    ) !Swapchain {
        const swapchainSupport = try vk.QuerySwapchainSupport(
            allocator,
            physicalDevice,
            surface,
        );

        const presentMode: c.VkPresentModeKHR = try ChooseSwapPresentMode(
            swapchainSupport.presentModes,
        );

        var newSwapchain = Swapchain{
            .m_swapchain = undefined,
            .m_imageCount = swapchainSupport.capabilities.minImageCount + 1,
            .m_images = undefined,
            .m_format = try ChooseSwapSurfaceFormat(swapchainSupport.formats),
            .m_extent = ChooseSwapExtent(swapchainSupport.capabilities),
            .m_imageViews = undefined,
            .m_frameBuffers = undefined,
            .m_currentImageIndex = 0,
            .m_depthImage = undefined,
            .m_colorImage = undefined,
        };

        // ensure we're within max image count
        if (swapchainSupport.capabilities.maxImageCount > 0 and
            newSwapchain.m_imageCount > swapchainSupport.capabilities.maxImageCount)
        {
            newSwapchain.m_imageCount = swapchainSupport.capabilities.maxImageCount;
        }

        const queueFamilyIndices = [_]u32{
            graphicsQueueIndex,
            presentQueueIndex,
        };
        const queuesAreConcurrent = queueFamilyIndices[0] != queueFamilyIndices[1];
        const createInfo = c.VkSwapchainCreateInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = surface,
            .minImageCount = newSwapchain.m_imageCount,
            .imageFormat = newSwapchain.m_format.format,
            .imageColorSpace = newSwapchain.m_format.colorSpace,
            .imageExtent = newSwapchain.m_extent,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = if (queuesAreConcurrent) c.VK_SHARING_MODE_CONCURRENT else c.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = if (queuesAreConcurrent) 2 else 0,
            .pQueueFamilyIndices = if (queuesAreConcurrent) &queueFamilyIndices else null,
            .preTransform = swapchainSupport.capabilities.currentTransform,
            .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = presentMode,
            .clipped = c.VK_TRUE,
            .oldSwapchain = null, //TODO check the sanity of this
            .pNext = null,
            .flags = 0,
        };

        try vk.CheckVkSuccess(
            c.vkCreateSwapchainKHR(
                logicalDevice,
                &createInfo,
                null,
                &newSwapchain.m_swapchain,
            ),
            SwapchainError.FailedToCreateSwapchain,
        );

        try vk.CheckVkSuccess(
            c.vkGetSwapchainImagesKHR(
                logicalDevice,
                newSwapchain.m_swapchain,
                &newSwapchain.m_imageCount,
                null,
            ),
            SwapchainError.FailedToGetImages,
        );

        newSwapchain.m_images = try allocator.alloc(c.VkImage, newSwapchain.m_imageCount);
        try vk.CheckVkSuccess(
            c.vkGetSwapchainImagesKHR(
                logicalDevice,
                newSwapchain.m_swapchain,
                &newSwapchain.m_imageCount,
                &newSwapchain.m_images[0],
            ),
            SwapchainError.FailedToGetImages,
        );

        //CREATE IMAGE VIEWS START
        newSwapchain.m_imageViews = try allocator.alloc(
            c.VkImageView,
            newSwapchain.m_images.len,
        );
        var i: u32 = 0;
        while (i < newSwapchain.m_images.len) : (i += 1) {
            newSwapchain.m_imageViews[i] = try vk.CreateImageView(
                newSwapchain.m_images[i],
                newSwapchain.m_format.format,
                c.VK_IMAGE_ASPECT_COLOR_BIT,
                1,
            );
        }

        return newSwapchain;
    }

    pub fn CreateColorAndDepthResources(self: *Swapchain, msaaSamples: c.VkSampleCountFlagBits) !void {
        //CREATE DEPTH RESOURCES START
        const depthFormat = try vk.FindDepthFormat();
        try vk.CreateImage(
            self.m_extent.width,
            self.m_extent.height,
            1,
            msaaSamples,
            depthFormat,
            c.VK_IMAGE_TILING_OPTIMAL,
            c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.m_depthImage.vkImage,
            &self.m_depthImage.vkMemory,
        );
        self.m_depthImage.vkView = try vk.CreateImageView(
            self.m_depthImage.vkImage,
            depthFormat,
            c.VK_IMAGE_ASPECT_DEPTH_BIT,
            1,
        );
        try vk.TransitionImageLayout(
            self.m_depthImage.vkImage,
            depthFormat,
            c.VK_IMAGE_LAYOUT_UNDEFINED,
            c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            1,
        );

        //CREATE COLOR RESOURCES START
        const colorFormat = self.m_format.format;

        try vk.CreateImage(
            self.m_extent.width,
            self.m_extent.height,
            1,
            msaaSamples,
            colorFormat,
            c.VK_IMAGE_TILING_OPTIMAL,
            c.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT |
                c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.m_colorImage.vkImage,
            &self.m_colorImage.vkMemory,
        );
        self.m_colorImage.vkView = try vk.CreateImageView(
            self.m_colorImage.vkImage,
            colorFormat,
            c.VK_IMAGE_ASPECT_COLOR_BIT,
            1,
        );
    }

    pub fn CreateFrameBuffers(self: *Swapchain, allocator: Allocator, logicalDevice: c.VkDevice, renderPass: c.VkRenderPass) !void {
        //CREATE FRAMEBUFFERS START
        self.m_frameBuffers = try allocator.alloc(
            c.VkFramebuffer,
            self.m_imageViews.len,
        );
        var i: usize = 0;
        while (i < self.m_imageViews.len) : (i += 1) {
            var attachments = [_]c.VkImageView{
                self.m_colorImage.vkView,
                self.m_depthImage.vkView,
                self.m_imageViews[i],
            };

            const framebufferInfo = c.VkFramebufferCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .renderPass = renderPass,
                .attachmentCount = attachments.len,
                .pAttachments = &attachments,
                .width = self.m_extent.width,
                .height = self.m_extent.height,
                .layers = 1,
                .flags = 0,
                .pNext = null,
            };

            try vk.CheckVkSuccess(
                c.vkCreateFramebuffer(
                    logicalDevice,
                    &framebufferInfo,
                    null,
                    &self.m_frameBuffers[i],
                ),
                SwapchainError.FailedToCreateFrameBuffers,
            );
        }
    }

    pub fn FreeSwapchain(self: *Swapchain, logicalDevice: c.VkDevice) void {
        defer c.vkDestroySwapchainKHR(logicalDevice, self.m_swapchain, null);
        defer {
            for (self.m_imageViews) |imageView| {
                c.vkDestroyImageView(logicalDevice, imageView, null);
            }
        }
        defer {
            for (self.m_frameBuffers) |frameBuffer| {
                c.vkDestroyFramebuffer(logicalDevice, frameBuffer, null);
            }
        }
        defer {
            c.vkDestroyImageView(logicalDevice, self.m_depthImage.vkView, null);
            c.vkDestroyImage(logicalDevice, self.m_depthImage.vkImage, null);
            c.vkFreeMemory(logicalDevice, self.m_depthImage.vkMemory, null);
        }

        defer {
            c.vkDestroyImage(logicalDevice, self.m_colorImage.vkImage, null);
            c.vkFreeMemory(logicalDevice, self.m_colorImage.vkMemory, null);
            c.vkDestroyImageView(logicalDevice, self.m_colorImage.vkView, null);
        }
    }
};

fn ChooseSwapPresentMode(availablePresentModes: []c.VkPresentModeKHR) !c.VkPresentModeKHR {
    for (availablePresentModes) |presentMode| {
        if (presentMode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
            return presentMode;
        }
    }

    if (availablePresentModes.len == 0) {
        return SwapchainError.NoAvailablePresentMode;
    }

    return availablePresentModes[0];
}

fn ChooseSwapSurfaceFormat(availableFormats: []c.VkSurfaceFormatKHR) !c.VkSurfaceFormatKHR {
    for (availableFormats) |format| {
        if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and
            format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
        {
            return format;
        }
    }

    if (availableFormats.len == 0) {
        return SwapchainError.NoAvailableSwapSurfaceFormat;
    }

    return availableFormats[0];
}

//TODO don't hardcode these
const INITIAL_WIDTH = 1280;
const INITIAL_HEIGHT = 720;
fn ChooseSwapExtent(capabilities: c.VkSurfaceCapabilitiesKHR) c.VkExtent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    } else {
        return c.VkExtent2D{
            .width = std.math.clamp(
                INITIAL_WIDTH,
                capabilities.minImageExtent.width,
                capabilities.maxImageExtent.width,
            ),
            .height = std.math.clamp(
                INITIAL_HEIGHT,
                capabilities.minImageExtent.height,
                capabilities.maxImageExtent.height,
            ),
        };
    }
}