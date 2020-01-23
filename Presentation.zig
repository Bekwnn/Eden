const c = @import("c.zig");
const SimWorld = @import("SimWorld.zig").SimWorld;
const debug = @import("std").debug;

pub fn Initialize(renderer: *c.SDL_Renderer) void {
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
    _ = LoadShader("basic.vert", "basic.frag");
}

//vertex shader: build, compile, link
// TODO should live in its own file
pub fn LoadShader(vertFile: []const u8, fragFile: []const u8) c.GLuint {
    var compileResult: c.GLint = c.GL_FALSE;

    // convert and compile
    debug.warn("Compiling {}...\n", vertFile);
    const vertProgramText = ReadShader(vertFile); // needs to be GLchar*
    const vertShaderObject: c.GLuint = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertShaderObject, 1, vertProgramText, 0);
    c.glCompileShader(vertShaderObject);

    c.glGetShaderiv(vertShaderObject, c.GL_COMPILE_STATUS, &compileResult);
    if (compileResult == c.GL_FALSE) {
        //glGetShaderiv(vertShaderObject, GL_INFO_LOG_LENGTH, &logLength);
        //std::vector<GLchar> vertErrorLog(logLength);
        //glGetShaderInfoLog(vertShaderObject, logLength, &logLength, &vertErrorLog[0]);
        //std::cout << &vertErrorLog[0] << std::endl;
        return;
    } else {
        debug.warn("Vertex shader {} compiled successfully.\n");
    }

    // fragment shader: build, compile, link
    debug.warn("Compiling {}...", fragFile);
    const fragProgramText = Presentation.ReadShader(fragFile); // needs to be GLchar*
    const fragShaderObject: c.GLuint = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(fragShaderObject, 1, fragProgramText, 0);
    c.glCompileShader(fragShaderObject);

    c.glGetShaderiv(fragShaderObject, c.GL_COMPILE_STATUS, &compileResult);
    if (compileResult == c.GL_FALSE) {
        //glGetShaderiv(vertShaderObject, GL_INFO_LOG_LENGTH, &logLength);
        //std::vector<GLchar> vertErrorLog(logLength);
        //glGetShaderInfoLog(vertShaderObject, logLength, &logLength, &vertErrorLog[0]);
        //std::cout << &vertErrorLog[0] << std::endl;
        return;
    } else {
        debug.warn("Fragment shader {} compiled successfully.\n");
    }

    // link shaders
    debug.warn("Linking shader programs {} and {}...", vertFile, fragFile);
    const shaderObject: c.GLuint = glCreateProgram();
    c.glAttachShader(shaderObject, vertShaderObject);
    c.glAttachShader(shaderObject, fragShaderObject);
    c.glLinkProgram(shaderObject);

    c.glGetProgramiv(shaderObject, c.GL_LINK_STATUS, &compileResult);
    if (compileResult == GL_FALSE) {
        //glGetProgramiv(shaderObject, GL_INFO_LOG_LENGTH, &logLength);
        //std::vector<GLchar> programError(logLength);
        //glGetProgramInfoLog(shaderObject, logLength, &logLength, &programError[0]);
        //std::cout << &programError[0] << std::endl;
        return;
    }
    debug.warn("Shader program {} and {} linked successfully.", vertFile, fragFile);

    // compiled shaders are linked to program, cleanup/delete source
    c.glDetachShader(shaderObject, vertShaderObject);
    c.glDetachShader(shaderObject, fragShaderObject);
    c.glDeleteShader(vertShaderObject);
    c.glDeleteShader(fragShaderObject);

    return shaderObject;
}

fn ReadShader(shaderFileName: []const u8) [1]u8 {
    return "!";
}

pub fn RenderFrame(renderer: *c.SDL_Renderer, simWorld: *const SimWorld) void {
    _ = c.SDL_RenderClear(renderer);

    const vertShaderTest: c.GLuint = 0;
    const fragShaderTest: c.GLuint = 0;

    c.SDL_RenderPresent(renderer); // End of Frame
}
