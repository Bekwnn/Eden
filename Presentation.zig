const c = @import("c.zig");
const SimWorld = @import("SimWorld.zig").SimWorld;
const debug = @import("std").debug;

var curShader: ?c.GLuint = null;

pub fn Initialize(renderer: *c.SDL_Renderer) void {
    c.glEnable(c.GL_DEPTH_TEST);
    c.glDepthFunc(c.GL_LESS);
    _ = c.SDL_SetRenderDrawColor(renderer, 20, 20, 40, 255);
    curShader = LoadShader("basic.vert", "basic.frag");
    BindVAO();
}

//vertex shader: build, compile, link
// TODO should live in its own file
pub fn LoadShader(vertFile: []const u8, fragFile: []const u8) ?c.GLuint {
    var compileResult: c.GLint = c.GL_FALSE;

    // convert and compile
    debug.warn("Compiling {}...\n", vertFile);
    const vertProgramText = ReadVShader(vertFile); // needs to be GLchar*
    const vertShaderObject: c.GLuint = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertShaderObject, 1, &vertProgramText, 0);
    c.glCompileShader(vertShaderObject);

    c.glGetShaderiv(vertShaderObject, c.GL_COMPILE_STATUS, &compileResult);
    if (compileResult == c.GL_FALSE) {
        var errLogLength: c.GLint = 0;
        c.glGetShaderiv(vertShaderObject, c.GL_INFO_LOG_LENGTH, &errLogLength);
        var errLog: []u8 = undefined;
        c.glGetShaderInfoLog(vertShaderObject, errLogLength, &errLogLength, &errLog[0]);
        debug.warn("{}\n", errLog[0..@intCast(usize, errLogLength)]);
        return null;
    } else {
        debug.warn("Vertex shader {} compiled successfully.\n", vertFile);
    }

    // fragment shader: build, compile, link
    debug.warn("Compiling {}...\n", fragFile);
    const fragProgramText = ReadFShader(fragFile); // needs to be GLchar*
    const fragShaderObject: c.GLuint = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(fragShaderObject, 1, &fragProgramText, 0);
    c.glCompileShader(fragShaderObject);

    c.glGetShaderiv(fragShaderObject, c.GL_COMPILE_STATUS, &compileResult);
    if (compileResult == c.GL_FALSE) {
        var errLogLength: c.GLint = 0;
        c.glGetShaderiv(fragShaderObject, c.GL_INFO_LOG_LENGTH, &errLogLength);
        var errLog: []u8 = undefined;
        c.glGetShaderInfoLog(fragShaderObject, errLogLength, &errLogLength, &errLog[0]);
        debug.warn("{}\n", errLog[0..@intCast(usize, errLogLength)]);
        return null;
    } else {
        debug.warn("Fragment shader {} compiled successfully.\n", fragFile);
    }

    // link shaders
    debug.warn("Linking shader programs {} and {}...\n", vertFile, fragFile);
    const shaderObject: c.GLuint = c.glCreateProgram();
    c.glAttachShader(shaderObject, vertShaderObject);
    c.glAttachShader(shaderObject, fragShaderObject);
    c.glLinkProgram(shaderObject);

    c.glGetProgramiv(shaderObject, c.GL_LINK_STATUS, &compileResult);
    if (compileResult == c.GL_FALSE) {
        var errLogLength: c.GLint = 0;
        c.glGetProgramiv(shaderObject, c.GL_INFO_LOG_LENGTH, &errLogLength);
        var errLog: []u8 = undefined;
        c.glGetProgramInfoLog(shaderObject, errLogLength, &errLogLength, &errLog[0]);
        debug.warn("{}\n", errLog[0..@intCast(usize, errLogLength)]);
        return null;
    }
    debug.warn("Shader program {} and {} linked successfully.\n", vertFile, fragFile);

    // compiled shaders are linked to program, cleanup/delete source
    c.glDetachShader(shaderObject, vertShaderObject);
    c.glDetachShader(shaderObject, fragShaderObject);
    c.glDeleteShader(vertShaderObject);
    c.glDeleteShader(fragShaderObject);

    return shaderObject;
}

//TODO read from file
fn ReadVShader(shaderFileName: []const u8) [*]const u8 {
    return
        c\\#version 330 core
        c\\layout (location = 0) in vec3 aPos;
        c\\
        c\\void main()
        c\\{
        c\\    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
        c\\}
    ;
}
fn ReadFShader(shaderFileName: []const u8) [*]const u8 {
    return
        c\\#version 330 core
        c\\out vec4 FragColor;
        c\\
        c\\void main()
        c\\{
        c\\    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
        c\\} 
    ;
}

const vertices = [_]f32{
    -0.5, -0.5, 0.0,
    0.5,  -0.5, 0.0,
    0.0,  0.5,  0.0,
};

var triVAO: c.GLuint = 0;
var triVBO: c.GLuint = 0;

fn BindVAO() void {
    c.glGenBuffers(1, &triVBO);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, triVBO);
    c.glBufferData(c.GL_ARRAY_BUFFER, 9 * @sizeOf(f32), &vertices[0], c.GL_STATIC_DRAW);

    c.glGenVertexArrays(1, &triVAO);
    c.glBindVertexArray(triVAO);
    c.glEnableVertexAttribArray(0);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, triVBO);
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
}

pub fn RenderFrame(renderer: *c.SDL_Renderer, simWorld: *const SimWorld) void {
    _ = c.SDL_RenderClear(renderer);

    if (curShader) |s| {
        c.glUseProgram(s);
    } else {
        debug.warn("panic!");
        return;
    }
    c.glBindVertexArray(triVAO);
    c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

    c.SDL_RenderPresent(renderer); // End of Frame
}
