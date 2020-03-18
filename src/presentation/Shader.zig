const std = @import("std");
const debug = std.debug;
const Dir = std.fs.Dir;
const Allocator = std.mem.Allocator;

usingnamespace @import("../c.zig");

var allocator = std.heap.direct_allocator;

const ShaderCompileErr = error{SeeLog};

fn ShaderTypeStr(comptime shaderType: GLenum) []const u8 {
    return switch (shaderType) {
        GL_VERTEX_SHADER => "Vertex",
        GL_FRAGMENT_SHADER => "Fragment",
        GL_COMPUTE_SHADER => "Compute",
        GL_GEOMETRY_SHADER => "Geometry",
        GL_TESS_CONTROL_SHADER => "Tessalation Control",
        GL_TESS_EVALUATION_SHADER => "Tessalation Evaluation",
        else => return "Unknown",
    };
}

// return needs to be cleaned up with glDeleteShader
fn CompileShader(relativePath: []const u8, comptime shaderType: GLenum) !GLuint {
    var compileResult: GLint = GL_FALSE;

    debug.warn("Compiling {} Shader {}...\n", .{ ShaderTypeStr(shaderType), relativePath });

    const cwd: Dir = std.fs.cwd();
    const shaderFile = try cwd.openFile(relativePath, .{});
    defer shaderFile.close();

    var shaderCode = try allocator.alloc(u8, try shaderFile.getEndPos());
    defer allocator.free(shaderCode);

    const shaderObject: GLuint = glCreateShader(shaderType);
    _ = try shaderFile.read(shaderCode);
    const shaderSrcPtr: ?[*]const u8 = shaderCode.ptr;
    glShaderSource(shaderObject, 1, &shaderSrcPtr, 0);
    glCompileShader(shaderObject);

    glGetShaderiv(shaderObject, GL_COMPILE_STATUS, &compileResult);
    if (compileResult == GL_FALSE) {
        var errLogLength: GLint = 0;
        glGetShaderiv(shaderObject, GL_INFO_LOG_LENGTH, &errLogLength);
        var errLog = try allocator.alloc(u8, @intCast(usize, errLogLength));
        glGetShaderInfoLog(shaderObject, errLogLength, &errLogLength, errLog.ptr); //this line segfaults?
        debug.warn("{}\n", .{errLog[0..@intCast(usize, errLogLength)]});
        return ShaderCompileErr.SeeLog;
    } else {
        debug.warn("{} shader {} compiled successfully.\n", .{ ShaderTypeStr(shaderType), relativePath });
    }

    return shaderObject;
}

pub const Shader = struct {
    gl_id: GLuint,

    pub fn init(vertFile: []const u8, fragFile: []const u8) ?Shader {

        // vert shader: build, compile, link
        const vertShaderObject = CompileShader(vertFile, GL_VERTEX_SHADER) catch |err| {
            debug.warn("Unable to compile {} shader with path {}, error: {}\n", .{ ShaderTypeStr(GL_VERTEX_SHADER), vertFile, err });
            return null;
        };
        defer glDeleteShader(vertShaderObject);

        // fragment shader: build, compile, link
        const fragShaderObject = CompileShader(fragFile, GL_FRAGMENT_SHADER) catch |err| {
            debug.warn("Unable to compile {} shader with path {}, error: {}\n", .{ ShaderTypeStr(GL_FRAGMENT_SHADER), fragFile, err });
            return null;
        };
        defer glDeleteShader(fragShaderObject);

        // link shaders
        debug.warn("Linking shader programs {} and {}...\n", .{ vertFile, fragFile });
        const shaderObject: GLuint = glCreateProgram();
        glAttachShader(shaderObject, vertShaderObject);
        glAttachShader(shaderObject, fragShaderObject);
        glLinkProgram(shaderObject);

        var compileResult: GLint = GL_FALSE;
        glGetProgramiv(shaderObject, GL_LINK_STATUS, &compileResult);
        if (compileResult == GL_FALSE) {
            var errLogLength: GLint = 0;
            glGetProgramiv(shaderObject, GL_INFO_LOG_LENGTH, &errLogLength);
            var errLog: []u8 = undefined;
            glGetProgramInfoLog(shaderObject, errLogLength, &errLogLength, &errLog[0]);
            debug.warn("{}\n", .{errLog[0..@intCast(usize, errLogLength)]});
            return null;
        }
        debug.warn("Shader program {} and {} linked successfully.\n", .{ vertFile, fragFile });

        return Shader{ .gl_id = shaderObject };
    }

    //    pub fn PushUniform(
};
