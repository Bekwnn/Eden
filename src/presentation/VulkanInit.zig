//TODO WIP initial vulkan implementation referencing andrewrk/zig-vulkan-triangle and github gist YukiSnowy/dc31f47448ac61dd6aedee18b5d53858
// and shout out to Alexander Overvoorde for his vulkan tutorial book

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

pub var swapChain: c.VkSwapchainKHR = undefined;
pub var swapChainImageCount: u32 = undefined;
pub var swapChainImages: []c.VkImage = undefined;
pub var swapChainSurfaceFormat: c.VkSurfaceFormatKHR = undefined;
pub var swapChainFormat: c.VkFormat = undefined;
pub var swapChainExtent: c.VkExtent2D = undefined;
//var swapChainImageViews: []c.VkImageView = undefined;

pub var renderPass: c.VkRenderPass = undefined;
//var pipelineLayout: c.VkPipelineLayout = undefined;
//var graphicsPipeline: c.VkPipeline = undefined;
pub var swapChainFrameBuffers: []c.VkFramebuffer = undefined;
//var commandPool: c.VkCommandPool = undefined;
pub var commandBuffers: []c.VkCommandBuffer = undefined;

pub var imageAvailableSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var renderFinishedSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var inFlightFences: [BUFFER_FRAMES]c.VkFence = undefined;

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
    SwapChainCreationFailed,
};

pub const QueueFamilyDetails = struct {
    graphicsQueueIdx: ?u32 = null,
    presentQueueIdx: ?u32 = null,
};

pub const SwapChainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR,
    formats: std.ArrayList(c.VkSurfaceFormatKHR),
    presentModes: std.ArrayList(c.VkPresentModeKHR),
};

pub fn VulkanInit(window: *c.SDL_Window) !void {
    const allocator = std.heap.page_allocator; //TODO seems like a reasonable choice?

    //TODO should setup validation layers for error reporting and logging
    //(see Validation Layers section of Vulkan Tutorial by Alexander Overvoorde)

    try CreateVKInstance(allocator, window);
    try CreateSurface(window); //TODO not yet implemented
    try PickPhysicalDevice(allocator, window);
    try CreateLogicalDevice(allocator);
    try CreateSwapChain(allocator);
}

pub fn VulkanCleanup() void {
    // defer so execution happens in unwinding order--easier to match init order above
    defer c.vkDestroyInstance(&instance, null);
    defer c.vkDestroyDevice(&logicalDevice, null);
    //TODO defer DestroySurface(); may involve SDL or may just be vkDestroySurfaceKHR()
    defer c.vkDestroySwapChainKHR(&logicalDevice, &swapChain, null);
}

fn CreateVKInstance(allocator: *Allocator, window: *c.SDL_Window) !void {
    const appInfo = c.VkApplicationInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Eden Test",
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "Eden",
        .engineVersion = c.VK_MAKE_VERSION(0, 1, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
        .pNext = null,
    };

    var extensionCount: c_uint = 0;
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, null);
    var extensionNames = try std.ArrayList([*]const u8).initCapacity(allocator, extensionCount);
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, @ptrCast([*c][*c]const u8, extensionNames.items.ptr));
    extensionNames.items.len = extensionCount;

    // TODO layers
    const instanceInfo = c.VkInstanceCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = @intCast(u32, extensionNames.items.len),
        .ppEnabledExtensionNames = extensionNames.items.ptr,
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
const requiredExtensions = [_][*c]u8{
    VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};
fn PhysicalDeviceIsSuitable(allocator: *Allocator, device: c.VkPhysicalDevice, window: *c.SDL_Window) !bool {
    //TODO should take in surface and check if presentation is supported (vkGetPhysicalDeviceSurfaceSupportKHR())
    var deviceProperties: c.VkPhysicalDeviceProperties = undefined;
    c.vkGetPhysicalDeviceProperties(device, &deviceProperties);

    var deviceFeatures: c.VkPhysicalDeviceFeatures = undefined;
    c.vkGetPhysicalDeviceFeatures(device, &deviceFeatures);

    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);
    var queueFamilies = try std.ArrayList(c.VkQueueFamilyProperties).initCapacity(allocator, queueFamilyCount);
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.items.ptr);
    queueFamilies.items.len = queueFamilyCount;

    var graphicsSupportExists = false;
    var i: usize = 0;
    while (i < queueFamilyCount) : (i += 1) {
        if (queueFamilies.items[i].queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
            graphicsSupportExists = true;
        }
    }

    //TODO ensure we hve all required extensions, compare the extensions we got to check all requiredExtensions exist
    var extensionCount: c_uint = 0;
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, null);
    var extensionNames = try std.ArrayList([*]const u8).initCapacity(allocator, extensionCount);
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, @ptrCast([*c][*c]const u8, extensionNames.items.ptr));
    extensionNames.items.len = extensionCount;

    const swapChainSupport: SwapChainSupportDetails = try QuerySwapChainSupport(allocator, device);
    const swapChainSupported = swapChainSupport.formats.items.len != 0 and swapChainSupport.presentModes.items.len != 0;

    // We don't need any special features really...
    // For now, just test it supports geometry shaders as a sort of test/placeholder?
    return graphicsSupportExists and deviceFeatures.geometryShader;
}

//TODO fix surface
fn QuerySwapChainSupport(allocator: *Allocator, physDevice: c.VkPhysicalDevice, s: c.VkSurface) !SwapChainSupportDetails {
    var details: SwapChainSupportDetails = undefined;

    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, s, &details.capabilities);

    {
        var formatCount: u32 = 0;
        c.vkGetPhysicalDeviceSurfaceFormatsKHR(physDevice, s, &formatCount, null);
        details.formats = try std.ArrayList(c.VkSurfaceFormatKHR).initCapacity(allocator, formatCount);
        c.vkGetPhysicalDeviceSurfaceFormatsKHR(physDevice, s, &formatCount, details.formats.items.ptr);
        details.formats.items.len = formatCount;
    }

    {
        var presentModeCount: u32 = 0;
        c.vkGetPhysicalDeviceSurfacePresentModesKHR(physDevice, s, &presentModeCount, null);
        details.presentModes = try std.ArrayList(c.VkPresentModeKHR).initCapacity(allocator, presentModeCount);
        c.vkGetPhysicalDeviceSurfacePresentModesKHR(physDevice, s, &presentModeCount, details.presentModes.items.ptr);
        details.presentModes.items.len = presentModeCount;
    }

    return details;
}

fn PickPhysicalDevice(allocator: *Allocator, window: *c.SDL_Window) !void {
    var deviceCount: u32 = 0;
    _ = c.vkEnumeratePhysicalDevices(instance, &deviceCount, null);
    if (deviceCount == 0) {
        return VKInitError.NoSupportedDevice; //no vulkan supporting devices
    }

    var deviceList = try std.ArrayList(c.VkPhysicalDevice).initCapacity(allocator, deviceCount);
    _ = c.vkEnumeratePhysicalDevices(instance, &deviceCount, deviceList.items.ptr);
    deviceList.items.len = deviceCount;

    //TODO rather than just picking first suitable device, could rate/score by some scheme and pick the best
    for (deviceList.items) |device| {
        if (try PhysicalDeviceIsSuitable(allocator, device, window)) {
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
    var queueFamilies = try std.ArrayList(c.VkQueueFamilyProperties).initCapacity(allocator, queueFamilyCount);
    c.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, queueFamilies.items.ptr);

    var graphicsQueueIndex: ?u32 = null;
    var presentationQueueIndex: ?u32 = null;
    while (i < queueFamilyCount) : (i += 1) {
        if (graphicsQueueIndex == null) {
            if (queueFamilies.items[i].queueFlags & c.VK_QUEUE_GRAPHICS_BIT) {
                graphicsQueueIndex = i;
            }
        }
        if (presentationQueueIndex == null) {
            var presentationSupport: VkBool32 = false;
            //TODO need surface
            vkGetPhysicalDeviceSurfaceSupportKHR(logicalDevice, i, surface, &presentationSupport);
            if (presentationSupport == true) {
                presentationQueueIndex = i;
            }
        }
    }

    if (!graphicsQueueIndex or !presentationQueueIndex) {
        return VKInitError.LogicDeviceCreationFailed;
    }
    queueFamilyDetails = QueueFamilyDetails{
        .graphicsQueueIdx = graphicsQueueIndex,
        .presentQueueIdx = presentationQueueIndex,
    };

    var queueCreateInfos = try std.ArrayList(VkDeviceQueueCreateInfo).initCapacity(allocator, 2);
    // graphics queue
    queueCreateInfos.append(VkDeviceQueueCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = graphicsQueueIndex,
        .queueCount = 1,
        .pQueuePriority = &basicQueuePriority,
    });
    // presentation queue
    queueCreateInfos.append(VkDeviceQueueCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = presentationQueueIndex,
        .queueCount = 1,
        .pQueuePriority = &basicQueuePriority,
    });

    // we should have verified earlier that requiredExtensions are all supported by this point
    const deviceCreateInfo = VkDeviceCreateInfo{
        .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pQueueCreateInfos = queueCreateInfos.items.ptr,
        .queueCreateInfoCount = 2,
        .pEnabledFeatures = &deviceFeatures,
        .enabledExtensionCount = requiredExtensions.len,
        .ppEnabledExtensions = requiredExtensions.ptr,
        .enabledLayerCount = 0, //TODO validation layers
        .ppEnabledLayers = null, //TODO validation layers
    };

    if (c.vkCreateDevice(physicalDevice, &deviceCreateInfo, null, &logicalDevice) != c.enum_VkResult.VK_SUCCESS) {
        return VKInitError.LogicDeviceCreationFailed;
    }

    //TODO double check this 0 isn't shifty
    c.vkGetDeviceQueue(&logicalDevice, graphicsQueueIndex, 0, &graphicsQueue);
    c.vkGetDeviceQueue(&logicalDevice, presentationQueueindex, 0, &presentationQueue);
}

fn CreateSurface(window: *c.SDL_Window) !void {
    const result = c.SDL_Vulkan_CreateSurface(window, instance, &surface);
    if (@enumToInt(result) != c.SDL_TRUE) {
        return VKInitError.SurfaceCreationFailed;
    }
}

fn ChooseSwapExtent(capabilities: c.VkSurfaceCapabilities) c.VkExtent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    } else {
        return c.VkExtent2D{
            .width = std.math.clamp(INITIAL_WIDTH, capabilities.minImageExtet.width, capabilities.maxImageExtent.width),
            .height = std.math.clamp(INITIAL_HEIGHT, capabilities.minImageExtent.height, capabilities.maxImageExtent.height),
        };
    }
}

fn ChooseSwapSurfaceFormat(availableFormats: *const std.ArrayList(c.VkSurfaceFormatKHR)) !c.VkSurfaceFormatKHR {
    for (availableFormats) |format| {
        if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR) {
            return format;
        }
    }

    if (availableFormats.items.len == 0) {
        return VKInitError.NoAvailableSwapSurfaceFormat;
    }

    return availableFormats.items[0];
}

fn ChooseSwapPresentMode(availablePresentModes: *const std.ArrayList(c.VkPresentModeKHR)) !c.VkPresentModeKHR {
    for (availablePresentModes) |presentMode| {
        if (presentMode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
            return presentMode;
        }
    }

    if (availablePresentModes.items.len == 0) {
        return VKInitError.NoAvailablePresentMode;
    }

    return availablePresentModes[0];
}

fn CreateSwapChain(allocator: *Allocator) !void {
    const swapChainSupport = try QuerySwapChainSupport(allocator, physicalDevice);

    swapChainExtent = ChooseSwapExtent(swapChainSupport.capabilities);

    swapChainFormat = try ChooseSwapSurfaceFormat(&swapChainSupport.formats);
    presentMode = try ChooseSwapPresentMode(&swapChainSupport.presentModes);

    // you want 1 more than minimum to avoid waiting
    swapChainImageCount = swapChainSupport.minImageCount + 1;

    // ensure we're within max image count
    if (swapChainSupport.maxImageCount > 0 and swapChainImageCount > swapChainSupport.maxImageCount) {
        swapChainImageCount = swapChainSupport.maxImageCount;
    }

    const queueFamilyIndices = [_]u32{ queueFamilyDetails.graphicsQueueIdx, queueFamilyDetails.presentQueueIdx };
    const queuesAreConcurrent = queueFamilyIndices[0] != queueFamilyIndices[1];
    const createInfo = c.VkSwapChainCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SWAP_CHAIN_CREATE_INFO_KHR,
        .surface = surface,
        .minImageCount = swapChainImageCount,
        .imageFormat = swapChainFormat.format,
        .imageColorSpace = swapChainFormat.colorSpace,
        .imageExtent = swapChainExtent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,

        .imageSharingMode = if (queuesAreConcurrent) c.VK_SHARING_MODE_CONCURRENT else c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = if (queuesAreConcurrent) 2 else 0,
        .imageSharingMode = if (queuesAreConcurrent) queueFamilyIndices else null,

        .preTransform = swapChainSupport.capabilities.currentTransform,
        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = presentMode,
        .clipped = c.VK_TRUE,
        .oldSwapChain = c.VK_NULL_HANDLE,
    };
    if (vkCreateSwapchainKHR(device, &createInfo, null, &swapChain) != c.enum_VkResult.VK_SUCCESS) {
        return VKInitError.SwapChainCreationFailed;
    }
}
