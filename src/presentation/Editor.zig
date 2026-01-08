const std = @import("std");

const DebugDraw = @import("DebugDraw.zig");
const presentation = @import("Presentation.zig");
const renderContext = @import("RenderContext.zig");
const RenderContext = renderContext.RenderContext;
const sceneInit = @import("SceneInit.zig");
const vkUtil = @import("VulkanUtil.zig");
const Texture = @import("Texture.zig").Texture;

const Quat = @import("../math/Quat.zig").Quat;
const Vec3 = @import("../math/Vec3.zig").Vec3;
const Vec2 = @import("../math/Vec2.zig").Vec2;

const c = @import("../c.zig").cLib;
const input = @import("../Input.zig");

const allocator = std.heap.page_allocator;

var mainWindow: ?*c.SDL_Window = null;

// TODO temp vars to setup widths of different docked windows
// should instead be more container/parent based than this
//
// bottom tray and top bar exist first, and the left/right
// trays + middle viewport lie sandwiched between them
const leftTrayWidth = 200.0;
const bottomTrayHeight = 200.0;
const rightTrayWidth = 300.0;
const topBarHeight = 50.0;
const fixedWindowFlags =
    c.ImGuiWindowFlags_NoResize |
    c.ImGuiWindowFlags_NoMove |
    c.ImGuiWindowFlags_NoTitleBar;

pub const EditorError = error{
    FailedToInitialize,
};

//TODO resize texture on swapchain resize
pub const ViewportFrameData = struct {
    m_descriptorSet: c.VkDescriptorSet,
    m_colorTexture: Texture,
    m_depthTexture: Texture,
    m_sampler: c.VkSampler,

    pub fn GetId(self: *ViewportFrameData) c.ImTextureID {
        return @as(c.ImTextureID, @intFromPtr(self.m_descriptorSet));
    }
};

var viewportFrameData: std.ArrayList(ViewportFrameData) = .empty;

pub fn Initialize(window: *c.SDL_Window) !void {
    c.igGetIO_Nil().*.ConfigFlags |= c.ImGuiConfigFlags_DockingEnable;
    mainWindow = window;

    // Initialize data for the render viewport
    const rContext = try RenderContext.GetInstance();
    const imageCount = rContext.m_swapchain.m_imageCount;
    try viewportFrameData.ensureTotalCapacity(allocator, imageCount);
    for (0..imageCount) |_| {
        const curViewportData = viewportFrameData.addOneAssumeCapacity();
        curViewportData.m_colorTexture = try Texture.CreateColorImage(
            rContext.m_logicalDevice,
            rContext.m_swapchain.m_extent.width,
            rContext.m_swapchain.m_extent.height,
            rContext.m_msaaSamples,
            rContext.m_swapchain.m_format.format,
            c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
                c.VK_IMAGE_USAGE_SAMPLED_BIT,
        );

        const depthFormat = try renderContext.FindDepthFormat();
        curViewportData.m_depthTexture = try Texture.CreateDepthImage(
            rContext.m_logicalDevice,
            rContext.m_swapchain.m_extent.width,
            rContext.m_swapchain.m_extent.height,
            rContext.m_msaaSamples,
            depthFormat,
        );

        const samplerInfo = c.VkSamplerCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
            .magFilter = c.VK_FILTER_LINEAR,
            .minFilter = c.VK_FILTER_LINEAR,
            .addressModeU = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
            .addressModeV = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
            .addressModeW = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
            .anisotropyEnable = c.VK_FALSE,
            .maxAnisotropy = 1,
            .borderColor = c.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
            .compareEnable = c.VK_FALSE,
            .compareOp = c.VK_COMPARE_OP_ALWAYS,
            .unnormalizedCoordinates = c.VK_FALSE,
            .mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR,
            .mipLodBias = 0.0,
            .minLod = -1000,
            .maxLod = 1000,
            .flags = 0,
            .pNext = null,
        };
        try vkUtil.CheckVkSuccess(
            c.vkCreateSampler(
                rContext.m_logicalDevice,
                &samplerInfo,
                null,
                &curViewportData.m_sampler,
            ),
            EditorError.FailedToInitialize,
        );

        curViewportData.m_descriptorSet = c.ImGui_ImplVulkan_AddTexture(
            curViewportData.m_sampler,
            curViewportData.m_colorTexture.m_imageView,
            c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        );
    }
}

pub fn Deinit() void {
    const rContext = RenderContext.GetInstance() catch {
        @panic("!");
    };
    for (viewportFrameData.items) |*vpFrameData| {
        vpFrameData.m_colorTexture.FreeTexture(rContext.m_logicalDevice);
        c.vkDestroySampler(rContext.m_logicalDevice, vpFrameData.m_sampler, null);
        //TODO causing GPU crash:
        // message: vkFreeDescriptorSets(): descriptorPool was created with
        // VkDescriptorPoolCreateFl ags(0) (missing FREE_DESCRIPTOR_SET_BIT).
        // The Vulkan spec states: descriptorPool must have been created with
        // the VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT flag
        // (https://vulkan.lunarg.com/doc/view/1.4.309.0/window s/antora/spec/latest/chapters/descriptorsets.html#VUID-vkFreeDescriptorSets-descriptorPoo l-00312)
        //
        //c.ImGui_ImplVulkan_RemoveTexture(vpFrameData.m_descriptorSet);
    }
}

fn TransitionImageLayout(
    cmd: c.VkCommandBuffer,
    image: c.VkImage,
    oldLayout: c.VkImageLayout,
    newLayout: c.VkImageLayout,
) void {
    const imageBarrier = c.VkImageMemoryBarrier2{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
        .srcStageMask = c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstStageMask = c.VK_PIPELINE_STAGE_2_TRANSFER_BIT,
        .srcAccessMask = 0,
        .dstAccessMask = c.VK_ACCESS_TRANSFER_READ_BIT,
        .oldLayout = oldLayout,
        .newLayout = newLayout,
        .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresourceRange = c.VkImageSubresourceRange{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseArrayLayer = 0,
            .layerCount = 1,
            .baseMipLevel = 0,
            .levelCount = 1,
        },
        .pNext = null,
    };

    //TODO double check _BITs used here against the spec
    c.vkCmdPipelineBarrier2(
        cmd,
        &c.VkDependencyInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEPENDENCY_INFO,
            .imageMemoryBarrierCount = 1,
            .pImageMemoryBarriers = &imageBarrier,
        },
    );
}

pub fn GetCurrentViewportFrameData() !*ViewportFrameData {
    const rContext = try RenderContext.GetInstance();
    return &viewportFrameData.items[rContext.m_currentFrame];
}

pub fn CopyImageToViewport(
    cmd: c.VkCommandBuffer,
    srcImage: c.VkImage,
    srcLayout: c.VkImageLayout,
) !void {
    const rContext = try RenderContext.GetInstance();
    const currentFrameData = &viewportFrameData.items[rContext.m_currentFrame];

    // Steps:
    // 1. transition both images to transfer_src/dst format
    // 2. perform copy
    // 3. transition images to ???

    //TODO make transition image layout util somewhere
    TransitionImageLayout(
        cmd,
        srcImage,
        srcLayout,
        c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
    );

    TransitionImageLayout(
        cmd,
        currentFrameData.m_colorTexture.m_image,
        c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
    );

    // Actual copy step
    c.vkCmdCopyImage(
        cmd,
        srcImage,
        c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        currentFrameData.m_colorTexture.m_image,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        1,
        &c.VkImageCopy{
            .srcOffset = c.VkOffset3D{ .x = 0, .y = 0, .z = 0 },
            .dstOffset = c.VkOffset3D{ .x = 0, .y = 0, .z = 0 },
            .srcSubresource = c.VkImageSubresourceLayers{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseArrayLayer = 0,
                .layerCount = 1,
                .mipLevel = 0,
            },
            .dstSubresource = c.VkImageSubresourceLayers{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseArrayLayer = 0,
                .layerCount = 1,
                .mipLevel = 0,
            },
            .extent = c.VkExtent3D{
                .width = rContext.m_swapchain.m_extent.width,
                .height = rContext.m_swapchain.m_extent.height,
                .depth = 1,
            },
        },
    );

    // Transition SRC and DST back
    TransitionImageLayout(
        cmd,
        srcImage,
        c.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        srcLayout,
    );

    TransitionImageLayout(
        cmd,
        currentFrameData.m_colorTexture.m_image,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    );
}

pub fn GetMainWindow() !*c.SDL_Window {
    const WindowError = error{MissingWindow};
    return mainWindow orelse WindowError.MissingWindow;
}

// right tray
pub fn DrawSceneInspector() !void {
    const window: *c.SDL_Window = try GetMainWindow();
    var winSizeX: c_int = 0;
    var winSizeY: c_int = 0;
    c.SDL_GetWindowSize(window, &winSizeX, &winSizeY);
    c.igSetNextWindowPos(
        c.ImVec2{ .x = @as(f32, @floatFromInt(winSizeX)) - rightTrayWidth, .y = topBarHeight },
        c.ImGuiCond_None,
        c.ImVec2{ .x = 0.0, .y = 0.0 },
    );
    c.igSetNextWindowSize(
        c.ImVec2{ .x = rightTrayWidth, .y = @as(f32, @floatFromInt(winSizeY)) - (topBarHeight + bottomTrayHeight) },
        c.ImGuiCond_None,
    );

    if (c.igBegin("Inspector", null, fixedWindowFlags)) {
        _ = c.igText("Scene View + Object Inspector go here.");
    }

    c.igEnd();
}

// left tray
pub fn DrawGlobalSettings() !void {
    const window: *c.SDL_Window = try GetMainWindow();
    var winSizeX: c_int = 0;
    var winSizeY: c_int = 0;
    c.SDL_GetWindowSize(window, &winSizeX, &winSizeY);
    c.igSetNextWindowPos(
        c.ImVec2{ .x = 0.0, .y = topBarHeight },
        c.ImGuiCond_None,
        c.ImVec2{ .x = 0.0, .y = 0.0 },
    );
    c.igSetNextWindowSize(
        c.ImVec2{ .x = leftTrayWidth, .y = @as(f32, @floatFromInt(winSizeY)) - (topBarHeight + bottomTrayHeight) },
        c.ImGuiCond_None,
    );

    if (c.igBegin("Global Settings", null, fixedWindowFlags)) {
        _ = c.igText("Global Settings go here.");
    }

    c.igEnd();
}

// top bar: will have menus, play button, and more
pub fn DrawTopBar() !void {
    const window: *c.SDL_Window = try GetMainWindow();
    var winSizeX: c_int = 0;
    var winSizeY: c_int = 0;
    c.SDL_GetWindowSize(window, &winSizeX, &winSizeY);
    c.igSetNextWindowPos(
        c.ImVec2{ .x = 0.0, .y = 0.0 },
        c.ImGuiCond_None,
        c.ImVec2{ .x = 0.0, .y = 0.0 },
    );
    c.igSetNextWindowSize(
        c.ImVec2{ .x = @floatFromInt(winSizeX), .y = topBarHeight },
        c.ImGuiCond_None,
    );

    if (c.igBegin("Top Bar", null, fixedWindowFlags)) {
        _ = c.igText("Menu + play button goes here.");
    }

    c.igEnd();
}

// bottom tray: will have folder browser + console + more
pub fn DrawBottomTray() !void {
    const window: *c.SDL_Window = try GetMainWindow();
    var winSizeX: c_int = 0;
    var winSizeY: c_int = 0;
    c.SDL_GetWindowSize(window, &winSizeX, &winSizeY);
    c.igSetNextWindowPos(
        c.ImVec2{ .x = 0.0, .y = @as(f32, @floatFromInt(winSizeY)) - bottomTrayHeight },
        c.ImGuiCond_None,
        c.ImVec2{ .x = 0.0, .y = 0.0 },
    );
    c.igSetNextWindowSize(
        c.ImVec2{ .x = @floatFromInt(winSizeX), .y = bottomTrayHeight },
        c.ImGuiCond_None,
    );

    if (c.igBegin("Bottom Tray", null, fixedWindowFlags)) {
        _ = c.igText("Bottom tray stuff goes here.");
    }

    c.igEnd();
}

// middle viewport
pub fn DrawViewport() !void {
    const window: *c.SDL_Window = try GetMainWindow();
    var winSizeX: c_int = 0;
    var winSizeY: c_int = 0;
    c.SDL_GetWindowSize(window, &winSizeX, &winSizeY);
    c.igSetNextWindowPos(
        c.ImVec2{ .x = leftTrayWidth, .y = topBarHeight },
        c.ImGuiCond_None,
        c.ImVec2{ .x = 0.0, .y = 0.0 },
    );
    c.igSetNextWindowSize(
        c.ImVec2{
            .x = @as(f32, @floatFromInt(winSizeX)) - (leftTrayWidth + rightTrayWidth),
            .y = @as(f32, @floatFromInt(winSizeY)) - (topBarHeight + bottomTrayHeight),
        },
        c.ImGuiCond_None,
    );

    if (c.igBegin("Viewport", null, fixedWindowFlags | c.ImGuiWindowFlags_NoBackground)) {
        _ = c.igText("Viewport goes here.");
        //const rContext = try RenderContext.GetInstance();
        //c.igImage(
        //    viewportFrameData.items[rContext.m_currentFrame].GetId(),
        //    c.ImVec2{
        //        .x = @floatFromInt(rContext.m_swapchain.m_extent.width),
        //        .y = @floatFromInt(rContext.m_swapchain.m_extent.height),
        //    },
        //    c.ImVec2{ .x = 0, .y = 0 }, // default
        //    c.ImVec2{ .x = 1, .y = 1 }, // default
        //);
    }

    c.igEnd();
}

//TODO delete eventually
pub fn DrawFloatingDebugWindow(deltaT: f32, rawDeltaNs: u64) !void {
    var camera = try sceneInit.GetCurrentScene().GetCurrentCamera();
    _ = c.igBegin("My Editor Window", null, c.ImGuiWindowFlags_None);
    _ = c.igText(
        "Actual FPS: %.1f, Uncapped FPS: %.1f",
        1.0 / deltaT,
        @as(f32, @floatFromInt(std.time.ns_per_s)) / @as(f32, @floatFromInt(rawDeltaNs)),
    );

    _ = c.igText("Camera Pos: (%.2f, %.2f, %.2f)", camera.m_pos.x, camera.m_pos.y, camera.m_pos.z);
    c.igSetNextItemWidth(150.0);
    _ = c.igSliderFloat("Camera Speed", &movespeed, 1.0, 75.0, "%.2f", c.ImGuiSliderFlags_None);
    _ = c.igColorEdit4("Monkey Color", @ptrCast(&sceneInit.shaderColor), c.ImGuiColorEditFlags_None);

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

    _ = c.igText("Draw Stats:");
    _ = c.igText("Batches: %d", presentation.drawStats.m_batches);
    _ = c.igText("Renderables Drawn: %d", presentation.drawStats.m_renderablesDrawn);
    _ = c.igText("Total Renderables in Scene: %d", presentation.drawStats.m_renderablesInScene);
    _ = c.igText("Total Debug Lines: %d", DebugDraw.debugLines.items.len);
    _ = c.igText("Total Debug Circles: %d", DebugDraw.debugCircles.items.len);
    c.igEnd();
}

pub fn Draw(deltaT: f32, rawDeltaNs: u64) !void {
    _ = deltaT;
    _ = rawDeltaNs;

    try DrawTopBar();
    try DrawBottomTray();
    try DrawSceneInspector();
    try DrawGlobalSettings();
    try DrawViewport();

    //try DrawFloatingDebugWindow(deltaT, rawDeltaNs);
}

//TODO temp function for camera movement
const degPerPixel: f32 = 0.25;
var movespeed: f32 = 20.0;
var rMouseButtonHeld = false;
var prevMouseX: i32 = 0;
var prevMouseY: i32 = 0;
pub fn UpdateCameraMovement(deltaTime: f32) !void {
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
            var camera = try sceneInit.GetCurrentScene().GetCurrentCamera();
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
                movementVec.ScaleSelf(movespeed * deltaTime);
            }

            camera.m_pos = camera.m_pos.Add(camera.m_rotation.Rotate(movementVec));
        }

        prevMouseX = relativeMouseX;
        prevMouseY = relativeMouseY;
    } else {
        rMouseButtonHeld = false;
    }
}
