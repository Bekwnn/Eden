const std = @import("std");
const allocator = std.heap.page_allocator;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const debug = std.debug;

const c = @import("../c.zig");
const input = @import("../Input.zig");

const filePathUtils = @import("../coreutil/FilePathUtils.zig");

const Color = @import("../math/Color.zig");
const Mat4x4 = @import("../math/Mat4x4.zig").Mat4x4;
const Quat = @import("../math/Quat.zig").Quat;
const Vec3 = @import("../math/Vec3.zig").Vec3;
const Vec4 = @import("../math/Vec4.zig").Vec4;
const ColorRGBA = @import("../math/ColorRGBA.zig");

const AssetInventory = @import("AssetInventory.zig").AssetInventory;
const Buffer = @import("Buffer.zig").Buffer;
const Camera = @import("Camera.zig").Camera;
const DebugDraw = @import("DebugDraw.zig");
const DescriptorAllocator = @import("DescriptorAllocator.zig").DescriptorAllocator;
const DescriptorLayoutBuilder = @import("DescriptorLayoutBuilder.zig").DescriptorLayoutBuilder;
const DescriptorWriter = @import("DescriptorWriter.zig").DescriptorWriter;
const GPUSceneData = @import("Scene.zig").GPUSceneData;
const Material = @import("Material.zig").Material;
const MaterialInstance = @import("MaterialInstance.zig").MaterialInstance;
const MaterialParam = @import("MaterialParam.zig").MaterialParam;
const Mesh = @import("Mesh.zig").Mesh;
const renderContext = @import("RenderContext.zig");
const RenderContext = renderContext.RenderContext;
const RenderObject = @import("RenderObject.zig").RenderObject;
const Scene = @import("Scene.zig").Scene;
const sceneInit = @import("SceneInit.zig");
const ShaderEffect = @import("ShaderEffect.zig").ShaderEffect;
const ShaderPass = @import("ShaderPass.zig").ShaderPass;
const Texture = @import("Texture.zig").Texture;
const TextureParam = @import("MaterialParam.zig").TextureParam;
const UniformParam = @import("MaterialParam.zig").UniformParam;
const vkUtil = @import("VulkanUtil.zig");

//TODO curTime should exist on a global of some kind
var curTime: f32 = 0.0;

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
    NoMeshBufferData,
};

pub fn OnWindowResized(window: *c.SDL_Window) !void {
    var rContext = try RenderContext.GetInstance();
    var width: c_int = 0;
    var height: c_int = 0;
    c.SDL_GetWindowSize(window, &width, &height);
    debug.print("Window resized to {} x {}\n", .{ width, height });

    const camera = try sceneInit.GetCurrentScene().GetCurrentCamera();
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
    try sceneInit.InitializeScene();
}

pub fn Shutdown() void {
    //defer imgui.CleanupImgui();

    const rContext = RenderContext.GetInstance() catch {
        return;
    };
    _ = c.vkDeviceWaitIdle(rContext.m_logicalDevice);
    rContext.Shutdown();
}

pub const DrawStats = struct {
    m_batches: u32 = 0,
    m_renderablesDrawn: u32 = 0,
    m_renderablesInScene: u32 = 0,
};
pub var drawStats = DrawStats{};
pub fn RecordCommandBuffer(commandBuffer: c.VkCommandBuffer, imageIndex: u32) !void {
    const rContext = try RenderContext.GetInstance();
    const currentFrame = rContext.GetCurrentFrame();

    drawStats = DrawStats{};
    drawStats.m_renderablesInScene = sceneInit.GetCurrentScene().m_renderables.count();

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

    const drawCommands = @as(
        [*]c.VkDrawIndirectCommand,
        @ptrCast(@alignCast(currentFrame.m_indirectDrawBuffer.m_mappedData orelse @panic("!"))),
    )[0..renderContext.FrameData.MAX_INDIRECT_DRAW];
    _ = drawCommands;

    var batchDraws = try OrganizeDraws();
    defer batchDraws.deinit();

    c.vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, c.VK_SUBPASS_CONTENTS_INLINE);
    {
        try currentFrame.m_descriptorAllocator.ClearPools(rContext.m_logicalDevice);
        try rContext.AllocateCurrentFrameGlobalDescriptors();

        try AllocateMaterialDescriptorSets(&currentFrame.m_descriptorAllocator);

        try UpdateUniformSceneBuffer();

        // TODO this should be automatic for all params that need updating
        try sceneInit.UpdateColoredShaderBuffer();

        try WriteDescriptors();

        var batchDrawIter = batchDraws.iterator();
        while (batchDrawIter.next()) |renderBatch| {
            try renderBatch.value_ptr.m_matInst.m_parentMaterial.BindMaterial(commandBuffer);
            try renderBatch.value_ptr.m_matInst.BindMaterialInstance(commandBuffer);

            // TODO move to/create "bind mesh" function
            if (renderBatch.value_ptr.m_mesh.m_bufferData) |*meshBufferData| {
                const offsets = [_]c.VkDeviceSize{0};
                const vertexBuffers = [_]c.VkBuffer{
                    meshBufferData.m_vertexBuffer.m_buffer,
                };
                c.vkCmdBindVertexBuffers(
                    commandBuffer,
                    0,
                    1,
                    &vertexBuffers,
                    &offsets,
                );
                c.vkCmdBindIndexBuffer(
                    commandBuffer,
                    meshBufferData.m_indexBuffer.m_buffer,
                    0,
                    c.VK_INDEX_TYPE_UINT32,
                );
            } else {
                return RenderLoopError.NoMeshBufferData;
            }

            //TODO indirect draw calls w/ compute shader culling
            const objLayout = renderBatch.value_ptr.m_matInst.GetObjectDescriptorSetLayout();
            for (renderBatch.value_ptr.m_renderables.items) |renderableEntry| {
                if (objLayout) |layout| {
                    try renderableEntry.value_ptr.AllocateDescriptorSet(&currentFrame.m_descriptorAllocator, layout);
                }
                try renderableEntry.value_ptr.BindPerObjectData(commandBuffer);
                c.vkCmdDrawIndexed(
                    commandBuffer,
                    @intCast(renderableEntry.value_ptr.m_mesh.m_indices.items.len),
                    1,
                    0,
                    0,
                    0,
                );
                drawStats.m_renderablesDrawn += 1;
            }
            drawStats.m_batches += 1;
        }

        if (DebugDraw.ShouldDraw()) {
            try DebugDraw.Draw(commandBuffer);
        }

        c.ImGui_ImplVulkan_RenderDrawData(c.igGetDrawData(), commandBuffer, null);
    }
    c.vkCmdEndRenderPass(commandBuffer);

    try vkUtil.CheckVkSuccess(
        c.vkEndCommandBuffer(commandBuffer),
        RenderLoopError.FailedToEndCommandBuffer,
    );
}

const DrawBatch = struct {
    m_mesh: *Mesh,
    m_matInst: *MaterialInstance,
    m_renderables: ArrayList(Scene.RenderableContainer.Entry),
};

fn GetMatAndMeshKey(matInstance: *MaterialInstance, mesh: *Mesh) u128 {
    return (@as(u128, @intFromPtr(matInstance)) << 64) | @as(u128, @intFromPtr(mesh));
}

fn OrganizeDraws() !AutoHashMap(u128, DrawBatch) {
    var batches = AutoHashMap(u128, DrawBatch).init(allocator);
    errdefer batches.deinit();

    const currentScene = sceneInit.GetCurrentScene();
    const renderables = currentScene.m_renderables;

    var renderableIter = renderables.iterator();
    while (renderableIter.next()) |renderableEntry| {
        if (!try IsVisible(try currentScene.GetCurrentCamera(), renderableEntry.value_ptr)) {
            continue;
        }

        const renderableBatchKey = GetMatAndMeshKey(
            renderableEntry.value_ptr.m_materialInstance,
            renderableEntry.value_ptr.m_mesh,
        );
        const getPutResult = try batches.getOrPut(renderableBatchKey);

        // getOrPut doesn't initialize data when it puts
        if (!getPutResult.found_existing) {
            getPutResult.value_ptr.* = DrawBatch{
                .m_mesh = renderableEntry.value_ptr.m_mesh,
                .m_matInst = renderableEntry.value_ptr.m_materialInstance,
                .m_renderables = ArrayList(Scene.RenderableContainer.Entry).init(allocator),
            };
        }

        // add current renderable to the draw batch
        try getPutResult.value_ptr.m_renderables.append(renderableEntry);
    }
    firstTimeBoundsDraw = false;
    return batches;
}

var firstTimeBoundsDraw = true; //TODO delete
fn IsVisible(camera: *const Camera, renderable: *const RenderObject) !bool {
    const renderablePos = renderable.m_transform.m_position;
    const renderableRot = renderable.m_transform.m_rotation;

    // Scale the sphere by max scaling value
    const renderableScale = renderable.m_transform.m_scale;
    const maxScale: f32 = @max(renderableScale.x, renderableScale.y, renderableScale.z);

    const renderableBounds = renderable.m_mesh.m_bounds;
    // get bounds origin in world space
    const boundsOrigin = renderablePos.Add(renderableRot.Rotate(renderableBounds.m_origin));

    //TODO delete and remove error union
    if (firstTimeBoundsDraw) {
        _ = try DebugDraw.CreateDebugCircle(
            boundsOrigin,
            Vec3.yAxis,
            renderableBounds.m_sphereRadius,
            ColorRGBA.presets.Green,
        );
        _ = try DebugDraw.CreateDebugBox(
            boundsOrigin,
            renderableBounds.m_extents,
            ColorRGBA.presets.Yellow,
        );
        _ = try DebugDraw.CreateDebugLine(
            boundsOrigin,
            boundsOrigin.Add(Vec3.xAxis.GetScaled(renderableBounds.m_extents.Length())),
            ColorRGBA.presets.Magenta,
        );
    }

    const cameraFrustum = camera.GetFrustumData();
    for (cameraFrustum.m_planes) |plane| {
        if (plane.GetSignedDistance(boundsOrigin) < -(renderableBounds.m_sphereRadius * maxScale)) {
            return false;
        }
    }

    return true;
}

fn WriteDescriptors() !void {
    const rContext = try RenderContext.GetInstance();
    const currentFrame = rContext.GetCurrentFrame();

    var writer = DescriptorWriter.init(allocator);
    try writer.WriteBuffer(
        0,
        currentFrame.m_gpuSceneDataBuffer.m_buffer,
        @sizeOf(@TypeOf(currentFrame.m_gpuSceneData)),
        0,
        c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
    );
    writer.UpdateSet(rContext.m_logicalDevice, currentFrame.m_gpuSceneDataDescriptorSet);

    const inventory = try AssetInventory.GetInstance();
    var matIter = inventory.m_materials.iterator();
    while (matIter.next()) |*material| {
        try material.value_ptr.WriteDescriptorSet(allocator);
    }
    var matInstIter = inventory.m_materialInstances.iterator();
    while (matInstIter.next()) |*matInst| {
        try matInst.value_ptr.WriteDescriptorSet(allocator);
    }
    var renderIter = sceneInit.GetCurrentScene().m_renderables.iterator();
    while (renderIter.next()) |*renderable| {
        try renderable.value_ptr.WriteDescriptorSet(allocator);
    }
}

fn UpdateUniformSceneBuffer() !void {
    const rContext = try RenderContext.GetInstance();
    const currentFrameData = rContext.GetCurrentFrame();

    // update time vec
    currentFrameData.m_gpuSceneData.m_time = GPUSceneData.CreateTimeVec(curTime);

    // update camera
    const camera = try sceneInit.GetCurrentScene().GetCurrentCamera();
    const view = camera.GetViewMatrix();
    const proj = camera.GetProjectionMatrix();
    currentFrameData.m_gpuSceneData.m_view = view.Transpose();
    currentFrameData.m_gpuSceneData.m_projection = proj.Transpose();
    currentFrameData.m_gpuSceneData.m_viewProj = proj.Mul(view).Transpose();

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

fn AllocateMaterialDescriptorSets(dAllocator: *DescriptorAllocator) !void {
    const inventory = try AssetInventory.GetInstance();

    var materialIter = inventory.m_materials.iterator();
    while (materialIter.next()) |*mat| {
        if (mat.value_ptr.m_shaderPass.m_shaderEffect.m_shaderDescriptorSetLayout) |matLayout| {
            try mat.value_ptr.AllocateDescriptorSet(dAllocator, matLayout);
        }
    }

    var materialInstIter = inventory.m_materialInstances.iterator();
    while (materialInstIter.next()) |*matInst| {
        if (matInst.value_ptr.m_parentMaterial.m_shaderPass.m_shaderEffect.m_instanceDescriptorSetLayout) |instLayout| {
            try matInst.value_ptr.AllocateDescriptorSet(dAllocator, instLayout);
        }
    }
}

pub fn RenderFrame(deltaTime: f32) !void {
    const swapchainAllocator = std.heap.page_allocator;

    curTime += deltaTime;
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
