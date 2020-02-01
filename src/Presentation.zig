const SimWorld = @import("SimWorld.zig").SimWorld;
const debug = @import("std").debug;

usingnamespace @import("c.zig");

var curShader: ?GLuint = null;

pub fn Initialize(renderer: *SDL_Renderer) void {
    glDepthFunc(GL_LESS);
    glClearColor(0.1, 0.1, 0.2, 1.0);
    curShader = LoadShader("basivert", "basifrag");
    BindVAO();
}

//vertex shader: build, compile, link
// TODO should live in its own file
pub fn LoadShader(vertFile: []const u8, fragFile: []const u8) ?GLuint {
    var compileResult: GLint = GL_FALSE;

    // convert and compile
    debug.warn("Compiling {}...\n", vertFile);
    const vertProgramText = ReadVShader(vertFile); // needs to be GLchar*
    const vertShaderObject: GLuint = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertShaderObject, 1, &vertProgramText, 0);
    glCompileShader(vertShaderObject);

    glGetShaderiv(vertShaderObject, GL_COMPILE_STATUS, &compileResult);
    if (compileResult == GL_FALSE) {
        var errLogLength: GLint = 0;
        glGetShaderiv(vertShaderObject, GL_INFO_LOG_LENGTH, &errLogLength);
        var errLog: []u8 = undefined;
        glGetShaderInfoLog(vertShaderObject, errLogLength, &errLogLength, &errLog[0]);
        debug.warn("{}\n", errLog[0..@intCast(usize, errLogLength)]);
        return null;
    } else {
        debug.warn("Vertex shader {} compiled successfully.\n", vertFile);
    }

    // fragment shader: build, compile, link
    debug.warn("Compiling {}...\n", fragFile);
    const fragProgramText = ReadFShader(fragFile); // needs to be GLchar*
    const fragShaderObject: GLuint = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragShaderObject, 1, &fragProgramText, 0);
    glCompileShader(fragShaderObject);

    glGetShaderiv(fragShaderObject, GL_COMPILE_STATUS, &compileResult);
    if (compileResult == GL_FALSE) {
        var errLogLength: GLint = 0;
        glGetShaderiv(fragShaderObject, GL_INFO_LOG_LENGTH, &errLogLength);
        var errLog: []u8 = undefined;
        glGetShaderInfoLog(fragShaderObject, errLogLength, &errLogLength, &errLog[0]);
        debug.warn("{}\n", errLog[0..@intCast(usize, errLogLength)]);
        return null;
    } else {
        debug.warn("Fragment shader {} compiled successfully.\n", fragFile);
    }

    // link shaders
    debug.warn("Linking shader programs {} and {}...\n", vertFile, fragFile);
    const shaderObject: GLuint = glCreateProgram();
    glAttachShader(shaderObject, vertShaderObject);
    glAttachShader(shaderObject, fragShaderObject);
    glLinkProgram(shaderObject);

    glGetProgramiv(shaderObject, GL_LINK_STATUS, &compileResult);
    if (compileResult == GL_FALSE) {
        var errLogLength: GLint = 0;
        glGetProgramiv(shaderObject, GL_INFO_LOG_LENGTH, &errLogLength);
        var errLog: []u8 = undefined;
        glGetProgramInfoLog(shaderObject, errLogLength, &errLogLength, &errLog[0]);
        debug.warn("{}\n", errLog[0..@intCast(usize, errLogLength)]);
        return null;
    }
    debug.warn("Shader program {} and {} linked successfully.\n", vertFile, fragFile);

    // compiled shaders are linked to program, cleanup/delete source
    glDeleteShader(vertShaderObject);
    glDeleteShader(fragShaderObject);

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

pub fn RenderFrame(renderer: *SDL_Renderer, screen: *SDL_Window, simWorld: *const SimWorld) void {
    glClear(GL_COLOR_BUFFER_BIT);

    if (curShader) |s| {
        glUseProgram(s);
    }
    glBindVertexArray(VAO);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null);

    SDL_GL_SwapWindow(screen);
}
