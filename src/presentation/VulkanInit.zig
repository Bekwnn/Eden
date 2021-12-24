//TODO WIP initial vulkan implementation referencing andrewrk/zig-vulkan-triangle and github gist YukiSnowy/dc31f47448ac61dd6aedee18b5d53858
// and shout out to Alexander Overvoorde for his vulkan tutorial book

const c = @import("../c.zig"); // keeping c import explicit for clarity

const std = @import("std");
const Allocator = std.mem.Allocator;

const Mesh = @import("Mesh.zig").Mesh;
const VertexData = @import("Mesh.zig").VertexData;
const Camera = @import("Camera.zig").Camera;
const mat4x4 = @import("../math/Mat4x4.zig");
const Mat4x4 = @import("../math/Mat4x4.zig").Mat4x4;

//TODO: these should be optional or something, but it seems like a PITA to unwrap them every time after intialization.
//maybe they should all be contained in one giant struct which is optional based on whether vulkan has initialized yet?
//A getter function which checks and returns the unwrapped optional and reports an error function if it doesn't exist
pub var instance: c.VkInstance = undefined;

//var debugCallback: c.VkDebugReportCallbackEXT = undefined;

//TODO parts of initialization should be moved out to assets that determine shader usage and shader structs which have differing layouts
pub var curMesh: ?Mesh = null;
pub var curCamera = Camera{};

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
pub var descriptorSetLayout: c.VkDescriptorSetLayout = undefined;
pub var pipelineLayout: c.VkPipelineLayout = undefined;
pub var graphicsPipeline: c.VkPipeline = undefined;
pub var swapchainFrameBuffers: []c.VkFramebuffer = undefined;
pub var commandPool: c.VkCommandPool = undefined;
pub var commandBuffers: []c.VkCommandBuffer = undefined;

pub var vertexBuffer: c.VkBuffer = undefined;
pub var vertexBufferMemory: c.VkDeviceMemory = undefined;
pub var indexBuffer: c.VkBuffer = undefined;
pub var indexBufferMemory: c.VkDeviceMemory = undefined;
pub var uniformBuffers: []c.VkBuffer = undefined;
pub var uniformBuffersMemory: []c.VkDeviceMemory = undefined;
pub var descriptorPool: c.VkDescriptorPool = undefined;
pub var descriptorSets: []c.VkDescriptorSet = undefined;

pub var imageAvailableSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var renderFinishedSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var inFlightFences: [BUFFER_FRAMES]c.VkFence = undefined;
pub var imagesInFlight: [BUFFER_FRAMES]c.VkFence = undefined;

const validationLayers = [_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};

const INITIAL_WIDTH = 1280;
const INITIAL_HEIGHT = 720;

const VKInitError = error{
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
    FailedToCreateFramebuffers,
    FailedToCreateCommandPool,
    FailedToCreateVertexBuffer,
    FailedToCreateDescriptorPool,
    FailedToCreateDescriptorSets,
    FailedToCreateCommandBuffers,
    FailedToRecordCommandBuffers,
    FailedToCreateSemaphores,
    FailedToCreateFences,
    FailedToFindMemoryType,
    MissingValidationLayer,
    MissingCurMesh, //TODO delete after testing
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
//TODO:
// Move out CreateFrameBuffers, CreateUniformBuffers, and CreateCommandBuffers to separate function which will be updated each frame
pub fn VulkanInit(window: *c.SDL_Window) !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("CreateVKInstance()...\n", .{});
    try CreateVKInstance(allocator, window);

    std.debug.print("CreateSurface()...\n", .{});
    try CreateSurface(window);

    std.debug.print("PickPhysicalDevice()...\n", .{});
    try PickPhysicalDevice(allocator, window);

    std.debug.print("CreateLogicalDevice()...\n", .{});
    try CreateLogicalDevice(allocator);

    std.debug.print("CreateSwapchain()...\n", .{});
    try CreateSwapchain(allocator);

    std.debug.print("CreateImageViews()...\n", .{});
    try CreateImageViews(allocator);

    std.debug.print("CreateRenderPass()...\n", .{});
    try CreateRenderPass();

    std.debug.print("CreateDescriptorSetLayout()...\n", .{});
    try CreateDescriptorSetLayout();

    std.debug.print("CreateGraphicsPipeline()...\n", .{});
    try CreateGraphicsPipeline(allocator, "src/shaders/compiled/basic_mesh-vert.spv", "src/shaders/compiled/basic_mesh-frag.spv");

    std.debug.print("CreateFrameBuffers()...\n", .{});
    try CreateFrameBuffers(allocator);

    std.debug.print("CreateCommandPool()...\n", .{});
    try CreateCommandPool();

    std.debug.print("CreateVertexBuffer()...\n", .{});
    try CreateVertexBuffer();

    std.debug.print("CreateIndexBuffer()...\n", .{});
    try CreateIndexBuffer();

    std.debug.print("CreateUniformBuffers()...\n", .{});
    try CreateUniformBuffers(allocator);

    std.debug.print("CreateDescriptorPool()...\n", .{});
    try CreateDescriptorPool();

    std.debug.print("CreateDescriptorSets()...\n", .{});
    try CreateDescriptorSets(allocator);

    std.debug.print("CreateCommandBuffers()...\n", .{});
    try CreateCommandBuffers(allocator);

    std.debug.print("CreateFencesAndSemaphores()...\n", .{});
    try CreateFencesAndSemaphores();
}

pub fn VulkanCleanup() void {
    // defer so execution happens in unwinding order--easier to match init order above
    defer c.vkDestroyInstance(instance, null);
    defer c.vkDestroyDevice(logicalDevice, null);
    //TODO defer DestroySurface(); may involve SDL or may just be vkDestroySurfaceKHR()
    defer c.vkDestroySwapchainKHR(logicalDevice, swapchain, null);
    defer {
        for (swapchainImageViews) |imageView| {
            c.vkDestroyImageView(logicalDevice, imageView, null);
        }
    }
    defer c.vkDestroyRenderPass(logicalDevice, renderPass, null);
    defer c.vkDestroyDescriptorSetLayout(logicalDevice, descriptorSetLayout, null);
    defer c.vkDestroyPipelineLayout(logicalDevice, pipelineLayout, null);
    defer c.vkDestroyPipeline(logicalDevice, graphicsPipeline, null);
    defer {
        for (swapchainFrameBuffers) |*frameBuffer| {
            c.vkDestroyFramebuffer(logicalDevice, frameBuffer.*, null);
        }
    }
    defer c.vkDestroyCommandPool(logicalDevice, commandPool, null);
    defer {
        c.vkDestroyBuffer(logicalDevice, vertexBuffer, null);
        c.vkFreeMemory(logicalDevice, vertexBufferMemory, null);
    }
    defer {
        c.vkDestroyBuffer(logicalDevice, indexBuffer, null);
        c.vkFreeMemory(logicalDevice, indexBufferMemory, null);
    }
    defer {
        for (uniformBuffers) |uniformBuffer| {
            c.vkDestroyBuffer(logicalDevice, uniformBuffer, null);
        }
        for (uniformBuffersMemory) |memory| {
            c.vkFreeMemory(logicalDevice, memory, null);
        }
        c.vkDestroyDescriptorPool(logicalDevice, descriptorPool, null);
    }
    defer {
        var i: usize = 0;
        while (i < BUFFER_FRAMES) : (i += 1) {
            c.vkDestroySemaphore(logicalDevice, imageAvailableSemaphores[i], null);
            c.vkDestroySemaphore(logicalDevice, renderFinishedSemaphores[i], null);
        }
    }
}

pub fn RecreateSwapchain(allocator: Allocator) !void {
    c.vkWaitDeviceIdle(logicalDevice);

    std.debug.print("CleanupSwapchain()...\n", .{});
    CleanupSwapchain();

    std.debug.print("Recreating Swapchain...\n", .{});
    try CreateSwapchain();
    try CreateImageViews();
    try CreateRenderPass();
    try CreateGraphicsPipeline();
    try CreateFrameBuffers();
    try CreateUniformBuffers();
    try CreateDescriptorPool();
    try CreateDescriptorSets(allocator);
    try CreateCommandBuffers();
}

fn CleanupSwapchain() !void {
    defer c.vkDestroySwapchainKHR(logicalDevice, swapchain, null);

    defer {
        for (swapchainImageViews) |imageView| {
            c.vkDestroyImageView(logicalDevice, imageView, null);
        }
    }

    defer c.vkDestroyRenderPass(logicalDevice, renderPass, null);
    defer c.vkDestroyPipelineLayout(logicalDevice, pipelineLayout, null);
    defer c.vkDestroyPipeline(logicalDevice, graphicsPipeline, null);

    defer c.vkFreeCommandBuffers(logicalDevice, commandPool, @intCast(u32, commandBuffers.len), commandBuffers.ptr);

    defer {
        for (swapchainFrameBuffers) |frameBuffer| {
            c.vkDestroyFramebuffer(logicalDevice, frameBuffer, null);
        }
    }
}

fn CheckValidationLayerSupport(allocator: Allocator) !void {
    //TODO handle return values
    var layerCount: u32 = 0;
    _ = c.vkEnumerateInstanceLayerProperties(&layerCount, null);

    var detectedLayerProperties = try allocator.alloc(c.VkLayerProperties, layerCount);
    _ = c.vkEnumerateInstanceLayerProperties(&layerCount, detectedLayerProperties.ptr);

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
            return VKInitError.MissingValidationLayer;
        }
    }
}

fn CreateVKInstance(allocator: Allocator, window: *c.SDL_Window) !void {
    const appInfo = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Eden",
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "Eden",
        .engineVersion = c.VK_MAKE_VERSION(0, 1, 0),
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

    const result = c.vkCreateInstance(&instanceInfo, null, &instance);
    if (result != c.VK_SUCCESS) {
        std.debug.print("Create VK Instance Failed", .{});
        return VKInitError.VKError;
    }
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

    const swapchainSupport: SwapchainSupportDetails = try QuerySwapchainSupport(allocator, device, s);
    const swapchainSupported = swapchainSupport.formats.len != 0 and swapchainSupport.presentModes.len != 0;

    // We don't need any special features really...
    // For now, just test it supports geometry shaders as a sort of test/placeholder?
    return swapchainSupported and graphicsSupportExists and deviceFeatures.geometryShader == c.VK_TRUE;
}

fn QuerySwapchainSupport(allocator: Allocator, physDevice: c.VkPhysicalDevice, s: c.VkSurfaceKHR) !SwapchainSupportDetails {
    var details: SwapchainSupportDetails = undefined;

    //TODO handle return values
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

fn PickPhysicalDevice(allocator: Allocator, window: *c.SDL_Window) !void {
    //TODO handle return values
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

fn CreateLogicalDevice(allocator: Allocator) !void {
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
            //TODO handle return values
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
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = graphicsQueueIndex orelse return VKInitError.LogicDeviceCreationFailed,
        .queueCount = 1,
        .pQueuePriorities = &basicQueuePriority,
        .flags = 0,
        .pNext = null,
    };
    if (numUniqueQueues == 2) {
        // presentation queue
        queueCreateInfos[1] = c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = presentQueueIndex orelse return VKInitError.LogicDeviceCreationFailed,
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

    if (c.vkCreateDevice(physicalDevice, &deviceCreateInfo, null, &logicalDevice) != c.VK_SUCCESS) {
        return VKInitError.LogicDeviceCreationFailed;
    }

    if (logicalDevice) |*ld| {
        c.vkGetDeviceQueue(ld.*, graphicsQueueIndex orelse return VKInitError.LogicDeviceCreationFailed, 0, &graphicsQueue);
        c.vkGetDeviceQueue(ld.*, presentQueueIndex orelse return VKInitError.LogicDeviceCreationFailed, 0, &presentQueue);
    }
}

fn CreateSurface(window: *c.SDL_Window) !void {
    const result = c.SDL_Vulkan_CreateSurface(window, instance, &surface);
    if (result != c.SDL_TRUE) {
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
        if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
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
        if (presentMode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
            return presentMode;
        }
    }

    if (availablePresentModes.len == 0) {
        return VKInitError.NoAvailablePresentMode;
    }

    return availablePresentModes[0];
}

fn CreateSwapchain(allocator: Allocator) !void {
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
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = surface,
        .minImageCount = swapchainImageCount,
        .imageFormat = swapchainFormat.format,
        .imageColorSpace = swapchainFormat.colorSpace,
        .imageExtent = swapchainExtent,
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
    if (c.vkCreateSwapchainKHR(logicalDevice, &createInfo, null, &swapchain) != c.VK_SUCCESS) {
        return VKInitError.FailedToCreateSwapchain;
    }

    //TODO handle return values
    _ = c.vkGetSwapchainImagesKHR(logicalDevice, swapchain, &swapchainImageCount, null);
    swapchainImages = try allocator.alloc(c.VkImage, swapchainImageCount);
    _ = c.vkGetSwapchainImagesKHR(logicalDevice, swapchain, &swapchainImageCount, &swapchainImages[0]);
}

fn CreateImageViews(allocator: Allocator) !void {
    swapchainImageViews = try allocator.alloc(c.VkImageView, swapchainImages.len);
    var i: u32 = 0;
    while (i < swapchainImages.len) : (i += 1) {
        const imageViewInfo = c.VkImageViewCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .image = swapchainImages[i],
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = swapchainImageFormat,
            .components = c.VkComponentMapping{
                .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
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
        if (result != c.VK_SUCCESS) {
            return VKInitError.FailedToCreateImageViews;
        }
    }
}

fn CreateRenderPass() !void {
    const colorAttachment = c.VkAttachmentDescription{
        .format = swapchainImageFormat,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
        .flags = 0,
    };
    const colorAttachmentRef = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };
    const subpass = c.VkSubpassDescription{
        .flags = 0,
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
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
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
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
    if (result != c.VK_SUCCESS) {
        return VKInitError.FailedToCreateRenderPass;
    }
}

// returns owned slice; caller needs to free
fn ReadShaderFile(comptime alignment: comptime_int, allocator: Allocator, relativeShaderPath: []const u8) ![]align(alignment) const u8 {
    std.debug.print("Reading shader {s}...\n", .{relativeShaderPath});

    var shaderDir = std.fs.cwd();
    var splitShaderPath = std.mem.tokenize(u8, relativeShaderPath, "\\/");

    while (splitShaderPath.next()) |path| {
        shaderDir = shaderDir.openDir(path, .{}) catch |err| {
            if (err != std.fs.Dir.OpenError.NotDir) {
                return err;
            } else {
                const shaderFile = try shaderDir.openFile(path, .{});
                defer shaderFile.close();

                var shaderCode: []align(alignment) u8 = try allocator.allocAdvanced(u8, alignment, try shaderFile.getEndPos(), .exact);

                //TODO handle return values
                _ = try shaderFile.read(shaderCode);
                return shaderCode;
            }
        };
    }
    return VKInitError.FailedToReadShaderFile;
}

//TODO make sure return value here is valid
fn CreateShaderModule(allocator: Allocator, relativeShaderPath: []const u8) !c.VkShaderModule {
    const shaderCode: []align(@alignOf(u32)) const u8 = try ReadShaderFile(@alignOf(u32), allocator, relativeShaderPath);
    defer allocator.free(shaderCode);

    const createInfo = c.VkShaderModuleCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = shaderCode.len,
        .pCode = std.mem.bytesAsSlice(u32, shaderCode).ptr,
        .pNext = null,
        .flags = 0,
    };

    var shaderModule: c.VkShaderModule = undefined;
    const result = c.vkCreateShaderModule(logicalDevice, &createInfo, null, &shaderModule);
    if (result != c.VK_SUCCESS) {
        return VKInitError.FailedToCreateShader;
    } else {
        return shaderModule;
    }
}

pub fn CreateDescriptorSetLayout() !void {
    const mvpUniformDescriptor = c.VkDescriptorSetLayoutBinding{
        .binding = 0,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
        .pImmutableSamplers = null,
    };

    const layoutInfo = c.VkDescriptorSetLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = 1,
        .pBindings = &mvpUniformDescriptor,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateDescriptorSetLayout(logicalDevice, &layoutInfo, null, &descriptorSetLayout) != c.VK_SUCCESS) {
        return VKInitError.FailedToCreateShader;
    }
}

//TODO some of these structs should be non-temporary so they can be read/referenced by other code
// Caller needs to call vkDestroyPipelineLayout
pub fn CreateGraphicsPipeline(allocator: Allocator, vertShaderRelativePath: []const u8, fragShaderRelativePath: []const u8) !void {
    const vertShaderModule = try CreateShaderModule(allocator, vertShaderRelativePath);
    defer c.vkDestroyShaderModule(logicalDevice, vertShaderModule, null);
    const fragShaderModule = try CreateShaderModule(allocator, fragShaderRelativePath);
    defer c.vkDestroyShaderModule(logicalDevice, fragShaderModule, null);

    const vertPipelineCreateInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vertShaderModule,
        .pName = "main",
        .pSpecializationInfo = null,
        .pNext = null,
        .flags = 0,
    };
    const fragPipelineCreateInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
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

    const bindingDescription = Mesh.GetBindingDescription();
    const attribDescriptions = Mesh.GetAttributeDescriptions();

    const vertexInputState = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &bindingDescription,
        .vertexAttributeDescriptionCount = @intCast(u32, attribDescriptions.len),
        .pVertexAttributeDescriptions = attribDescriptions.ptr,
        .pNext = null,
        .flags = 0,
    };

    //TODO change to indexed triangle list
    const inputAssemblyState = c.VkPipelineInputAssemblyStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
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
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor,
        .pNext = null,
        .flags = 0,
    };
    const rasterizationState = c.VkPipelineRasterizationStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0,
        .cullMode = c.VK_CULL_MODE_BACK_BIT,
        .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,
        .depthBiasConstantFactor = 0.0,
        .depthBiasClamp = 0.0,
        .depthBiasSlopeFactor = 0.0,
        .pNext = null,
        .flags = 0,
    };
    const multisamplingState = c.VkPipelineMultisampleStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = c.VK_FALSE,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
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
        .srcColorBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };
    const colorBlendingState = c.VkPipelineColorBlendStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &colorBlending,
        .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        .pNext = null,
        .flags = 0,
    };

    const pipelineLayoutState = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptorSetLayout,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
        .pNext = null,
        .flags = 0,
    };

    const createLayoutResult = c.vkCreatePipelineLayout(logicalDevice, &pipelineLayoutState, null, &pipelineLayout);
    if (createLayoutResult != c.VK_SUCCESS) {
        return VKInitError.FailedToCreateLayout;
    }

    const pipelineInfo = c.VkGraphicsPipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
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
    if (createPipelineResult != c.VK_SUCCESS) {
        return VKInitError.FailedToCreatePipeline;
    }
}

fn CreateFrameBuffers(allocator: Allocator) !void {
    swapchainFrameBuffers = try allocator.alloc(c.VkFramebuffer, swapchainImageViews.len);
    var i: usize = 0;
    while (i < swapchainImageViews.len) : (i += 1) {
        var attachments = [_]c.VkImageView{swapchainImageViews[i]};

        const framebufferInfo = c.VkFramebufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = renderPass,
            .attachmentCount = 1,
            .pAttachments = &attachments,
            .width = swapchainExtent.width,
            .height = swapchainExtent.height,
            .layers = 1,
            .flags = 0,
            .pNext = null,
        };

        if (c.vkCreateFramebuffer(logicalDevice, &framebufferInfo, null, &swapchainFrameBuffers[i]) != c.VK_SUCCESS) {
            return VKInitError.FailedToCreateFramebuffers;
        }
    }
}

fn CreateCommandPool() !void {
    const poolInfo = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = queueFamilyDetails.graphicsQueueIdx.?,
        .flags = 0,
        .pNext = null,
    };

    const result = c.vkCreateCommandPool(logicalDevice, &poolInfo, null, &commandPool);
    if (result != c.VK_SUCCESS) {
        return VKInitError.FailedToCreateCommandPool;
    }
}

fn FindMemoryType(typeFilter: u32, properties: c.VkMemoryPropertyFlags) !u32 {
    var memProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
    //TODO handle return values
    _ = c.vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);

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

fn CreateBuffer(
    size: c.VkDeviceSize,
    usage: c.VkBufferUsageFlags,
    properties: c.VkMemoryPropertyFlags,
    buffer: *c.VkBuffer,
    bufferMemory: *c.VkDeviceMemory,
) !void {
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

    const result = c.vkCreateBuffer(logicalDevice, &bufferInfo, null, buffer);
    if (result != c.VK_SUCCESS) {
        return VKInitError.FailedToCreateVertexBuffer;
    }
    var memRequirements: c.VkMemoryRequirements = undefined;
    //TODO handle return result
    _ = c.vkGetBufferMemoryRequirements(logicalDevice, buffer.*, &memRequirements);

    const allocInfo = c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memRequirements.size,
        .memoryTypeIndex = try FindMemoryType(memRequirements.memoryTypeBits, properties),
        .pNext = null,
    };

    const allocResult = c.vkAllocateMemory(logicalDevice, &allocInfo, null, bufferMemory);
    if (allocResult != c.VK_SUCCESS) {
        return VKInitError.FailedToCreateVertexBuffer;
    }

    _ = c.vkBindBufferMemory(logicalDevice, buffer.*, bufferMemory.*, 0);
}

fn CopyBuffer(srcBuffer: c.VkBuffer, dstBuffer: c.VkBuffer, size: c.VkDeviceSize) void {
    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = commandPool,
        .commandBufferCount = 1,
        .pNext = null,
    };

    var commandBuffer: c.VkCommandBuffer = undefined;
    //TODO handle return result
    _ = c.vkAllocateCommandBuffers(logicalDevice, &allocInfo, &commandBuffer);

    const beginInfo = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
        .pNext = null,
    };

    _ = c.vkBeginCommandBuffer(commandBuffer, &beginInfo);

    const copyRegion = c.VkBufferCopy{
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size,
    };

    c.vkCmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion);

    _ = c.vkEndCommandBuffer(commandBuffer);

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

    _ = c.vkQueueSubmit(graphicsQueue, 1, &submitInfo, null);
    _ = c.vkQueueWaitIdle(graphicsQueue);
}

fn CreateVertexBuffer() !void {
    if (curMesh) |*meshPtr| {
        const bufferSize: c.VkDeviceSize = meshPtr.m_vertexData.items.len * @sizeOf(VertexData);

        var stagingBuffer: c.VkBuffer = undefined;
        var stagingBufferMemory: c.VkDeviceMemory = undefined;

        try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &stagingBuffer,
            &stagingBufferMemory,
        );

        var data: [*]u8 = undefined;
        //TODO handle return result
        _ = c.vkMapMemory(logicalDevice, stagingBufferMemory, 0, bufferSize, 0, @ptrCast([*c]?*anyopaque, &data));
        @memcpy(data, @ptrCast([*]u8, meshPtr.m_vertexData.items.ptr), bufferSize);
        _ = c.vkUnmapMemory(logicalDevice, stagingBufferMemory);

        try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &vertexBuffer,
            &vertexBufferMemory,
        );

        CopyBuffer(stagingBuffer, vertexBuffer, bufferSize);

        c.vkDestroyBuffer(logicalDevice, stagingBuffer, null);
        c.vkFreeMemory(logicalDevice, stagingBufferMemory, null);
    } else {
        return VKInitError.MissingCurMesh;
    }
}

fn CreateIndexBuffer() !void {
    if (curMesh) |*meshPtr| {
        const bufferSize: c.VkDeviceSize = meshPtr.m_indices.items.len * @sizeOf(u32);

        var stagingBuffer: c.VkBuffer = undefined;
        var stagingBufferMemory: c.VkDeviceMemory = undefined;

        try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &stagingBuffer,
            &stagingBufferMemory,
        );

        var data: [*]u8 = undefined;
        //TODO handle return result
        _ = c.vkMapMemory(logicalDevice, stagingBufferMemory, 0, bufferSize, 0, @ptrCast([*c]?*anyopaque, &data));
        @memcpy(data, @ptrCast([*]u8, meshPtr.m_indices.items.ptr), bufferSize);
        _ = c.vkUnmapMemory(logicalDevice, stagingBufferMemory);

        try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &indexBuffer,
            &indexBufferMemory,
        );

        CopyBuffer(stagingBuffer, indexBuffer, bufferSize);

        c.vkDestroyBuffer(logicalDevice, stagingBuffer, null);
        c.vkFreeMemory(logicalDevice, stagingBufferMemory, null);
    } else {
        return VKInitError.MissingCurMesh;
    }
}

const MeshUBO = packed struct {
    model: Mat4x4,
    view: Mat4x4,
    projection: Mat4x4,
};
var curCameraMVP: MeshUBO = undefined;

fn CreateUniformBuffers(allocator: Allocator) !void {
    //TODO remove/rework
    curCamera.m_pos.z = -2.0;
    curCameraMVP = MeshUBO{
        .model = mat4x4.identity,
        .view = curCamera.GetViewMatrix(),
        .projection = curCamera.GetProjectionMatrix(),
    };

    var bufferSize: c.VkDeviceSize = @sizeOf(MeshUBO);

    uniformBuffers = try allocator.alloc(c.VkBuffer, swapchainImages.len);
    uniformBuffersMemory = try allocator.alloc(c.VkDeviceMemory, swapchainImages.len);

    var i: u32 = 0;
    while (i < swapchainImages.len) : (i += 1) {
        try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &uniformBuffers[i],
            &uniformBuffersMemory[i],
        );

        var data: [*]u8 = undefined;
        //TODO handle return result
        _ = c.vkMapMemory(logicalDevice, uniformBuffersMemory[i], 0, bufferSize, 0, @ptrCast([*c]?*anyopaque, &data));
        @memcpy(data, @ptrCast([*]u8, &curCameraMVP), bufferSize);
        _ = c.vkUnmapMemory(logicalDevice, uniformBuffersMemory[i]);
    }
}

fn CreateDescriptorPool() !void {
    const poolSize = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = @intCast(u32, swapchainImages.len),
    };

    const poolInfo = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = 1,
        .pPoolSizes = &poolSize,
        .maxSets = @intCast(u32, swapchainImages.len),
        .flags = 0,
        .pNext = null,
    };

    const result = c.vkCreateDescriptorPool(logicalDevice, &poolInfo, null, &descriptorPool);
    if (result != c.VK_SUCCESS) {
        return VKInitError.FailedToCreateDescriptorPool;
    }
}

fn CreateDescriptorSets(allocator: Allocator) !void {
    var layouts = try allocator.alloc(c.VkDescriptorSetLayout, swapchainImages.len);
    for (layouts) |*layout| {
        layout.* = descriptorSetLayout;
    }

    const allocInfo = c.VkDescriptorSetAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = descriptorPool,
        .descriptorSetCount = @intCast(u32, swapchainImages.len),
        .pSetLayouts = layouts.ptr,
        .pNext = null,
    };

    descriptorSets = try allocator.alloc(c.VkDescriptorSet, swapchainImages.len);
    const result = c.vkAllocateDescriptorSets(logicalDevice, &allocInfo, descriptorSets.ptr);
    if (result != c.VK_SUCCESS) {
        return VKInitError.FailedToCreateDescriptorSets;
    }

    var i: u32 = 0;
    while (i < swapchainImages.len) : (i += 1) {
        const bufferInfo = c.VkDescriptorBufferInfo{
            .buffer = uniformBuffers[i],
            .offset = 0,
            .range = @sizeOf(MeshUBO),
        };
        const descriptorWrite = c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = descriptorSets[i],
            .dstBinding = 0,
            .dstArrayElement = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .pBufferInfo = &bufferInfo,
            .pImageInfo = null,
            .pTexelBufferView = null,
            .pNext = null,
        };
        c.vkUpdateDescriptorSets(logicalDevice, 1, &descriptorWrite, 0, null);
    }
}

fn CreateCommandBuffers(allocator: Allocator) !void {
    commandBuffers = try allocator.alloc(c.VkCommandBuffer, swapchainFrameBuffers.len);
    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = commandPool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = @intCast(u32, commandBuffers.len),
        .pNext = null,
    };

    const result = c.vkAllocateCommandBuffers(logicalDevice, &allocInfo, commandBuffers.ptr);
    if (result != c.VK_SUCCESS) {
        return VKInitError.FailedToCreateCommandBuffers;
    }

    var i: usize = 0;
    while (i < commandBuffers.len) : (i += 1) {
        var beginInfo = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pInheritanceInfo = null,
            .flags = 0,
            .pNext = null,
        };

        const beginResult = c.vkBeginCommandBuffer(commandBuffers[i], &beginInfo);
        if (beginResult != c.VK_SUCCESS) {
            return VKInitError.FailedToCreateCommandBuffers;
        }
        const clearColor = c.VkClearValue{
            .color = c.VkClearColorValue{ .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 } },
        };
        const renderPassInfo = c.VkRenderPassBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = renderPass,
            .framebuffer = swapchainFrameBuffers[i],
            .renderArea = c.VkRect2D{
                .offset = c.VkOffset2D{
                    .x = 0,
                    .y = 0,
                },
                .extent = swapchainExtent,
            },
            .clearValueCount = 1,
            .pClearValues = &clearColor,
            .pNext = null,
        };

        c.vkCmdBeginRenderPass(commandBuffers[i], &renderPassInfo, c.VK_SUBPASS_CONTENTS_INLINE);
        {
            c.vkCmdBindPipeline(commandBuffers[i], c.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);

            const vertexBuffers = [_]c.VkBuffer{vertexBuffer};
            const offsets = [_]c.VkDeviceSize{0};
            c.vkCmdBindVertexBuffers(commandBuffers[i], 0, 1, &vertexBuffers, &offsets);

            c.vkCmdBindIndexBuffer(commandBuffers[i], indexBuffer, 0, c.VK_INDEX_TYPE_UINT32);

            c.vkCmdBindDescriptorSets(commandBuffers[i], c.VK_PIPELINE_BIND_POINT_GRAPHICS, pipelineLayout, 0, 1, &descriptorSets[i], 0, null);

            //TODO testing mesh
            if (curMesh) |*meshPtr| {
                c.vkCmdDrawIndexed(commandBuffers[i], @intCast(u32, meshPtr.m_indices.items.len), 1, 0, 0, 0);
            } else {
                return VKInitError.MissingCurMesh;
            }
        }
        c.vkCmdEndRenderPass(commandBuffers[i]);

        const endCommandBufferResult = c.vkEndCommandBuffer(commandBuffers[i]);
        if (endCommandBufferResult != c.VK_SUCCESS) {
            return VKInitError.FailedToRecordCommandBuffers;
        }
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

    var i: usize = 0;
    while (i < BUFFER_FRAMES) : (i += 1) {
        const renderSemaphoreResult = c.vkCreateSemaphore(logicalDevice, &semaphoreInfo, null, &renderFinishedSemaphores[i]);
        const imageSemaphoreResult = c.vkCreateSemaphore(logicalDevice, &semaphoreInfo, null, &imageAvailableSemaphores[i]);
        const fenceResult = c.vkCreateFence(logicalDevice, &fenceInfo, null, &inFlightFences[i]);
        if (renderSemaphoreResult != c.VK_SUCCESS or
            imageSemaphoreResult != c.VK_SUCCESS)
        {
            return VKInitError.FailedToCreateSemaphores;
        }
        if (fenceResult != c.VK_SUCCESS) {
            return VKInitError.FailedToCreateFences;
        }
    }
}
