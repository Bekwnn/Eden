//const c = @import("../c.zig");
//const vk = @import("VulkanInit.zig");
//
//pub var renderPass: c.VkRenderPass = undefined;
//pub var descriptorPool: c.VkDescriptorPool = undefined;
//pub var commandBuffers: []c.VkCommandBuffer = undefined;
//pub var swapchainFrameBuffers: []c.VkFramebuffer = undefined;
//pub var igVulkanWindowData: c.ImGui_ImplVulkanH_Window = undefined;
//
//const IGError = error{
//    InitError,
//};
//
////TODO fix all the cppness of this func
//pub fn SetupVulkanWindow(wd: *ImGui_ImplVulkanH_Window, surface: VkSurfaceKHR, width: u32, height: u32)
//!void {
//    wd.Surface = surface;
//
//    // Check for WSI support
//    c.VkBool32 res;
//    c.vkGetPhysicalDeviceSurfaceSupportKHR(g_PhysicalDevice, g_QueueFamily, wd.Surface, &res);
//    if (res != c.VK_TRUE)
//    {
//        // no WSI support on physical device
//        return IGError.InitError;
//    }
//
//    // Select Surface Format
//    const requestSurfaceImageFormat = [_]VkFormat{ c.VK_FORMAT_B8G8R8A8_UNORM, c.VK_FORMAT_R8G8B8A8_UNORM, c.VK_FORMAT_B8G8R8_UNORM, c.VK_FORMAT_R8G8B8_UNORM };
//    const requestSurfaceColorSpace: c.VkColorSpaceKHR= c.VK_COLORSPACE_SRGB_NONLINEAR_KHR;
//    wd.SurfaceFormat = c.ImGui_ImplVulkanH_SelectSurfaceFormat(g_PhysicalDevice, wd.Surface, requestSurfaceImageFormat, (size_t)IM_ARRAYSIZE(requestSurfaceImageFormat), requestSurfaceColorSpace);
//
//    // Select Present Mode
//    //if (IMGUI_UNLIMITED_FRAME_RATE)
//    //{
//    //    VkPresentModeKHR present_modes[] = { VK_PRESENT_MODE_MAILBOX_KHR, VK_PRESENT_MODE_IMMEDIATE_KHR, VK_PRESENT_MODE_FIFO_KHR };
//    //}
//    //else
//    //{
//    //    VkPresentModeKHR present_modes[] = { VK_PRESENT_MODE_FIFO_KHR };
//    //}
//    wd.PresentMode = c.ImGui_ImplVulkanH_SelectPresentMode(g_PhysicalDevice, wd.Surface, &present_modes[0], IM_ARRAYSIZE(present_modes));
//    //printf("[vulkan] Selected PresentMode = %d\n", wd->PresentMode);
//
//    // Create SwapChain, RenderPass, Framebuffer, etc.
//    IM_ASSERT(g_MinImageCount >= 2);
//    ImGui_ImplVulkanH_CreateWindow(g_Instance, g_PhysicalDevice, g_Device, wd, g_QueueFamily, g_Allocator, width, height, g_MinImageCount);
//}
//
//pub fn InitImgui(window: *c.SDL_Window) !void {
//    //TODO handle returns
//    //TODO w/h should actually be correct and not fixed
//    c.SetupVulkanWindow(&igVulkanWindowData, vk.surface, 1280, 720);
//
//    _ = c.igCreateContext(null);
//
//    c.igStyleColorsDark();
//
//    _ = c.ImGui_ImplSDL2_InitForVulkan(window);
//    const imguiVulkanInitInfo = c.ImGui_ImplVulkan_InitInfo{
//        .Instance = vk.instance,
//        .PhysicalDevice = vk.physicalDevice,
//        .Device = vk.logicalDevice,
//        //TODO double check these two fields should be the graphics queue
//        .QueueFamily = vk.queueFamilyDetails.graphicsQueueIdx,
//        .Queue = vk.graphicsQueue,
//        .PipelineCache = vk.pipelineCache,
//        .DescriptorPool = descriptorPool, //TODO should this be the same pool?
//        .Allocator = null,
//        .MinImageCount = vk.BUFFER_FRAMES,
//        .ImageCount = igVulkanWindowData.ImageCount,
//        .CheckVkResultFn = null,
//    };
//    c.ImGui_ImplVulkan_Init(&imguiVulkanInitInfo, igVulkanWindowData.RenderPass);
//
//    // Upload Fonts
//    {
//        var wd: *c.ImGui_ImplVulkanH_Window = &igVulkanWindowData;
//        // Use any command queue
//        var commandPool: c.VkCommandPool = wd.Frames[wd.FrameIndex].CommandPool;
//        var commandBuffer: c.VkCommandBuffer = wd.Frames[wd.FrameIndex].CommandBuffer;
//
//        try vk.CheckVkSuccess(
//            c.vkResetCommandPool(vk.logicalDevice, commandPool, 0),
//            IGError.InitError,
//        );
//        const beginInfo = c.VkCommandBufferBeginInfo{
//            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
//            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
//        };
//        try vk.CheckVkSuccess(
//            c.vkBeginCommandBuffer(commandBuffer, &beginInfo),
//            IGError.InitError,
//        );
//
//        c.ImGui_ImplVulkan_CreateFontsTexture(commandBuffer);
//
//        const endInfo = c.VkSubmitInfo{
//            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
//            .commandBufferCount = 1,
//            .pCommandBuffers = &commandBuffer,
//        };
//        try vk.CheckVkSuccess(
//            c.vkEndCommandBuffer(commandBuffer),
//            IGError.InitError,
//        );
//        try vk.CheckVkSuccess(
//            c.vkQueueSubmit(vk.graphicsQueue, 1, &endInfo, null),
//            IGError.InitError,
//        );
//
//        _ = c.vkDeviceWaitIdle(vk.logicalDevice);
//        c.ImGui_ImplVulkan_DestroyFontUploadObjects();
//    }
//}
//
//pub fn CleanupImgui() void {
//    //TODO handle return
//    _ = c.vkDeviceWaitIdle(vk.logicalDevice);
//    defer c.igDestroyContext(null);
//    defer c.ImGui_ImplVulkanH_DestroyWindow(
//        vk.instance,
//        vk.logicalDevice,
//        &igVulkanWindowData,
//        null,
//    );
//    defer c.ImGui_ImplSDL2_Shutdown();
//    defer c.ImGui_ImplVulkan_Shutdown();
//}
