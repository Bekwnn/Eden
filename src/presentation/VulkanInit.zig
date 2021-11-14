//TODO WIP initial vulkan implementation referencing andrewrk/zig-vulkan-triangle and github gist YukiSnowy/dc31f47448ac61dd6aedee18b5d53858
// and shout out to Alexander Overvoorde for his vulkan tutorial book

//TODO check all VK_FALSE/VK_TRUE and check if we can just use false/true instead for simplicity

const c = @import("../c.zig"); // keeping c import explicit for clarity

const std = @import("std");
const Allocator = std.mem.Allocator;

//TODO: these should be optional or something, but it seems like a PITA to unwrap them every time after intialization.
//maybe they should all be contained in one giant struct which is optional based on whether vulkan has initialized yet?
//A getter function which checks and returns the unwrapped optional and reports an error function if it doesn't exist
pub var instance: c.VkInstance = undefined;

//var debugCallback: c.VkDebugReportCallbackEXT = undefined;

pub var surface: c.VkSurfaceKHR = undefined;

pub var physicalDevice: c.VkPhysicalDevice = undefined;
pub var logicalDevice: c.VkDevice = undefined;

pub var queueFamilyDetails: QueueFamilyDetails = undefined;
pub var graphicsQueue: c.VkQueue = undefined;
pub var presentQueue: c.VkQueue = undefined;

pub const BUFFER_FRAMES = 2;
pub var curFrameBufferIdx: u32 = 0;

pub var swapchain: c.VkSwapchainKHR = undefined;
pub var swapchainImageCount: u32 = undefined;
pub var swapchainImages: []c.VkImage = undefined;
pub var swapchainImageFormat: c.VkFormat = undefined;
pub var swapchainSurfaceFormat: c.VkSurfaceFormatKHR = undefined;
pub var swapchainFormat: c.VkSurfaceFormatKHR = undefined;
pub var swapchainExtent: c.VkExtent2D = undefined;
pub var swapchainImageViews: []c.VkImageView = undefined;

pub var renderPass: c.VkRenderPass = undefined;
pub var pipelineLayout: c.VkPipelineLayout = undefined;
pub var graphicsPipeline: c.VkPipeline = undefined;
pub var swapchainFrameBuffers: []c.VkFramebuffer = undefined;
//var commandPool: c.VkCommandPool = undefined;
pub var commandBuffers: []c.VkCommandBuffer = undefined;

pub var imageAvailableSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var renderFinishedSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var inFlightFences: [BUFFER_FRAMES]c.VkFence = undefined;

const validationLayers = [_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};

const INITIAL_WIDTH = 1280;
const INITIAL_HEIGHT = 720;

const VKInitError = error{
    //TODO replace all VKError nstances with specific error and delete
    VKError,
    SurfaceCreationFailed,
    NoSupportedDevice, // no device supporting vulkan detected
    NoSuitableDevice, // device with vulkan support detected; does not satisfy properties
    LogicDeviceCreationFailed,
    NoAvailablePresentMode,
    NoAvailableSwapSurfaceFormat,
    FailedToCreateSwapchain,
    FailedToCreateImageViews,
    FailedToCreateRenderPass,
    FailedToCreateShader,
    FailedToCreateLayout,
    FailedToCreatePipeline,
    FailedToReadShaderFile,
    MissingValidationLayer,
};

pub const QueueFamilyDetails = struct {
    graphicsQueueIdx: ?u32 = null,
    presentQueueIdx: ?u32 = null,
};

pub const SwapchainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR,
    formats: []c.VkSurfaceFormatKHR,
    presentModes: []c.VkPresentModeKHR,
};

//TODO cleanup steps need to be consistent/correct in the event one of these throws an error
pub fn VulkanInit(window: *c.SDL_Window) !void {
    const allocator = std.heap.page_allocator; //TODO seems like a reasonable choice?

    //TODO should setup validation layers for error reporting and logging
    //(see Validation Layers section of Vulkan Tutorial by Alexander Overvoorde)

    std.debug.warn("CreateVKInstance()...\n", .{});
    try CreateVKInstance(allocator, window);
    std.debug.warn("CreateSurface()...\n", .{});
    try CreateSurface(window); //TODO not yet implemented
    std.debug.warn("PickPhysicalDevice()...\n", .{});
    try PickPhysicalDevice(allocator, window);
    std.debug.warn("CreateLogicalDevice()...\n", .{});
    try CreateLogicalDevice(allocator);
    std.debug.warn("CreateSwapchain()...\n", .{});
    try CreateSwapchain(allocator);
    std.debug.warn("CreateImageViews()...\n", .{});
    try CreateImageViews(allocator);
    std.debug.warn("CreateRenderPass()...\n", .{});
    try CreateRenderPass();
    std.debug.warn("CreateGraphicsPipeline()...\n", .{});
    try CreateGraphicsPipeline(allocator, "src/shaders/compiled/basic_mesh-vert.spv", "src/shaders/compiled/basic_mesh-frag.spv");
}

pub fn VulkanCleanup() void {
    // defer so execution happens in unwinding order--easier to match init order above
    defer c.vkDestroyInstance(instance.?, null);
    defer c.vkDestroyDevice(logicalDevice.?, null);
    //TODO defer DestroySurface(); may involve SDL or may just be vkDestroySurfaceKHR()
    defer c.vkDestroySwapchainKHR(logicalDevice.?, swapchain.?, null);
    defer {
        for (swapchainImageViews) |imageView| {
            c.vkDestroyImageView(logicalDevice.?, imageView, null);
        }
    }
    defer c.vkDestroyRenderPass(logicalDevice.?, renderPass.?, null);
    defer c.vkDestroyPipelineLayout(logicalDevice.?, pipelineLayout.?, null);
    defer c.vkDestroyPipeline(logicalDevice.?, graphicsPipeline.?, null);
}

fn CheckValidationLayerSupport(allocator: *Allocator) !void {
    //TODO handle return value
    var layerCount: u32 = 0;
    _ = c.vkEnumerateInstanceLayerProperties(&layerCount, null);

    var detectedLayerProperties = try allocator.alloc(c.VkLayerProperties, layerCount);
    _ = c.vkEnumerateInstanceLayerProperties(&layerCount, detectedLayerProperties.ptr);

    for (validationLayers) |validationLayer| {
        var layerFound = false;

        for (detectedLayerProperties) |detectedLayer| {
            if (std.mem.startsWith(u8, std.mem.spanZ(&detectedLayer.layerName), std.mem.span(validationLayer))) {
                layerFound = true;
                break;
            }
        }

        if (!layerFound) {
            std.debug.warn("Unable to find validation layer \"{s}\"\n", .{validationLayer});
            std.debug.warn("Layers found:\n", .{});
            for (detectedLayerProperties) |detectedLayer| {
                var trailingWhitespaceStripped = std.mem.tokenize(std.mem.spanZ(&detectedLayer.layerName), " ");
                std.debug.warn("\"{s}\"\n", .{trailingWhitespaceStripped.next().?});
            }
            return VKInitError.MissingValidationLayer;
        }
    }
}

fn CreateVKInstance(allocator: *Allocator, window: *c.SDL_Window) !void {
    const appInfo = c.VkApplicationInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Eden",
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "Eden",
        .engineVersion = c.VK_MAKE_VERSION(0, 1, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
        .pNext = null,
    };

    var extensionCount: c_uint = 0;
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, null);
    var extensionNames = try allocator.alloc([*]const u8, extensionCount);
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, @ptrCast([*c][*c]const u8, extensionNames.ptr));

    // TODO layers
    try CheckValidationLayerSupport(allocator);
    const instanceInfo = c.VkInstanceCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledLayerCount = @intCast(u32, validationLayers.len),
        .ppEnabledLayerNames = &validationLayers,
        .enabledExtensionCount = @intCast(u32, extensionNames.len),
        .ppEnabledExtensionNames = extensionNames.ptr,
        .pNext = null,
        .flags = 0,
    };

    const result = c.vkCreateInstance(&instanceInfo, null, &instance);
    if (result != c.enum_VkResult.VK_SUCCESS) {
        std.debug.warn("Create VK Instance Failed", .{});
        return VKInitError.VKError;
    }
}

// Currently just checks if geometry shaders are supported and if the device supports VK_QUEUE_GRAPHICS_BIT
// Mostly a proof-of-concept function; could ensure device support exists for more advanced stuff later
const requiredExtensions = [_][*]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};
fn PhysicalDeviceIsSuitable(allocator: *Allocator, device: c.VkPhysicalDevice, window: *c.SDL_Window, s: c.VkSurfaceKHR) !bool {
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
    var extensionCount: c_uint = 0;
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, null);
    var extensionNames = try allocator.alloc([*]const u8, extensionCount);
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, @ptrCast([*c][*c]const u8, extensionNames.ptr));

    const swapchainSupport: SwapchainSupportDetails = try QuerySwapchainSupport(allocator, device, s);
    const swapchainSupported = swapchainSupport.formats.len != 0 and swapchainSupport.presentModes.len != 0;

    // We don't need any special features really...
    // For now, just test it supports geometry shaders as a sort of test/placeholder?
    return graphicsSupportExists and deviceFeatures.geometryShader == c.VK_TRUE;
}

//TODO error handle vkresults
fn QuerySwapchainSupport(allocator: *Allocator, physDevice: c.VkPhysicalDevice, s: c.VkSurfaceKHR) !SwapchainSupportDetails {
    var details: SwapchainSupportDetails = undefined;

    _ = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physDevice, s, &details.capabilities);

    {
        var formatCount: u32 = 0;
        _ = c.vkGetPhysicalDeviceSurfaceFormatsKHR(physDevice, s, &formatCount, null);
        details.formats = try allocator.alloc(c.VkSurfaceFormatKHR, formatCount);
        _ = c.vkGetPhysicalDeviceSurfaceFormatsKHR(physDevice, s, &formatCount, details.formats.ptr);
    }

    {
        var presentModeCount: u32 = 0;
        _ = c.vkGetPhysicalDeviceSurfacePresentModesKHR(physDevice, s, &presentModeCount, null);
        details.presentModes = try allocator.alloc(c.VkPresentModeKHR, presentModeCount);
        _ = c.vkGetPhysicalDeviceSurfacePresentModesKHR(physDevice, s, &presentModeCount, details.presentModes.ptr);
    }

    return details;
}

fn PickPhysicalDevice(allocator: *Allocator, window: *c.SDL_Window) !void {
    var deviceCount: u32 = 0;
    _ = c.vkEnumeratePhysicalDevices(instance, &deviceCount, null);
    if (deviceCount == 0) {
        return VKInitError.NoSupportedDevice; //no vulkan supporting devices
    }

    var deviceList = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
    _ = c.vkEnumeratePhysicalDevices(instance, &deviceCount, deviceList.ptr);

    //TODO rather than just picking first suitable device, could rate/score by some scheme and pick the best
    for (deviceList) |device| {
        if (try PhysicalDeviceIsSuitable(allocator, device, window, surface)) {
            physicalDevice = device;
            return;
        }
    }

    return VKInitError.NoSuitableDevice;
}

const basicQueuePriority: f32 = 1.0; //TODO real queue priorities

fn CreateLogicalDevice(allocator: *Allocator) !void {
    //TODO just copying device features that we found on the selected physical device,
    //in the future it should just have features we're actually using
    var deviceFeatures: c.VkPhysicalDeviceFeatures = undefined;
    c.vkGetPhysicalDeviceFeatures(physicalDevice, &deviceFeatures);

    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, null);
    var queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
    c.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, queueFamilies.ptr);

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
            _ = c.vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, i, surface, &presentationSupport);
            if (presentationSupport == c.VK_TRUE) {
                presentQueueIndex = i;
            }
        }
    }

    if (graphicsQueueIndex == null or presentQueueIndex == null) {
        return VKInitError.LogicDeviceCreationFailed;
    }

    queueFamilyDetails = QueueFamilyDetails{
        .graphicsQueueIdx = graphicsQueueIndex,
        .presentQueueIdx = presentQueueIndex,
    };

    //TODO make handling of duplicate queues cleaner
    const numUniqueQueues: u32 = if (graphicsQueueIndex.? == presentQueueIndex.?) 1 else 2;
    var queueCreateInfos = try allocator.alloc(c.VkDeviceQueueCreateInfo, numUniqueQueues);
    // graphics queue
    queueCreateInfos[0] = c.VkDeviceQueueCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = graphicsQueueIndex orelse return VKInitError.LogicDeviceCreationFailed,
        .queueCount = 1,
        .pQueuePriorities = &basicQueuePriority,
        .flags = 0,
        .pNext = null,
    };
    if (numUniqueQueues == 2) {
        // presentation queue
        queueCreateInfos[1] = c.VkDeviceQueueCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = presentQueueIndex orelse return VKInitError.LogicDeviceCreationFailed,
            .queueCount = 1,
            .pQueuePriorities = &basicQueuePriority,
            .flags = 0,
            .pNext = null,
        };
    }

    // we should have verified earlier that requiredExtensions are all supported by this point
    const deviceCreateInfo = c.VkDeviceCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
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

    if (c.vkCreateDevice(physicalDevice, &deviceCreateInfo, null, &logicalDevice) != c.enum_VkResult.VK_SUCCESS) {
        return VKInitError.LogicDeviceCreationFailed;
    }

    //TODO double check this 0 isn't shifty
    if (logicalDevice) |*ld| {
        c.vkGetDeviceQueue(ld.*, graphicsQueueIndex orelse return VKInitError.LogicDeviceCreationFailed, 0, &graphicsQueue);
        c.vkGetDeviceQueue(ld.*, presentQueueIndex orelse return VKInitError.LogicDeviceCreationFailed, 0, &presentQueue);
    }
}

fn CreateSurface(window: *c.SDL_Window) !void {
    const result = c.SDL_Vulkan_CreateSurface(window, instance, &surface);
    if (@enumToInt(result) != c.SDL_TRUE) {
        return VKInitError.SurfaceCreationFailed;
    }
}

fn ChooseSwapExtent(capabilities: c.VkSurfaceCapabilitiesKHR) c.VkExtent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    } else {
        return c.VkExtent2D{
            .width = std.math.clamp(INITIAL_WIDTH, capabilities.minImageExtent.width, capabilities.maxImageExtent.width),
            .height = std.math.clamp(INITIAL_HEIGHT, capabilities.minImageExtent.height, capabilities.maxImageExtent.height),
        };
    }
}

fn ChooseSwapSurfaceFormat(availableFormats: []c.VkSurfaceFormatKHR) !c.VkSurfaceFormatKHR {
    for (availableFormats) |format| {
        if (format.format == c.enum_VkFormat.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == c.enum_VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            return format;
        }
    }

    if (availableFormats.len == 0) {
        return VKInitError.NoAvailableSwapSurfaceFormat;
    }

    return availableFormats[0];
}

fn ChooseSwapPresentMode(availablePresentModes: []c.VkPresentModeKHR) !c.VkPresentModeKHR {
    for (availablePresentModes) |presentMode| {
        if (presentMode == c.enum_VkPresentModeKHR.VK_PRESENT_MODE_MAILBOX_KHR) {
            return presentMode;
        }
    }

    if (availablePresentModes.len == 0) {
        return VKInitError.NoAvailablePresentMode;
    }

    return availablePresentModes[0];
}

fn CreateSwapchain(allocator: *Allocator) !void {
    const swapchainSupport = try QuerySwapchainSupport(allocator, physicalDevice, surface);

    swapchainExtent = ChooseSwapExtent(swapchainSupport.capabilities);

    swapchainFormat = try ChooseSwapSurfaceFormat(swapchainSupport.formats);
    swapchainImageFormat = swapchainFormat.format;
    const presentMode: c.VkPresentModeKHR = try ChooseSwapPresentMode(swapchainSupport.presentModes);

    // you want 1 more than minimum to avoid waiting
    swapchainImageCount = swapchainSupport.capabilities.minImageCount + 1;

    // ensure we're within max image count
    if (swapchainSupport.capabilities.maxImageCount > 0 and swapchainImageCount > swapchainSupport.capabilities.maxImageCount) {
        swapchainImageCount = swapchainSupport.capabilities.maxImageCount;
    }

    const queueFamilyIndices = [_]u32{
        queueFamilyDetails.graphicsQueueIdx orelse return VKInitError.FailedToCreateSwapchain,
        queueFamilyDetails.presentQueueIdx orelse return VKInitError.FailedToCreateSwapchain,
    };
    const queuesAreConcurrent = queueFamilyIndices[0] != queueFamilyIndices[1];
    const createInfo = c.VkSwapchainCreateInfoKHR{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = surface,
        .minImageCount = swapchainImageCount,
        .imageFormat = swapchainFormat.format,
        .imageColorSpace = swapchainFormat.colorSpace,
        .imageExtent = swapchainExtent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,

        .imageSharingMode = if (queuesAreConcurrent) c.enum_VkSharingMode.VK_SHARING_MODE_CONCURRENT else c.enum_VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = if (queuesAreConcurrent) 2 else 0,
        .pQueueFamilyIndices = if (queuesAreConcurrent) &queueFamilyIndices else null,

        .preTransform = swapchainSupport.capabilities.currentTransform,
        .compositeAlpha = c.enum_VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = presentMode,
        .clipped = c.VK_TRUE,
        .oldSwapchain = null, //TODO check the sanity of this
        .pNext = null,
        .flags = 0,
    };
    if (c.vkCreateSwapchainKHR(logicalDevice, &createInfo, null, &swapchain) != c.enum_VkResult.VK_SUCCESS) {
        return VKInitError.FailedToCreateSwapchain;
    }
}

fn CreateImageViews(allocator: *Allocator) !void {
    swapchainImageViews = try allocator.alloc(c.VkImageView, swapchainImages.len);
    var i: u32 = 0;
    while (i < swapchainImages.len) {
        defer i += 1;

        const imageViewInfo = c.VkImageViewCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .image = swapchainImages[i],
            .viewType = c.enum_VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
            .format = swapchainImageFormat,
            .components = c.VkComponentMapping{
                .r = c.enum_VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.enum_VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.enum_VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.enum_VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = c.VkImageSubresourceRange{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        //TODO errdefer cleanup?
        const result = c.vkCreateImageView(logicalDevice, &imageViewInfo, null, &swapchainImageViews[i]);
        if (result != c.enum_VkResult.VK_SUCCESS) {
            return VKInitError.FailedToCreateImageViews;
        }
    }
}

fn CreateRenderPass() !void {
    const colorAttachment = c.VkAttachmentDescription{
        .format = swapchainImageFormat,
        .samples = c.enum_VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.enum_VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.enum_VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.enum_VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.enum_VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.enum_VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.enum_VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
        .flags = 0,
    };
    const colorAttachmentRef = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.enum_VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };
    const subpass = c.VkSubpassDescription{
        .flags = 0,
        .pipelineBindPoint = c.enum_VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .inputAttachmentCount = 0,
        .pInputAttachments = null,
        .colorAttachmentCount = 1,
        .pColorAttachments = &colorAttachmentRef,
        .pResolveAttachments = null,
        .pDepthStencilAttachment = null,
        .preserveAttachmentCount = 0,
        .pPreserveAttachments = null,
    };
    const renderPassInfo = c.VkRenderPassCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .attachmentCount = 1,
        .pAttachments = &colorAttachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 0,
        .pDependencies = null,
    };

    const result = c.vkCreateRenderPass(logicalDevice, &renderPassInfo, null, &renderPass);
    if (result != c.enum_VkResult.VK_SUCCESS) {
        return VKInitError.FailedToCreateRenderPass;
    }
}

// returns owned slice; caller needs to free
fn ReadShaderFile(comptime alignment: comptime_int, allocator: *Allocator, relativeShaderPath: []const u8) ![]align(alignment) const u8 {
    std.debug.warn("Reading shader {s}...\n", .{relativeShaderPath});

    var shaderDir = std.fs.cwd();
    var splitShaderPath = std.mem.tokenize(relativeShaderPath, "\\/");

    while (splitShaderPath.next()) |path| {
        shaderDir = shaderDir.openDir(path, .{}) catch |err| {
            if (err != std.fs.Dir.OpenError.NotDir) {
                return err;
            } else {
                const shaderFile = try shaderDir.openFile(path, .{});
                defer shaderFile.close();

                var shaderCode: []align(alignment) u8 = try allocator.allocAdvanced(u8, alignment, try shaderFile.getEndPos(), .exact);

                _ = try shaderFile.read(shaderCode);
                return shaderCode;
            }
        };
    }
    return VKInitError.FailedToReadShaderFile;
}

//TODO make sure return value here is valid
fn CreateShaderModule(allocator: *Allocator, relativeShaderPath: []const u8) !c.VkShaderModule {
    const shaderCode: []align(@alignOf(u32)) const u8 = try ReadShaderFile(@alignOf(u32), allocator, relativeShaderPath);
    defer allocator.free(shaderCode);

    const createInfo = c.VkShaderModuleCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = shaderCode.len,
        .pCode = std.mem.bytesAsSlice(u32, shaderCode).ptr,
        .pNext = null,
        .flags = 0,
    };

    var shaderModule: c.VkShaderModule = undefined;
    const result = c.vkCreateShaderModule(logicalDevice, &createInfo, null, &shaderModule);
    if (result != c.enum_VkResult.VK_SUCCESS) {
        return VKInitError.FailedToCreateShader;
    } else {
        return shaderModule;
    }
}

//TODO some of these structs should be non-temporary so they can be read/referenced by other code
// Caller needs to call vkDestroyPipelineLayout
pub fn CreateGraphicsPipeline(allocator: *Allocator, vertShaderRelativePath: []const u8, fragShaderRelativePath: []const u8) !void {
    const vertShaderModule = try CreateShaderModule(allocator, vertShaderRelativePath);
    defer c.vkDestroyShaderModule(logicalDevice, vertShaderModule, null);
    const fragShaderModule = try CreateShaderModule(allocator, fragShaderRelativePath);
    defer c.vkDestroyShaderModule(logicalDevice, fragShaderModule, null);

    const vertPipelineCreateInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.enum_VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vertShaderModule,
        .pName = "main",
        .pSpecializationInfo = null,
        .pNext = null,
        .flags = 0,
    };
    const fragPipelineCreateInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.enum_VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = fragShaderModule,
        .pName = "main",
        .pSpecializationInfo = null,
        .pNext = null,
        .flags = 0,
    };

    const shaderStages = [_]c.VkPipelineShaderStageCreateInfo{
        vertPipelineCreateInfo,
        fragPipelineCreateInfo,
    };

    const vertexInputState = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 0,
        .pVertexBindingDescriptions = null,
        .vertexAttributeDescriptionCount = 0,
        .pVertexAttributeDescriptions = null,
        .pNext = null,
        .flags = 0,
    };

    //TODO change to indexed triangle list
    const inputAssemblyState = c.VkPipelineInputAssemblyStateCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.enum_VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
        .pNext = null,
        .flags = 0,
    };

    const viewport = c.VkViewport{
        .x = 0.0,
        .y = 0.0,
        .width = @intToFloat(f32, swapchainExtent.width),
        .height = @intToFloat(f32, swapchainExtent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };
    const scissor = c.VkRect2D{
        .offset = c.VkOffset2D{ .x = 0, .y = 0 },
        .extent = swapchainExtent,
    };
    const viewportState = c.VkPipelineViewportStateCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor,
        .pNext = null,
        .flags = 0,
    };
    const rasterizationState = c.VkPipelineRasterizationStateCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.enum_VkPolygonMode.VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0,
        .cullMode = c.VK_CULL_MODE_BACK_BIT,
        .frontFace = c.enum_VkFrontFace.VK_FRONT_FACE_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,
        .depthBiasConstantFactor = 0.0,
        .depthBiasClamp = 0.0,
        .depthBiasSlopeFactor = 0.0,
        .pNext = null,
        .flags = 0,
    };
    const multisamplingState = c.VkPipelineMultisampleStateCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = c.VK_FALSE,
        .rasterizationSamples = c.enum_VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
        .minSampleShading = 1.0,
        .pSampleMask = null,
        .alphaToCoverageEnable = c.VK_FALSE,
        .alphaToOneEnable = c.VK_FALSE,
        .pNext = null,
        .flags = 0,
    };
    //TODO VkPipelineDepthStencilStateCreateInfo

    const colorBlending = c.VkPipelineColorBlendAttachmentState{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_FALSE,
        .srcColorBlendFactor = c.enum_VkBlendFactor.VK_BLEND_FACTOR_ONE,
        .dstColorBlendFactor = c.enum_VkBlendFactor.VK_BLEND_FACTOR_ZERO,
        .colorBlendOp = c.enum_VkBlendOp.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.enum_VkBlendFactor.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.enum_VkBlendFactor.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.enum_VkBlendOp.VK_BLEND_OP_ADD,
    };
    const colorBlendingState = c.VkPipelineColorBlendStateCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.enum_VkLogicOp.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &colorBlending,
        .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        .pNext = null,
        .flags = 0,
    };

    const dynamicStates = [_]c.VkDynamicState{
        c.enum_VkDynamicState.VK_DYNAMIC_STATE_VIEWPORT,
        c.enum_VkDynamicState.VK_DYNAMIC_STATE_LINE_WIDTH,
    };
    const dynamicStateCreateInfo = c.VkPipelineDynamicStateCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = 2,
        .pDynamicStates = &dynamicStates,
        .pNext = null,
        .flags = 0,
    };

    const pipelineLayoutState = c.VkPipelineLayoutCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 0,
        .pSetLayouts = null,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
        .pNext = null,
        .flags = 0,
    };

    const createLayoutResult = c.vkCreatePipelineLayout(logicalDevice, &pipelineLayoutState, null, &pipelineLayout);
    if (createLayoutResult != c.enum_VkResult.VK_SUCCESS) {
        return VKInitError.FailedToCreateLayout;
    }

    const pipelineInfo = c.VkGraphicsPipelineCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2,
        .pStages = &shaderStages,
        .pVertexInputState = &vertexInputState,
        .pInputAssemblyState = &inputAssemblyState,
        .pViewportState = &viewportState,
        .pRasterizationState = &rasterizationState,
        .pTessellationState = null,
        .pMultisampleState = &multisamplingState,
        .pDepthStencilState = null,
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

    const createPipelineResult = c.vkCreateGraphicsPipelines(logicalDevice, null, 1, &pipelineInfo, null, &graphicsPipeline);
    if (createPipelineResult != c.enum_VkResult.VK_SUCCESS) {
        return VKInitError.FailedToCreatePipeline;
    }
}
