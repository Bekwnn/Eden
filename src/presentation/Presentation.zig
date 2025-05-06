const c = @import("../c.zig");

const std = @import("std");
const debug = std.debug;
const ArrayList = std.ArrayList;
const allocator = std.heap.page_allocator;

const AssetInventory = @import("AssetInventory.zig").AssetInventory;
const Camera = @import("Camera.zig").Camera;
const DescriptorWriter = @import("DescriptorWriter.zig").DescriptorWriter;
const Material = @import("Material.zig").Material;
const Mesh = @import("Mesh.zig").Mesh;
const renderContext = @import("RenderContext.zig");
const RenderObject = @import("RenderObject.zig").RenderObject;
const scene = @import("Scene.zig");
const ShaderEffect = @import("ShaderEffect.zig").ShaderEffect;
const ShaderPass = @import("ShaderPass.zig").ShaderPass;
const vkUtil = @import("VulkanUtil.zig");

const GPUSceneData = scene.GPUSceneData;
const RenderContext = renderContext.RenderContext;
const Scene = scene.Scene;

const Mat4x4 = @import("../math/Mat4x4.zig").Mat4x4;
const Vec3 = @import("../math/Vec3.zig").Vec3;
const Vec4 = @import("../math/Vec4.zig").Vec4;
const Quat = @import("../math/Quat.zig").Quat;
const em = @import("../math/Math.zig");

const game = @import("../game/GameWorld.zig");
const GameWorld = @import("../game/GameWorld.zig").GameWorld;

const filePathUtils = @import("../coreutil/FilePathUtils.zig");

var curTime: f32 = 0.0;
const circleTime: f32 = 1.0 / (2.0 * std.math.pi);
const circleRadius: f32 = 0.5;

var currentScene = Scene{};

const RenderLoopError = error{
    FailedToAcquireNextImage,
    FailedToBeginCommandBuffer,
    FailedToEndCommandBuffer,
    FailedToPresent,
    FailedToQueuePresent,
    FailedToQueueSubmit,
    FailedToQueueWaitIdle,
    FailedToResetCommandBuffer,
    FailedToResetFences,
    FailedToUpdateSceneUniforms,
    FailedToWaitForImageFence,
    FailedToWaitForInFlightFence,
};

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

    try currentScene.CreateCamera("default");

    const currentCamera = try currentScene.GetCurrentCamera();

    currentCamera.m_pos = Vec3{ .x = 0.0, .y = 0.0, .z = -25.0 };
    currentCamera.LookAt(Vec3.zero);

    const cameraViewMat = try currentCamera.GetViewMatrix();
    const cameraProjMat = currentCamera.GetProjectionMatrix();

    const rContext = try RenderContext.GetInstance();
    for (&rContext.m_frameData) |*frameData| {
        frameData.m_gpuSceneData = scene.GPUSceneData{
            .m_view = cameraViewMat,
            .m_projection = cameraProjMat,
            .m_viewProj = cameraProjMat.Mul(&cameraViewMat),
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
                .w = 10.0,
            },
            .m_sunColor = Vec4{
                .x = 1.0,
                .y = 1.0,
                .z = 1.0,
                .w = 1.0,
            },
            .m_time = Vec4{
                .x = 0.0,
                .y = 0.0,
                .z = 0.0,
                .w = 0.0,
            },
        };
    }

    debug.print("Building ShaderEffect...\n", .{});
    const testShaderEffect = try ShaderEffect.CreateBasicShader(
        allocator,
        "src\\shaders\\compiled\\basic_mesh-vert.spv",
        "src\\shaders\\compiled\\basic_mesh-frag.spv",
    );
    debug.print("Building ShaderPass...\n", .{});
    material.m_shaderPass = try ShaderPass.BuildShaderPass(
        allocator,
        &testShaderEffect,
        c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        c.VK_POLYGON_MODE_FILL,
        Mesh.GetBindingDescription(),
        Mesh.GetAttributeDescriptions(),
    );

    try currentScene.m_renderables.put(
        "Monkey_Mesh",
        RenderObject{
            .m_mesh = mesh,
            .m_material = material,
            .m_transform = Mat4x4.identity,
        },
    );
}

// TODO remove params, make them accessible elsewhere
pub fn ImguiFrame(deltaT: f32, rawDeltaNs: u64) !void {
    //_ = c.igShowDemoWindow(null);

    var camera = try currentScene.GetCurrentCamera();
    _ = c.igBegin("My Editor Window", null, c.ImGuiWindowFlags_None);
    _ = c.igText(
        "Actual FPS: %.1f, Uncapped FPS: %.1f",
        1.0 / deltaT,
        @as(f32, @floatFromInt(std.time.ns_per_s)) / @as(f32, @floatFromInt(rawDeltaNs)),
    );

    _ = c.igText("Camera Pos");
    c.igSetNextItemWidth(150.0);
    _ = c.igSliderFloat("X", &camera.m_pos.x, -30.0, 30.0, "%.2f", c.ImGuiSliderFlags_None);

    c.igSetNextItemWidth(150.0);
    c.igSameLine(0.0, 2.0);
    _ = c.igSliderFloat("Y", &camera.m_pos.y, -30.0, 30.0, "%.2f", c.ImGuiSliderFlags_None);

    c.igSetNextItemWidth(150.0);
    c.igSameLine(0.0, 2.0);
    _ = c.igSliderFloat("Z", &camera.m_pos.z, -30.0, 30.0, "%.2f", c.ImGuiSliderFlags_None);

    const rotateLeft = c.igButton("<", c.ImVec2{ .x = 20.0, .y = 20.0 });
    c.igSameLine(0.0, 2.0);
    const rotateRight = c.igButton(">", c.ImVec2{ .x = 20.0, .y = 20.0 });
    _ = c.igText("Camera Rotation: %.2f", camera.m_rotation.GetZEuler() * em.util.radToDeg);
    _ = c.igText(
        "Camera Quat: {x:%.3f, y:%.3f, z:%.3f, w:%.3f}",
        camera.m_rotation.x,
        camera.m_rotation.y,
        camera.m_rotation.z,
        camera.m_rotation.w,
    );
    if (rotateLeft) {
        camera.m_rotation = camera.m_rotation.Mul(Quat.GetAxisRotation(Vec3.zAxis, -5.0));
    } else if (rotateRight) {
        camera.m_rotation = camera.m_rotation.Mul(Quat.GetAxisRotation(Vec3.zAxis, 5.0));
    }
    c.igEnd();
}

pub fn RecordCommandBuffer(commandBuffer: c.VkCommandBuffer, imageIndex: u32) !void {
    const rContext = try RenderContext.GetInstance();
    const currentFrame = rContext.GetCurrentFrame();

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

    const clearColor = c.VkClearValue{
        .color = c.VkClearColorValue{ .float32 = [_]f32{ 0.05, 0.1, 0.15, 1.0 } },
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
        try UpdateUniformSceneBuffer();

        var writer = DescriptorWriter.init(allocator);
        try writer.WriteBuffer(
            0,
            currentFrame.m_gpuSceneDataBuffer.m_buffer,
            @sizeOf(@TypeOf(currentFrame.m_gpuSceneData)),
            0,
            c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        );
        writer.UpdateSet(rContext.m_logicalDevice, currentFrame.m_gpuSceneDataDescriptorSet);

        var renderableIter = currentScene.m_renderables.iterator();
        while (renderableIter.next()) |renderableEntry| {
            renderableEntry.value_ptr.Draw(commandBuffer) catch |err| {
                std.debug.print("Error {} drawing {s}\n", .{ err, renderableEntry.key_ptr });
            };
        }

        //for each render type (shadow, opaque, transparent, post process, etc)
        //  bindGlobalDescriptors()
        //  for each material:
        //    bindPipeline()
        //    bindPerMaterialDescriptors()
        //    for each material instance:
        //      bindPerInstanceDescriptors()
        //      for each render object:
        //        bindPerObjectDescriptors()
        //        draw()

        c.ImGui_ImplVulkan_RenderDrawData(c.igGetDrawData(), commandBuffer, null);
    }
    c.vkCmdEndRenderPass(commandBuffer);

    try vkUtil.CheckVkSuccess(
        c.vkEndCommandBuffer(commandBuffer),
        RenderLoopError.FailedToEndCommandBuffer,
    );
}

pub fn UpdateUniformSceneBuffer() !void {
    const rContext = try RenderContext.GetInstance();
    const currentFrameData = rContext.GetCurrentFrame();

    // update time vec
    currentFrameData.m_gpuSceneData.m_time = GPUSceneData.CreateTimeVec(curTime);

    // update camera
    var camera = try currentScene.GetCurrentCamera();
    //camera.LookAt(if (!camera.m_pos.Equals(Vec3.zero)) Vec3.zero else Vec3.xAxis);
    const view = try camera.GetViewMatrix();
    const proj = camera.GetOrthoMatrix(-10.0, 10.0, -10.0, 10.0);
    currentFrameData.m_gpuSceneData.m_view = view;
    currentFrameData.m_gpuSceneData.m_projection = proj;
    currentFrameData.m_gpuSceneData.m_viewProj = proj.Mul(&view);

    // update uniform buffer
    if (currentFrameData.m_gpuSceneDataBuffer.m_mappedData) |mappedData| {
        const bufferSize = @sizeOf(@TypeOf(currentFrameData.m_gpuSceneData));
        @memcpy(
            @as([*]u8, @ptrCast(mappedData))[0..bufferSize],
            @as([*]u8, @ptrCast(&currentFrameData.m_gpuSceneData))[0..bufferSize],
        );
    } else {
        return RenderLoopError.FailedToUpdateSceneUniforms;
    }
}

pub fn RenderFrame() !void {
    const swapchainAllocator = std.heap.page_allocator;

    curTime += game.deltaTime;
    const rContext = try RenderContext.GetInstance();
    const currentFrameData = rContext.GetCurrentFrame();

    // 1sec = 1e9 nanoseconds
    const timeoutns = 1000000000;

    // sync stage
    const fencesResult = c.vkWaitForFences(
        rContext.m_logicalDevice,
        1,
        &currentFrameData.m_renderFence,
        c.VK_TRUE,
        timeoutns,
    );
    if (fencesResult != c.VK_SUCCESS and fencesResult != c.VK_TIMEOUT) {
        return RenderLoopError.FailedToWaitForInFlightFence;
    }

    try vkUtil.CheckVkSuccess(
        c.vkResetFences(rContext.m_logicalDevice, 1, &currentFrameData.m_renderFence),
        RenderLoopError.FailedToResetFences,
    );

    var imageIndex: u32 = 0;
    const acquireImageResult = c.vkAcquireNextImageKHR(
        rContext.m_logicalDevice,
        rContext.m_swapchain.m_swapchain,
        timeoutns,
        currentFrameData.m_swapchainSemaphore,
        null,
        &imageIndex,
    );
    if (acquireImageResult == c.VK_ERROR_OUT_OF_DATE_KHR) {
        try rContext.RecreateSwapchain(swapchainAllocator); // recreate swapchain and skip this frame
        return;
    } else if (acquireImageResult != c.VK_SUCCESS and acquireImageResult != c.VK_SUBOPTIMAL_KHR) {
        return RenderLoopError.FailedToAcquireNextImage;
    }

    // reset and record command buffer
    try vkUtil.CheckVkSuccess(
        c.vkResetCommandBuffer(currentFrameData.m_mainCommandBuffer, 0),
        RenderLoopError.FailedToResetCommandBuffer,
    );

    try RecordCommandBuffer(currentFrameData.m_mainCommandBuffer, imageIndex);

    // submit commands
    const waitStages = [_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    const submitInfo = c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &currentFrameData.m_mainCommandBuffer,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &currentFrameData.m_renderSemaphore,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &currentFrameData.m_swapchainSemaphore,
        .pWaitDstStageMask = &waitStages,
        .pNext = null,
    };

    try vkUtil.CheckVkSuccess(
        c.vkQueueSubmit(rContext.m_graphicsQueue, 1, &submitInfo, currentFrameData.m_renderFence),
        RenderLoopError.FailedToQueueSubmit,
    );

    // present the result
    const presentInfo = c.VkPresentInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &currentFrameData.m_renderSemaphore,
        .swapchainCount = 1,
        .pSwapchains = &rContext.m_swapchain.m_swapchain,
        .pImageIndices = &imageIndex,
        .pResults = null,
        .pNext = null,
    };

    const presentResult = c.vkQueuePresentKHR(rContext.m_presentQueue, &presentInfo);
    //TODO fix RecreateSwapchain
    if (presentResult == c.VK_ERROR_OUT_OF_DATE_KHR or presentResult == c.VK_SUBOPTIMAL_KHR) {
        try rContext.RecreateSwapchain(swapchainAllocator);
    } else if (presentResult != c.VK_SUCCESS) {
        return RenderLoopError.FailedToPresent;
    }

    rContext.m_currentFrame = (rContext.m_currentFrame + 1) % renderContext.FRAMES_IN_FLIGHT;
}
