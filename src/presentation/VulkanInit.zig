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

const imageFileUtil = @import("../coreutil/ImageFileUtil.zig");

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

pub var msaaSamples: c.VkSampleCountFlagBits = c.VK_SAMPLE_COUNT_1_BIT;

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

pub var depthImage: c.VkImage = undefined;
pub var depthImageMemory: c.VkDeviceMemory = undefined;
pub var depthImageView: c.VkImageView = undefined;

pub var colorImage: c.VkImage = undefined;
pub var colorImageMemory: c.VkDeviceMemory = undefined;
pub var colorImageView: c.VkImageView = undefined;

pub var textureMipLevels: u32 = undefined;
pub var textureImage: c.VkImage = undefined;
pub var textureImageMemory: c.VkDeviceMemory = undefined;
pub var textureImageView: c.VkImageView = undefined;
pub var textureSampler: c.VkSampler = undefined;

pub var imageAvailableSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var renderFinishedSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined;
pub var inFlightFences: [BUFFER_FRAMES]c.VkFence = undefined;

const validationLayers = [_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};

const INITIAL_WIDTH = 1280;
const INITIAL_HEIGHT = 720;

const VKInitError = error{
    VKError, //TODO anything with this error should be replaced with a more specific error
    SurfaceCreationFailed,
    NoSupportedDevice, // no device supporting vulkan detected
    NoSuitableDevice, // device with vulkan support detected; does not satisfy properties
    LogicDeviceCreationFailed,
    NoAvailablePresentMode,
    NoAvailableSwapSurfaceFormat,
    FailedToCreateSwapchain,
    FailedToCreateImageView,
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
    FailedToCheckInstanceLayerProperties,
    MissingValidationLayer,
    MissingCurMesh, //TODO delete after testing
};

//TODO could have a better home
pub fn CheckVkSuccess(result: c.VkResult, errorToReturn: anyerror) !void {
    if (result != c.VK_SUCCESS) {
        return errorToReturn;
    }
}

pub const QueueFamilyDetails = struct {
    graphicsQueueIdx: ?u32 = null,
    presentQueueIdx: ?u32 = null,
};

pub const SwapchainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR,
    formats: []c.VkSurfaceFormatKHR,
    presentModes: []c.VkPresentModeKHR,
};

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

    std.debug.print("CreateSwapchainImageViews()...\n", .{});
    try CreateSwapchainImageViews(allocator);

    std.debug.print("CreateRenderPass()...\n", .{});
    try CreateRenderPass();

    std.debug.print("CreateDescriptorSetLayout()...\n", .{});
    try CreateDescriptorSetLayout();

    std.debug.print("CreateGraphicsPipeline()...\n", .{});
    try CreateGraphicsPipeline(allocator, "src/shaders/compiled/basic_mesh-vert.spv", "src/shaders/compiled/basic_mesh-frag.spv");

    std.debug.print("CreateCommandPool()...\n", .{});
    try CreateCommandPool();

    std.debug.print("CreateColorResources()...\n", .{});
    try CreateColorResources();

    std.debug.print("CreateDepthResources()...\n", .{});
    try CreateDepthResources();

    std.debug.print("CreateFrameBuffers()...\n", .{});
    try CreateFrameBuffers(allocator);

    const testImagePath = "test-assets\\test.png";
    std.debug.print("CreateTextureImage()...\n", .{});
    try CreateTextureImage(testImagePath);

    std.debug.print("CreateTextureImageView()...\n", .{});
    try CreateTextureImageView();

    std.debug.print("CreateTextureSampler()...\n", .{});
    try CreateTextureSampler();

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

    defer c.vkDestroySurfaceKHR(instance, surface, null);

    // if (enableValidationLayers) destroy debug utils messanger

    defer c.vkDestroyDevice(logicalDevice, null);

    defer c.vkDestroyCommandPool(logicalDevice, commandPool, null);

    defer {
        var i: usize = 0;
        while (i < BUFFER_FRAMES) : (i += 1) {
            c.vkDestroySemaphore(logicalDevice, imageAvailableSemaphores[i], null);
            c.vkDestroySemaphore(logicalDevice, renderFinishedSemaphores[i], null);
            c.vkDestroyFence(logicalDevice, inFlightFences[i], null);
        }
    }

    defer {
        c.vkDestroyBuffer(logicalDevice, vertexBuffer, null);
        c.vkFreeMemory(logicalDevice, vertexBufferMemory, null);
    }
    defer {
        c.vkDestroyBuffer(logicalDevice, indexBuffer, null);
        c.vkFreeMemory(logicalDevice, indexBufferMemory, null);
    }

    defer c.vkDestroyDescriptorSetLayout(logicalDevice, descriptorSetLayout, null);

    defer {
        c.vkDestroyImageView(logicalDevice, textureImageView, null);
        c.vkDestroyImage(logicalDevice, textureImage, null);
        c.vkFreeMemory(logicalDevice, textureImageMemory, null);
    }
    defer c.vkDestroySampler(logicalDevice, textureSampler, null);

    defer CleanupSwapchain();
}

pub fn RecreateSwapchain(allocator: Allocator) !void {
    try CheckVkSuccess(
        c.vkDeviceWaitIdle(logicalDevice),
        VKInitError.VKError,
    );

    std.debug.print("Recreating Swapchain...\n", .{});
    CleanupSwapchain();

    try CreateSwapchain(allocator);
    try CreateSwapchainImageViews(allocator);
    try CreateRenderPass();
    try CreateGraphicsPipeline(allocator, "src/shaders/compiled/basic_mesh-vert.spv", "src/shaders/compiled/basic_mesh-frag.spv");
    try CreateColorResources();
    try CreateDepthResources();
    try CreateFrameBuffers(allocator);
    try CreateUniformBuffers(allocator);
    try CreateDescriptorPool();
    try CreateDescriptorSets(allocator);
    try CreateCommandBuffers(allocator);
}

fn CleanupSwapchain() void {
    defer {
        for (uniformBuffers) |uniformBuffer| {
            c.vkDestroyBuffer(logicalDevice, uniformBuffer, null);
        }
        for (uniformBuffersMemory) |memory| {
            c.vkFreeMemory(logicalDevice, memory, null);
        }
        c.vkDestroyDescriptorPool(logicalDevice, descriptorPool, null);
    }

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

    defer {
        c.vkDestroyImageView(logicalDevice, depthImageView, null);
        c.vkDestroyImage(logicalDevice, depthImage, null);
        c.vkFreeMemory(logicalDevice, depthImageMemory, null);
    }

    defer {
        c.vkDestroyImage(logicalDevice, colorImage, null);
        c.vkFreeMemory(logicalDevice, colorImageMemory, null);
        c.vkDestroyImageView(logicalDevice, colorImageView, null);
    }
}

fn CheckValidationLayerSupport(allocator: Allocator) !void {
    var layerCount: u32 = 0;
    try CheckVkSuccess(
        c.vkEnumerateInstanceLayerProperties(&layerCount, null),
        VKInitError.FailedToCheckInstanceLayerProperties,
    );

    var detectedLayerProperties = try allocator.alloc(c.VkLayerProperties, layerCount);
    try CheckVkSuccess(
        c.vkEnumerateInstanceLayerProperties(&layerCount, detectedLayerProperties.ptr),
        VKInitError.FailedToCheckInstanceLayerProperties,
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

    try CheckVkSuccess(
        c.vkCreateInstance(&instanceInfo, null, &instance),
        VKInitError.VKError,
    );
}

fn GetMaxUsableSampleCount() c.VkSampleCountFlagBits {
    var deviceProperties: c.VkPhysicalDeviceProperties = undefined;
    c.vkGetPhysicalDeviceProperties(physicalDevice, &deviceProperties);

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
    return swapchainSupported and graphicsSupportExists and deviceFeatures.geometryShader == c.VK_TRUE and deviceFeatures.samplerAnisotropy == c.VK_TRUE;
}

fn QuerySwapchainSupport(allocator: Allocator, physDevice: c.VkPhysicalDevice, s: c.VkSurfaceKHR) !SwapchainSupportDetails {
    var details: SwapchainSupportDetails = undefined;

    try CheckVkSuccess(
        c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physDevice, s, &details.capabilities),
        VKInitError.VKError,
    );

    {
        var formatCount: u32 = 0;
        try CheckVkSuccess(
            c.vkGetPhysicalDeviceSurfaceFormatsKHR(physDevice, s, &formatCount, null),
            VKInitError.VKError,
        );
        details.formats = try allocator.alloc(c.VkSurfaceFormatKHR, formatCount);
        try CheckVkSuccess(
            c.vkGetPhysicalDeviceSurfaceFormatsKHR(physDevice, s, &formatCount, details.formats.ptr),
            VKInitError.VKError,
        );
    }

    {
        var presentModeCount: u32 = 0;
        try CheckVkSuccess(
            c.vkGetPhysicalDeviceSurfacePresentModesKHR(physDevice, s, &presentModeCount, null),
            VKInitError.VKError,
        );
        details.presentModes = try allocator.alloc(c.VkPresentModeKHR, presentModeCount);
        try CheckVkSuccess(
            c.vkGetPhysicalDeviceSurfacePresentModesKHR(physDevice, s, &presentModeCount, details.presentModes.ptr),
            VKInitError.VKError,
        );
    }

    return details;
}

fn PickPhysicalDevice(allocator: Allocator, window: *c.SDL_Window) !void {
    var deviceCount: u32 = 0;
    try CheckVkSuccess(
        c.vkEnumeratePhysicalDevices(instance, &deviceCount, null),
        VKInitError.VKError,
    );
    if (deviceCount == 0) {
        return VKInitError.NoSupportedDevice; //no vulkan supporting devices
    }

    var deviceList = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
    try CheckVkSuccess(
        c.vkEnumeratePhysicalDevices(instance, &deviceCount, deviceList.ptr),
        VKInitError.VKError,
    );

    //TODO rather than just picking first suitable device, could rate/score by some scheme and pick the best
    for (deviceList) |device| {
        if (try PhysicalDeviceIsSuitable(allocator, device, window, surface)) {
            physicalDevice = device;
            msaaSamples = GetMaxUsableSampleCount();
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
            try CheckVkSuccess(
                c.vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, i, surface, &presentationSupport),
                VKInitError.VKError,
            );
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

    try CheckVkSuccess(
        c.vkCreateDevice(physicalDevice, &deviceCreateInfo, null, &logicalDevice),
        VKInitError.LogicDeviceCreationFailed,
    );

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
    try CheckVkSuccess(
        c.vkCreateSwapchainKHR(logicalDevice, &createInfo, null, &swapchain),
        VKInitError.FailedToCreateSwapchain,
    );

    try CheckVkSuccess(
        c.vkGetSwapchainImagesKHR(logicalDevice, swapchain, &swapchainImageCount, null),
        VKInitError.VKError,
    );
    swapchainImages = try allocator.alloc(c.VkImage, swapchainImageCount);
    try CheckVkSuccess(
        c.vkGetSwapchainImagesKHR(logicalDevice, swapchain, &swapchainImageCount, &swapchainImages[0]),
        VKInitError.VKError,
    );
}

fn CreateSwapchainImageViews(allocator: Allocator) !void {
    swapchainImageViews = try allocator.alloc(c.VkImageView, swapchainImages.len);
    var i: u32 = 0;
    while (i < swapchainImages.len) : (i += 1) {
        swapchainImageViews[i] = try CreateImageView(swapchainImages[i], swapchainImageFormat, c.VK_IMAGE_ASPECT_COLOR_BIT, 1);
    }
}

fn CreateRenderPass() !void {
    const colorAttachment = c.VkAttachmentDescription{
        .format = swapchainImageFormat,
        .samples = msaaSamples,
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
        .format = swapchainImageFormat,
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
        .samples = msaaSamples,
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

    try CheckVkSuccess(
        c.vkCreateRenderPass(logicalDevice, &renderPassInfo, null, &renderPass),
        VKInitError.FailedToCreateRenderPass,
    );
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

                _ = try shaderFile.read(shaderCode);
                return shaderCode;
            }
        };
    }
    return VKInitError.FailedToReadShaderFile;
}

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
    try CheckVkSuccess(
        c.vkCreateShaderModule(logicalDevice, &createInfo, null, &shaderModule),
        VKInitError.FailedToCreateShader,
    );

    return shaderModule;
}

pub fn CreateDescriptorSetLayout() !void {
    const mvpUniformDescriptor = c.VkDescriptorSetLayoutBinding{
        .binding = 0,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
        .pImmutableSamplers = null,
    };
    const samplerLayoutBinding = c.VkDescriptorSetLayoutBinding{
        .binding = 1,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .pImmutableSamplers = null,
    };

    const bindings = [_]c.VkDescriptorSetLayoutBinding{ mvpUniformDescriptor, samplerLayoutBinding };
    const layoutInfo = c.VkDescriptorSetLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = bindings.len,
        .pBindings = &bindings,
        .pNext = null,
        .flags = 0,
    };

    try CheckVkSuccess(
        c.vkCreateDescriptorSetLayout(logicalDevice, &layoutInfo, null, &descriptorSetLayout),
        VKInitError.FailedToCreateShader,
    );
}

pub fn CreateGraphicsPipeline(
    allocator: Allocator,
    vertShaderRelativePath: []const u8,
    fragShaderRelativePath: []const u8,
) !void {
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
        .frontFace = c.VK_FRONT_FACE_COUNTER_CLOCKWISE,
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
        .rasterizationSamples = msaaSamples,
        .minSampleShading = 1.0,
        .pSampleMask = null,
        .alphaToCoverageEnable = c.VK_FALSE,
        .alphaToOneEnable = c.VK_FALSE,
        .pNext = null,
        .flags = 0,
    };
    const depthStencilState = c.VkPipelineDepthStencilStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .depthTestEnable = c.VK_TRUE,
        .depthWriteEnable = c.VK_TRUE,
        .depthCompareOp = c.VK_COMPARE_OP_LESS,
        .depthBoundsTestEnable = c.VK_FALSE,
        .stencilTestEnable = c.VK_FALSE,
        .minDepthBounds = 0.0,
        .maxDepthBounds = 1.0,
        .front = c.VkStencilOpState{
            .failOp = c.VK_STENCIL_OP_KEEP,
            .passOp = c.VK_STENCIL_OP_KEEP,
            .depthFailOp = c.VK_STENCIL_OP_KEEP,
            .compareOp = c.VK_COMPARE_OP_NEVER,
            .compareMask = 0,
            .writeMask = 0,
            .reference = 0,
        },
        .back = c.VkStencilOpState{
            .failOp = c.VK_STENCIL_OP_KEEP,
            .passOp = c.VK_STENCIL_OP_KEEP,
            .depthFailOp = c.VK_STENCIL_OP_KEEP,
            .compareOp = c.VK_COMPARE_OP_NEVER,
            .compareMask = 0,
            .writeMask = 0,
            .reference = 0,
        },
        .flags = 0,
        .pNext = null,
    };

    const colorBlending = c.VkPipelineColorBlendAttachmentState{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT |
            c.VK_COLOR_COMPONENT_G_BIT |
            c.VK_COLOR_COMPONENT_B_BIT |
            c.VK_COLOR_COMPONENT_A_BIT,
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

    try CheckVkSuccess(
        c.vkCreatePipelineLayout(logicalDevice, &pipelineLayoutState, null, &pipelineLayout),
        VKInitError.FailedToCreateLayout,
    );

    const pipelineInfo = c.VkGraphicsPipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = shaderStages.len,
        .pStages = &shaderStages,
        .pVertexInputState = &vertexInputState,
        .pInputAssemblyState = &inputAssemblyState,
        .pViewportState = &viewportState,
        .pRasterizationState = &rasterizationState,
        .pTessellationState = null,
        .pMultisampleState = &multisamplingState,
        .pDepthStencilState = &depthStencilState,
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
    try CheckVkSuccess(
        c.vkCreateGraphicsPipelines(logicalDevice, null, 1, &pipelineInfo, null, &graphicsPipeline),
        VKInitError.FailedToCreatePipeline,
    );
}

fn CreateFrameBuffers(allocator: Allocator) !void {
    swapchainFrameBuffers = try allocator.alloc(c.VkFramebuffer, swapchainImageViews.len);
    var i: usize = 0;
    while (i < swapchainImageViews.len) : (i += 1) {
        var attachments = [_]c.VkImageView{
            colorImageView,
            depthImageView,
            swapchainImageViews[i],
        };

        const framebufferInfo = c.VkFramebufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = renderPass,
            .attachmentCount = attachments.len,
            .pAttachments = &attachments,
            .width = swapchainExtent.width,
            .height = swapchainExtent.height,
            .layers = 1,
            .flags = 0,
            .pNext = null,
        };

        try CheckVkSuccess(
            c.vkCreateFramebuffer(logicalDevice, &framebufferInfo, null, &swapchainFrameBuffers[i]),
            VKInitError.FailedToCreateFramebuffers,
        );
    }
}

fn CreateCommandPool() !void {
    const poolInfo = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = queueFamilyDetails.graphicsQueueIdx.?,
        .flags = 0,
        .pNext = null,
    };

    try CheckVkSuccess(
        c.vkCreateCommandPool(logicalDevice, &poolInfo, null, &commandPool),
        VKInitError.FailedToCreateCommandPool,
    );
}

fn FindSupportedFormat(
    candidates: []const c.VkFormat,
    tiling: c.VkImageTiling,
    features: c.VkFormatFeatureFlags,
) !c.VkFormat {
    for (candidates) |format| {
        var properties: c.VkFormatProperties = undefined;
        c.vkGetPhysicalDeviceFormatProperties(physicalDevice, format, &properties);
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

fn CreateColorResources() !void {
    const colorFormat = swapchainImageFormat;

    try CreateImage(
        swapchainExtent.width,
        swapchainExtent.height,
        1,
        msaaSamples,
        colorFormat,
        c.VK_IMAGE_TILING_OPTIMAL,
        c.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT |
            c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        &colorImage,
        &colorImageMemory,
    );
    colorImageView = try CreateImageView(colorImage, colorFormat, c.VK_IMAGE_ASPECT_COLOR_BIT, 1);
}

fn HasStencilComponent(format: c.VkFormat) bool {
    return format == c.VK_FORMAT_D32_SFLOAT_S8_UINT or format == c.VK_FORMAT_D24_UNORM_S8_UINT;
}

fn FindDepthFormat() !c.VkFormat {
    return FindSupportedFormat(
        &[_]c.VkFormat{ c.VK_FORMAT_D32_SFLOAT, c.VK_FORMAT_D32_SFLOAT_S8_UINT, c.VK_FORMAT_D24_UNORM_S8_UINT },
        c.VK_IMAGE_TILING_OPTIMAL,
        c.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT,
    );
}

fn CreateDepthResources() !void {
    const depthFormat = try FindDepthFormat();
    try CreateImage(
        swapchainExtent.width,
        swapchainExtent.height,
        1,
        msaaSamples,
        depthFormat,
        c.VK_IMAGE_TILING_OPTIMAL,
        c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        &depthImage,
        &depthImageMemory,
    );
    depthImageView = try CreateImageView(depthImage, depthFormat, c.VK_IMAGE_ASPECT_DEPTH_BIT, 1);
    try TransitionImageLayout(
        depthImage,
        depthFormat,
        c.VK_IMAGE_LAYOUT_UNDEFINED,
        c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        1,
    );
}

fn CreateImage(
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
    try CheckVkSuccess(
        c.vkCreateImage(logicalDevice, &imageInfo, null, image),
        VKInitError.VKError,
    );

    var memRequirements: c.VkMemoryRequirements = undefined;
    c.vkGetImageMemoryRequirements(logicalDevice, image.*, &memRequirements);
    const allocInfo = c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memRequirements.size,
        .memoryTypeIndex = try FindMemoryType(memRequirements.memoryTypeBits, properties),
        .pNext = null,
    };
    try CheckVkSuccess(
        c.vkAllocateMemory(logicalDevice, &allocInfo, null, imageMemory),
        VKInitError.VKError,
    );

    try CheckVkSuccess(
        c.vkBindImageMemory(logicalDevice, image.*, imageMemory.*, 0),
        VKInitError.VKError,
    );
}

//TODO generating mip maps should be done offline; possibly as a build step/function?
// shader compilation and other rendering-baking could join it
fn GenerateMipmaps(image: c.VkImage, imageFormat: c.VkFormat, imageWidth: u32, imageHeight: u32, mipLevels: u32) !void {
    var formatProperties: c.VkFormatProperties = undefined;
    c.vkGetPhysicalDeviceFormatProperties(physicalDevice, imageFormat, &formatProperties);
    if (formatProperties.optimalTilingFeatures & c.VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT == 0) {
        return VKInitError.VKError;
    }

    var commandBuffer = try BeginSingleTimeCommands();

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
                    .x = @intCast(i32, mipWidth),
                    .y = @intCast(i32, mipHeight),
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
                    .x = @intCast(i32, if (mipWidth > 1) mipWidth / 2 else 1),
                    .y = @intCast(i32, if (mipHeight > 1) mipHeight / 2 else 1),
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

    try EndSingleTimeCommands(commandBuffer);
}

fn CreateTextureImage(imagePath: []const u8) !void {
    std.debug.print("Loading Image {s} ...\n", .{imagePath});
    var image = try imageFileUtil.LoadImage(imagePath);
    defer image.FreeImage();

    //TODO decouple from this variable in particular
    textureMipLevels = @floatToInt(u32, std.math.floor(std.math.log2(@intToFloat(f32, std.math.max(image.m_width, image.m_height))))) + 1;

    const imageSize: c.VkDeviceSize = image.m_width * image.m_height * 4;
    var stagingBuffer: c.VkBuffer = undefined;
    var stagingBufferMemory: c.VkDeviceMemory = undefined;
    try CreateBuffer(
        imageSize,
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &stagingBuffer,
        &stagingBufferMemory,
    );
    defer c.vkDestroyBuffer(logicalDevice, stagingBuffer, null);
    defer c.vkFreeMemory(logicalDevice, stagingBufferMemory, null);

    var data: [*]u8 = undefined;
    try CheckVkSuccess(
        c.vkMapMemory(logicalDevice, stagingBufferMemory, 0, imageSize, 0, @ptrCast([*c]?*anyopaque, &data)),
        VKInitError.VKError,
    );

    @memcpy(data, image.m_imageData, imageSize);
    c.vkUnmapMemory(logicalDevice, stagingBufferMemory);

    try CreateImage(
        image.m_width,
        image.m_height,
        textureMipLevels,
        c.VK_SAMPLE_COUNT_1_BIT,
        c.VK_FORMAT_R8G8B8A8_SRGB,
        c.VK_IMAGE_TILING_OPTIMAL,
        c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT | c.VK_IMAGE_USAGE_SAMPLED_BIT,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        &textureImage,
        &textureImageMemory,
    );

    try TransitionImageLayout(
        textureImage,
        c.VK_FORMAT_R8G8B8A8_SRGB,
        c.VK_IMAGE_LAYOUT_UNDEFINED,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        textureMipLevels,
    );
    try CopyBufferToImage(stagingBuffer, textureImage, image.m_width, image.m_height);
    //transitioned to VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL while generating mipmaps
    try GenerateMipmaps(textureImage, c.VK_FORMAT_R8G8B8A8_SRGB, image.m_width, image.m_height, textureMipLevels);
}

fn CreateImageView(
    image: c.VkImage,
    format: c.VkFormat,
    aspectFlags: c.VkImageAspectFlags,
    mipLevels: u32,
) !c.VkImageView {
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
    try CheckVkSuccess(
        c.vkCreateImageView(logicalDevice, &imageViewInfo, null, &imageView),
        VKInitError.FailedToCreateImageView,
    );

    return imageView;
}

fn CreateTextureImageView() !void {
    textureImageView = try CreateImageView(
        textureImage,
        c.VK_FORMAT_R8G8B8A8_SRGB,
        c.VK_IMAGE_ASPECT_COLOR_BIT,
        textureMipLevels,
    );
}

fn CreateTextureSampler() !void {
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
        .maxLod = @intToFloat(f32, textureMipLevels),
        .flags = 0,
        .pNext = null,
    };

    try CheckVkSuccess(
        c.vkCreateSampler(logicalDevice, &samplerInfo, null, &textureSampler),
        VKInitError.VKError,
    );
}

fn FindMemoryType(typeFilter: u32, properties: c.VkMemoryPropertyFlags) !u32 {
    var memProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);

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

    try CheckVkSuccess(
        c.vkCreateBuffer(logicalDevice, &bufferInfo, null, buffer),
        VKInitError.FailedToCreateVertexBuffer,
    );
    var memRequirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(logicalDevice, buffer.*, &memRequirements);

    const allocInfo = c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memRequirements.size,
        .memoryTypeIndex = try FindMemoryType(memRequirements.memoryTypeBits, properties),
        .pNext = null,
    };

    try CheckVkSuccess(
        c.vkAllocateMemory(logicalDevice, &allocInfo, null, bufferMemory),
        VKInitError.FailedToCreateVertexBuffer,
    );
    try CheckVkSuccess(
        c.vkBindBufferMemory(logicalDevice, buffer.*, bufferMemory.*, 0),
        VKInitError.VKError,
    );
}

fn BeginSingleTimeCommands() !c.VkCommandBuffer {
    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = commandPool,
        .commandBufferCount = 1,
        .pNext = null,
    };

    var commandBuffer: c.VkCommandBuffer = undefined;
    try CheckVkSuccess(
        c.vkAllocateCommandBuffers(logicalDevice, &allocInfo, &commandBuffer),
        VKInitError.VKError,
    );

    const beginInfo = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
        .pNext = null,
    };

    try CheckVkSuccess(
        c.vkBeginCommandBuffer(commandBuffer, &beginInfo),
        VKInitError.VKError,
    );

    return commandBuffer;
}

fn EndSingleTimeCommands(commandBuffer: c.VkCommandBuffer) !void {
    try CheckVkSuccess(
        c.vkEndCommandBuffer(commandBuffer),
        VKInitError.VKError,
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

    try CheckVkSuccess(
        c.vkQueueSubmit(graphicsQueue, 1, &submitInfo, null),
        VKInitError.VKError,
    );
    try CheckVkSuccess(
        c.vkQueueWaitIdle(graphicsQueue),
        VKInitError.VKError,
    );
}

fn CopyBuffer(srcBuffer: c.VkBuffer, dstBuffer: c.VkBuffer, size: c.VkDeviceSize) !void {
    var commandBuffer = try BeginSingleTimeCommands();

    const copyRegion = c.VkBufferCopy{
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size,
    };
    c.vkCmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion);

    try EndSingleTimeCommands(commandBuffer);
}

fn CopyBufferToImage(buffer: c.VkBuffer, image: c.VkImage, width: u32, height: u32) !void {
    var commandBuffer = try BeginSingleTimeCommands();

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

    try EndSingleTimeCommands(commandBuffer);
}

fn TransitionImageLayout(
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
        return VKInitError.VKError;
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
        defer c.vkDestroyBuffer(logicalDevice, stagingBuffer, null);
        defer c.vkFreeMemory(logicalDevice, stagingBufferMemory, null);

        var data: [*]u8 = undefined;
        try CheckVkSuccess(
            c.vkMapMemory(logicalDevice, stagingBufferMemory, 0, bufferSize, 0, @ptrCast([*c]?*anyopaque, &data)),
            VKInitError.VKError,
        );
        @memcpy(data, @ptrCast([*]u8, meshPtr.m_vertexData.items.ptr), bufferSize);
        c.vkUnmapMemory(logicalDevice, stagingBufferMemory);

        try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &vertexBuffer,
            &vertexBufferMemory,
        );

        try CopyBuffer(stagingBuffer, vertexBuffer, bufferSize);
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
        defer c.vkDestroyBuffer(logicalDevice, stagingBuffer, null);
        defer c.vkFreeMemory(logicalDevice, stagingBufferMemory, null);

        var data: [*]u8 = undefined;
        try CheckVkSuccess(
            c.vkMapMemory(logicalDevice, stagingBufferMemory, 0, bufferSize, 0, @ptrCast([*c]?*anyopaque, &data)),
            VKInitError.VKError,
        );
        @memcpy(data, @ptrCast([*]u8, meshPtr.m_indices.items.ptr), bufferSize);
        c.vkUnmapMemory(logicalDevice, stagingBufferMemory);

        try CreateBuffer(
            bufferSize,
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &indexBuffer,
            &indexBufferMemory,
        );

        try CopyBuffer(stagingBuffer, indexBuffer, bufferSize);
    } else {
        return VKInitError.MissingCurMesh;
    }
}

const MeshUBO = packed struct {
    model: Mat4x4,
    view: Mat4x4,
    projection: Mat4x4,
};

fn CreateUniformBuffers(allocator: Allocator) !void {
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
    }
}

pub fn UpdateUniformBuffer(camera: *Camera, currentFrame: usize) !void {
    var bufferSize: c.VkDeviceSize = @sizeOf(MeshUBO);

    var cameraMVP = MeshUBO{
        .model = mat4x4.identity,
        .view = camera.GetViewMatrix(),
        .projection = camera.GetProjectionMatrix(),
    };

    var data: [*]u8 = undefined;
    try CheckVkSuccess(
        c.vkMapMemory(logicalDevice, uniformBuffersMemory[currentFrame], 0, bufferSize, 0, @ptrCast([*c]?*anyopaque, &data)),
        VKInitError.VKError,
    );
    @memcpy(data, @ptrCast([*]u8, &cameraMVP), bufferSize);
    c.vkUnmapMemory(logicalDevice, uniformBuffersMemory[currentFrame]);
}

fn CreateDescriptorPool() !void {
    const uboSize = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = @intCast(u32, swapchainImages.len),
    };
    const imageSamplerSize = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = @intCast(u32, swapchainImages.len),
    };

    const poolSizes = [_]c.VkDescriptorPoolSize{ uboSize, imageSamplerSize };
    const poolInfo = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = poolSizes.len,
        .pPoolSizes = &poolSizes,
        .maxSets = @intCast(u32, swapchainImages.len),
        .flags = 0,
        .pNext = null,
    };

    try CheckVkSuccess(
        c.vkCreateDescriptorPool(logicalDevice, &poolInfo, null, &descriptorPool),
        VKInitError.FailedToCreateDescriptorPool,
    );
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
    try CheckVkSuccess(
        c.vkAllocateDescriptorSets(logicalDevice, &allocInfo, descriptorSets.ptr),
        VKInitError.FailedToCreateDescriptorSets,
    );

    var i: u32 = 0;
    while (i < swapchainImages.len) : (i += 1) {
        const bufferInfo = c.VkDescriptorBufferInfo{
            .buffer = uniformBuffers[i],
            .offset = 0,
            .range = @sizeOf(MeshUBO),
        };
        const imageInfo = c.VkDescriptorImageInfo{
            .imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            .imageView = textureImageView,
            .sampler = textureSampler,
        };
        const uboDescriptorWrite = c.VkWriteDescriptorSet{
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
        const textureSamplerDescriptorWrite = c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = descriptorSets[i],
            .dstBinding = 1,
            .dstArrayElement = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            .descriptorCount = 1,
            .pBufferInfo = null,
            .pImageInfo = &imageInfo,
            .pTexelBufferView = null,
            .pNext = null,
        };
        const descriptorWrites = [_]c.VkWriteDescriptorSet{ uboDescriptorWrite, textureSamplerDescriptorWrite };
        c.vkUpdateDescriptorSets(logicalDevice, descriptorWrites.len, &descriptorWrites, 0, null);
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

    try CheckVkSuccess(
        c.vkAllocateCommandBuffers(logicalDevice, &allocInfo, commandBuffers.ptr),
        VKInitError.FailedToCreateCommandBuffers,
    );

    var i: usize = 0;
    while (i < commandBuffers.len) : (i += 1) {
        var beginInfo = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pInheritanceInfo = null,
            .flags = 0,
            .pNext = null,
        };

        try CheckVkSuccess(
            c.vkBeginCommandBuffer(commandBuffers[i], &beginInfo),
            VKInitError.FailedToCreateCommandBuffers,
        );

        const clearColor = c.VkClearValue{
            .color = c.VkClearColorValue{ .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 } },
        };
        const clearDepth = c.VkClearValue{
            .depthStencil = c.VkClearDepthStencilValue{ .depth = 1.0, .stencil = 0 },
        };
        const clearValues = [_]c.VkClearValue{ clearColor, clearDepth };
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
            .clearValueCount = 2,
            .pClearValues = &clearValues,
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

        try CheckVkSuccess(
            c.vkEndCommandBuffer(commandBuffers[i]),
            VKInitError.FailedToRecordCommandBuffers,
        );
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
        try CheckVkSuccess(
            c.vkCreateSemaphore(logicalDevice, &semaphoreInfo, null, &renderFinishedSemaphores[i]),
            VKInitError.FailedToCreateSemaphores,
        );
        try CheckVkSuccess(
            c.vkCreateSemaphore(logicalDevice, &semaphoreInfo, null, &imageAvailableSemaphores[i]),
            VKInitError.FailedToCreateSemaphores,
        );
        try CheckVkSuccess(
            c.vkCreateFence(logicalDevice, &fenceInfo, null, &inFlightFences[i]),
            VKInitError.FailedToCreateFences,
        );
    }
}
