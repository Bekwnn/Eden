const c = @import("../c.zig");

const std = @import("std");
const debug = std.debug;
const ArrayList = std.ArrayList;
const allocator = std.heap.page_allocator;

const AssetInventory = @import("AssetInventory.zig").AssetInventory;
const vkUtil = @import("VulkanUtil.zig");

const Camera = @import("Camera.zig").Camera;
const Material = @import("Material.zig").Material;
const Mesh = @import("Mesh.zig").Mesh;
const renderContext = @import("RenderContext.zig");
const RenderContext = renderContext.RenderContext;
const RenderObject = @import("RenderObject.zig").RenderObject;
const scene = @import("Scene.zig");
const Scene = scene.Scene;
const Shader = @import("Shader.zig").Shader;

const mat4x4 = @import("../math/Mat4x4.zig");
const Vec3 = @import("../math/Vec3.zig").Vec3;
const Vec4 = @import("../math/Vec4.zig").Vec4;

const game = @import("../game/GameWorld.zig");
const GameWorld = @import("../game/GameWorld.zig").GameWorld;

const filePathUtils = @import("../coreutil/FilePathUtils.zig");

var curTime: f32 = 0.0;
const circleTime: f32 = 1.0 / (2.0 * std.math.pi);
const circleRadius: f32 = 0.5;

var currentScene = Scene{};

// temporary location for this
var renderables: ArrayList(RenderObject) = ArrayList(RenderObject).init(allocator);

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
};

//var imguiIO: ?*c.ImGuiIO = null;
//
//fn ImguiInit() void {
//    imguiIO = c.igGetIO();
//    if (imguiIO) |io| {
//        var text_pixels: [*c]u8 = undefined;
//        var text_w: i32 = undefined;
//        var text_h: i32 = undefined;
//        c.ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &text_pixels, &text_w, &text_h, null);
//    } else {
//        @panic("imguiIO is null");
//    }
//}

pub fn OnWindowResized(window: *c.SDL_Window) !void {
    var rContext = try RenderContext.GetInstance();
    var width: c_int = 0;
    var height: c_int = 0;
    c.SDL_GetWindowSize(window, &width, &height);
    debug.print("Window resized to {} x {}\n", .{ width, height });

    const camera = try currentScene.GetCurrentCamera();
    camera.*.m_aspectRatio = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));

    try rContext.RecreateSwapchain(allocator);
}

pub fn Initialize(
    window: *c.SDL_Window,
    applicationName: []const u8,
    applicationVersion: u32,
) !void {
    try RenderContext.Initialize(
        allocator,
        window,
        applicationName,
        applicationVersion,
    );

    //TODO get imgui working again
    //ImguiInit();

    try AssetInventory.Initialize();
    try InitializeScene();
}

pub fn Shutdown() void {
    //defer imgui.CleanupImgui();

    const rContext = RenderContext.GetInstance() catch {
        return;
    };
    _ = c.vkDeviceWaitIdle(rContext.m_logicalDevice);
    rContext.Shutdown();
}

fn InitializeScene() !void {
    // init hardcoded test currentScene:
    var inventory = try AssetInventory.GetInstance();
    const mesh = inventory.CreateMesh("monkey", "test-assets\\test.obj") catch |meshErr| {
        debug.print("Error creating mesh: {}\n", .{meshErr});
        return meshErr;
    };
    const material = inventory.CreateMaterial("monkey_mat") catch |materialErr| {
        debug.print("Error creating material: {}\n", .{materialErr});
        return materialErr;
    };

    const currentCamera = try currentScene.GetCurrentCamera();
    const cameraViewMat = currentCamera.GetViewMatrix();
    const cameraProjMat = currentCamera.GetProjectionMatrix();

    const rContext = try RenderContext.GetInstance();
    rContext.m_gpuSceneData = scene.GPUSceneData{
        .m_view = cameraViewMat,
        .m_projection = cameraProjMat,
        .m_viewProj = cameraViewMat.Mul(&cameraProjMat),
        .m_ambientColor = Vec4{
            .x = 0.5,
            .y = 0.5,
            .z = 0.5,
            .w = 1.0,
        },
        .m_sunDirection = Vec4{
            .x = 0.0,
            .y = 0.0,
            .z = -1.0,
            .w = 0.0,
        },
        .m_sunColor = Vec4{
            .x = 1.0,
            .y = 1.0,
            .z = 1.0,
            .w = 1.0,
        },
    };
    var ix: i8 = -1;
    var iy: i8 = -1;
    while (iy <= 1) : (iy += 1) {
        while (ix <= 1) : (ix += 1) {
            var newRenderable = renderables.addOne() catch @panic("!");
            newRenderable.* = try RenderObject.CreateRenderObject(mesh, material);
            const ixf: f32 = @floatFromInt(ix);
            const iyf: f32 = @floatFromInt(iy);
            newRenderable.m_transform = mat4x4.TranslationMat4x4(Vec3{
                .x = ixf * 2.0,
                .y = iyf * 2.0,
                .z = 0.0,
            });
        }
    }
}

pub fn RecordCommandBuffer(commandBuffer: c.VkCommandBuffer, imageIndex: u32) !void {
    const beginInfo = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = null,
        .flags = 0,
        .pInheritanceInfo = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkBeginCommandBuffer(commandBuffer, &beginInfo),
        RenderLoopError.FailedToBeginCommandBuffer,
    );

    const rContext = try RenderContext.GetInstance();

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
        .framebuffer = rContext.m_swapchain.m_frameBuffers[imageIndex],
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

    c.vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, c.VK_SUBPASS_CONTENTS_INLINE);
    {
        c.vkCmdBindPipeline(commandBuffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, rContext.m_pipeline);

        //TODO the below is just a guess
        var curMesh: ?*Mesh = null;
        const curMaterial: ?*Material = null;
        for (renderables.items, 0..) |_, i| {
            const renderObj: *RenderObject = &renderables.items[i];
            // Update Mesh
            if (curMesh == null or curMesh != renderObj.m_mesh) {
                curMesh = renderObj.m_mesh;
                //TODO check if buffer data exists
                const vertexBuffers = [_]c.VkBuffer{curMesh.?.m_bufferData.?.m_vertexBuffer.m_buffer};
                const offsets = [_]c.VkDeviceSize{0};
                c.vkCmdBindVertexBuffers(commandBuffer, 0, 1, &vertexBuffers, &offsets);

                c.vkCmdBindIndexBuffer(commandBuffer, curMesh.?.m_bufferData.?.m_indexBuffer.m_buffer, 0, c.VK_INDEX_TYPE_UINT32);
            }

            // Update Material
            const perMaterialDescriptorIdx: usize = @intFromEnum(renderContext.DescriptorSetType.PerMaterial);
            if (curMaterial == null or curMaterial != renderObj.m_material) {
                c.vkCmdBindDescriptorSets(
                    commandBuffer,
                    c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                    rContext.m_pipelineLayout,
                    0,
                    1,
                    &rContext.m_frameData[currentFrame].m_descriptorSets[perMaterialDescriptorIdx],
                    0,
                    null,
                );
            }

            c.vkCmdDrawIndexed(commandBuffer, @intCast(curMesh.?.m_indices.items.len), 1, 0, 0, 0);
        }
    }
    c.vkCmdEndRenderPass(commandBuffer);

    try vkUtil.CheckVkSuccess(
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
//        io.DisplaySize.x = @floatFromInt(window_w);
//        io.DisplaySize.y = @floatFromInt(window_h);
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

    curTime += game.deltaTime;

    // TEMP camera movement test
    const curCamera = try currentScene.GetCurrentCamera();
    curCamera.*.m_pos.z = -5.0;
    curCamera.*.m_pos.x = circleRadius * std.math.cos(curTime / (std.math.tau * circleTime));
    curCamera.*.m_pos.y = circleRadius * std.math.sin(curTime / (std.math.tau * circleTime));

    const rContext = try RenderContext.GetInstance();

    // sync stage
    const fencesResult = c.vkWaitForFences(
        rContext.m_logicalDevice,
        1,
        &rContext.m_frameData[currentFrame].m_renderFence,
        c.VK_TRUE,
        2000000000,
    );
    if (fencesResult != c.VK_SUCCESS and fencesResult != c.VK_TIMEOUT) {
        return RenderLoopError.FailedToWaitForInFlightFence;
    }

    try vkUtil.CheckVkSuccess(
        c.vkResetFences(rContext.m_logicalDevice, 1, &rContext.m_frameData[currentFrame].m_renderFence),
        RenderLoopError.FailedToResetFences,
    );

    //TODO create deletion queue? flush it?
    const currentFrameData = rContext.GetCurrentFrame();
    try currentFrameData.m_descriptorAllocator.ClearPools(rContext.m_logicalDevice);

    var imageIndex: u32 = 0;
    const timeoutns = 1000000000; // 1sec = 1e9 nanoseconds
    const acquireImageResult = c.vkAcquireNextImageKHR(
        rContext.m_logicalDevice,
        rContext.m_swapchain.m_swapchain,
        timeoutns,
        rContext.m_frameData[currentFrame].m_swapchainSemaphore,
        null,
        &imageIndex,
    );
    if (acquireImageResult == c.VK_ERROR_OUT_OF_DATE_KHR) {
        try rContext.RecreateSwapchain(swapchainAllocator); // recreate swapchain and skip this frame
        return;
    } else if (acquireImageResult != c.VK_SUCCESS and acquireImageResult != c.VK_SUBOPTIMAL_KHR) {
        return RenderLoopError.FailedToAcquireNextImage;
    }

    //TODO update the uniform buffers
    //try rContext.UpdateUniformBuffer(&currentScene.GetCurrentCamera(), currentFrame);

    try vkUtil.CheckVkSuccess(
        c.vkResetCommandBuffer(rContext.m_frameData[imageIndex].m_mainCommandBuffer, 0),
        RenderLoopError.FailedToResetCommandBuffer,
    );

    // begin and run commands
    try RecordCommandBuffer(rContext.m_frameData[imageIndex].m_mainCommandBuffer, imageIndex);

    //TODO check if this is correct semaphore
    const waitSemaphores = [_]c.VkSemaphore{rContext.m_frameData[currentFrame].m_swapchainSemaphore};
    const waitStages = [_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    const signalSemaphores = [_]c.VkSemaphore{rContext.m_frameData[currentFrame].m_renderSemaphore};
    const submitInfo = c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &waitSemaphores,
        .pWaitDstStageMask = &waitStages,
        .commandBufferCount = 1,
        .pCommandBuffers = &rContext.m_frameData[imageIndex].m_mainCommandBuffer,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &signalSemaphores,
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkQueueSubmit(rContext.m_graphicsQueue, 1, &submitInfo, rContext.m_frameData[currentFrame].m_renderFence),
        RenderLoopError.FailedToSubmitDrawCommandBuffer,
    );

    const swapchains = [_]c.VkSwapchainKHR{rContext.m_swapchain.m_swapchain};
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

    //TODO fix up currentScene drawing
    try currentScene.DrawScene(rContext.m_frameData[imageIndex].m_mainCommandBuffer, renderables.items);

    const queuePresentResult = c.vkQueuePresentKHR(rContext.m_presentQueue, &presentInfo);

    if (queuePresentResult == c.VK_ERROR_OUT_OF_DATE_KHR or queuePresentResult == c.VK_SUBOPTIMAL_KHR or framebufferResized) {
        framebufferResized = false;
        try rContext.RecreateSwapchain(swapchainAllocator);
    } else if (queuePresentResult != c.VK_SUCCESS) {
        return RenderLoopError.FailedToQueuePresent;
    }

    currentFrame = (currentFrame + 1) % renderContext.FRAMES_IN_FLIGHT;
}

//fn RenderFrameImgui() void {
//    c.ImGui_ImplVulkan_NewFrame();
//    c.ImGui_ImplSDL2_NewFrame(window);
//    c.igNewFrame();
//    c.igShowDemoWindow(&showDemoWindow);
//    c.igBegin("Hello, world!");
//    {
//        c.igText("This is some useful text.");
//        c.igCheckbox("Demo Window", &showDemoWindow);
//
//        c.igSliderFloat("float", &f, 0.0, 1.0);
//
//        if (c.igButton("Button")) {
//            counter += 1;
//        }
//
//        c.igSameLine();
//        c.igText("counter = %d", counter);
//
//        c.igText("Application average {} ms/frame ({} FPS)", 1000.0 / c.igGetIO().Framerate, c.igGetIO().Framerate);
//    }
//    c.igEnd();
//
//    c.igRender();
//}

//fn DrawBackground(cmd: c.VkCommandBuffer) void {
//
//}
//
//fn DrawMeshes(cmd: c.VkCommandBuffer) void {
//
//}
