const std = @import("std");
const debug = std.debug;
const Dir = std.fs.Dir;
const Allocator = std.mem.Allocator;

usingnamespace @import("../c.zig");

var allocator = std.heap.page_allocator;

const ShaderCompileErr = error{SeeLog};

fn ShaderTypeStr(comptime shaderType: GLenum) []const u8 {
    return switch (shaderType) {
        GL_VERTEX_SHADER => "Vertex",
        GL_FRAGMENT_SHADER => "Fragment",
        GL_COMPUTE_SHADER => "Compute",
        GL_GEOMETRY_SHADER => "Geometry",
        GL_TESS_CONTROL_SHADER => "Tesselation Control",
        GL_TESS_EVALUATION_SHADER => "Tesselation Evaluation",
        else => return "Unknown",
    };
}
