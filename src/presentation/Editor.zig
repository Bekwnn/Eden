const c = @import("../c.zig");
const sceneInit = @import("SceneInit.zig");
const std = @import("std");
const presentation = @import("Presentation.zig");
const DebugDraw = @import("DebugDraw.zig");
const input = @import("../Input.zig");

const Quat = @import("../math/Quat.zig").Quat;
const Vec3 = @import("../math/Vec3.zig").Vec3;
const Vec2 = @import("../math/Vec2.zig").Vec2;

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

pub fn Initialize(window: *c.SDL_Window) !void {
    c.igGetIO_Nil().*.ConfigFlags |= c.ImGuiConfigFlags_DockingEnable;
    mainWindow = window;
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
