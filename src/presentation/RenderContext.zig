const c = @import("../c.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const vkUtil = @import("VulkanUtil.zig");
const swapchain = @import("Swapchain.zig");
const Swapchain = swapchain.Swapchain;
const PipelineBuilder = @import("PipelineBuilder.zig");
const Shader = @import("Shader.zig");

var instance: ?RenderContext = null;

const engineName = "Eden";
const engineVersion = c.VK_MAKE_API_VERSION(0, 0, 1, 0);

pub const RenderContextError = error{
    AlreadyInitialized,
    FailedToCheckInstanceLayerProperties,
    FailedToCreateCommandBuffers,
    FailedToCreateCommandPool,
    FailedToCreateFences,
    FailedToCreateImageView,
    FailedToCreateInstance,
    FailedToCreateLogicDevice,
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

    m_commandPool: c.VkCommandPool = undefined,
    m_commandBuffers: []c.VkCommandBuffer = undefined,

    // We want to stick to 4 descriptor sets due lower end hardware limitations
    // 0 = bound once per frame
    // 1 = bound once per pass
    // 2 = bound once per material (lives in the material)
    // 3 = bound once per material instance (lives in material instance)
    m_descriptorPool: c.VkDescriptorPool = undefined,

    m_perFrameDescriptorSetLayout: c.VkDescriptorSetLayout = undefined,
    m_perPassDescriptorSetLayout: c.VkDescriptorSetLayout = undefined,
    m_perFrameDescriptorSet: c.VkDescriptorSet = undefined,
    m_perPassDescriptorSet: c.VkDescriptorSet = undefined,

    //TODO should we have some material db where we create all necessary pipelines?
    m_pipelineLayout: c.VkPipelineLayout = undefined,
    m_pipeline: c.VkPipeline = undefined,

    m_msaaSamples: c.VkSampleCountFlagBits = c.VK_SAMPLE_COUNT_1_BIT,

    m_imageAvailableSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined,
    m_renderFinishedSemaphores: [BUFFER_FRAMES]c.VkSemaphore = undefined,
    m_inFlightFences: [BUFFER_FRAMES]c.VkFence = undefined,

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
        if (newInstance.m_graphicsQueueIdx == null or
            newInstance.m_presentQueueIdx == null)
        {
            return RenderContextError.NotInitialized;
        }
        newInstance.m_swapchain = try Swapchain.CreateSwapchain(
            allocator,
            newInstance.m_logicalDevice,
            newInstance.m_physicalDevice,
            newInstance.m_surface,
            newInstance.m_graphicsQueueIdx.?,
            newInstance.m_presentQueueIdx.?,
        );

        try newInstance.m_swapchain.CreateColorAndDepthResources(
            newInstance.m_logicalDevice,
            newInstance.m_msaaSamples,
        );

        try newInstance.m_swapchain.CreateFrameBuffers(
            allocator,
            newInstance.m_logicalDevice,
            newInstance.m_renderPass,
        );

        try CreateCommandPool();

        try CreateCommandBuffers(allocator);
    }

    pub fn Shutdown() void {
        if (instance == null) return;

        // if (enableValidationLayers) destroy debug utils messenger
        defer c.vkDestroyInstance(instance.?.m_vkInstance, null);

        defer c.vkDestroySurfaceKHR(instance.?.m_vkInstance, instance.?.m_surface, null);

        defer c.vkDestroyDevice(instance.?.m_logicalDevice, null);

        defer instance.DestroySwapchain();

        defer c.vkDestroyCommandPool(instance.?.m_logicalDevice, instance.?.m_commandPool, null);

        defer {
            var i: usize = 0;
            while (i < BUFFER_FRAMES) : (i += 1) {
                c.vkDestroySemaphore(instance.?.m_logicalDevice, instance.?.m_imageAvailableSemaphores[i], null);
                c.vkDestroySemaphore(instance.?.m_logicalDevice, instance.?.m_renderFinishedSemaphores[i], null);
                c.vkDestroyFence(instance.?.m_logicalDevice, instance.?.m_inFlightFences[i], null);
            }
        }
        instance = null;
    }

    pub fn RecreateSwapchain(self: *RenderContext, allocator: Allocator) !void {
        try vkUtil.CheckVkSuccess(
            c.vkDeviceWaitIdle(self.m_logicalDevice),
            RenderContextError.FailedToWait,
        );

        std.debug.print("Recreating Swapchain...\n", .{});
        self.DestroySwapchain();

        try Swapchain.CreateSwapchain(allocator, self);
        try CreateRenderPass();
        try swapchain.CreateColorAndDepthResources(
            self.m_logicalDevice,
            self.m_msaaSamples,
        );
        try swapchain.CreateFrameBuffers(
            allocator,
            self.m_logicalDevice,
            self.m_renderPass,
        );
        try CreateCommandBuffers(allocator);
    }

    pub fn DestroySwapchain(self: *RenderContext) void {
        defer {
            for (self.m_uniformBuffers) |*uniformBuffer| {
                uniformBuffer.DestroyBuffer(self.m_logicalDevice);
            }
            c.vkDestroyDescriptorPool(
                self.m_logicalDevice,
                self.m_descriptorPool,
                null,
            );
        }

        defer swapchain.FreeSwapchain(self.m_logicalDevice);

        defer c.vkDestroyRenderPass(self.m_logicalDevice, self.m_renderPass, null);

        defer swapchain.CleanupFrameBuffers(self.m_logicalDevice);

        defer c.vkFreeCommandBuffers(
            self.m_logicalDevice,
            self.m_commandPool,
            @intCast(u32, self.m_commandBuffers.len),
            self.m_commandBuffers.ptr,
        );

        defer swapchain.CleanupDepthAndColorImages(self.m_logicalDevice);
    }
};

const validationLayers = [_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};
fn CheckValidationLayerSupport(allocator: Allocator) !void {
    var layerCount: u32 = 0;
    try vkUtil.CheckVkSuccess(
        c.vkEnumerateInstanceLayerProperties(&layerCount, null),
        RenderContextError.FailedToCheckInstanceLayerProperties,
    );

    var detectedLayerProperties = try allocator.alloc(c.VkLayerProperties, layerCount);
    try vkUtil.CheckVkSuccess(
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

    var deviceList = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
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
        .enabledLayerCount = validationLayers.len,
        .ppEnabledLayerNames = &validationLayers,
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

fn CreateDescriptorPool() !void {
    const rContext = try RenderContext.GetInstance();
    const uboSize = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = @intCast(u32, rContext.swapchain.m_images.len),
    };
    const imageSamplerSize = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = @intCast(u32, rContext.swapchain.m_images.len),
    };

    const poolSizes = [_]c.VkDescriptorPoolSize{ uboSize, imageSamplerSize };
    const poolInfo = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = poolSizes.len,
        .pPoolSizes = &poolSizes,
        .maxSets = @intCast(u32, rContext.swapchain.m_images.len),
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

fn CreateDescriptorSets() !void {
    const rContext = RenderContext.GetInstance();
    var layouts = try allocator.alloc(
        c.VkDescriptorSetLayout,
        rContext.swapchain.m_images.len,
    );
    for (layouts) |*layout| {
        layout.* = descriptorSetLayout;
    }

    const allocInfo = c.VkDescriptorSetAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = descriptorPool,
        .descriptorSetCount = @intCast(u32, rContext.swapchain.m_images.len),
        .pSetLayouts = layouts.ptr,
        .pNext = null,
    };

    descriptorSets = try allocator.alloc(c.VkDescriptorSet, rContext.swapchain.m_images.len);
    try vkUtil.CheckVkSuccess(
        c.vkAllocateDescriptorSets(
            rContext.m_logicalDevice,
            &allocInfo,
            descriptorSets.ptr,
        ),
        vkUtil.VkError.FailedToCreateDescriptorSets,
    );

    var i: u32 = 0;
    while (i < swapchain.m_images.len) : (i += 1) {
        const bufferInfo = c.VkDescriptorBufferInfo{
            .buffer = uniformBuffers[i].m_buffer,
            .offset = 0,
            .range = @sizeOf(MeshUBO),
        };
        const imageInfo = c.VkDescriptorImageInfo{
            .imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            .imageView = textureImage.m_imageView,
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
        const descriptorWrites = [_]c.VkWriteDescriptorSet{
            uboDescriptorWrite,
            textureSamplerDescriptorWrite,
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
    vertShaderRelativePath: []const u8,
    fragShaderRelativePath: []const u8,
) !void {
    var shader = try Shader.CreateBasicShader(
        allocator,
        vertShaderRelativePath,
        fragShaderRelativePath,
    );
    defer shader.FreeShader();

    var pipelineBuilder: PipelineBuilder;

    const bindingDescription = Mesh.GetBindingDescription();
    const attribDescriptions = Mesh.GetAttributeDescriptions();
    pipelineBuilder.InitializeBuilder(
        c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        c.VK_POLYGON_MODE_FILL,
        bindingDescription,
        attribDescriptions,
    );

    pipelineBuilder.ClearShaderStages();
    pipelineBuilder.AddShaderStage(
        c.VK_SHADER_STAGE_VERTEX_BIT,
        shader.m_vertShader.?,
    );
    pipelineBuilder.AddShaderStage(
        c.VK_SHADER_STAGE_FRAGMENT_BIT,
        shader.m_fragShader.?,
    );

    m_pipeline = try pipelineBuilder.BuildPipeline(m_logicalDevice, m_renderPass);
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

fn CreateCommandBuffers(allocator: Allocator) !void {
    var rContext = try RenderContext.GetInstance();
    rContext.m_commandBuffers = try allocator.alloc(
        c.VkCommandBuffer,
        rContext.m_swapchain.m_frameBuffers.len,
    );
    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = rContext.m_commandPool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = @intCast(u32, rContext.m_commandBuffers.len),
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkAllocateCommandBuffers(rContext.m_logicalDevice, &allocInfo, rContext.m_commandBuffers.ptr),
        RenderContextError.FailedToCreateCommandBuffers,
    );

    var i: usize = 0;
    while (i < rContext.m_commandBuffers.len) : (i += 1) {
        var beginInfo = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pInheritanceInfo = null,
            .flags = 0,
            .pNext = null,
        };

        try vkUtil.CheckVkSuccess(
            c.vkBeginCommandBuffer(rContext.m_commandBuffers[i], &beginInfo),
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
            rContext.m_commandBuffers[i],
            &renderPassInfo,
            c.VK_SUBPASS_CONTENTS_INLINE,
        );
        {
            //TODO scene.RenderObjects(commandBuffers[i], renderObjects);
        }
        c.vkCmdEndRenderPass(rContext.m_commandBuffers[i]);

        try vkUtil.CheckVkSuccess(
            c.vkEndCommandBuffer(rContext.m_commandBuffers[i]),
            RenderContextError.FailedToRecordCommandBuffers,
        );
    }
}

fn CreateCommandPool() !void {
    const rContext = try RenderContext.GetInstance();

    if (rContext.m_graphicsQueueIdx == null) {
        return RenderContextError.FailedToCreateCommandPool;
    }
    const poolInfo = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = rContext.m_graphicsQueueIdx.?,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkCreateCommandPool(rContext.m_logicalDevice, &poolInfo, null, &rContext.m_commandPool),
        RenderContextError.FailedToCreateCommandPool,
    );
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
    var i: usize = 0;
    while (i < BUFFER_FRAMES) : (i += 1) {
        try vkUtil.CheckVkSuccess(
            c.vkCreateSemaphore(rContext.m_logicalDevice, &semaphoreInfo, null, &rContext.m_renderFinishedSemaphores[i]),
            RenderContextError.FailedToCreateSemaphores,
        );
        try vkUtil.CheckVkSuccess(
            c.vkCreateSemaphore(rContext.m_logicalDevice, &semaphoreInfo, null, &rContext.m_imageAvailableSemaphores[i]),
            RenderContextError.FailedToCreateSemaphores,
        );
        try vkUtil.CheckVkSuccess(
            c.vkCreateFence(rContext.m_logicalDevice, &fenceInfo, null, &rContext.m_inFlightFences[i]),
            RenderContextError.FailedToCreateFences,
        );
    }
}
