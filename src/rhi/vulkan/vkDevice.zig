const Device = @import("../Device.zig");

const c = @import("../../c.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const Self = @This();

pub const VkDeviceError = error{
    AlreadyInitialized,
    FailedToCreateDebugMessenger,
    FailedToCreateInstance,
    FailedToCreateLogicDevice,
    FailedToFindPhysicalDevice,
    NoSupportedDevice,
    NotInitialized,
};

pub const vtable: Device.VTable = .{
    .init = init,
    .deinit = deinit,
    .create_swapchain = ,
    .recreate_swapchain = ,
    .destroy_swapchain = ,
    .create_fence = ,
    .destroy_fence = ,
    .create_semaphore = ,
    .destroy_semaphore = ,
    .create_bind_group = ,
    .destroy_bind_group = ,
    .create_buffer = create_buffer,
    .destroy_buffer = destroy_buffer,
    .copy_buffer = copy_buffer,
    .map_buffer = map_buffer,
    .create_texture = ,
    .destroy_texture = ,
    .create_texture_view = ,
    .destroy_texture_view = ,
    .wait_idle = wait_idle,
};

const DeviceContext = struct {
    m_vkInstance: c.VkInstance = undefined,
    m_surface: c.VkSurfaceKHR = undefined,
    m_physicalDevice: c.VkPhysicalDevice = undefined,
    m_logicalDevice: c.VkDevice = undefined,
    m_debugMessenger: c.VkDebugUtilsMessengerEXT = undefined,
};

pub fn init(
    self: *Self,
    allocator: Allocator,
    window: *c.SDL_Window,
    applicationName: []const u8,
    applicationVersion: u32,
) !void {
    if (instance != null) return VkDeviceError.AlreadyInitialized;

    instance = RenderContext{};

    var newInstance = try RenderContext.GetInstance();

    std.debug.print("Creating Vulkan instance...\n", .{});
    try CreateVkInstance(
        allocator,
        window,
        applicationName,
        applicationVersion,
    );

    if (builtin.mode == .Debug) {
        std.debug.print("Creating debug messenger...\n", .{});
        try SetupDebugMessenger();
    }

    std.debug.print("Creating surface...\n", .{});
    try CreateSurface(window);

    std.debug.print("Creating physical device...\n", .{});
    try PickPhysicalDevice(allocator);

    std.debug.print("Creating logical device...\n", .{});
    try CreateLogicalDevice(allocator);

    if (newInstance.m_graphicsQueueIdx == null or
        newInstance.m_presentQueueIdx == null)
    {
        return VkDeviceError.NotInitialized;
    }
}

fn deinit() void {}

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
        .apiVersion = c.VK_API_VERSION_1_4,
        .pNext = null,
    };

    if (builtin.mode == .Debug) {
        try CheckExtensionSupport(allocator);
        try CheckValidationLayerSupport(allocator);
    }

    // Note: this is only for vulkan instance extensions, not device extensions
    //TODO handle return values
    var sdlExtCount: c_uint = 0;
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &sdlExtCount, null);
    const sdlExtNames = try allocator.alloc([*:0]const u8, sdlExtCount);
    defer allocator.free(sdlExtNames);
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &sdlExtCount, @ptrCast(sdlExtNames.ptr));

    // Merge SDL required extensions with our required extensions
    // TODO: We're assuming vulkan handles duplicates gracefully (untested)
    const extensionNames = try allocator.alloc([*:0]const u8, sdlExtNames.len + enabledExtensions.len);
    defer allocator.free(extensionNames);
    var nameIter: usize = 0;
    for (sdlExtNames) |sdlExtName| {
        extensionNames[nameIter] = sdlExtName;
        nameIter += 1;
    }
    for (enabledExtensions) |enabledExtName| {
        extensionNames[nameIter] = enabledExtName;
        nameIter += 1;
    }

    const instanceInfo =
        c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &appInfo,
            .enabledLayerCount = @intCast(enabledLayers.len),
            .ppEnabledLayerNames = @ptrCast(enabledLayers[0..].ptr),
            .enabledExtensionCount = @intCast(extensionNames.len),
            .ppEnabledExtensionNames = extensionNames.ptr,
            .flags = 0,
            .pNext = null,
        };

    const logLayersAndExtensions = true;
    if (logLayersAndExtensions) {
        std.debug.print("Enabled Instance Extensions:\n", .{});
        for (extensionNames) |extName| {
            std.debug.print(" {s}\n", .{extName});
        }

        std.debug.print("Enabled Layers:\n", .{});
        for (enabledLayers) |layerName| {
            std.debug.print(" {s}\n", .{layerName});
        }
    }

    const rContext = try RenderContext.GetInstance();
    try vkUtil.CheckVkSuccess(
        c.vkCreateInstance(&instanceInfo, null, &rContext.m_vkInstance),
        VkDeviceError.FailedToCreateInstance,
    );
}

fn SetupDebugMessenger() !void {
    const severityFlags: c.VkDebugUtilsMessageSeverityFlagsEXT =
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
    const messageTypeFlags: c.VkDebugUtilsMessageTypeFlagsEXT =
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;

    const messengerCreateInfo = c.VkDebugUtilsMessengerCreateInfoEXT{
        .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .messageSeverity = severityFlags,
        .messageType = messageTypeFlags,
        .pfnUserCallback = &DebugMessengerCallback,
        .pUserData = null,
        .flags = 0,
        .pNext = null,
    };

    var rContext = try RenderContext.GetInstance();
    const pfnTempFn = c.vkGetInstanceProcAddr(
        rContext.m_vkInstance,
        "vkCreateDebugUtilsMessengerEXT",
    );
    const pfnCreateDebugUtilsMessenger = @as(
        c.PFN_vkCreateDebugUtilsMessengerEXT,
        @ptrCast(pfnTempFn),
    );

    if (pfnCreateDebugUtilsMessenger) |createDebugUtilFn| {
        try vkUtil.CheckVkSuccess(
            createDebugUtilFn(
                rContext.m_vkInstance,
                &messengerCreateInfo,
                null,
                &rContext.m_debugMessenger,
            ),
            VkDeviceError.FailedToCreateDebugMessenger,
        );
    } else {
        return VkDeviceError.FailedToCreateDebugMessenger;
    }
}

fn DebugMessengerCallback(
    severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    msgType: c.VkDebugUtilsMessageTypeFlagsEXT,
    callbackData: ?*const c.VkDebugUtilsMessengerCallbackDataEXT,
    ext: ?*anyopaque,
) callconv(.c) c.VkBool32 {
    _ = severity;
    _ = ext;

    std.debug.print("\nmessage type: ", .{});

    // type is a bit flag, accumulate which ones exist
    // https://docs.vulkan.org/refpages/latest/refpages/source/VkDebugUtilsMessageTypeFlagBitsEXT.html
    var messageTypeStrs = [4]?[]const u8{ null, null, null, null };
    if (msgType & c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT != 0) {
        messageTypeStrs[0] = "General";
    }
    if (msgType & c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT != 0) {
        messageTypeStrs[1] = "Validation";
    }
    if (msgType & c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT != 0) {
        messageTypeStrs[2] = "Performance";
    }
    if (msgType & c.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT != 0) {
        messageTypeStrs[3] = "Device Address Binding";
    }
    var isFirstType = true;
    for (messageTypeStrs) |maybeTypeStr| {
        if (maybeTypeStr) |msgTypeStr| {
            if (isFirstType) {
                isFirstType = false;
            } else {
                std.debug.print(" | ", .{});
            }
            std.debug.print("{s}", .{msgTypeStr});
        }
    }
    std.debug.print("\n", .{});

    if (callbackData) |data| {
        std.debug.print("message: {s}\n", .{data.pMessage});
    } else {
        std.debug.print("msg: <no message data>\n", .{});
    }

    // Very verbose, toggle on and off for debugging
    std.debug.dumpCurrentStackTrace(.{
        .first_address = @returnAddress(),
    });

    return c.VK_FALSE;
}

fn PickPhysicalDevice(allocator: Allocator) !void {
    const rContext = try RenderContext.GetInstance();
    var deviceCount: u32 = 0;
    try vkUtil.CheckVkSuccess(
        c.vkEnumeratePhysicalDevices(rContext.m_vkInstance, &deviceCount, null),
        VkDeviceError.FailedToFindPhysicalDevice,
    );
    if (deviceCount == 0) {
        return VkDeviceError.NoSupportedDevice; //no vulkan supporting devices
    }

    const deviceList = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
    try vkUtil.CheckVkSuccess(
        c.vkEnumeratePhysicalDevices(rContext.m_vkInstance, &deviceCount, deviceList.ptr),
        VkDeviceError.FailedToFindPhysicalDevice,
    );

    //Create list of physical device features we want

    //TODO rather than just picking first suitable device, could rate/score by some scheme and pick the best
    for (deviceList) |device| {
        if (try PhysicalDeviceIsSuitable(allocator, device, rContext.m_surface, &requiredFeatures)) {
            rContext.m_physicalDevice = device;
            //TODO fix msaa in dynamic rendering
            //rContext.m_msaaSamples = try GetDeviceMaxUsableSampleCount();
            rContext.m_msaaSamples = c.VK_SAMPLE_COUNT_1_BIT;
            rContext.m_maxDescriptorSets = try GetDeviceMaxDescriptorSets();
            return;
        }
    }

    return VkDeviceError.NoSuitableDevice;
}

const requiredDeviceExtensions = [_][*]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    //c.VK_KHR_CREATE_RENDERPASS_2_EXTENSION_NAME, // required by DEPTH_STENCIL_RESOLVE
    //c.VK_KHR_DEPTH_STENCIL_RESOLVE_EXTENSION_NAME, // required by DYNAMIC_RENDERING
    c.VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME,
};
var requiredFeatures13 = c.VkPhysicalDeviceVulkan13Features{
    .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
    .pNext = null,
    .dynamicRendering = c.VK_TRUE,
    .synchronization2 = c.VK_TRUE,
};
var requiredFeatures12 = c.VkPhysicalDeviceVulkan12Features{
    .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
    .pNext = &requiredFeatures13,
    .bufferDeviceAddress = c.VK_TRUE,
    .descriptorIndexing = c.VK_TRUE,
};
const requiredFeatures = c.VkPhysicalDeviceFeatures2{
    .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
    .pNext = &requiredFeatures12,
    .features = c.VkPhysicalDeviceFeatures{
        .geometryShader = c.VK_TRUE,
        .samplerAnisotropy = c.VK_TRUE,
        .fillModeNonSolid = c.VK_TRUE,
    },
};

fn PhysicalDeviceIsSuitable(
    allocator: Allocator,
    device: c.VkPhysicalDevice,
    surface: c.VkSurfaceKHR,
    enabledFeatures: *const c.VkPhysicalDeviceFeatures2,
) !bool {
    var deviceProperties: c.VkPhysicalDeviceProperties = undefined;
    c.vkGetPhysicalDeviceProperties(device, &deviceProperties);

    // to query different major versions, have to create a pnext chain of device features structs
    // deviceFeatures.features contains 1.0 features.
    var deviceFeatures13 = c.VkPhysicalDeviceVulkan13Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
    };
    var deviceFeatures12 = c.VkPhysicalDeviceVulkan12Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        .pNext = &deviceFeatures13,
    };
    var deviceFeatures11 = c.VkPhysicalDeviceVulkan11Features{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
        .pNext = &deviceFeatures12,
    };
    var deviceFeatures = c.VkPhysicalDeviceFeatures2{
        .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
        .pNext = &deviceFeatures11,
    };
    c.vkGetPhysicalDeviceFeatures2(device, &deviceFeatures);

    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

    const queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

    var graphicsSupportExists = false;
    var i: usize = 0;
    while (i < queueFamilyCount) : (i += 1) {
        if (queueFamilies[i].queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
            graphicsSupportExists = true;
        }
    }

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
        try EnabledFeaturesExist(enabledFeatures, &deviceFeatures);
}

fn CheckFeatureFieldsAreSupported(
    comptime FeatureType: type,
    enabledFeatures: *const FeatureType,
    physicalFeatures: *const FeatureType,
) bool {
    inline for (@typeInfo(FeatureType).@"struct".fields) |f| {
        if (f.type == c.VkBool32) {
            if (@as(f.type, @field(enabledFeatures, f.name)) == c.VK_TRUE and
                @as(f.type, @field(physicalFeatures, f.name)) != c.VK_TRUE)
            {
                return false;
            }
        }
    }
    return true;
}

// assumes features are pNext chained starting from old to new versions
fn EnabledFeaturesExist(
    enabledFeatures: *const c.VkPhysicalDeviceFeatures2,
    physicalDeviceFeatures: *const c.VkPhysicalDeviceFeatures2,
) !bool {
    // check 1.0 features
    if (!CheckFeatureFieldsAreSupported(
        c.VkPhysicalDeviceFeatures,
        &enabledFeatures.features,
        &physicalDeviceFeatures.features,
    )) {
        return false;
    }

    // check 1.1+ features
    var enabledVersionFeaturesChain = enabledFeatures.pNext;
    while (enabledVersionFeaturesChain) |enabledVersionFeatures| {
        const enabledAs11: *c.VkPhysicalDeviceVulkan11Features = @ptrCast(@alignCast(enabledVersionFeatures));
        var physicalVersionFeaturesChain = physicalDeviceFeatures.pNext;
        // skip if enabledVersionFeatures has a whole version missing from its pNext chain
        while (physicalVersionFeaturesChain) |physicalVersionFeatures| {
            const physicalAs11: *c.VkPhysicalDeviceVulkan11Features = @ptrCast(@alignCast(physicalVersionFeatures));
            if (enabledAs11.sType == physicalAs11.sType) {
                break;
            }
            physicalVersionFeaturesChain = physicalAs11.pNext;
        }

        if (physicalVersionFeaturesChain) |physicalVersionFeatures| {
            switch (enabledAs11.sType) {
                inline c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
                c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
                c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
                c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_4_FEATURES,
                => |structType| {
                    const FeatureStructType = switch (structType) {
                        c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES => c.VkPhysicalDeviceVulkan11Features,
                        c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES => c.VkPhysicalDeviceVulkan12Features,
                        c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES => c.VkPhysicalDeviceVulkan13Features,
                        c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_4_FEATURES => c.VkPhysicalDeviceVulkan14Features,
                        else => comptime unreachable, //sType was wrong?
                    };
                    const enabledAsFeatureType: *FeatureStructType = @ptrCast(@alignCast(enabledVersionFeatures));
                    const physicalAsFeatureType: *FeatureStructType = @ptrCast(@alignCast(physicalVersionFeatures));
                    if (!CheckFeatureFieldsAreSupported(FeatureStructType, enabledAsFeatureType, physicalAsFeatureType)) {
                        return false;
                    }
                },
                else => return VkDeviceError.FailedToFindPhysicalDevice, //sType was wrong?
            }
        } else {
            // physical device is missing a whole version's worth of features
            return false;
        }

        enabledVersionFeaturesChain = enabledAs11.pNext;
    }

    return true;
}

const basicQueuePriority: f32 = 1.0; //TODO real queue priorities
fn CreateLogicalDevice(allocator: Allocator) !void {
    const rContext = try RenderContext.GetInstance();

    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(
        rContext.m_physicalDevice,
        &queueFamilyCount,
        null,
    );
    const queueFamilies = try allocator.alloc(
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
            try vkUtil.CheckVkSuccess(
                c.vkGetPhysicalDeviceSurfaceSupportKHR(
                    rContext.m_physicalDevice,
                    i,
                    rContext.m_surface,
                    &presentationSupport,
                ),
                VkDeviceError.FailedToFindPhysicalDevice,
            );
            if (presentationSupport == c.VK_TRUE) {
                presentQueueIndex = i;
            }
        }
    }

    if (graphicsQueueIndex == null or presentQueueIndex == null) {
        return VkDeviceError.FailedToCreateLogicDevice;
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
            return VkDeviceError.FailedToCreateLogicDevice,
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
                return VkDeviceError.FailedToCreateLogicDevice,
            .queueCount = 1,
            .pQueuePriorities = &basicQueuePriority,
            .flags = 0,
            .pNext = null,
        };
    }

    // query surface capabilities for supported usage flags
    //var surfaceCapabilities: c.VkSurfaceCapabilitiesKHR = undefined;
    //c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(rContext.m_physicalDevice, rContext.m_surface, &surfaceCapabilities);

    // we should have verified earlier that requiredExtensions are all supported by this point
    const deviceCreateInfo = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = numUniqueQueues,
        .pQueueCreateInfos = queueCreateInfos.ptr,
        .pEnabledFeatures = null, //1.0 feature struct only, pass pnext chain into pnext instead
        .enabledExtensionCount = requiredDeviceExtensions.len,
        .ppEnabledExtensionNames = &requiredDeviceExtensions,
        .enabledLayerCount = 0, //depricated, per Khronos
        .ppEnabledLayerNames = null, //depricated, per Khronos
        .flags = 0,
        .pNext = &requiredFeatures,
    };

    try vkUtil.CheckVkSuccess(
        c.vkCreateDevice(rContext.m_physicalDevice, &deviceCreateInfo, null, &rContext.m_logicalDevice),
        VkDeviceError.FailedToCreateLogicDevice,
    );

    if (rContext.m_logicalDevice) |*ld| {
        c.vkGetDeviceQueue(
            ld.*,
            graphicsQueueIndex orelse return VkDeviceError.FailedToCreateLogicDevice,
            0,
            &rContext.m_graphicsQueue,
        );
        c.vkGetDeviceQueue(
            ld.*,
            presentQueueIndex orelse return VkDeviceError.FailedToCreateLogicDevice,
            0,
            &rContext.m_presentQueue,
        );
    }
}

pub fn create_buffer(
    size: c.VkDeviceSize,
    usage: c.VkBufferUsageFlags,
    properties: c.VkMemoryPropertyFlags,
) !Buffer {
    const rContext = try RenderContext.GetInstance();
    var newBuffer: Buffer = undefined;
    const bufferInfo = c.VkBufferCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .flags = 0,
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkCreateBuffer(
            rContext.m_logicalDevice,
            &bufferInfo,
            null,
            &newBuffer.m_buffer,
        ),
        BufferError.FailedToCreateBuffer,
    );
    var memRequirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(
        rContext.m_logicalDevice,
        newBuffer.m_buffer,
        &memRequirements,
    );

    const allocInfo = c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memRequirements.size,
        .memoryTypeIndex = try vkUtil.FindMemoryType(memRequirements.memoryTypeBits, properties),
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkAllocateMemory(
            rContext.m_logicalDevice,
            &allocInfo,
            null,
            &newBuffer.m_memory,
        ),
        BufferError.FailedToCreateBuffer,
    );
    try vkUtil.CheckVkSuccess(
        c.vkBindBufferMemory(
            rContext.m_logicalDevice,
            newBuffer.m_buffer,
            newBuffer.m_memory,
            0,
        ),
        BufferError.FailedToCreateBuffer,
    );
    newBuffer.m_mappedData = null;
    return newBuffer;
}

pub fn destroy_buffer(
    self: *Buffer,
    logicalDevice: c.VkDevice,
) void {
    c.vkDestroyBuffer(logicalDevice, self.m_buffer, null);
    c.vkFreeMemory(logicalDevice, self.m_memory, null);
}

fn copy_buffer(srcBuffer: c.VkBuffer, dstBuffer: c.VkBuffer, size: c.VkDeviceSize) !void {
    const commandBuffer = try vkUtil.BeginSingleTimeCommands();

    const copyRegion = c.VkBufferCopy{
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size,
    };
    c.vkCmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion);

    try vkUtil.EndSingleTimeCommands(commandBuffer);
}

pub fn map_buffer(
    self: *Self,
    bufferSize: c.VkDeviceSize,
) !void {
    if (self.m_mappedData != null) {
        return BufferError.FailedToMapData;
    }

    const rContext = try RenderContext.GetInstance();
    try vkUtil.CheckVkSuccess(
        c.vkMapMemory(
            rContext.m_logicalDevice,
            self.m_memory,
            0,
            bufferSize,
            0,
            @ptrCast(&self.m_mappedData),
        ),
        BufferError.FailedToMapData,
    );
}
