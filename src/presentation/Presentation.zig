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
    FailedToAcquireNextImage,
    FailedToBeginCommandBuffer,
    FailedToEndCommandBuffer,
    FailedToPresent,
    FailedToQueuePresent,
    FailedToQueueSubmit,
    FailedToQueueWaitIdle,
    FailedToResetCommandBuffer,
    FailedToResetFences,
    FailedToWaitForImageFence,
    FailedToWaitForInFlightFence,
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

    try currentScene.CreateCamera("default");

    const currentCamera = try currentScene.GetCurrentCamera();
    currentCamera.m_pos = Vec3{ .x = 0.0, .y = 0.0, .z = -5.0 };

    const cameraViewMat = currentCamera.GetViewMatrix();
    const cameraProjMat = currentCamera.GetProjectionMatrix();

    const rContext = try RenderContext.GetInstance();
    for (&rContext.m_frameData) |*frameData| {
        frameData.m_gpuSceneData = scene.GPUSceneData{
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
        "src\\shaders\\compiled\\basic-vert.spv",
        "src\\shaders\\compiled\\basic-frag.spv",
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

    // set up meshes
    var ix: i8 = -1;
    var iy: i8 = -1;
    while (iy <= 1) : (iy += 1) {
        while (ix <= 1) : (ix += 1) {
            // TODO build properly
            try renderables.append(RenderObject{
                .m_mesh = mesh,
                .m_material = material,
                .m_transform = mat4x4.TranslationMat4x4(Vec3{
                    .x = @as(f32, @floatFromInt(ix)) * 2.0,
                    .y = @as(f32, @floatFromInt(iy)) * 2.0,
                    .z = 0.0,
                }),
            });
        }
    }
}

pub fn RecordCommandBuffer(commandBuffer: c.VkCommandBuffer, imageIndex: u32) !void {
    const rContext = try RenderContext.GetInstance();

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
        // bind scene data
        // updating and binding this data should probably be broken up into two steps, but for now doing both works
        try UpdateAndBindUniformSceneBuffer();

        // TODO bind everything to a single vert/index buffer?

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
    }
    c.vkCmdEndRenderPass(commandBuffer);

    try vkUtil.CheckVkSuccess(
        c.vkEndCommandBuffer(commandBuffer),
        RenderLoopError.FailedToEndCommandBuffer,
    );
}

pub fn UpdateAndBindUniformSceneBuffer() !void {
    const rContext = try RenderContext.GetInstance();
    const currentFrameData = rContext.GetCurrentFrame();

    // update time vec
    currentFrameData.m_gpuSceneData.m_time = GPUSceneData.CreateTimeVec(curTime);

    // update uniform buffer
    if (currentFrameData.m_gpuSceneDataBuffer.m_mappedData) |mappedData| {
        const bufferSize = @sizeOf(@TypeOf(currentFrameData.m_gpuSceneData));
        @memcpy(
            @as([*]u8, @ptrCast(mappedData))[0..bufferSize],
            @as([*]u8, @ptrCast(&currentFrameData.m_gpuSceneData))[0..bufferSize],
        );
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

    try RecordCommandBuffer(currentFrameData.m_mainCommandBuffer, @intCast(rContext.m_currentFrame));

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

    //TODO docs.vulkan.org has the following, consider adding something similar:
    // if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR || framebufferResized) {
    //      framebufferResized = false;
    //      recreateSwapChain();
    // else if (result != VK_SUCCESS) /*throw error*/
    try vkUtil.CheckVkSuccess(
        c.vkQueuePresentKHR(rContext.m_presentQueue, &presentInfo),
        RenderLoopError.FailedToPresent,
    );

    rContext.m_currentFrame = (rContext.m_currentFrame + 1) % renderContext.FRAMES_IN_FLIGHT;
}
