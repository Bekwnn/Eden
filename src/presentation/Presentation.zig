const debug = @import("std").debug;
const Shader = @import("Shader.zig").Shader;
const Mesh = @import("Mesh.zig").Mesh;
const assimp = @import("AssImpInterface.zig");

const GameWorld = @import("../game/GameWorld.zig").GameWorld;

usingnamespace @import("../c.zig");

var curShader: ?Shader = null;
var curMesh: ?Mesh = null;

var imguiIO: ?*ImGuiIO = null;

pub fn Initialize(renderer: *SDL_Renderer) void {
    glClearColor(0.1, 0.1, 0.2, 1.0);
    curShader = Shader.init("src\\shaders\\basic_mesh.vert", "src\\shaders\\basic_mesh.frag");

    if (assimp.ImportMesh("F:/Dev Demos and Content/Zig/Eden/test-assets/test.obj")) |mesh| {
        curMesh = mesh;
    } else |meshErr| {
        debug.warn("Error importing mesh: {}\n", .{meshErr});
    }

    if (curMesh != null) {
        curMesh.?.PushDataToBuffers();
    }

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

    if (curMesh) |m| {
        if (curShader) |s| {
            m.Draw(s.gl_id);
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
