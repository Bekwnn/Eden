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
const ShaderEffect = @import("ShaderEffect.zig").ShaderEffect;
const ShaderPass = @import("ShaderPass.zig").ShaderPass;

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

    const testShaderEffect = try ShaderEffect.CreateBasicShader(allocator, "basic.vert", "basic.frag");
    const testShaderPass = try ShaderPass.BuildShaderPass(
        &testShaderEffect,
        c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        c.VK_POLYGON_MODE_FILL,
        Mesh.GetBindingDescription(),
        Mesh.GetAttributeDescriptions(),
    );
    _ = testShaderPass;

    // set up meshes
    var ix: i8 = -1;
    var iy: i8 = -1;
    while (iy <= 1) : (iy += 1) {
        while (ix <= 1) : (ix += 1) {
            // TODO build properly
            _ = mesh;
            try renderables.append(RenderObject{
                .m_firstIndex = 0,
                .m_indexCount = 0,
                .m_indexBuffer = undefined,
                .m_material = material,
                .m_transform = mat4x4.TranslationMat4x4(Vec3{
                    .x = @as(f32, @floatFromInt(ix)) * 2.0,
                    .y = @as(f32, @floatFromInt(iy)) * 2.0,
                    .z = 0.0,
                }),
                .m_vertBufferAddress = undefined,
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
        for (&renderables.items, 0..) |*renderObj, i| {
            _ = renderObj;
            _ = i;
            //TODO
            //c.vkCmdBindVertexBuffers();
            //c.vkCmdBindIndexBuffer();
            //c.vkCmdBindDescriptorSets();
            //c.vkCmdDrawIndexed();
        }
    }
    c.vkCmdEndRenderPass(commandBuffer);

    try vkUtil.CheckVkSuccess(
        c.vkEndCommandBuffer(commandBuffer),
        RenderLoopError.FailedToEndCommandBuffer,
    );
}

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

    currentFrame = (currentFrame + 1) % renderContext.FRAMES_IN_FLIGHT;
}

//fn DrawBackground(cmd: c.VkCommandBuffer) void {
//
//}
//
//fn DrawMeshes(cmd: c.VkCommandBuffer) void {
//
//}
