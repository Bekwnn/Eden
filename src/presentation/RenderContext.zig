const c = @import("../c.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const Buffer = @import("Buffer.zig").Buffer;
const frameUBO = @import("FrameUBO.zig");
const FrameUBO = frameUBO.FrameUBO;
const PipelineBuilder = @import("PipelineBuilder.zig").PipelineBuilder;
const Shader = @import("Shader.zig").Shader;
const swapchain = @import("Swapchain.zig");
const Swapchain = swapchain.Swapchain;
const vkUtil = @import("VulkanUtil.zig");

const Mesh = @import("Mesh.zig").Mesh;

var instance: ?RenderContext = null;

const engineName = "Eden";
const engineVersion = c.VK_MAKE_API_VERSION(0, 0, 1, 0);

//TODO
// all the functions that are outside of the RenderContext struct but are accessing rContext should
// really just be moved inside the struct and take a (self: *RenderContext)

pub const RenderContextError = error{
    AlreadyInitialized,
    FailedToCheckInstanceLayerProperties,
    FailedToCreateCommandBuffers,
    FailedToCreateCommandPool,
    FailedToCreateFences,
    FailedToCreateImageView,
    FailedToCreateInstance,
    FailedToCreateLogicDevice,
    FailedToCreatePipelineLayout,
    FailedToCreateRenderPass,
    FailedToCreateSemaphores,
    FailedToCreateSurface,
    FailedToFindPhysicalDevice,
    FailedToFindSupportedFormat,
    FailedToRecordCommandBuffers,
    FailedToWait,
    MissingValidationLayer,
    UninitializedShutdown,

    // device with vulkan support detected; does not satisfy properties
    NoSuitableDevice,

    // no device supporting vulkan detected
    NoSupportedDevice,

    NotInitialized,
};

pub const DescriptorSetType = enum(u8) {
    PerFrame = 0,
    PerPass = 1,
    PerMaterial = 2,
    PerInstance = 3,
    // We do not want to exceed 4 descriptor sets since since some
    // integrated gpus don't support having more
};
const DESCRIPTOR_SET_COUNT = @typeInfo(DescriptorSetType).Enum.fields.len;

// contains data that we store per frame, when double buffering
pub const FrameData = struct {
    m_presentSemaphore: c.VkSemaphore,
    m_renderSemaphore: c.VkSemaphore,
    m_renderFence: c.VkFence,

    m_commandPool: c.VkCommandPool,
    m_mainCommandBuffer: c.VkCommandBuffer,

    m_descriptorSets: [DESCRIPTOR_SET_COUNT]c.VkDescriptorSet = undefined,
    m_uniformBuffers: [DESCRIPTOR_SET_COUNT]Buffer = undefined,
};

pub const BUFFER_FRAMES = 2;

pub const RenderContext = struct {
    m_vkInstance: c.VkInstance = undefined,
    m_surface: c.VkSurfaceKHR = undefined,
    m_physicalDevice: c.VkPhysicalDevice = undefined,
    m_logicalDevice: c.VkDevice = undefined,
    //m_debugCallback: c.VkDebugReportCallbackEXT,

    m_swapchain: Swapchain = undefined,
    m_renderPass: c.VkRenderPass = undefined,

    m_graphicsQueueIdx: ?u32 = null,
    m_graphicsQueue: c.VkQueue = undefined,
    m_presentQueueIdx: ?u32 = null,
    m_presentQueue: c.VkQueue = undefined,

    m_descriptorSetLayouts: [DESCRIPTOR_SET_COUNT]c.VkDescriptorSetLayout = undefined,
    m_frameData: [BUFFER_FRAMES]FrameData = undefined,
    m_currentFrame: u32 = 0,

    // We want to stick to 4 descriptor sets due lower end hardware limitations
    // 0 = bound once per frame
    // 1 = bound once per pass
    // 2 = bound once per material (lives in the material)
    // 3 = bound once per material instance (lives in material instance)
    m_descriptorPool: c.VkDescriptorPool = undefined,

    m_pipelineLayout: c.VkPipelineLayout = undefined,
    m_pipeline: c.VkPipeline = undefined,

    m_msaaSamples: c.VkSampleCountFlagBits = c.VK_SAMPLE_COUNT_1_BIT,

    pub fn GetInstance() !*RenderContext {
        if (instance) |*inst| {
            return inst;
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

        var newInstance = try RenderContext.GetInstance();

        std.debug.print("Creating Vulkan instance...\n", .{});
        try CreateVkInstance(
            allocator,
            window,
            applicationName,
            applicationVersion,
        );

        std.debug.print("Creating surface...\n", .{});
        try CreateSurface(window);

        std.debug.print("Creating physical device...\n", .{});
        try PickPhysicalDevice(allocator, window);

        std.debug.print("Creating logical device...\n", .{});
        try CreateLogicalDevice(allocator);

        //TODO move all swapchain initialization to Swapchain.zig
        if (newInstance.m_graphicsQueueIdx == null or
            newInstance.m_presentQueueIdx == null)
        {
            return RenderContextError.NotInitialized;
        }

        std.debug.print("Creating swapchain...\n", .{});
        newInstance.m_swapchain = try Swapchain.CreateSwapchain(
            allocator,
            newInstance.m_logicalDevice,
            newInstance.m_physicalDevice,
            newInstance.m_surface,
            newInstance.m_graphicsQueueIdx.?,
            newInstance.m_presentQueueIdx.?,
        );

        std.debug.print("Creating render pass...\n", .{});
        try CreateRenderPass();

        std.debug.print("Creating descriptor set layouts...\n", .{});
        try CreateDescriptorSetLayouts(allocator);

        std.debug.print("Creating pipeline...\n", .{});
        try CreatePipeline(
            allocator,
            "src/shaders/compiled/basic_mesh-vert.spv",
            "src/shaders/compiled/basic_mesh-frag.spv",
        );

        std.debug.print("Creating command pool...\n", .{});
        try CreateCommandPool();

        std.debug.print("Creating color depth resources...\n", .{});
        try newInstance.m_swapchain.CreateColorAndDepthResources(
            newInstance.m_logicalDevice,
            newInstance.m_msaaSamples,
        );

        std.debug.print("Creating frame buffers...\n", .{});
        try newInstance.m_swapchain.CreateFrameBuffers(
            allocator,
            newInstance.m_logicalDevice,
            newInstance.m_renderPass,
        );

        std.debug.print("Creating descriptor pools...\n", .{});
        try CreateDescriptorPools();

        std.debug.print("Creating command buffers...\n", .{});
        try CreateCommandBuffers();

        std.debug.print("Creating fences and semaphores...\n", .{});
        try CreateFencesAndSemaphores();
    }

    pub fn Shutdown(self: *RenderContext) void {
        // if (enableValidationLayers) destroy debug utils messenger
        defer c.vkDestroyInstance(self.m_vkInstance, null);

        defer c.vkDestroySurfaceKHR(self.m_vkInstance, self.m_surface, null);

        defer c.vkDestroyDevice(instance.?.m_logicalDevice, null);

        defer self.DestroySwapchain();

        defer {
            for (&self.m_frameData) |*frameData| {
                c.vkDestroySemaphore(self.m_logicalDevice, frameData.m_presentSemaphore, null);
                c.vkDestroySemaphore(self.m_logicalDevice, frameData.m_renderSemaphore, null);
                c.vkDestroyFence(self.m_logicalDevice, frameData.m_renderFence, null);

                c.vkDestroyCommandPool(self.m_logicalDevice, frameData.m_commandPool, null);
            }
        }
        instance = null;
    }

    pub fn GetCurrentFrame(self: *RenderContext) *FrameData {
        return &self.m_frameData[self.m_currentFrame % BUFFER_FRAMES];
    }

    pub fn RecreateSwapchain(self: *RenderContext, allocator: Allocator) !void {
        try vkUtil.CheckVkSuccess(
            c.vkDeviceWaitIdle(self.m_logicalDevice),
            RenderContextError.FailedToWait,
        );

        std.debug.print("Recreating Swapchain...\n", .{});
        self.DestroySwapchain();

        self.m_swapchain = try Swapchain.CreateSwapchain(
            allocator,
            self.m_logicalDevice,
            self.m_physicalDevice,
            self.m_surface,
            self.m_graphicsQueueIdx.?,
            self.m_presentQueueIdx.?,
        );
        try CreateRenderPass();
        try self.m_swapchain.CreateColorAndDepthResources(
            self.m_logicalDevice,
            self.m_msaaSamples,
        );
        try self.m_swapchain.CreateFrameBuffers(
            allocator,
            self.m_logicalDevice,
            self.m_renderPass,
        );
        try CreateCommandBuffers();
    }

    pub fn DestroySwapchain(self: *RenderContext) void {
        defer {
            for (&self.m_frameData) |*frameData| {
                for (&frameData.m_uniformBuffers) |*uniformBuffer| {
                    uniformBuffer.DestroyBuffer(self.m_logicalDevice);
                }
            }
            c.vkDestroyDescriptorPool(
                self.m_logicalDevice,
                self.m_descriptorPool,
                null,
            );
        }

        defer self.m_swapchain.FreeSwapchain(self.m_logicalDevice);

        defer c.vkDestroyRenderPass(self.m_logicalDevice, self.m_renderPass, null);

        defer self.m_swapchain.CleanupFrameBuffers(self.m_logicalDevice);

        for (&self.m_frameData) |*frameData| {
            defer c.vkFreeCommandBuffers(
                self.m_logicalDevice,
                frameData.m_commandPool,
                1,
                &frameData.m_mainCommandBuffer,
            );
        }

        defer self.m_swapchain.CleanupDepthAndColorImages(self.m_logicalDevice);
    }
};

const validationLayers = [_][:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};
fn CheckValidationLayerSupport(allocator: Allocator) !void {
    var layerCount: u32 = 0;
    try vkUtil.CheckVkSuccess(
        c.vkEnumerateInstanceLayerProperties(&layerCount, null),
        RenderContextError.FailedToCheckInstanceLayerProperties,
    );

    const detectedLayerProperties = try allocator.alloc(c.VkLayerProperties, layerCount);
    try vkUtil.CheckVkSuccess(
        c.vkEnumerateInstanceLayerProperties(&layerCount, detectedLayerProperties.ptr),
        RenderContextError.FailedToCheckInstanceLayerProperties,
    );

    for (validationLayers) |validationLayer| {
        var layerFound = false;

        for (detectedLayerProperties) |detectedLayer| {
            const needle: []const u8 = validationLayer;
            const haystack: []const u8 = &detectedLayer.layerName;
            if (std.mem.startsWith(u8, haystack, needle)) {
                layerFound = true;
                break;
            }
        }

        if (!layerFound) {
            std.debug.print("Unable to find validation layer \"{s}\"\n", .{validationLayer});
            std.debug.print("Layers found:\n", .{});
            for (detectedLayerProperties) |detectedLayer| {
                var trailingWhitespaceStripped = std.mem.tokenize(u8, &detectedLayer.layerName, " ");
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
    const extensionNames = try allocator.alloc([*]const u8, extensionCount);
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, @ptrCast(extensionNames.ptr));

    try CheckValidationLayerSupport(allocator);
    const instanceInfo = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledLayerCount = @intCast(validationLayers.len),
        .ppEnabledLayerNames = @ptrCast(validationLayers[0..].ptr),
        .enabledExtensionCount = @intCast(extensionNames.len),
        .ppEnabledExtensionNames = extensionNames.ptr,
        .pNext = null,
        .flags = 0,
    };

    const rContext = try RenderContext.GetInstance();
    try vkUtil.CheckVkSuccess(
        c.vkCreateInstance(&instanceInfo, null, &rContext.m_vkInstance),
        RenderContextError.FailedToCreateInstance,
    );
}

fn PickPhysicalDevice(allocator: Allocator, window: *c.SDL_Window) !void {
    const rContext = try RenderContext.GetInstance();
    var deviceCount: u32 = 0;
    try vkUtil.CheckVkSuccess(
        c.vkEnumeratePhysicalDevices(rContext.m_vkInstance, &deviceCount, null),
        RenderContextError.FailedToFindPhysicalDevice,
    );
    if (deviceCount == 0) {
        return RenderContextError.NoSupportedDevice; //no vulkan supporting devices
    }

    const deviceList = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
    try vkUtil.CheckVkSuccess(
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

    const queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
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
    const extensionNames = try allocator.alloc([*]const u8, extensionCount);
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, @ptrCast(extensionNames.ptr));

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
        .enabledLayerCount = 0, //depricated, per Khronos
        .ppEnabledLayerNames = null, //depricated, per Khronos
        .flags = 0,
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
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

fn CreateDescriptorPools() !void {
    const rContext = try RenderContext.GetInstance();
    const uboSize = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = @intCast(rContext.m_swapchain.m_images.len),
    };
    const imageSamplerSize = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = @intCast(rContext.m_swapchain.m_images.len),
    };

    const poolSizes = [_]c.VkDescriptorPoolSize{ uboSize, imageSamplerSize };
    const poolInfo = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = poolSizes.len,
        .pPoolSizes = &poolSizes,
        .maxSets = @intCast(rContext.m_swapchain.m_images.len),
        .flags = 0,
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkCreateDescriptorPool(
            rContext.m_logicalDevice,
            &poolInfo,
            null,
            &rContext.m_descriptorPool,
        ),
        vkUtil.VkError.FailedToCreateDescriptorPool,
    );
}

fn CreateDescriptorSetLayouts(allocator: Allocator) !void {
    const rContext = try RenderContext.GetInstance();
    const layouts = try allocator.alloc(
        c.VkDescriptorSetLayout,
        rContext.m_swapchain.m_images.len,
    );
    for (layouts, 0..) |*layout, i| {
        layout.* = rContext.m_descriptorSetLayouts[i];
    }

    const allocInfo = c.VkDescriptorSetAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = rContext.m_descriptorPool,
        .descriptorSetCount = @intCast(rContext.m_swapchain.m_images.len),
        .pSetLayouts = layouts.ptr,
        .pNext = null,
    };

    //TODO rethink if fixed size array should be = undefined
    for (rContext.m_frameData) |*frameData| {
        frameData.m_descriptorSets = try allocator.alloc(
            c.VkDescriptorSet,
            rContext.m_swapchain.m_images.len,
        );
    }

    try vkUtil.CheckVkSuccess(
        c.vkAllocateDescriptorSets(
            rContext.m_logicalDevice,
            &allocInfo,
            rContext.m_descriptorSets.ptr,
        ),
        vkUtil.VkError.FailedToCreateDescriptorSets,
    );

    // Only initializing global per frame UBO with camera data at the moment
    for (rContext.m_frameData) |*frameData| {
        const bufferInfo = c.VkDescriptorBufferInfo{
            .buffer = frameData.m_uniformBuffers[DescriptorSetType.PerFrame].m_buffer,
            .offset = 0,
            .range = @sizeOf(FrameUBO),
        };
        //TODO add texture sampler to Material or MaterialInstance UBO
        //const imageInfo = c.VkDescriptorImageInfo{
        //    .imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        //    .imageView = textureImage.m_imageView,
        //    .sampler = textureSampler,
        //};
        const uboDescriptorWrite = c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = rContext.m_descriptorSets[DescriptorSetType.PerFrame],
            .dstBinding = 0,
            .dstArrayElement = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .pBufferInfo = &bufferInfo,
            .pImageInfo = null,
            .pTexelBufferView = null,
            .pNext = null,
        };
        //const textureSamplerDescriptorWrite = c.VkWriteDescriptorSet{
        //    .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        //    .dstSet = descriptorSets[DescriptorSetType.PerFrame],
        //    .dstBinding = 1,
        //    .dstArrayElement = 0,
        //    .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        //    .descriptorCount = 1,
        //    .pBufferInfo = null,
        //    .pImageInfo = &imageInfo,
        //    .pTexelBufferView = null,
        //    .pNext = null,
        //};
        const descriptorWrites = [_]c.VkWriteDescriptorSet{
            uboDescriptorWrite,
            //textureSamplerDescriptorWrite,
        };
        c.vkUpdateDescriptorSets(
            rContext.m_logicalDevice,
            descriptorWrites.len,
            &descriptorWrites,
            0,
            null,
        );
    }
}

fn CreatePipeline(
    allocator: Allocator,
    vertShaderRelativePath: []const u8,
    fragShaderRelativePath: []const u8,
) !void {
    const rContext = try RenderContext.GetInstance();

    const pipelineLayoutInfo = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = rContext.m_descriptorSetLayouts.len,
        .pSetLayouts = rContext.m_descriptorSetLayouts.ptr,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
        .flags = 0,
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkCreatePipelineLayout(
            rContext.m_logicalDevice,
            &pipelineLayoutInfo,
            null,
            &rContext.m_pipelineLayout,
        ),
        RenderContextError.FailedToCreatePipelineLayout,
    );

    var shader = try Shader.CreateBasicShader(
        allocator,
        vertShaderRelativePath,
        fragShaderRelativePath,
    );
    defer shader.FreeShader();

    var pipelineBuilder = PipelineBuilder{};

    const bindingDescription = Mesh.GetBindingDescription();
    const attribDescriptions = Mesh.GetAttributeDescriptions();
    try pipelineBuilder.InitializeBuilder(
        c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        c.VK_POLYGON_MODE_FILL,
        bindingDescription,
        attribDescriptions,
    );

    pipelineBuilder.ClearShaderStages();
    try pipelineBuilder.AddShaderStage(
        c.VK_SHADER_STAGE_VERTEX_BIT,
        shader.m_vertShader.?,
    );
    try pipelineBuilder.AddShaderStage(
        c.VK_SHADER_STAGE_FRAGMENT_BIT,
        shader.m_fragShader.?,
    );

    rContext.m_pipeline = try pipelineBuilder.BuildPipeline();
}

fn CreateRenderPass() !void {
    const rContext = try RenderContext.GetInstance();
    const colorAttachment = c.VkAttachmentDescription{
        .format = rContext.m_swapchain.m_format.format,
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
        .format = rContext.m_swapchain.m_format.format,
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

    try vkUtil.CheckVkSuccess(
        c.vkCreateRenderPass(rContext.m_logicalDevice, &renderPassInfo, null, &rContext.m_renderPass),
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
    return RenderContextError.FailedToFindSupportedFormat;
}

fn CreateCommandBuffers() !void {
    const rContext = try RenderContext.GetInstance();
    for (rContext.m_frameData, 0..) |_, i| {
        const allocInfo = c.VkCommandBufferAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = rContext.m_frameData[i].m_commandPool,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
            .pNext = null,
        };

        try vkUtil.CheckVkSuccess(
            c.vkAllocateCommandBuffers(
                rContext.m_logicalDevice,
                &allocInfo,
                &rContext.m_frameData[i].m_mainCommandBuffer,
            ),
            RenderContextError.FailedToCreateCommandBuffers,
        );
    }

    var i: usize = 0;
    while (i < rContext.m_frameData.len) : (i += 1) {
        var beginInfo = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pInheritanceInfo = null,
            .flags = 0,
            .pNext = null,
        };

        try vkUtil.CheckVkSuccess(
            c.vkBeginCommandBuffer(rContext.m_frameData[i].m_mainCommandBuffer, &beginInfo),
            RenderContextError.FailedToCreateCommandBuffers,
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
            .renderPass = rContext.m_renderPass,
            .framebuffer = rContext.m_swapchain.m_frameBuffers[i],
            .renderArea = c.VkRect2D{
                .offset = c.VkOffset2D{
                    .x = 0,
                    .y = 0,
                },
                .extent = rContext.m_swapchain.m_extent,
            },
            .clearValueCount = 2,
            .pClearValues = &clearValues,
            .pNext = null,
        };

        c.vkCmdBeginRenderPass(
            rContext.m_frameData[i].m_mainCommandBuffer,
            &renderPassInfo,
            c.VK_SUBPASS_CONTENTS_INLINE,
        );
        {
            //TODO scene.RenderObjects(commandBuffers[i], renderObjects);
        }
        c.vkCmdEndRenderPass(rContext.m_frameData[i].m_mainCommandBuffer);

        try vkUtil.CheckVkSuccess(
            c.vkEndCommandBuffer(rContext.m_frameData[i].m_mainCommandBuffer),
            RenderContextError.FailedToRecordCommandBuffers,
        );
    }
}

fn CreateCommandPool() !void {
    const rContext = try RenderContext.GetInstance();

    if (rContext.m_graphicsQueueIdx == null) {
        return RenderContextError.FailedToCreateCommandPool;
    }
    for (rContext.m_frameData, 0..) |_, i| {
        const poolInfo = c.VkCommandPoolCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .queueFamilyIndex = rContext.m_graphicsQueueIdx.?,
            .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .pNext = null,
        };

        try vkUtil.CheckVkSuccess(
            c.vkCreateCommandPool(
                rContext.m_logicalDevice,
                &poolInfo,
                null,
                &rContext.m_frameData[i].m_commandPool,
            ),
            RenderContextError.FailedToCreateCommandPool,
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

    var rContext = try RenderContext.GetInstance();
    for (rContext.m_frameData, 0..) |_, i| {
        try vkUtil.CheckVkSuccess(
            c.vkCreateSemaphore(rContext.m_logicalDevice, &semaphoreInfo, null, &rContext.m_frameData[i].m_renderSemaphore),
            RenderContextError.FailedToCreateSemaphores,
        );
        try vkUtil.CheckVkSuccess(
            c.vkCreateSemaphore(rContext.m_logicalDevice, &semaphoreInfo, null, &rContext.m_frameData[i].m_presentSemaphore),
            RenderContextError.FailedToCreateSemaphores,
        );
        try vkUtil.CheckVkSuccess(
            c.vkCreateFence(rContext.m_logicalDevice, &fenceInfo, null, &rContext.m_frameData[i].m_renderFence),
            RenderContextError.FailedToCreateFences,
        );
    }
}
