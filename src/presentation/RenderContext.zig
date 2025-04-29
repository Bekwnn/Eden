const c = @import("../c.zig");

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const DeletionQueue = @import("../coreutil/DeletionQueue.zig").DeletionQueue;

const Buffer = @import("Buffer.zig").Buffer;
const DescriptorAllocator = @import("DescriptorAllocator.zig").DescriptorAllocator;
const DescriptorLayoutBuilder = @import("DescriptorLayoutBuilder.zig").DescriptorLayoutBuilder;
const FrameUBO = @import("Camera.zig").FrameUBO;
const GPUSceneData = @import("Scene.zig").GPUSceneData;
const Mesh = @import("Mesh.zig").Mesh;
const ShaderEffect = @import("ShaderEffect.zig").ShaderEffect;
const swapchain = @import("Swapchain.zig");
const Swapchain = swapchain.Swapchain;
const vkUtil = @import("VulkanUtil.zig");

var instance: ?RenderContext = null;

const engineName = "Eden";
const engineVersion = c.VK_MAKE_API_VERSION(0, 0, 1, 0);

//TODO
// all the functions that are outside of the RenderContext struct but are accessing rContext should
// really just be moved inside the struct and take a (self: *RenderContext)

pub const RenderContextError = error{
    AlreadyInitialized,
    FailedToBeginCommandBuffer,
    FailedToCheckInstanceLayerProperties,
    FailedToCreateCommandBuffers,
    FailedToCreateCommandPool,
    FailedToCreateDescriptorPool,
    FailedToCreateDescriptorSets,
    FailedToCreateFences,
    FailedToCreateImageView,
    FailedToCreateInstance,
    FailedToCreateLogicDevice,
    FailedToCreatePipelineLayout,
    FailedToCreateRenderPass,
    FailedToCreateSemaphores,
    FailedToCreateSurface,
    FailedToEndCommandBuffer,
    FailedToFindPhysicalDevice,
    FailedToFindSupportedFormat,
    FailedToInitImgui,
    FailedToQueueSubmit,
    FailedToRecordCommandBuffers,
    FailedToResetCommandBuffer,
    FailedToResetFence,
    FailedToWait,
    MissingValidationLayer,
    UninitializedShutdown,

    // device with vulkan support detected; does not satisfy properties
    NoSuitableDevice,

    // no device supporting vulkan detected
    NoSupportedDevice,

    NotInitialized,
};

//TODO gets used by shader system move out to its own file maybe?
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
    m_swapchainSemaphore: c.VkSemaphore,
    m_renderSemaphore: c.VkSemaphore,
    m_renderFence: c.VkFence,

    m_commandPool: c.VkCommandPool,
    m_mainCommandBuffer: c.VkCommandBuffer,

    // descriptor set 0 scene data used by most shaders
    m_gpuSceneData: GPUSceneData = undefined,
    m_gpuSceneDataBuffer: Buffer = undefined,
    m_gpuSceneDataDescriptorSet: c.VkDescriptorSet = undefined,

    // do we want one for each frame?
    m_descriptorAllocator: DescriptorAllocator,
};

pub const FRAMES_IN_FLIGHT = 2;

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

    // descriptor set 0 data shared across shaders/materials
    // includes some fundamental scene data like global lights, view and projection matrix
    m_gpuSceneDescriptorLayout: c.VkDescriptorSetLayout = undefined,

    m_frameData: [FRAMES_IN_FLIGHT]FrameData = undefined,
    m_currentFrame: u32 = 0,

    m_msaaSamples: c.VkSampleCountFlagBits = c.VK_SAMPLE_COUNT_1_BIT,
    m_maxDescriptorSets: u32 = 0,

    // used by imgui
    m_immediateFence: c.VkFence = undefined,
    m_immediateCommandBuffer: c.VkCommandBuffer = undefined,
    m_immediateCommandPool: c.VkCommandPool = undefined,

    m_imguiPool: c.VkDescriptorPool = undefined,

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

        std.debug.print("Creating command pool...\n", .{});
        try CreateCommandPool();

        std.debug.print("Creating command buffers...\n", .{});
        try CreateCommandBuffers();

        std.debug.print("Creating fences and semaphores...\n", .{});
        try CreateFencesAndSemaphores();

        std.debug.print("Creating render pass...\n", .{});
        try CreateRenderPass();

        std.debug.print("Creating descriptor allocators...\n", .{});
        try CreateDescriptorAllocators(allocator);

        std.debug.print("Creating gpu scene data...\n", .{});
        try InitGPUSceneData(allocator);

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

        std.debug.print("Creating Imgui resources...\n", .{});
        try InitImgui(window);
    }

    pub fn Shutdown(self: *RenderContext) void {
        // TODO if (enableValidationLayers) destroy debug utils messenger
        // TODO teardown out of date
        defer c.vkDestroyInstance(self.m_vkInstance, null);

        defer c.vkDestroySurfaceKHR(self.m_vkInstance, self.m_surface, null);

        defer c.vkDestroyDevice(instance.?.m_logicalDevice, null);

        defer self.DestroySwapchain();

        defer {
            for (&self.m_frameData) |*frameData| {
                c.vkDestroySemaphore(self.m_logicalDevice, frameData.m_swapchainSemaphore, null);
                c.vkDestroySemaphore(self.m_logicalDevice, frameData.m_renderSemaphore, null);
                c.vkDestroyFence(self.m_logicalDevice, frameData.m_renderFence, null);

                // destroying the parent pool frees all command buffers allocated with it
                c.vkDestroyCommandPool(self.m_logicalDevice, frameData.m_commandPool, null);
            }
        }
        instance = null;
    }

    pub fn GetCurrentFrame(self: *RenderContext) *FrameData {
        return &self.m_frameData[self.m_currentFrame % FRAMES_IN_FLIGHT];
    }

    //TODO move to swapchain
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

        //TODO check if we really need to recreate command buffers?
        // maybe they rely on swapchain state?
        try CreateCommandBuffers();
    }

    //TODO redo + move to swapchain
    pub fn DestroySwapchain(self: *RenderContext) void {
        defer {
            for (&self.m_frameData) |*frameData| {
                frameData.m_descriptorAllocator.deinit(self.m_logicalDevice);
            }
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

    // usage: call BeginImmedaiteSubmit(), record to the command buffer, call FinishImmediateSubmit()
    pub fn BeginImmediateSubmit() !c.VkCommandBuffer {
        const rContext = RenderContext.GetInstance();

        try vkUtil.CheckVkSuccess(
            c.vkResetFences(rContext.m_logicalDevice, 1, &rContext.m_immediateFence),
            RenderContextError.FailedToResetFence,
        );
        try vkUtil.CheckVkSuccess(
            c.vkResetCommandBuffer(rContext.m_immediateCommandBuffer, 0),
            RenderContextError.FailedToResetCommandBuffer,
        );

        const beginInfo = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null,
            .pNext = null,
        };

        try vkUtil.CheckVkSuccess(
            c.vkBeginCommandBuffer(rContext.m_immediateCommandBuffer, &beginInfo),
            RenderContextError.FailedToBeginCommandBuffer,
        );

        return rContext.m_immediateCommandBuffer;
    }

    pub fn FinishImmediateSubmit() !void {
        const rContext = RenderContext.GetInstance();

        try vkUtil.CheckVkSuccess(
            c.vkEndCommandBuffer(rContext.m_immediateCommandBuffer),
            RenderContextError.FailedToEndCommandBuffer,
        );

        const submitInfo = c.VkSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .commandBufferCount = 1,
            .pCommandBuffers = &rContext.m_immediateCommandBuffer,
            .pNext = null,
            .waitSemaphoreCount = 0,
            .pWaitSemaphores = null,
            .pWaitDstStageMask = null,
            .signalSemaphoreCount = 0,
            .pSignalSemaphores = null,
        };

        try vkUtil.CheckVkSuccess(
            c.vkQueueSubmit(rContext.m_graphicsQueue, 1, &submitInfo, rContext.m_immediateFence),
            RenderContextError.FailedToQueueSubmit,
        );
        try vkUtil.CheckVkSuccess(
            c.vkWaitForFences(rContext.m_logicalDevice, 1, &rContext.m_immediateFence, true, 9999999999),
            RenderContextError.FailedToWaitForFences,
        );
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
    const extensionNames = try allocator.alloc([*:0]const u8, extensionCount);
    defer allocator.free(extensionNames);
    _ = c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, @ptrCast(extensionNames.ptr));

    try CheckValidationLayerSupport(allocator);
    const instanceInfo = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledLayerCount = @intCast(validationLayers.len),
        .ppEnabledLayerNames = @ptrCast(validationLayers[0..].ptr),
        .enabledExtensionCount = @intCast(extensionNames.len),
        .ppEnabledExtensionNames = extensionNames.ptr,
        .flags = 0,
        .pNext = null,
    };

    const logLayersAndExtensions = true;
    if (logLayersAndExtensions) {
        std.debug.print("Enabled Extensions:\n", .{});
        for (extensionNames) |extName| {
            std.debug.print(" {s}\n", .{extName});
        }

        std.debug.print("Enabled Validation Layers:\n", .{});
        for (validationLayers) |layerName| {
            std.debug.print(" {s}\n", .{layerName});
        }
    }

    const rContext = try RenderContext.GetInstance();
    try vkUtil.CheckVkSuccess(
        c.vkCreateInstance(&instanceInfo, null, &rContext.m_vkInstance),
        RenderContextError.FailedToCreateInstance,
    );
}

//TODO pass in a list of required/enabled extensions
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

    //Create list of physical device features we want

    //TODO rather than just picking first suitable device, could rate/score by some scheme and pick the best
    for (deviceList) |device| {
        if (try PhysicalDeviceIsSuitable(allocator, device, window, rContext.m_surface, &requiredFeatures)) {
            rContext.m_physicalDevice = device;
            rContext.m_msaaSamples = try GetDeviceMaxUsableSampleCount();
            rContext.m_maxDescriptorSets = try GetDeviceMaxDescriptorSets();
            return;
        }
    }

    return RenderContextError.NoSuitableDevice;
}

const requiredDeviceExtensions = [_][*]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    c.VK_KHR_CREATE_RENDERPASS_2_EXTENSION_NAME, // required by DEPTH_STENCIL_RESOLVE
    c.VK_KHR_DEPTH_STENCIL_RESOLVE_EXTENSION_NAME, // required by DYNAMIC_RENDERING
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
    },
};
fn PhysicalDeviceIsSuitable(allocator: Allocator, device: c.VkPhysicalDevice, window: *c.SDL_Window, surface: c.VkSurfaceKHR, enabledFeatures: *const c.VkPhysicalDeviceFeatures2) !bool {
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
        try EnabledFeaturesExist(enabledFeatures, &deviceFeatures);
}

fn CheckFeatureFieldsAreSupported(
    comptime FeatureType: type,
    enabledFeatures: *const FeatureType,
    physicalFeatures: *const FeatureType,
) bool {
    inline for (@typeInfo(FeatureType).Struct.fields) |f| {
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
    if (!CheckFeatureFieldsAreSupported(c.VkPhysicalDeviceFeatures, &enabledFeatures.features, &physicalDeviceFeatures.features)) {
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
                else => return RenderContextError.FailedToFindPhysicalDevice, //sType was wrong?
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
        RenderContextError.FailedToCreateLogicDevice,
    );

    if (rContext.m_logicalDevice) |*ld| {
        c.vkGetDeviceQueue(ld.*, graphicsQueueIndex orelse return RenderContextError.FailedToCreateLogicDevice, 0, &rContext.m_graphicsQueue);
        c.vkGetDeviceQueue(ld.*, presentQueueIndex orelse return RenderContextError.FailedToCreateLogicDevice, 0, &rContext.m_presentQueue);
    }
}

fn GetDeviceMaxUsableSampleCount() !c.VkSampleCountFlagBits {
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

fn GetDeviceMaxDescriptorSets() !u32 {
    const rContext = try RenderContext.GetInstance();
    var deviceProperties: c.VkPhysicalDeviceProperties = undefined;
    c.vkGetPhysicalDeviceProperties(rContext.m_physicalDevice, &deviceProperties);

    std.debug.print("Max bound descriptor sets detected: {}\n", .{deviceProperties.limits.maxBoundDescriptorSets});
    return deviceProperties.limits.maxBoundDescriptorSets;
}

fn CreateDescriptorAllocators(allocator: Allocator) !void {
    const rContext = try RenderContext.GetInstance();

    const frameSizes = [_]DescriptorAllocator.PoolSizeRatio{
        .{ .m_descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, .m_ratio = 3 },
        .{ .m_descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .m_ratio = 3 },
        .{ .m_descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, .m_ratio = 3 },
        .{ .m_descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, .m_ratio = 4 },
    };

    // Creates a descriptor pool that will hold as much as in frame sizes times 1000
    for (&rContext.m_frameData) |*frameData| {
        frameData.m_descriptorAllocator = try DescriptorAllocator.init(allocator, rContext.m_logicalDevice, 1000, &frameSizes);
    }
}

fn InitGPUSceneData(allocator: Allocator) !void {
    var rContext = try RenderContext.GetInstance();
    var builder = DescriptorLayoutBuilder.init(allocator);
    try builder.AddBinding(0, c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER);
    rContext.m_gpuSceneDescriptorLayout = try builder.Build(
        rContext.m_logicalDevice,
        c.VK_SHADER_STAGE_VERTEX_BIT | c.VK_SHADER_STAGE_FRAGMENT_BIT,
    );

    const sizeOfSceneData = @sizeOf(@TypeOf(rContext.m_frameData[0].m_gpuSceneData));
    for (&rContext.m_frameData) |*frameData| {
        frameData.m_gpuSceneDataBuffer = try Buffer.CreateBuffer(
            sizeOfSceneData,
            c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );

        try frameData.m_gpuSceneDataBuffer.MapMemory(@ptrCast(&frameData.m_gpuSceneData), sizeOfSceneData);

        frameData.m_gpuSceneDataDescriptorSet = try frameData.m_descriptorAllocator.Allocate(
            rContext.m_logicalDevice,
            rContext.m_gpuSceneDescriptorLayout,
        );
    }
}

fn InitImgui(window: *c.SDL_Window) !void {
    //per vkguide: probably overkill
    const poolSizes = [_]c.VkDescriptorPoolSize{
        c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_SAMPLER, .descriptorCount = 1000 },
        c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, .descriptorCount = 1000 },
        c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, .descriptorCount = 1000 },
        c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER, .descriptorCount = 1000 },
        c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER, .descriptorCount = 1000 },
        c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, .descriptorCount = 1000 },
        c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .descriptorCount = 1000 },
        c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC, .descriptorCount = 1000 },
        c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC, .descriptorCount = 1000 },
        c.VkDescriptorPoolSize{ .type = c.VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT, .descriptorCount = 1000 },
    };

    const poolInfo = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .maxSets = 1000,
        .poolSizeCount = poolSizes.len,
        .pPoolSizes = &poolSizes,
        .flags = 0,
    };

    const rContext = try RenderContext.GetInstance();
    try vkUtil.CheckVkSuccess(
        c.vkCreateDescriptorPool(rContext.m_logicalDevice, &poolInfo, null, &rContext.m_imguiPool),
        RenderContextError.FailedToInitImgui,
    );

    //TODO handle return vals
    _ = c.igCreateContext(null);

    _ = c.ImGui_ImplSDL2_InitForVulkan(window);

    var imguiInitInfo = c.ImGui_ImplVulkan_InitInfo{
        .Instance = rContext.m_vkInstance,
        .PhysicalDevice = rContext.m_physicalDevice,
        .Device = rContext.m_logicalDevice,
        .Queue = rContext.m_graphicsQueue,
        .DescriptorPool = rContext.m_imguiPool,
        .MinImageCount = 3,
        .ImageCount = 3,
        .UseDynamicRendering = true,
        .PipelineRenderingCreateInfo = c.VkPipelineRenderingCreateInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = &rContext.m_swapchain.m_format.format,
        },
        .MSAASamples = c.VK_SAMPLE_COUNT_1_BIT,
    };

    _ = c.ImGui_ImplVulkan_Init(&imguiInitInfo);

    _ = c.ImGui_ImplVulkan_CreateFontsTexture();

    //TODO create cleanup function, destory m_imguiPool
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
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | c.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
        .srcAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | c.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
        .dependencyFlags = 0,
    };
    const attachments = [_]c.VkAttachmentDescription{ colorAttachment, depthAttachment, colorAttachmentResolve };
    const renderPassInfo = c.VkRenderPassCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = attachments.len,
        .pAttachments = &attachments,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,
        .pNext = null,
        .flags = 0,
    };

    try vkUtil.CheckVkSuccess(
        c.vkCreateRenderPass(rContext.m_logicalDevice, &renderPassInfo, null, &rContext.m_renderPass),
        RenderContextError.FailedToCreateRenderPass,
    );
}

//TODO shared function used by swapchain.zig; should this live here?
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

    for (&rContext.m_frameData) |*frameData| {
        // Create main command buffers
        const allocInfo = c.VkCommandBufferAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = frameData.m_commandPool,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
            .pNext = null,
        };

        try vkUtil.CheckVkSuccess(
            c.vkAllocateCommandBuffers(
                rContext.m_logicalDevice,
                &allocInfo,
                &frameData.m_mainCommandBuffer,
            ),
            RenderContextError.FailedToCreateCommandBuffers,
        );
    }

    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = rContext.m_immediateCommandPool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkAllocateCommandBuffers(
            rContext.m_logicalDevice,
            &allocInfo,
            &rContext.m_immediateCommandBuffer,
        ),
        RenderContextError.FailedToCreateCommandBuffers,
    );
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

    for (&rContext.m_frameData) |*frameData| {
        try vkUtil.CheckVkSuccess(
            c.vkCreateCommandPool(
                rContext.m_logicalDevice,
                &poolInfo,
                null,
                &frameData.m_commandPool,
            ),
            RenderContextError.FailedToCreateCommandPool,
        );
    }

    try vkUtil.CheckVkSuccess(
        c.vkCreateCommandPool(
            rContext.m_logicalDevice,
            &poolInfo,
            null,
            &rContext.m_immediateCommandPool,
        ),
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
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
        .pNext = null,
    };

    var rContext = try RenderContext.GetInstance();
    for (&rContext.m_frameData) |*frameData| {
        try vkUtil.CheckVkSuccess(
            c.vkCreateSemaphore(rContext.m_logicalDevice, &semaphoreInfo, null, &frameData.m_renderSemaphore),
            RenderContextError.FailedToCreateSemaphores,
        );
        try vkUtil.CheckVkSuccess(
            c.vkCreateSemaphore(rContext.m_logicalDevice, &semaphoreInfo, null, &frameData.m_swapchainSemaphore),
            RenderContextError.FailedToCreateSemaphores,
        );
        try vkUtil.CheckVkSuccess(
            c.vkCreateFence(rContext.m_logicalDevice, &fenceInfo, null, &frameData.m_renderFence),
            RenderContextError.FailedToCreateFences,
        );
    }

    try vkUtil.CheckVkSuccess(
        c.vkCreateFence(rContext.m_logicalDevice, &fenceInfo, null, &rContext.m_immediateFence),
        RenderContextError.FailedToCreateFences,
    );
}
