const c = @import("../c.zig");
const sceneInit = @import("SceneInit.zig");
const std = @import("std");
const drawStats = @import("Presentation.zig").drawStats;
const DebugDraw = @import("DebugDraw.zig");
const input = @import("../Input.zig");

const Quat = @import("../math/Quat.zig").Quat;
const Vec3 = @import("../math/Vec3.zig").Vec3;

pub fn Initialize() !void {
    c.igGetIO().ConfigFlags |= c.ImGuiConfigFlags_DockingEnabled;
}

pub fn Draw(deltaT: f32, rawDeltaNs: f32) !void {
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
    _ = c.igText("Batches: %d", drawStats.m_batches);
    _ = c.igText("Renderables Drawn: %d", drawStats.m_renderablesDrawn);
    _ = c.igText("Total Renderables in Scene: %d", drawStats.m_renderablesInScene);
    _ = c.igText("Total Debug Lines: %d", DebugDraw.debugLines.items.len);
    _ = c.igText("Total Debug Circles: %d", DebugDraw.debugCircles.items.len);
    c.igEnd();
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
