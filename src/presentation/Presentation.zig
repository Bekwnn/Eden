const std = @import("std");
const debug = std.debug;
const ArrayList = std.ArrayList;
const allocator = std.heap.page_allocator;

const AssetInventory = @import("AssetInventory.zig").AssetInventory;
const Buffer = @import("Buffer.zig").Buffer;
const c = @import("../c.zig");
const Camera = @import("Camera.zig").Camera;
const ColorRGBA = @import("../math/Color.zig").ColorRGBA;
const DescriptorAllocator = @import("DescriptorAllocator.zig").DescriptorAllocator;
const DescriptorLayoutBuilder = @import("DescriptorLayoutBuilder.zig").DescriptorLayoutBuilder;
const DescriptorWriter = @import("DescriptorWriter.zig").DescriptorWriter;
const em = @import("../math/Math.zig");
const filePathUtils = @import("../coreutil/FilePathUtils.zig");
const game = @import("../game/GameWorld.zig");
const GameWorld = @import("../game/GameWorld.zig").GameWorld;
const GPUSceneData = scene.GPUSceneData;
const input = @import("../Input.zig");
const Mat4x4 = @import("../math/Mat4x4.zig").Mat4x4;
const Material = @import("Material.zig").Material;
const materialParam = @import("MaterialParam.zig");
const MaterialParam = materialParam.MaterialParam;
const TextureParam = materialParam.TextureParam;
const UniformParam = materialParam.UniformParam;
const MaterialInstance = @import("MaterialInstance.zig").MaterialInstance;
const Mesh = @import("Mesh.zig").Mesh;
const Quat = @import("../math/Quat.zig").Quat;
const renderContext = @import("RenderContext.zig");
const RenderContext = renderContext.RenderContext;
const RenderObject = @import("RenderObject.zig").RenderObject;
const scene = @import("Scene.zig");
const Scene = scene.Scene;
const ShaderEffect = @import("ShaderEffect.zig").ShaderEffect;
const ShaderPass = @import("ShaderPass.zig").ShaderPass;
const Texture = @import("Texture.zig").Texture;
const Vec3 = @import("../math/Vec3.zig").Vec3;
const Vec4 = @import("../math/Vec4.zig").Vec4;
const vkUtil = @import("VulkanUtil.zig");

//TODO curTime should exist on a global of some kind
var curTime: f32 = 0.0;

//TODO move scene out
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

//TODO this needs to live somewhere, probably in AssetInventory
var texturedShaderEffect: ShaderEffect = undefined;
var coloredShaderEffect: ShaderEffect = undefined;
var coloredShaderBuffer: Buffer = undefined;
var shaderColor = ColorRGBA{
    .r = 0.0,
    .g = 0.6,
    .b = 0.6,
    .a = 1.0,
};
fn InitializeScene() !void {
    // init hardcoded test currentScene:
    var inventory = try AssetInventory.GetInstance();
    const mesh = inventory.CreateMesh("monkey", "test-assets\\test.obj") catch |meshErr| {
        debug.print("Error creating mesh: {}\n", .{meshErr});
        return meshErr;
    };

    const uvTexture = inventory.CreateTexture("uv_test", "test-assets\\test.png") catch |texErr| {
        debug.print("Error creating texture: {}\n", .{texErr});
        return texErr;
    };
    const texMaterial = inventory.CreateMaterial("textured_mat") catch |materialErr| {
        debug.print("Error creating material: {}\n", .{materialErr});
        return materialErr;
    };
    const texMaterialInst = inventory.CreateMaterialInstance("textured_mat_inst", texMaterial) catch |matInstError| {
        debug.print("Error creating material instance: {}\n", .{matInstError});
        return matInstError;
    };
    const coloredMat = inventory.CreateMaterial("colored_mat") catch |materialErr| {
        debug.print("Error creating material: {}\n", .{materialErr});
        return materialErr;
    };
    const coloredMatInst = inventory.CreateMaterialInstance("colored_mat_inst", coloredMat) catch |matInstError| {
        debug.print("Error creating material instance: {}\n", .{matInstError});
        return matInstError;
    };

    try currentScene.CreateCamera("default");

    const currentCamera = try currentScene.GetCurrentCamera();

    currentCamera.m_pos = Vec3{ .x = 0.0, .y = 0.0, .z = -25.0 };
    currentCamera.LookAt(Vec3.zero);

    const cameraViewMat = currentCamera.GetViewMatrix();
    const cameraProjMat = currentCamera.GetProjectionMatrix();
    const cameraViewProj = cameraProjMat.Mul(&cameraViewMat);

    //TODO should we include the clipspace mat?
    const rContext = try RenderContext.GetInstance();
    for (&rContext.m_frameData) |*frameData| {
        frameData.m_gpuSceneData = scene.GPUSceneData{
            .m_view = cameraViewMat.Transpose(),
            .m_projection = cameraProjMat.Transpose(),
            .m_viewProj = Camera.gl2VkClipSpace.Mul(&cameraViewProj).Transpose(),
            .m_ambientColor = Vec4{
                .x = 0.2,
                .y = 0.2,
                .z = 0.2,
                .w = 1.0,
            },
            .m_sunDirection = Vec4{
                .x = 0.0,
                .y = -1.0,
                .z = 0.0,
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

    // textured shader
    debug.print("Building basic_textured_mesh ShaderEffect...\n", .{});
    texturedShaderEffect = try ShaderEffect.CreateBasicShader(
        allocator,
        "src\\shaders\\compiled\\basic_textured_mesh-vert.spv",
        "src\\shaders\\compiled\\basic_textured_mesh-frag.spv",
    );

    // TODO make setting up a material parameter binding 1 call
    const textureParam = try TextureParam.init(allocator, uvTexture);
    try texMaterialInst.m_materialInstanceParams.append(MaterialParam.init(textureParam, 1));
    try texturedShaderEffect.m_instanceSetParams.append(ShaderEffect.DescriptorParam{
        .m_binding = 1,
        .m_descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .m_shaderStageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
    });

    try texturedShaderEffect.m_pushConstantRanges.append(c.VkPushConstantRange{
        .offset = 0,
        .size = @sizeOf(Mat4x4),
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    });
    try texturedShaderEffect.BuildLayouts(allocator);

    debug.print("Building basic_textured_mesh ShaderPass...\n", .{});
    texMaterial.m_shaderPass = try ShaderPass.BuildShaderPass(
        allocator,
        &texturedShaderEffect,
        c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        c.VK_POLYGON_MODE_FILL,
        Mesh.GetBindingDescription(),
        Mesh.GetAttributeDescriptions(),
    );

    // basic shader
    debug.print("Building basic_mesh ShaderEffect...\n", .{});
    coloredShaderEffect = try ShaderEffect.CreateBasicShader(
        allocator,
        "src\\shaders\\compiled\\basic_mesh-vert.spv",
        "src\\shaders\\compiled\\basic_mesh-frag.spv",
    );

    // TODO make setting up a material parameter binding 1 call
    const colorParam = try UniformParam.init(allocator, &coloredShaderBuffer, @sizeOf(@TypeOf(shaderColor)), 0);
    try coloredMatInst.m_materialInstanceParams.append(MaterialParam.init(colorParam, 1));
    try coloredShaderEffect.m_instanceSetParams.append(ShaderEffect.DescriptorParam{
        .m_binding = 1,
        .m_descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .m_shaderStageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
    });
    try coloredShaderEffect.m_pushConstantRanges.append(c.VkPushConstantRange{
        .offset = 0,
        .size = @sizeOf(Mat4x4),
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    });
    try coloredShaderEffect.BuildLayouts(allocator);

    coloredShaderBuffer = try Buffer.CreateBuffer(
        @sizeOf(ColorRGBA),
        c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    );

    try coloredShaderBuffer.MapMemory(@ptrCast(&shaderColor), @sizeOf(ColorRGBA));

    debug.print("Building basic_mesh ShaderPass...\n", .{});
    coloredMat.m_shaderPass = try ShaderPass.BuildShaderPass(
        allocator,
        &coloredShaderEffect,
        c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        c.VK_POLYGON_MODE_FILL,
        Mesh.GetBindingDescription(),
        Mesh.GetAttributeDescriptions(),
    );

    const width = 10;
    const height = 10;
    for (0..height) |i| {
        for (0..width) |j| {
            const name = try std.fmt.allocPrint(allocator, "Monkey_Mesh_{d}.{d}", .{ i, j });
            try currentScene.m_renderables.put(
                name,
                RenderObject.init(
                    allocator,
                    name,
                    mesh,
                    if ((i + j) % 2 == 0) texMaterialInst else coloredMatInst,
                ),
            );
            const newRenderObj = currentScene.m_renderables.getPtr(name) orelse @panic("!");
            newRenderObj.m_transform = Mat4x4.Translation(Vec3{
                .x = (-5.0 * @divFloor(width, 2)) + (@as(f32, @floatFromInt(j)) * 5.0),
                .y = 0.0,
                .z = (-5.0 * @divFloor(height, 2)) + (@as(f32, @floatFromInt(i)) * 5.0),
            }).Transpose();
        }
    }
}

// TODO remove time params, make them accessible elsewhere
pub fn ImguiFrame(deltaT: f32, rawDeltaNs: u64) !void {
    //_ = c.igShowDemoWindow(null);

    var camera = try currentScene.GetCurrentCamera();
    _ = c.igBegin("My Editor Window", null, c.ImGuiWindowFlags_None);
    _ = c.igText(
        "Actual FPS: %.1f, Uncapped FPS: %.1f",
        1.0 / deltaT,
        @as(f32, @floatFromInt(std.time.ns_per_s)) / @as(f32, @floatFromInt(rawDeltaNs)),
    );

    _ = c.igText("Camera Pos: (%.2f, %.2f, %.2f)", camera.m_pos.x, camera.m_pos.y, camera.m_pos.z);
    c.igSetNextItemWidth(150.0);
    _ = c.igSliderFloat("Camera Speed", &movespeed, 1.0, 75.0, "%.2f", c.ImGuiSliderFlags_None);
    _ = c.igColorEdit4("Monkey Color", @ptrCast(&shaderColor), c.ImGuiColorEditFlags_None);

    const cameraEulers = camera.m_rotation.GetEulerAngles();
    _ = c.igText(
        "Camera (Pitch, Yaw, Roll): (%.2f, %.2f, %.2f)",
        cameraEulers.x * std.math.deg_per_rad,
        cameraEulers.y * std.math.deg_per_rad,
        cameraEulers.z * std.math.deg_per_rad,
    );
    _ = c.igText(
        "Camera Quat: (x:%.3f, y:%.3f, z:%.3f, w:%.3f)",
        camera.m_rotation.x,
        camera.m_rotation.y,
        camera.m_rotation.z,
        camera.m_rotation.w,
    );
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
        try currentFrame.m_descriptorAllocator.ClearPools(rContext.m_logicalDevice);
        try rContext.AllocateCurrentFrameGlobalDescriptors();

        try AllocateMaterialDescriptorSets(&currentFrame.m_descriptorAllocator);

        try UpdateUniformSceneBuffer();

        try WriteDescriptors();

        var renderableIter = currentScene.m_renderables.iterator();
        var previousParentMaterial: ?*Material = null;
        var previousMaterialInstance: ?*MaterialInstance = null;
        while (renderableIter.next()) |renderableEntry| {
            var matInstance = renderableEntry.value_ptr.m_materialInstance;

            //TODO move out handling binding somewhere else
            c.vkCmdBindPipeline(
                commandBuffer,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                matInstance.m_parentMaterial.m_shaderPass.m_pipeline,
            );

            if (previousParentMaterial == null or
                (previousParentMaterial != null and previousParentMaterial.? != matInstance.m_parentMaterial))
            {
                // currently binding shader globals with material params, could bind shader globals separately
                const descriptorSets = [_]c.VkDescriptorSet{
                    currentFrame.m_gpuSceneDataDescriptorSet,
                    matInstance.m_parentMaterial.m_materialDescriptorSet orelse currentFrame.m_emptyDescriptorSet,
                };
                c.vkCmdBindDescriptorSets(
                    commandBuffer,
                    c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                    matInstance.m_parentMaterial.m_shaderPass.m_pipelineLayout,
                    0,
                    @intCast(descriptorSets.len),
                    &descriptorSets,
                    0,
                    null,
                );
                previousParentMaterial = matInstance.m_parentMaterial;
            }

            if (previousMaterialInstance == null or
                (previousMaterialInstance != null and previousMaterialInstance.? != matInstance))
            {
                c.vkCmdBindDescriptorSets(
                    commandBuffer,
                    c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                    matInstance.m_parentMaterial.m_shaderPass.m_pipelineLayout,
                    2,
                    1,
                    &(matInstance.m_instanceDescriptorSet orelse currentFrame.m_emptyDescriptorSet),
                    0,
                    null,
                );
                previousMaterialInstance = matInstance;
            }

            if (matInstance.GetObjectDescriptorSetLayout()) |objLayout| {
                try renderableEntry.value_ptr.AllocateDescriptorSet(&currentFrame.m_descriptorAllocator, objLayout);
            }

            c.vkCmdBindDescriptorSets(
                commandBuffer,
                c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                matInstance.m_parentMaterial.m_shaderPass.m_pipelineLayout,
                3,
                1,
                &(renderableEntry.value_ptr.m_objectDescriptorSet orelse currentFrame.m_emptyDescriptorSet),
                0,
                null,
            );

            renderableEntry.value_ptr.Draw(commandBuffer) catch |err| {
                std.debug.print("Error {} drawing {s}\n", .{ err, renderableEntry.key_ptr });
            };
        }

        c.ImGui_ImplVulkan_RenderDrawData(c.igGetDrawData(), commandBuffer, null);
    }
    c.vkCmdEndRenderPass(commandBuffer);

    try vkUtil.CheckVkSuccess(
        c.vkEndCommandBuffer(commandBuffer),
        RenderLoopError.FailedToEndCommandBuffer,
    );
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
    var renderIter = currentScene.m_renderables.iterator();
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
    const camera = try currentScene.GetCurrentCamera();
    const view = camera.GetViewMatrix();
    const proj = camera.GetProjectionMatrix();
    currentFrameData.m_gpuSceneData.m_view = view.Transpose();
    currentFrameData.m_gpuSceneData.m_projection = proj.Transpose();
    currentFrameData.m_gpuSceneData.m_viewProj = proj.Mul(&view).Transpose();

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

    if (coloredShaderBuffer.m_mappedData) |mappedData| {
        const bufferSize = @sizeOf(ColorRGBA);
        @memcpy(
            @as([*]u8, @ptrCast(mappedData))[0..bufferSize],
            @as([*]u8, @ptrCast(&shaderColor))[0..bufferSize],
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

//TODO temp function for camera movement
const degPerPixel: f32 = 0.25;
var movespeed: f32 = 20.0;
var rMouseButtonHeld = false;
var prevMouseX: i32 = 0;
var prevMouseY: i32 = 0;
fn UpdateCameraMovement(deltaTime: f32) !void {
    var relativeMouseX: i32 = 0;
    var relativeMouseY: i32 = 0;
    const mouseState = c.SDL_GetMouseState(&relativeMouseX, &relativeMouseY);
    if (mouseState & c.SDL_BUTTON_RMASK != 0) {
        if (!rMouseButtonHeld) {
            // start tracking mouse pos on frame 0, update rotation on subsequent frames
            rMouseButtonHeld = true;
        } else {
            const deltaMouseX = relativeMouseX - prevMouseX;
            const deltaMouseY = relativeMouseY - prevMouseY;
            var camera = try currentScene.GetCurrentCamera();
            const deltaYaw = @as(f32, @floatFromInt(deltaMouseX)) * degPerPixel * std.math.rad_per_deg;
            const deltaPitch = @as(f32, @floatFromInt(deltaMouseY)) * degPerPixel * std.math.rad_per_deg;
            const cameraEulers = camera.m_rotation.GetEulerAngles();
            camera.m_rotation = Quat.FromEulerAngles(cameraEulers.y - deltaYaw, cameraEulers.x - deltaPitch, 0.0);

            var movementVec = Vec3.zero;
            if (input.GetKeyState(c.SDL_SCANCODE_W, null)) {
                movementVec.z -= 1.0; //why is +Z not forward?
            }
            if (input.GetKeyState(c.SDL_SCANCODE_S, null)) {
                movementVec.z += 1.0;
            }

            if (input.GetKeyState(c.SDL_SCANCODE_D, null)) {
                movementVec.x += 1.0;
            }
            if (input.GetKeyState(c.SDL_SCANCODE_A, null)) {
                movementVec.x -= 1.0;
            }

            if (input.GetKeyState(c.SDL_SCANCODE_E, null)) {
                movementVec.y += 1.0;
            }
            if (input.GetKeyState(c.SDL_SCANCODE_Q, null)) {
                movementVec.y -= 1.0;
            }

            if (!movementVec.Equals(Vec3.zero)) {
                movementVec.NormalizeSelf();
                movementVec.Scale(movespeed * deltaTime);
            }

            camera.m_pos = camera.m_pos.Add(camera.m_rotation.Rotate(movementVec));
        }

        prevMouseX = relativeMouseX;
        prevMouseY = relativeMouseY;
    } else {
        rMouseButtonHeld = false;
    }
}

pub fn RenderFrame(deltaTime: f32) !void {
    const swapchainAllocator = std.heap.page_allocator;

    curTime += deltaTime;
    const rContext = try RenderContext.GetInstance();
    const currentFrameData = rContext.GetCurrentFrame();

    //TODO move input logic
    try UpdateCameraMovement(deltaTime);

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
