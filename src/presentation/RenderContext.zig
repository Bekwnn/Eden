const c = @import("../c.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const vk = @import("VulkanInit.zig");

const swapchain = @import("Swapchain.zig");
const Swapchain = swapchain.Swapchain;

var instance: ?RenderContext = null;

const engineName = "Eden";
const engineVersion = c.VK_MAKE_API_VERSION(0, 0, 1, 0);

pub const RenderContextError = error{
    AlreadyInitialized,
    FailedToCheckInstanceLayerProperties,
    FailedToCreateInstance,
    FailedToCreateLogicDevice,
    FailedToCreateRenderPass,
    FailedToCreateSurface,
    FailedToFindPhysicalDevice,
    FailedToWait,
    MissingValidationLayer,

    // device with vulkan support detected; does not satisfy properties
    NoSuitableDevice,

    // no device supporting vulkan detected
    NoSupportedDevice,

    NotInitialized,
};

pub const RenderContext = struct {
    m_vkInstance: c.VkInstance,
    m_surface: c.VkSurfaceKHR,
    m_physicalDevice: c.VkPhysicalDevice,
    m_logicalDevice: c.VkDevice,
    //m_debugCallback: c.VkDebugReportCallbackEXT,

    m_swapchain: Swapchain,
    m_renderPass: c.VkRenderPass,

    m_graphicsQueueIdx: ?u32,
    m_graphicsQueue: c.VkQueue,
    m_presentQueueIdx: ?u32,
    m_presentQueue: c.VkQueue,

    m_msaaSamples: c.VkSampleCountFlagBits = c.VK_SAMPLE_COUNT_1_BIT,

    pub fn GetInstance() !*RenderContext {
        if (instance != null) {
            return &instance.?;
        } else {
            return RenderContextError.NotInitialized;
        }
    }

    pub fn Initialize(
        allocator: Allocator,
        window: *c.SDL_Window,
        applicationName: []const u8,
        applicationVersion: u32,
    ) !void {
        if (instance != null) return RenderContextError.AlreadyInitialized;

        instance = RenderContext{
            .m_vkInstance = undefined,
            .m_surface = undefined,
            .m_physicalDevice = undefined,
            .m_logicalDevice = undefined,
            //.m_debugCallback = undefined,

            .m_swapchain = undefined,

            .m_graphicsQueueIdx = null,
            .m_graphicsQueue = undefined,
            .m_presentQueueIdx = null,
            .m_presentQueue = undefined,
        };

        try CreateVkInstance(
            allocator,
            window,
            applicationName,
            applicationVersion,
        );

        try CreateSurface(window);

        try PickPhysicalDevice(allocator, window);

        try CreateLogicalDevice(allocator);

        //TODO move all swapchain initialization to Swapchain.zig
        if (instance.m_graphicsQueueIdx == null or
            instance.m_presentQueueIdx == null)
        {
            return RenderContextError.NotInitialized;
        }
        instance.m_swapchain = try Swapchain.CreateSwapchain(
            allocator,
            instance.m_logicalDevice,
            instance.m_physicalDevice,
            instance.m_surface,
            instance.m_graphicsQueueIdx.?,
            instance.m_presentQueueIdx.?,
        );

        try instance.m_swapchain.CreateColorAndDepthResources(
            instance.m_logicalDevice,
            instance.m_msaaSamples,
        );

        try instance.m_swapchain.CreateFrameBuffers(
            allocator,
            instance.m_logicalDevice,
            instance.m_renderPass,
        );
    }

    pub fn Shutdown() void {
        if (instance != null) {
            instance.DestroySwapchain();
            c.vkDestroyDevice(instance.?.m_logicalDevice, null);
            c.vkDestroySurfaceKHR(
                instance.?.m_vkInstance,
                instance.?.m_surface,
                null,
            );
            // if (enableValidationLayers) destroy debug utils messenger
            c.vkDestroyInstance(instance.?.m_vkInstance, null);
            instance = null;
        }
    }

    pub fn RecreateSwapchain(allocator: Allocator) !void {
        const rContext = try RenderContext.GetInstance();
        try vk.CheckVkSuccess(
            c.vkDeviceWaitIdle(rContext.m_logicalDevice),
            RenderContextError.FailedToWait,
        );

        std.debug.print("Recreating Swapchain...\n", .{});
        rContext.DestroySwapchain();

        try Swapchain.CreateSwapchain(allocator, rContext);
        try CreateRenderPass();
        try swapchain.CreateColorAndDepthResources(
            rContext.m_logicalDevice,
            rContext.m_msaaSamples,
        );
        try swapchain.CreateFrameBuffers(
            allocator,
            rContext.m_logicalDevice,
            renderPass,
        );
        try CreateCommandBuffers(allocator);
    }

    pub fn DestroySwapchain(self: *RenderContext) void {
        const rContext = RenderContext.GetInstance() catch @panic("!");

        defer {
            for (uniformBuffers) |*uniformBuffer| {
                uniformBuffer.DestroyBuffer(rContext.m_logicalDevice);
            }
            c.vkDestroyDescriptorPool(
                rContext.m_logicalDevice,
                descriptorPool,
                null,
            );
        }

        defer swapchain.FreeSwapchain(rContext.m_logicalDevice);

        defer c.vkDestroyRenderPass(rContext.m_logicalDevice, renderPass, null);
        defer c.vkDestroyPipelineLayout(
            rContext.m_logicalDevice,
            pipelineLayout,
            null,
        );
        defer c.vkDestroyPipeline(rContext.m_logicalDevice, graphicsPipeline, null);

        defer swapchain.CleanupFrameBuffers(rContext.m_logicalDevice);

        defer c.vkFreeCommandBuffers(
            rContext.m_logicalDevice,
            commandPool,
            @intCast(u32, commandBuffers.len),
            commandBuffers.ptr,
        );

        defer swapchain.CleanupDepthAndColorImages(rContext.m_logicalDevice);
    }
};

const validationLayers = [_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};
fn CheckValidationLayerSupport(allocator: Allocator) !void {
    var layerCount: u32 = 0;
    try vk.CheckVkSuccess(
        c.vkEnumerateInstanceLayerProperties(&layerCount, null),
        RenderContextError.FailedToCheckInstanceLayerProperties,
    );

    var detectedLayerProperties = try allocator.alloc(c.VkLayerProperties, layerCount);
    try vk.CheckVkSuccess(
        c.vkEnumerateInstanceLayerProperties(&layerCount, detectedLayerProperties.ptr),
        RenderContextError.FailedToCheckInstanceLayerProperties,
    );

    for (validationLayers) |validationLayer| {
        var layerFound = false;

        for (detectedLayerProperties) |detectedLayer| {
            if (std.mem.startsWith(u8, std.mem.span(&detectedLayer.layerName), std.mem.span(validationLayer))) {
                layerFound = true;
                break;
            }
        }

        if (!layerFound) {
            std.debug.print("Unable to find validation layer \"{s}\"\n", .{validationLayer});
            std.debug.print("Layers found:\n", .{});
            for (detectedLayerProperties) |detectedLayer| {
                var trailingWhitespaceStripped = std.mem.tokenize(u8, std.mem.span(&detectedLayer.layerName), " ");
                std.debug.print("\"{s}\"\n", .{trailingWhitespaceStripped.next().?});
            }
            return RenderContextError.MissingValidationLayer;
        }
    }
}

fn CreateSurface(window: *c.SDL_Window) !void {
    const rContext = try RenderContext.GetInstance();
    const result = c.SDL_Vulkan_CreateSurface(window, rContext.m_vkInstance, &rContext.m_surface);
    if (result != c.SDL_TRUE) {
        return RenderContextError.FailedToCreateSurface;
    }
}

fn CreateVkInstance(
    allocator: Allocator,
    window: *c.SDL_Window,
    applicationName: []const u8,
    applicationVersion: u32,
) !void {
    const appInfo = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = &applicationName[0],
        .applicationVersion = applicationVersion,
        .pEngineName = engineName,
        .engineVersion = engineVersion,
        .apiVersion = c.VK_API_VERSION_1_0,
        .pNext = null,
    };

    //TODO handle return values
    var extensionCount: c_uint = 0;
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, null);
    var extensionNames = try allocator.alloc([*]const u8, extensionCount);
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, @ptrCast([*c][*c]const u8, extensionNames.ptr));

    try CheckValidationLayerSupport(allocator);
    const instanceInfo = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledLayerCount = @intCast(u32, validationLayers.len),
        .ppEnabledLayerNames = &validationLayers,
        .enabledExtensionCount = @intCast(u32, extensionNames.len),
        .ppEnabledExtensionNames = extensionNames.ptr,
        .pNext = null,
        .flags = 0,
    };

    const rContext = try RenderContext.GetInstance();
    try vk.CheckVkSuccess(
        c.vkCreateInstance(&instanceInfo, null, &rContext.m_vkInstance),
        RenderContextError.FailedToCreateInstance,
    );
}

fn PickPhysicalDevice(allocator: Allocator, window: *c.SDL_Window) !void {
    const rContext = try RenderContext.GetInstance();
    var deviceCount: u32 = 0;
    try vk.CheckVkSuccess(
        c.vkEnumeratePhysicalDevices(rContext.m_vkInstance, &deviceCount, null),
        RenderContextError.FailedToFindPhysicalDevice,
    );
    if (deviceCount == 0) {
        return RenderContextError.NoSupportedDevice; //no vulkan supporting devices
    }

    var deviceList = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
    try vk.CheckVkSuccess(
        c.vkEnumeratePhysicalDevices(rContext.m_vkInstance, &deviceCount, deviceList.ptr),
        RenderContextError.FailedToFindPhysicalDevice,
    );

    //TODO rather than just picking first suitable device, could rate/score by some scheme and pick the best
    for (deviceList) |device| {
        if (try PhysicalDeviceIsSuitable(allocator, device, window, rContext.m_surface)) {
            rContext.m_physicalDevice = device;
            rContext.m_msaaSamples = try GetMaxUsableSampleCount();
            return;
        }
    }

    return RenderContextError.NoSuitableDevice;
}

// Currently just checks if geometry shaders are supported and if the device supports VK_QUEUE_GRAPHICS_BIT
// Mostly a proof-of-concept function; could ensure device support exists for more advanced stuff later
const requiredExtensions = [_][*]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};
fn PhysicalDeviceIsSuitable(allocator: Allocator, device: c.VkPhysicalDevice, window: *c.SDL_Window, surface: c.VkSurfaceKHR) !bool {
    //TODO should take in surface and check if presentation is supported (vkGetPhysicalDeviceSurfaceSupportKHR())
    var deviceProperties: c.VkPhysicalDeviceProperties = undefined;
    c.vkGetPhysicalDeviceProperties(device, &deviceProperties);

    var deviceFeatures: c.VkPhysicalDeviceFeatures = undefined;
    c.vkGetPhysicalDeviceFeatures(device, &deviceFeatures);

    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

    var queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

    var graphicsSupportExists = false;
    var i: usize = 0;
    while (i < queueFamilyCount) : (i += 1) {
        if (queueFamilies[i].queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
            graphicsSupportExists = true;
        }
    }

    //TODO ensure we hve all required extensions, compare the extensions we got to check all requiredExtensions exist
    //TODO handle return values
    var extensionCount: c_uint = 0;
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, null);
    var extensionNames = try allocator.alloc([*]const u8, extensionCount);
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, @ptrCast([*c][*c]const u8, extensionNames.ptr));

    const swapchainSupport = try swapchain.QuerySwapchainSupport(
        allocator,
        device,
        surface,
    );
    const swapchainSupported =
        swapchainSupport.formats.len != 0 and
        swapchainSupport.presentModes.len != 0;

    // We don't need any special features really...
    // For now, just test it supports geometry shaders as a sort of test/placeholder?
    return swapchainSupported and
        graphicsSupportExists and
        deviceFeatures.geometryShader == c.VK_TRUE and
        deviceFeatures.samplerAnisotropy == c.VK_TRUE;
}

const basicQueuePriority: f32 = 1.0; //TODO real queue priorities
fn CreateLogicalDevice(allocator: Allocator) !void {
    const rContext = try RenderContext.GetInstance();
    //TODO just copying device features that we found on the selected physical
    //device--in the future it should just have features we're actually using
    var deviceFeatures: c.VkPhysicalDeviceFeatures = undefined;
    c.vkGetPhysicalDeviceFeatures(rContext.m_physicalDevice, &deviceFeatures);

    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(
        rContext.m_physicalDevice,
        &queueFamilyCount,
        null,
    );
    var queueFamilies = try allocator.alloc(
        c.VkQueueFamilyProperties,
        queueFamilyCount,
    );
    c.vkGetPhysicalDeviceQueueFamilyProperties(
        rContext.m_physicalDevice,
        &queueFamilyCount,
        queueFamilies.ptr,
    );

    var graphicsQueueIndex: ?u32 = null;
    var presentQueueIndex: ?u32 = null;
    var i: u32 = 0;
    while (i < queueFamilyCount) : (i += 1) {
        if (graphicsQueueIndex == null) {
            if ((queueFamilies[i].queueFlags & c.VK_QUEUE_GRAPHICS_BIT) != 0) {
                graphicsQueueIndex = i;
            }
        }
        if (presentQueueIndex == null) {
            var presentationSupport: c.VkBool32 = c.VK_FALSE;
            try vk.CheckVkSuccess(
                c.vkGetPhysicalDeviceSurfaceSupportKHR(
                    rContext.m_physicalDevice,
                    i,
                    rContext.m_surface,
                    &presentationSupport,
                ),
                RenderContextError.FailedToFindPhysicalDevice,
            );
            if (presentationSupport == c.VK_TRUE) {
                presentQueueIndex = i;
            }
        }
    }

    if (graphicsQueueIndex == null or presentQueueIndex == null) {
        return RenderContextError.FailedToCreateLogicDevice;
    }

    rContext.m_graphicsQueueIdx = graphicsQueueIndex;
    rContext.m_presentQueueIdx = presentQueueIndex;

    //TODO make handling of duplicate queues cleaner
    const numUniqueQueues: u32 = if (graphicsQueueIndex.? == presentQueueIndex.?) 1 else 2;
    var queueCreateInfos = try allocator.alloc(c.VkDeviceQueueCreateInfo, numUniqueQueues);
    // graphics queue
    queueCreateInfos[0] = c.VkDeviceQueueCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = graphicsQueueIndex orelse
            return RenderContextError.FailedToCreateLogicDevice,
        .queueCount = 1,
        .pQueuePriorities = &basicQueuePriority,
        .flags = 0,
        .pNext = null,
    };
    if (numUniqueQueues == 2) {
        // presentation queue
        queueCreateInfos[1] = c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = presentQueueIndex orelse
                return RenderContextError.FailedToCreateLogicDevice,
            .queueCount = 1,
            .pQueuePriorities = &basicQueuePriority,
            .flags = 0,
            .pNext = null,
        };
    }

    // we should have verified earlier that requiredExtensions are all supported by this point
    const deviceCreateInfo = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = numUniqueQueues,
        .pQueueCreateInfos = queueCreateInfos.ptr,
        .pEnabledFeatures = &deviceFeatures,
        .enabledExtensionCount = requiredExtensions.len,
        .ppEnabledExtensionNames = &requiredExtensions,
        .enabledLayerCount = validationLayers.len,
        .ppEnabledLayerNames = &validationLayers,
        .flags = 0,
        .pNext = null,
    };

    try vk.CheckVkSuccess(
        c.vkCreateDevice(rContext.m_physicalDevice, &deviceCreateInfo, null, &rContext.m_logicalDevice),
        RenderContextError.FailedToCreateLogicDevice,
    );

    if (rContext.m_logicalDevice) |*ld| {
        c.vkGetDeviceQueue(ld.*, graphicsQueueIndex orelse return RenderContextError.FailedToCreateLogicDevice, 0, &rContext.m_graphicsQueue);
        c.vkGetDeviceQueue(ld.*, presentQueueIndex orelse return RenderContextError.FailedToCreateLogicDevice, 0, &rContext.m_presentQueue);
    }
}

fn GetMaxUsableSampleCount() !c.VkSampleCountFlagBits {
    const rContext = try RenderContext.GetInstance();
    var deviceProperties: c.VkPhysicalDeviceProperties = undefined;
    c.vkGetPhysicalDeviceProperties(rContext.m_physicalDevice, &deviceProperties);

    const counts = deviceProperties.limits.framebufferColorSampleCounts & deviceProperties.limits.framebufferDepthSampleCounts;
    if (counts & c.VK_SAMPLE_COUNT_64_BIT != 0) {
        std.debug.print("MSAA detected: SAMPLE_COUNT_64_BIT\n", .{});
        return c.VK_SAMPLE_COUNT_64_BIT;
    }
    if (counts & c.VK_SAMPLE_COUNT_32_BIT != 0) {
        std.debug.print("MSAA detected: SAMPLE_COUNT_32_BIT\n", .{});
        return c.VK_SAMPLE_COUNT_32_BIT;
    }
    if (counts & c.VK_SAMPLE_COUNT_16_BIT != 0) {
        std.debug.print("MSAA detected: SAMPLE_COUNT_16_BIT\n", .{});
        return c.VK_SAMPLE_COUNT_16_BIT;
    }
    if (counts & c.VK_SAMPLE_COUNT_8_BIT != 0) {
        std.debug.print("MSAA detected: SAMPLE_COUNT_8_BIT\n", .{});
        return c.VK_SAMPLE_COUNT_8_BIT;
    }
    if (counts & c.VK_SAMPLE_COUNT_4_BIT != 0) {
        std.debug.print("MSAA detected: SAMPLE_COUNT_4_BIT\n", .{});
        return c.VK_SAMPLE_COUNT_4_BIT;
    }
    if (counts & c.VK_SAMPLE_COUNT_2_BIT != 0) {
        std.debug.print("MSAA detected: SAMPLE_COUNT_2_BIT\n", .{});
        return c.VK_SAMPLE_COUNT_2_BIT;
    }

    std.debug.print("MSAA detected: SAMPLE_COUNT_1_BIT\n", .{});
    return c.VK_SAMPLE_COUNT_1_BIT;
}

fn CreateRenderPass() !void {
    const rContext = try RenderContext.GetInstance();
    const colorAttachment = c.VkAttachmentDescription{
        .format = swapchain.m_format.format,
        .samples = rContext.m_msaaSamples,
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
        .samples = rContext.m_msaaSamples,
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

    try vk.CheckVkSuccess(
        c.vkCreateRenderPass(rContext.m_logicalDevice, &renderPassInfo, null, &renderPass),
        RenderContextError.FailedToCreateRenderPass,
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
    const rContext = try RenderContext.GetInstance();
    for (candidates) |format| {
        var properties: c.VkFormatProperties = undefined;
        c.vkGetPhysicalDeviceFormatProperties(rContext.m_physicalDevice, format, &properties);
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
