//TODO WIP initial vulkan implementation mainly referencing andrewrk/zig-vulkan-triangle and github gist YukiSnowy/dc31f47448ac61dd6aedee18b5d53858

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
var curCamera = Camera{};
var curTime: f32 = 0.0;
const circleTime: f32 = 1.0 / (2.0 * std.math.pi);
const circleRadius: f32 = 0.5;

const RenderLoopError = error{
    FailedToSubmitDrawCommandBuffer,
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

    //TODO repush data to buffers

    curCamera.m_pos.z -= 2.0;

    const modelMat = mat4x4.identity;
    const viewMat = curCamera.GetViewMatrix();
    const projectionMat = curCamera.GetProjectionMatrix();
    debug.print("Model matrix:\n", .{});
    mat4x4.DebugLogMat4x4(&modelMat);
    debug.print("View matrix:\n", .{});
    mat4x4.DebugLogMat4x4(&viewMat);
    debug.print("Projection matrix:\n", .{});
    mat4x4.DebugLogMat4x4(&projectionMat);

    //TODO get imgui working again
    //ImguiInit();
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

var currentFrame: usize = 0;
pub fn RenderFrame() !void {
    curTime += game.deltaTime;
    curCamera.m_pos.x = circleRadius * std.math.cos(curTime / (std.math.tau * circleTime));
    curCamera.m_pos.y = circleRadius * std.math.sin(curTime / (std.math.tau * circleTime));

    //TODO handle return values
    _ = c.vkWaitForFences(vk.logicalDevice, 1, &vk.inFlightFences[currentFrame], c.VK_TRUE, std.math.maxInt(u64));

    var imageIndex: u32 = 0;
    _ = c.vkAcquireNextImageKHR(vk.logicalDevice, vk.swapchain, std.math.maxInt(u64), vk.imageAvailableSemaphores[currentFrame], null, &imageIndex);

    //Vulkan render loop
    if (vk.imagesInFlight[imageIndex] != null) {
        _ = c.vkWaitForFences(vk.logicalDevice, 1, &vk.imagesInFlight[currentFrame], c.VK_TRUE, std.math.maxInt(u64));
    }
    vk.imagesInFlight[imageIndex] = vk.inFlightFences[currentFrame];

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

    _ = c.vkResetFences(vk.logicalDevice, 1, &vk.inFlightFences[currentFrame]);

    const submitResult = c.vkQueueSubmit(vk.graphicsQueue, 1, &submitInfo, vk.inFlightFences[currentFrame]);
    if (submitResult != c.VK_SUCCESS) {
        return RenderLoopError.FailedToSubmitDrawCommandBuffer;
    }

    const presentInfo = c.VkPresentInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &signalSemaphores,
        .swapchainCount = 1,
        .pSwapchains = &vk.swapchain,
        .pImageIndices = &imageIndex,
        .pResults = null,
        .pNext = null,
    };

    _ = c.vkQueuePresentKHR(vk.presentQueue, &presentInfo);

    currentFrame = (currentFrame + 1) % vk.BUFFER_FRAMES;

    //TODO get imgui working again
    //ImguiUpdate();
}
