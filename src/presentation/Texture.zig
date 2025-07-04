//manages a texture asset for vulkan
const std = @import("std");

const c = @import("../c.zig");
const imageFileUtil = @import("../coreutil/ImageFileUtil.zig");
const Buffer = @import("Buffer.zig").Buffer;
const RenderContext = @import("RenderContext.zig").RenderContext;
const vkUtil = @import("VulkanUtil.zig");

pub const TextureError = error{
    BadMipmapFormat,
    FailedToAllocateMemory,
    FailedToBindMemory,
    FailedToCreateImage,
    FailedToCreateImageView,
    FailedToCreateSampler,
    FailedToMapMemory,
};

//TODO should it be renamed to something else?
pub const Texture = struct {
    m_name: []const u8,
    m_image: c.VkImage,
    m_memory: c.VkDeviceMemory,
    m_imageView: c.VkImageView,
    m_mipLevels: u32,

    pub fn CreateTexture(
        name: []const u8,
        imagePath: []const u8,
    ) !Texture {
        const rContext = try RenderContext.GetInstance();

        std.debug.print("Loading Image {s} ...\n", .{imagePath});
        var image = try imageFileUtil.LoadImage(imagePath);
        defer image.FreeImage();

        var newTexture: Texture = undefined;
        newTexture.m_name = name;

        newTexture.m_mipLevels = CalcTextureMipLevels(image.m_width, image.m_height);
        const imageSize: c.VkDeviceSize = image.m_width * image.m_height * 4;
        var stagingBuffer = try Buffer.CreateBuffer(
            imageSize,
            c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
        defer stagingBuffer.DestroyBuffer(rContext.m_logicalDevice);

        var data: [*]u8 = undefined;
        try vkUtil.CheckVkSuccess(
            c.vkMapMemory(rContext.m_logicalDevice, stagingBuffer.m_memory, 0, imageSize, 0, @ptrCast(&data)),
            TextureError.FailedToMapMemory,
        );

        @memcpy(
            @as([*]u8, @ptrCast(data))[0..imageSize],
            @as([*]const u8, @ptrCast(image.m_imageData))[0..imageSize],
        );
        c.vkUnmapMemory(rContext.m_logicalDevice, stagingBuffer.m_memory);

        try CreateImage(
            rContext.m_logicalDevice,
            image.m_width,
            image.m_height,
            newTexture.m_mipLevels,
            c.VK_SAMPLE_COUNT_1_BIT,
            c.VK_FORMAT_R8G8B8A8_SRGB,
            c.VK_IMAGE_TILING_OPTIMAL,
            c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT | c.VK_IMAGE_USAGE_SAMPLED_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &newTexture.m_image,
            &newTexture.m_memory,
        );

        try vkUtil.TransitionImageLayout(
            newTexture.m_image,
            c.VK_FORMAT_R8G8B8A8_SRGB,
            c.VK_IMAGE_LAYOUT_UNDEFINED,
            c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            null,
        );
        try CopyBufferToImage(stagingBuffer.m_buffer, newTexture.m_image, image.m_width, image.m_height);
        //transitioned to VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL while generating mipmaps
        try GenerateMipmaps(
            rContext.m_physicalDevice,
            newTexture.m_image,
            c.VK_FORMAT_R8G8B8A8_SRGB,
            image.m_width,
            image.m_height,
            newTexture.m_mipLevels,
        );

        newTexture.m_imageView = try CreateImageView(
            newTexture.m_image,
            c.VK_FORMAT_R8G8B8A8_SRGB,
            c.VK_IMAGE_ASPECT_COLOR_BIT,
            newTexture.m_mipLevels,
        );

        return newTexture;
    }

    pub fn CreateDepthImage(
        logicalDevice: c.VkDevice,
        width: u32,
        height: u32,
        msaaSamples: c.VkSampleCountFlagBits,
        depthFormat: c.VkFormat,
    ) !Texture {
        var depthTexture: Texture = undefined;
        try CreateImage(
            logicalDevice,
            width,
            height,
            1,
            msaaSamples,
            depthFormat,
            c.VK_IMAGE_TILING_OPTIMAL,
            c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &depthTexture.m_image,
            &depthTexture.m_memory,
        );
        depthTexture.m_imageView = try CreateImageView(
            depthTexture.m_image,
            depthFormat,
            c.VK_IMAGE_ASPECT_DEPTH_BIT,
            1,
        );
        try vkUtil.TransitionImageLayout(
            depthTexture.m_image,
            depthFormat,
            c.VK_IMAGE_LAYOUT_UNDEFINED,
            c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            null,
        );
        return depthTexture;
    }

    pub fn CreateColorImage(
        logicalDevice: c.VkDevice,
        width: u32,
        height: u32,
        msaaSamples: c.VkSampleCountFlagBits,
        colorFormat: c.VkFormat,
    ) !Texture {
        var colorTexture: Texture = undefined;
        try CreateImage(
            logicalDevice,
            width,
            height,
            1,
            msaaSamples,
            colorFormat,
            c.VK_IMAGE_TILING_OPTIMAL,
            c.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT |
                c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &colorTexture.m_image,
            &colorTexture.m_memory,
        );
        colorTexture.m_imageView = try CreateImageView(
            colorTexture.m_image,
            colorFormat,
            c.VK_IMAGE_ASPECT_COLOR_BIT,
            1,
        );
        return colorTexture;
    }

    pub fn FreeTexture(self: *Texture, logicalDevice: c.VkDevice) void {
        c.vkDestroyImageView(logicalDevice, self.m_imageView, null);
        c.vkDestroyImage(logicalDevice, self.m_image, null);
        c.vkFreeMemory(logicalDevice, self.m_memory, null);
    }
};

pub fn CreateImage(
    logicalDevice: c.VkDevice,
    width: u32,
    height: u32,
    mipLevels: u32,
    numSamples: c.VkSampleCountFlagBits,
    format: c.VkFormat,
    tiling: c.VkImageTiling,
    usage: c.VkImageUsageFlags,
    properties: c.VkMemoryPropertyFlags,
    image: *c.VkImage,
    imageMemory: *c.VkDeviceMemory,
) !void {
    const imageInfo = c.VkImageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .imageType = c.VK_IMAGE_TYPE_2D,
        .extent = c.VkExtent3D{
            .width = width,
            .height = height,
            .depth = 1,
        },
        .mipLevels = mipLevels,
        .arrayLayers = 1,
        .format = format,
        .tiling = tiling,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .samples = numSamples,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .pNext = null,
        .flags = 0,
    };
    try vkUtil.CheckVkSuccess(
        c.vkCreateImage(logicalDevice, &imageInfo, null, image),
        TextureError.FailedToCreateImage,
    );

    var memRequirements: c.VkMemoryRequirements = undefined;
    c.vkGetImageMemoryRequirements(logicalDevice, image.*, &memRequirements);
    const allocInfo = c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memRequirements.size,
        .memoryTypeIndex = try vkUtil.FindMemoryType(memRequirements.memoryTypeBits, properties),
        .pNext = null,
    };
    try vkUtil.CheckVkSuccess(
        c.vkAllocateMemory(logicalDevice, &allocInfo, null, imageMemory),
        TextureError.FailedToAllocateMemory,
    );

    try vkUtil.CheckVkSuccess(
        c.vkBindImageMemory(logicalDevice, image.*, imageMemory.*, 0),
        TextureError.FailedToBindMemory,
    );
}

fn CalcTextureMipLevels(width: u32, height: u32) u32 {
    return @as(u32, @intFromFloat(@floor(@log2(@as(f32, @floatFromInt(@max(width, height))))))) + 1;
}

//TODO generating mip maps should be done offline; possibly as a build step/function?
// shader compilation and other rendering-baking could join it
fn GenerateMipmaps(
    physicalDevice: c.VkPhysicalDevice,
    image: c.VkImage,
    imageFormat: c.VkFormat,
    imageWidth: u32,
    imageHeight: u32,
    mipLevels: u32,
) !void {
    var formatProperties: c.VkFormatProperties = undefined;
    c.vkGetPhysicalDeviceFormatProperties(physicalDevice, imageFormat, &formatProperties);
    if (formatProperties.optimalTilingFeatures & c.VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT == 0) {
        return TextureError.BadMipmapFormat;
    }

    const commandBuffer = try vkUtil.BeginSingleTimeCommands();

    var barrier = c.VkImageMemoryBarrier{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .image = image,
        .oldLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .newLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .subresourceRange = c.VkImageSubresourceRange{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .srcAccessMask = 0,
        .dstAccessMask = 0,
        .pNext = null,
    };

    var mipWidth = imageWidth;
    var mipHeight = imageHeight;
    var i: u32 = 1;
    while (i < mipLevels) : (i += 1) {
        barrier.subresourceRange.baseMipLevel = i - 1;
        barrier.oldLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        barrier.newLayout = c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
        barrier.srcAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = c.VK_ACCESS_TRANSFER_READ_BIT;

        c.vkCmdPipelineBarrier(
            commandBuffer,
            c.VK_PIPELINE_STAGE_TRANSFER_BIT,
            c.VK_PIPELINE_STAGE_TRANSFER_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &barrier,
        );

        const blit = c.VkImageBlit{
            .srcOffsets = [2]c.VkOffset3D{
                c.VkOffset3D{
                    .x = 0,
                    .y = 0,
                    .z = 0,
                },
                c.VkOffset3D{
                    .x = @intCast(mipWidth),
                    .y = @intCast(mipHeight),
                    .z = 1,
                },
            },
            .dstOffsets = [2]c.VkOffset3D{
                c.VkOffset3D{
                    .x = 0,
                    .y = 0,
                    .z = 0,
                },
                c.VkOffset3D{
                    .x = @intCast(if (mipWidth > 1) mipWidth / 2 else 1),
                    .y = @intCast(if (mipHeight > 1) mipHeight / 2 else 1),
                    .z = 1,
                },
            },
            .srcSubresource = c.VkImageSubresourceLayers{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .mipLevel = i - 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
            .dstSubresource = c.VkImageSubresourceLayers{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .mipLevel = i,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        c.vkCmdBlitImage(
            commandBuffer,
            image,
            c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            image,
            c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &blit,
            c.VK_FILTER_LINEAR,
        );

        barrier.oldLayout = c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
        barrier.newLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        barrier.srcAccessMask = c.VK_ACCESS_TRANSFER_READ_BIT;
        barrier.dstAccessMask = c.VK_ACCESS_SHADER_READ_BIT;

        c.vkCmdPipelineBarrier(
            commandBuffer,
            c.VK_PIPELINE_STAGE_TRANSFER_BIT,
            c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &barrier,
        );

        if (mipWidth > 1) mipWidth /= 2;
        if (mipHeight > 1) mipHeight /= 2;
    }

    barrier.subresourceRange.baseMipLevel = mipLevels - 1;
    barrier.oldLayout = c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier.newLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barrier.srcAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier.dstAccessMask = c.VK_ACCESS_SHADER_READ_BIT;

    c.vkCmdPipelineBarrier(
        commandBuffer,
        c.VK_PIPELINE_STAGE_TRANSFER_BIT,
        c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
        0,
        0,
        null,
        0,
        null,
        1,
        &barrier,
    );

    try vkUtil.EndSingleTimeCommands(commandBuffer);
}

fn CopyBufferToImage(buffer: c.VkBuffer, image: c.VkImage, width: u32, height: u32) !void {
    const commandBuffer = try vkUtil.BeginSingleTimeCommands();

    const region = c.VkBufferImageCopy{
        .bufferOffset = 0,
        .bufferRowLength = 0,
        .bufferImageHeight = 0,
        .imageSubresource = c.VkImageSubresourceLayers{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .mipLevel = 0,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .imageOffset = c.VkOffset3D{
            .x = 0,
            .y = 0,
            .z = 0,
        },
        .imageExtent = c.VkExtent3D{
            .width = width,
            .height = height,
            .depth = 1,
        },
    };
    c.vkCmdCopyBufferToImage(
        commandBuffer,
        buffer,
        image,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        1,
        &region,
    );

    try vkUtil.EndSingleTimeCommands(commandBuffer);
}

pub fn CreateImageView(
    image: c.VkImage,
    format: c.VkFormat,
    aspectFlags: c.VkImageAspectFlags,
    mipLevels: u32,
) !c.VkImageView {
    const rContext = try RenderContext.GetInstance();
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
    try vkUtil.CheckVkSuccess(
        c.vkCreateImageView(rContext.m_logicalDevice, &imageViewInfo, null, &imageView),
        TextureError.FailedToCreateImageView,
    );

    return imageView;
}

pub fn CreateTextureSampler(
    texture: *const Texture,
    textureSampler: *c.VkSampler,
) !void {
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
        .maxLod = @floatFromInt(texture.m_mipLevels),
        .flags = 0,
        .pNext = null,
    };

    const rContext = try RenderContext.GetInstance();
    try vkUtil.CheckVkSuccess(
        c.vkCreateSampler(
            rContext.m_logicalDevice,
            &samplerInfo,
            null,
            &textureSampler,
        ),
        TextureError.FailedToCreateSampler,
    );
}
