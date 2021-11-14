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

usingnamespace @import("../c.zig");

var curShader: ?u32 = null;
var curMesh: ?Mesh = null;
var curCamera = Camera{};
var curTime: f32 = 0.0;
const circleTime: f32 = 1.0 / (2.0 * std.math.pi);
const circleRadius: f32 = 0.5;

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

pub fn Initialize(renderer: *SDL_Renderer) void {
    const meshPath = filePathUtils.CwdToAbsolute(allocator, "test-assets\\test.obj") catch |err| {
        @panic("!");
    };
    defer allocator.free(meshPath);
    if (assimp.ImportMesh(meshPath)) |mesh| {
        curMesh = mesh;
    } else |meshErr| {
        debug.warn("Error importing mesh: {}\n", .{meshErr});
    }

    if (curMesh != null) {
        curMesh.?.PushDataToBuffers();
    } else {
        debug.warn("No mesh, no data pushed to buffers!\n", .{});
    }

    curCamera.m_pos.z -= 2.0;

    const modelMat = mat4x4.identity;
    const viewMat = curCamera.GetViewMatrix();
    const projectionMat = curCamera.GetProjectionMatrix();
    debug.warn("Model matrix:\n", .{});
    mat4x4.DebugLogMat4x4(&modelMat);
    debug.warn("View matrix:\n", .{});
    mat4x4.DebugLogMat4x4(&viewMat);
    debug.warn("Projection matrix:\n", .{});
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

var vkCommandBuffer: VkCommandBuffer = undefined;
var vkImage: VkImage = undefined;
fn AcquireNextImage() void {
    //TODO handle results
    _ = vkAcquireNextImageKHR(
        vk.logicalDevice,
        vk.swapchain,
        std.math.maxInt(u64),
        vk.imageAvailableSemaphores[vk.curFrameBufferIdx],
        null,
        &vk.curFrameBufferIdx,
    );

    //TODO handle results
    _ = vkWaitForFences(vk.logicalDevice, 1, &vk.inFlightFences[vk.curFrameBufferIdx], VK_TRUE, std.math.maxInt(u64));
    _ = vkResetFences(vk.logicalDevice, 1, &vk.inFlightFences[vk.curFrameBufferIdx]);

    vkCommandBuffer = vk.commandBuffers[vk.curFrameBufferIdx];
    vkImage = vk.swapchainImages[vk.curFrameBufferIdx];
}

fn ResetCommandBuffer() void {
    //TODO report result
    _ = vkResetCommandBuffer(vkCommandBuffer, 0);
}

fn BeginCommandBuffer() void {
    const beginInfo = VkCommandBufferBeginInfo{
        .sType = enum_VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT,
        .pNext = null,
        .pInheritanceInfo = null,
    };
    _ = vkBeginCommandBuffer(vkCommandBuffer, &beginInfo);
}

fn BeginRenderPass(clear_color: VkClearColorValue, clear_depth_stencil: VkClearDepthStencilValue) !void {
    var clearValues = try std.ArrayList(VkClearValue).initCapacity(allocator, 2);
    clearValues.items[0].color = clear_color;
    clearValues.items[1].depthStencil = clear_depth_stencil;

    const renderPassInfo = VkRenderPassBeginInfo{
        .sType = enum_VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = vk.renderPass,
        .framebuffer = vk.swapchainFrameBuffers[vk.curFrameBufferIdx],
        .renderArea = VkRect2D{
            .offset = VkOffset2D{ .x = 0, .y = 0 },
            .extent = vk.swapchainExtent,
        },
        .clearValueCount = @intCast(u32, clearValues.items.len), //color, depthstencil
        .pClearValues = @ptrCast([*c]VkClearValue, &clearValues.items),
        .pNext = null,
    };

    vkCmdBeginRenderPass(vkCommandBuffer, &renderPassInfo, enum_VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE);
}

fn EndRenderPass() void {
    vkCmdEndRenderPass(vkCommandBuffer);
}

fn EndCommandBuffer() void {
    //TODO handle result
    _ = vkEndCommandBuffer(vkCommandBuffer);
}

fn QueueSubmit() void {
    var waitStages = [_]VkPipelineStageFlags{VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    const submitInfo = VkSubmitInfo{
        .sType = enum_VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &vk.imageAvailableSemaphores[vk.curFrameBufferIdx],
        .pWaitDstStageMask = &waitStages,
        .commandBufferCount = 1,
        .pCommandBuffers = &vkCommandBuffer,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &vk.renderFinishedSemaphores[vk.curFrameBufferIdx],
        .pNext = null,
    };
    //TODO handle result
    _ = vkQueueSubmit(vk.graphicsQueue, 1, &submitInfo, vk.inFlightFences[vk.curFrameBufferIdx]);
}

fn QueuePresent() void {
    const presentInfo = VkPresentInfoKHR{
        .sType = enum_VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &vk.renderFinishedSemaphores[vk.curFrameBufferIdx],
        .swapchainCount = 1,
        .pSwapchains = &vk.swapchain,
        .pImageIndices = &vk.curFrameBufferIdx,
        .pNext = null,
        .pResults = null,
    };
    //TODO handle result
    _ = vkQueuePresentKHR(vk.presentQueue, &presentInfo);

    //TODO handle result
    _ = vkQueueWaitIdle(vk.presentQueue);
}

pub fn RenderFrame(renderer: *SDL_Renderer, screen: *SDL_Window, gameWorld: *const GameWorld) !void {
    curTime += game.deltaTime;
    curCamera.m_pos.x = circleRadius * std.math.cos(curTime / (std.math.tau * circleTime));
    curCamera.m_pos.y = circleRadius * std.math.sin(curTime / (std.math.tau * circleTime));

    //Vulkan render loop
    AcquireNextImage();

    ResetCommandBuffer();
    BeginCommandBuffer();
    {
        const clearColour = VkClearColorValue{ .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 } };
        const clearDepthStencil = VkClearDepthStencilValue{ .depth = 1.0, .stencil = 0 };
        try BeginRenderPass(clearColour, clearDepthStencil);
        {
            if (curMesh) |m| {
                if (curShader) |s| {
                    m.Draw(&curCamera, s);
                }
            }
        }
        EndRenderPass();

        //TODO get imgui working again
        //ImguiUpdate();
    }
    EndCommandBuffer();

    QueueSubmit();
    QueuePresent();
}
