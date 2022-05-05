const c = @import("../c.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const vk = @import("VulkanInit.zig");

var instance: ?PresentationInstance = null;

const engineName = "Eden";
const engineVersion = c.VK_MAKE_API_VERSION(0, 0, 1, 0);

pub const PresentationError = error{
    AlreadyInitialized,
    FailedToCheckInstanceLayerProperties,
    FailedToCreateInstance,
    FailedToCreateLogicDevice,
    FailedToCreateSurface,
    FailedToFindPhysicalDevice,
    MissingValidationLayer,
    NoSuitableDevice, // device with vulkan support detected; does not satisfy properties
    NoSupportedDevice, // no device supporting vulkan detected
    NotInitialized,
};

//TODO settle on a shorter, better name
pub const PresentationInstance = struct {
    m_vkInstance: c.VkInstance,
    m_surface: c.VkSurfaceKHR,
    m_physicalDevice: c.VkPhysicalDevice,
    m_logicalDevice: c.VkDevice,
    //m_debugCallback: c.VkDebugReportCallbackEXT,

    m_graphicsQueueIdx: ?u32,
    m_graphicsQueue: c.VkQueue,
    m_presentQueueIdx: ?u32,
    m_presentQueue: c.VkQueue,

    m_msaaSamples: c.VkSampleCountFlagBits = c.VK_SAMPLE_COUNT_1_BIT,

    pub fn GetInstance() !*PresentationInstance {
        if (instance != null) {
            return &instance.?;
        } else {
            return PresentationError.NotInitialized;
        }
    }

    pub fn Initialize(allocator: Allocator, window: *c.SDL_Window, applicationName: []const u8, applicationVersion: u32) !void {
        if (instance != null) return PresentationError.AlreadyInitialized;

        instance = PresentationInstance{
            .m_vkInstance = undefined,
            .m_surface = undefined,
            .m_physicalDevice = undefined,
            .m_logicalDevice = undefined,
            //.m_debugCallback = undefined,
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
    }

    pub fn Shutdown() void {
        defer instance = null;

        const presInstance = PresentationInstance.GetInstance() catch @panic("!");
        defer c.vkDestroyInstance(presInstance.m_vkInstance, null);

        defer c.vkDestroySurfaceKHR(presInstance.m_vkInstance, presInstance.m_surface, null);

        // if (enableValidationLayers) destroy debug utils messenger

        defer c.vkDestroyDevice(presInstance.m_logicalDevice, null);
    }
};

const validationLayers = [_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};
fn CheckValidationLayerSupport(allocator: Allocator) !void {
    var layerCount: u32 = 0;
    try vk.CheckVkSuccess(
        c.vkEnumerateInstanceLayerProperties(&layerCount, null),
        PresentationError.FailedToCheckInstanceLayerProperties,
    );

    var detectedLayerProperties = try allocator.alloc(c.VkLayerProperties, layerCount);
    try vk.CheckVkSuccess(
        c.vkEnumerateInstanceLayerProperties(&layerCount, detectedLayerProperties.ptr),
        PresentationError.FailedToCheckInstanceLayerProperties,
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
            return PresentationError.MissingValidationLayer;
        }
    }
}

fn CreateSurface(window: *c.SDL_Window) !void {
    const presInstance = try PresentationInstance.GetInstance();
    const result = c.SDL_Vulkan_CreateSurface(window, presInstance.m_vkInstance, &presInstance.m_surface);
    if (result != c.SDL_TRUE) {
        return PresentationError.FailedToCreateSurface;
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

    const presInstance = try PresentationInstance.GetInstance();
    try vk.CheckVkSuccess(
        c.vkCreateInstance(&instanceInfo, null, &presInstance.m_vkInstance),
        PresentationError.FailedToCreateInstance,
    );
}

fn PickPhysicalDevice(allocator: Allocator, window: *c.SDL_Window) !void {
    const presInstance = try PresentationInstance.GetInstance();
    var deviceCount: u32 = 0;
    try vk.CheckVkSuccess(
        c.vkEnumeratePhysicalDevices(presInstance.m_vkInstance, &deviceCount, null),
        PresentationError.FailedToFindPhysicalDevice,
    );
    if (deviceCount == 0) {
        return PresentationError.NoSupportedDevice; //no vulkan supporting devices
    }

    var deviceList = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
    try vk.CheckVkSuccess(
        c.vkEnumeratePhysicalDevices(presInstance.m_vkInstance, &deviceCount, deviceList.ptr),
        PresentationError.FailedToFindPhysicalDevice,
    );

    //TODO rather than just picking first suitable device, could rate/score by some scheme and pick the best
    for (deviceList) |device| {
        if (try PhysicalDeviceIsSuitable(allocator, device, window, presInstance.m_surface)) {
            presInstance.m_physicalDevice = device;
            presInstance.m_msaaSamples = try GetMaxUsableSampleCount();
            return;
        }
    }

    return PresentationError.NoSuitableDevice;
}

// Currently just checks if geometry shaders are supported and if the device supports VK_QUEUE_GRAPHICS_BIT
// Mostly a proof-of-concept function; could ensure device support exists for more advanced stuff later
const requiredExtensions = [_][*]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};
fn PhysicalDeviceIsSuitable(allocator: Allocator, device: c.VkPhysicalDevice, window: *c.SDL_Window, s: c.VkSurfaceKHR) !bool {
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

    const swapchainSupport = try vk.QuerySwapchainSupport(allocator, device, s);
    const swapchainSupported = swapchainSupport.formats.len != 0 and swapchainSupport.presentModes.len != 0;

    // We don't need any special features really...
    // For now, just test it supports geometry shaders as a sort of test/placeholder?
    return swapchainSupported and graphicsSupportExists and deviceFeatures.geometryShader == c.VK_TRUE and deviceFeatures.samplerAnisotropy == c.VK_TRUE;
}

const basicQueuePriority: f32 = 1.0; //TODO real queue priorities
fn CreateLogicalDevice(allocator: Allocator) !void {
    const presInstance = try PresentationInstance.GetInstance();
    //TODO just copying device features that we found on the selected physical device,
    //in the future it should just have features we're actually using
    var deviceFeatures: c.VkPhysicalDeviceFeatures = undefined;
    c.vkGetPhysicalDeviceFeatures(presInstance.m_physicalDevice, &deviceFeatures);

    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(presInstance.m_physicalDevice, &queueFamilyCount, null);
    var queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
    c.vkGetPhysicalDeviceQueueFamilyProperties(presInstance.m_physicalDevice, &queueFamilyCount, queueFamilies.ptr);

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
                c.vkGetPhysicalDeviceSurfaceSupportKHR(presInstance.m_physicalDevice, i, presInstance.m_surface, &presentationSupport),
                PresentationError.FailedToFindPhysicalDevice,
            );
            if (presentationSupport == c.VK_TRUE) {
                presentQueueIndex = i;
            }
        }
    }

    if (graphicsQueueIndex == null or presentQueueIndex == null) {
        return PresentationError.FailedToCreateLogicDevice;
    }

    presInstance.m_graphicsQueueIdx = graphicsQueueIndex;
    presInstance.m_presentQueueIdx = presentQueueIndex;

    //TODO make handling of duplicate queues cleaner
    const numUniqueQueues: u32 = if (graphicsQueueIndex.? == presentQueueIndex.?) 1 else 2;
    var queueCreateInfos = try allocator.alloc(c.VkDeviceQueueCreateInfo, numUniqueQueues);
    // graphics queue
    queueCreateInfos[0] = c.VkDeviceQueueCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = graphicsQueueIndex orelse return PresentationError.FailedToCreateLogicDevice,
        .queueCount = 1,
        .pQueuePriorities = &basicQueuePriority,
        .flags = 0,
        .pNext = null,
    };
    if (numUniqueQueues == 2) {
        // presentation queue
        queueCreateInfos[1] = c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = presentQueueIndex orelse return PresentationError.FailedToCreateLogicDevice,
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
        c.vkCreateDevice(presInstance.m_physicalDevice, &deviceCreateInfo, null, &presInstance.m_logicalDevice),
        PresentationError.FailedToCreateLogicDevice,
    );

    if (presInstance.m_logicalDevice) |*ld| {
        c.vkGetDeviceQueue(ld.*, graphicsQueueIndex orelse return PresentationError.FailedToCreateLogicDevice, 0, &presInstance.m_graphicsQueue);
        c.vkGetDeviceQueue(ld.*, presentQueueIndex orelse return PresentationError.FailedToCreateLogicDevice, 0, &presInstance.m_presentQueue);
    }
}

fn GetMaxUsableSampleCount() !c.VkSampleCountFlagBits {
    const presInstance = try PresentationInstance.GetInstance();
    var deviceProperties: c.VkPhysicalDeviceProperties = undefined;
    c.vkGetPhysicalDeviceProperties(presInstance.m_physicalDevice, &deviceProperties);

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
