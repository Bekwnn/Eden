//TODO WIP initial vulkan implementation mainly referencing andrewrk/zig-vulkan-triangle and github gist YukiSnowy/dc31f47448ac61dd6aedee18b5d53858

const c = @import("../c.zig"); // keeping c import explicit for clarity

const std = @import("std");
const Allocator = std.mem.Allocator;

const VKInitError = error{
    //TODO
    VKError,
};

pub const BUFFER_FRAMES = 2;
pub var curFrameBufferIdx: u32 = 0;
pub var instance: c.VkInstance = undefined;
//var debugCallback: c.VkDebugReportCallbackEXT = undefined;
//var surface: c.VkSurfaceKHR = undefined;
//pub var physicalDevice: c.VkPhysicalDevice = undefined;
pub var globalDevice: c.VkDevice = undefined;
pub var graphicsQueue: c.VkQueue = undefined;
pub var presentQueue: c.VkQueue = undefined;
pub var swapChainImages: []c.VkImage = undefined;
pub var swapChain: c.VkSwapchainKHR = undefined;
//var swapChainImageFormat: c.VkFormat = undefined;
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

//const SwapChainSupportDetails = struct {
//    surfaceCapabilities: c.VkSurfaceCapabilitiesKHR,
//    formats: std.ArrayList(c.VkSurfaceFormatKHR),
//    presentModes: std.ArrayList(c.VkPresentModeKHR),
//
//    pub fn init(allocator: *Allocator) SwapChainSupportDetails {
//        var result = SwapChainSupportDetails{
//            .capabilities = undefined,
//            .formats = std.ArrayList(c.VkSurfaceFormatKHR).init(allocator),
//            .presentModes = std.ArrayList(c.VkPresentModeKHR).init(allocator),
//        };
//        const slice = mem.sliceAsBytes(@as(*[1]c.VkSurfaceCapabilitiesKHR, &result.capabilities)[0..1]);
//        std.mem.set(u8, slice, 0);
//        return result;
//    }
//
//    pub fn deinit(self: *SwapChainSupportDetails) void {
//        self.formats.deinit();
//        self.presentModes.deinit();
//    }
//};

pub fn CreateVKInstance(window: *SDL_Window) !void {
    const appInfo = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Eden Test",
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "Eden",
        .engineVersion = c.VK_MAKE_VERSION(0, 1, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
        .pNext = null,
    };

    var extensionCount: usize = 0;
    c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, null);
    var extensionNames = std.ArrayList([*]const u8).initCapacity(allocator, extensionCount);
    c.SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, &extensionNames.items);

    // TODO layers
    const instanceInfo = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = @intCast(u32, extensionNames.items.len),
        .ppEnabledExtensionNames = extensionNames.items.ptr,
        .pNext = null,
        .flags = 0,
    };

    const result = c.vkCreateInstance(&instanceInfo, null, &vkInstance);
    if (result != c.VK_SUCCESS) {
        c.SDL_LogMessage(c.SDL_LOG_CATEGORY_APPLICATION, c.SDL_LOG_PRIORITY_ERROR, "Create VK Instance Failed");
        return VKInitError.VKError;
    }
}

pub fn VulkanInit() !void {
    try CreateVKInstance(allocator);
    //try setupDebugCallback();
    try createSurface(window);
    try pickPhysicalDevice(allocator);
    try createLogicalDevice(allocator);
    try createSwapChain(allocator);
    try createImageViews(allocator);
    try createRenderPass();
    try createGraphicsPipeline(allocator);
    try createFramebuffers(allocator);
    try createCommandPool(allocator);
    try createCommandBuffers(allocator);
    try createSyncObjects();
}
