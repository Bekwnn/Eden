//TODO WIP initial vulkan implementation

const std = @import("std");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const Shader = @import("Shader.zig").Shader;
const Mesh = @import("Mesh.zig").Mesh;
const assimp = @import("AssImpInterface.zig");
const Camera = @import("Camera.zig").Camera;
const vk = @import("VulkanInit.zig");

const mat4x4 = @import("../math/Mat4x4.zig");

const game = @import("../game/GameWorld.zig");
const GameWorld = @import("../game/GameWorld.zig").GameWorld;

const filePathUtils = @import("../coreutil/FilePathUtils.zig");

const c = @import("../c.zig");

var curShader: ?u32 = null;
var curTime: f32 = 0.0;
const circleTime: f32 = 1.0 / (2.0 * std.math.pi);
const circleRadius: f32 = 0.5;

const RenderLoopError = error{
    FailedToSubmitDrawCommandBuffer,
    FailedToQueuePresent,
    FailedToQueueWaitIdle,
    FailedToWaitForInFlightFence,
    FailedToWaitForImageFence,
    FailedToResetFences,
    FailedToResetCommandBuffer,
    FailedToAcquireNextImage,
    FailedToBeginCommandBuffer,
    FailedToEndCommandBuffer,
    MissingMesh,
};

//var imguiIO: ?*ImGuiIO = null;

//fn ImguiInit() void {
//    imguiIO = igGetIO();
//    if (imguiIO) |io| {
//        var text_pixels: [*c]u8 = undefined;
//        var text_w: i32 = undefined;
//        var text_h: i32 = undefined;
//        ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &text_pixels, &text_w, &text_h, null);
//    } else {
//        @panic("imguiIO is null");
//    }
//}

pub fn OnWindowResized(window: *c.SDL_Window) !void {
    var width: c_int = 0;
    var height: c_int = 0;
    c.SDL_GetWindowSize(window, &width, &height);
    debug.print("Window resized to {} x {}\n", .{ width, height });
    vk.curCamera.m_aspectRatio = @intToFloat(f32, width) / @intToFloat(f32, height);
    try vk.RecreateSwapchain(allocator);
}

pub fn Initialize() void {
    const meshPath = filePathUtils.CwdToAbsolute(allocator, "test-assets\\test.obj") catch {
        @panic("!");
    };
    defer allocator.free(meshPath);
    if (assimp.ImportMesh(meshPath)) |mesh| {
        vk.curMesh = mesh;
    } else |meshErr| {
        debug.print("Error importing mesh: {}\n", .{meshErr});
    }

    //TODO get imgui working again
    //ImguiInit();
}

pub fn RecordCommandBuffer(commandBuffer: c.VkCommandBuffer, imageIndex: u32) !void {
    const beginInfo = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = null,
        .flags = 0,
        .pInheritanceInfo = null,
    };

    try vk.CheckVkSuccess(
        c.vkBeginCommandBuffer(commandBuffer, &beginInfo),
        RenderLoopError.FailedToBeginCommandBuffer,
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
        .renderPass = vk.renderPass,
        .framebuffer = vk.swapchain.m_frameBuffers[imageIndex],
        .renderArea = c.VkRect2D{
            .offset = c.VkOffset2D{
                .x = 0,
                .y = 0,
            },
            .extent = vk.swapchain.m_extent,
        },
        .clearValueCount = 2,
        .pClearValues = &clearValues,
        .pNext = null,
    };

    c.vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, c.VK_SUBPASS_CONTENTS_INLINE);
    {
        c.vkCmdBindPipeline(commandBuffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, vk.graphicsPipeline);

        const vertexBuffers = [_]c.VkBuffer{vk.vertexBuffer};
        const offsets = [_]c.VkDeviceSize{0};
        c.vkCmdBindVertexBuffers(commandBuffer, 0, 1, &vertexBuffers, &offsets);

        c.vkCmdBindIndexBuffer(commandBuffer, vk.indexBuffer, 0, c.VK_INDEX_TYPE_UINT32);

        c.vkCmdBindDescriptorSets(commandBuffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, vk.pipelineLayout, 0, 1, &vk.descriptorSets[currentFrame], 0, null);

        //TODO testing mesh
        if (vk.curMesh) |*meshPtr| {
            c.vkCmdDrawIndexed(commandBuffer, @intCast(u32, meshPtr.m_indices.items.len), 1, 0, 0, 0);
        } else {
            return RenderLoopError.MissingMesh;
        }
    }
    c.vkCmdEndRenderPass(commandBuffer);

    try vk.CheckVkSuccess(
        c.vkEndCommandBuffer(commandBuffer),
        RenderLoopError.FailedToEndCommandBuffer,
    );
}

//fn ImguiUpdate() void {
//    //imgui update
//    var window_w: i32 = undefined;
//    var window_h: i32 = undefined;
//    SDL_GetWindowSize(screen, &window_w, &window_h);
//    if (imguiIO) |io| {
//        io.DisplaySize.x = @intToFloat(f32, window_w);
//        io.DisplaySize.y = @intToFloat(f32, window_h);
//        io.DeltaTime = 1.0 / 60.0;
//    } else {
//        @panic("imguiIO is null");
//    }
//
//    ImGui_ImplOpenGL3_NewFrame();
//    ImGui_ImplSDL2_NewFrame(screen);
//    igNewFrame();
//
//    igShowDemoWindow(null);
//
//    igRender();
//    ImGui_ImplOpenGL3_RenderDrawData(igGetDrawData());
//}

//TODO make a generalized function
var framebufferResized = false;
var showDemoWindow = true;
var f: f32 = 0.0;
var counter: u32 = 0;
//TODO
//pub fun FramebufferResizeCallback(GLFWwindow* window, u32 width, u32 height) void {
//    framebufferResized = true;
//}
var currentFrame: usize = 0;
//pub fn RenderFrame(window: *c.SDL_Window) !void { //ImGui
pub fn RenderFrame() !void {
    const swapchainAllocator = std.heap.page_allocator;

    vk.curCamera.m_pos.z = -2.0;
    curTime += game.deltaTime;
    vk.curCamera.m_pos.x = circleRadius * std.math.cos(curTime / (std.math.tau * circleTime));
    vk.curCamera.m_pos.y = circleRadius * std.math.sin(curTime / (std.math.tau * circleTime));

    //c.ImGui_ImplVulkan_NewFrame();
    //c.ImGui_ImplSDL2_NewFrame(window);
    //c.igNewFrame();
    //c.igShowDemoWindow(&showDemoWindow);
    //c.igBegin("Hello, world!");
    //{
    //    c.igText("This is some useful text.");
    //    c.igCheckbox("Demo Window", &showDemoWindow);

    //    c.igSliderFloat("float", &f, 0.0, 1.0);

    //    if (c.igButton("Button")) {
    //        counter += 1;
    //    }

    //    c.igSameLine();
    //    c.igText("counter = %d", counter);

    //    c.igText("Application average {} ms/frame ({} FPS)", 1000.0 / c.igGetIO().Framerate, c.igGetIO().Framerate);
    //}
    //c.igEnd();

    //c.igRender();

    const fencesResult = c.vkWaitForFences(vk.logicalDevice, 1, &vk.inFlightFences[currentFrame], c.VK_TRUE, 2000000000);
    if (fencesResult != c.VK_SUCCESS and fencesResult != c.VK_TIMEOUT) {
        return RenderLoopError.FailedToWaitForInFlightFence;
    }

    var imageIndex: u32 = 0;
    const acquireImageResult = c.vkAcquireNextImageKHR(vk.logicalDevice, vk.swapchain.m_swapchain, std.math.maxInt(u64), vk.imageAvailableSemaphores[currentFrame], null, &imageIndex);
    if (acquireImageResult == c.VK_ERROR_OUT_OF_DATE_KHR) {
        try vk.RecreateSwapchain(swapchainAllocator);
        return;
    } else if (acquireImageResult != c.VK_SUCCESS and acquireImageResult != c.VK_SUBOPTIMAL_KHR) {
        return RenderLoopError.FailedToAcquireNextImage;
    }

    try vk.UpdateUniformBuffer(&vk.curCamera, currentFrame);

    try vk.CheckVkSuccess(
        c.vkResetFences(vk.logicalDevice, 1, &vk.inFlightFences[currentFrame]),
        RenderLoopError.FailedToResetFences,
    );

    //vkResetCommandBuffer?
    try vk.CheckVkSuccess(
        c.vkResetCommandBuffer(vk.commandBuffers[imageIndex], 0),
        RenderLoopError.FailedToResetCommandBuffer,
    );
    try RecordCommandBuffer(vk.commandBuffers[imageIndex], imageIndex);

    const waitSemaphores = [_]c.VkSemaphore{vk.imageAvailableSemaphores[currentFrame]};
    const waitStages = [_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    const signalSemaphores = [_]c.VkSemaphore{vk.renderFinishedSemaphores[currentFrame]};
    const submitInfo = c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &waitSemaphores,
        .pWaitDstStageMask = &waitStages,
        .commandBufferCount = 1,
        .pCommandBuffers = &vk.commandBuffers[imageIndex],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &signalSemaphores,
        .pNext = null,
    };

    try vk.CheckVkSuccess(
        c.vkQueueSubmit(vk.graphicsQueue, 1, &submitInfo, vk.inFlightFences[currentFrame]),
        RenderLoopError.FailedToSubmitDrawCommandBuffer,
    );

    const swapchains = [_]c.VkSwapchainKHR{vk.swapchain.m_swapchain};
    const presentInfo = c.VkPresentInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &signalSemaphores,
        .swapchainCount = 1,
        .pSwapchains = &swapchains,
        .pImageIndices = &imageIndex,
        .pResults = null,
        .pNext = null,
    };

    //TODO get imgui working again
    //ImguiUpdate()

    const queuePresentResult = c.vkQueuePresentKHR(vk.presentQueue, &presentInfo);

    if (queuePresentResult == c.VK_ERROR_OUT_OF_DATE_KHR or queuePresentResult == c.VK_SUBOPTIMAL_KHR or framebufferResized) {
        framebufferResized = false;
        try vk.RecreateSwapchain(swapchainAllocator);
    } else if (queuePresentResult != c.VK_SUCCESS) {
        return RenderLoopError.FailedToQueuePresent;
    }

    currentFrame = (currentFrame + 1) % vk.BUFFER_FRAMES;
}
