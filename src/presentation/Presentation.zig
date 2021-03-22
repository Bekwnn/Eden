const std = @import("std");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const Shader = @import("Shader.zig").Shader;
const Mesh = @import("Mesh.zig").Mesh;
const assimp = @import("AssImpInterface.zig");
const Camera = @import("Camera.zig").Camera;
const mat4x4 = @import("../math/Mat4x4.zig");

const game = @import("../game/GameWorld.zig");
const GameWorld = @import("../game/GameWorld.zig").GameWorld;

const filePathUtils = @import("../coreutil/FilePathUtils.zig");

usingnamespace @import("../c.zig");

var curShader: ?Shader = null;
var curMesh: ?Mesh = null;
var curMesh2: ?Mesh = null;
var curCamera = Camera{};
var curTime: f32 = 0.0;
var circleTime: f32 = 1.0 / (2.0 * std.math.pi);
const circleRadius: f32 = 0.5;

var imguiIO: ?*ImGuiIO = null;

pub fn Initialize(renderer: *SDL_Renderer) void {
    glClearColor(0.1, 0.1, 0.2, 1.0);
    curShader = Shader.init("src\\shaders\\basic_mesh.vert", "src\\shaders\\basic_mesh.frag");

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
    curMesh2 = curMesh;
    if (curMesh2 != null) {
        curMesh2.?.PushDataToBuffers();
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

    // imgui init
    imguiIO = igGetIO();
    if (imguiIO) |io| {
        var text_pixels: [*c]u8 = undefined;
        var text_w: i32 = undefined;
        var text_h: i32 = undefined;
        ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &text_pixels, &text_w, &text_h, null);
    } else {
        @panic("imguiIO is null");
    }
}

pub fn RenderFrame(renderer: *SDL_Renderer, screen: *SDL_Window, gameWorld: *const GameWorld) void {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);

    curTime += game.deltaTime;
    curCamera.m_pos.x = circleRadius * std.math.cos(curTime / (std.math.tau * circleTime));
    curCamera.m_pos.y = circleRadius * std.math.sin(curTime / (std.math.tau * circleTime));

    if (curMesh) |m| {
        if (curShader) |s| {
            m.Draw(&curCamera, s.gl_id);
        }
    }
    if (curMesh2) |m| {
        if (curShader) |s| {
            m.Draw(&curCamera, s.gl_id);
        }
    }

    //imgui update
    var window_w: i32 = undefined;
    var window_h: i32 = undefined;
    SDL_GetWindowSize(screen, &window_w, &window_h);
    if (imguiIO) |io| {
        io.DisplaySize.x = @intToFloat(f32, window_w);
        io.DisplaySize.y = @intToFloat(f32, window_h);
        io.DeltaTime = 1.0 / 60.0;
    } else {
        @panic("imguiIO is null");
    }

    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplSDL2_NewFrame(screen);
    igNewFrame();

    igShowDemoWindow(null);

    igRender();
    ImGui_ImplOpenGL3_RenderDrawData(igGetDrawData());

    SDL_GL_SwapWindow(screen);
}
