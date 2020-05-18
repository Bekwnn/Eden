const debug = @import("std").debug;
const Shader = @import("Shader.zig").Shader;

const GameWorld = @import("../game/GameWorld.zig").GameWorld;

usingnamespace @import("../c.zig");

var curShader: ?Shader = null;

var imguiIO: ?*ImGuiIO = null;

pub fn Initialize(renderer: *SDL_Renderer) void {
    glClearColor(0.1, 0.1, 0.2, 1.0);
    curShader = Shader.init("src\\shaders\\basic.vert", "src\\shaders\\basic.frag");
    BindVAO();

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

const vertices = [_]f32{
    0.5,  0.5,  0.0,
    0.5,  -0.5, 0.0,
    -0.5, -0.5, 0.0,
    -0.5, 0.5,  0.0,
};

const indices = [_]u32{
    0, 1, 3,
    1, 2, 3,
};

var VAO: GLuint = 0;
var VBO: GLuint = 0;
var EBO: GLuint = 0;

fn BindVAO() void {
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    glGenBuffers(1, &EBO);

    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * @sizeOf(f32), null);
    glEnableVertexAttribArray(0);

    glBindVertexArray(0);
}

pub fn RenderFrame(renderer: *SDL_Renderer, screen: *SDL_Window, gameWorld: *const GameWorld) void {
    glClear(GL_COLOR_BUFFER_BIT);

    if (curShader) |s| {
        glUseProgram(s.gl_id);
    }
    glBindVertexArray(VAO);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null);

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
