const c = @import("../c.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const vk = @import("VulkanInit.zig");
const RenderContext = @import("RenderContext.zig").RenderContext;

pub const ShaderError = error{
    FailedToCreateShader,
    FailedToReadShaderFile,
};

// This struct holds multiple shader modules to render something with
pub const Shader = struct {
    m_vertShader: ?c.VkShaderModule,
    m_fragShader: ?c.VkShaderModule,
    //TODO support for other shader types/steps

    pub fn CreateBasicShader(
        allocator: Allocator,
        vertShaderSource: []const u8,
        fragShaderSource: []const u8,
    ) !Shader {
        //TODO shader paths should be optionals and shaders should be set null if no path is given
        //TODO how do we handle setting up shader stages and binding attribs or input state?
        return Shader{
            .m_vertShader = try CreateShaderModule(
                allocator,
                vertShaderSource,
            ),
            .m_fragShader = try CreateShaderModule(
                allocator,
                fragShaderSource,
            ),
        };
    }

    pub fn FreeShader(self: *Shader) void {
        defer CheckAndFreeShaderModule(&self.m_vertShader);
        defer CheckAndFreeShaderModule(&self.m_fragShader);
    }
};

fn CheckAndFreeShaderModule(shader: *?c.VkShaderModule) void {
    if (shader.* != null) {
        const rContext = RenderContext.GetInstance() catch return;
        c.vkDestroyShaderModule(
            rContext.m_logicalDevice,
            shader.*.?,
            null,
        );
        shader.* = null;
    }
}

// returns owned slice; caller needs to free
fn ReadShaderFile(comptime alignment: comptime_int, allocator: Allocator, relativeShaderPath: []const u8) ![]align(alignment) const u8 {
    std.debug.print("Reading shader {s}...\n", .{relativeShaderPath});

    var shaderDir = std.fs.cwd();
    var splitShaderPath = std.mem.tokenize(u8, relativeShaderPath, "\\/");

    while (splitShaderPath.next()) |path| {
        shaderDir = shaderDir.openDir(path, .{}) catch |err| {
            if (err != std.fs.Dir.OpenError.NotDir) {
                return err;
            } else {
                const shaderFile = try shaderDir.openFile(path, .{});
                defer shaderFile.close();

                var shaderCode: []align(alignment) u8 = try allocator.allocAdvanced(u8, alignment, try shaderFile.getEndPos(), .exact);

                _ = try shaderFile.read(shaderCode);
                return shaderCode;
            }
        };
    }
    return ShaderError.FailedToReadShaderFile;
}

fn CreateShaderModule(allocator: Allocator, relativeShaderPath: []const u8) !c.VkShaderModule {
    const shaderCode: []align(@alignOf(u32)) const u8 = try ReadShaderFile(@alignOf(u32), allocator, relativeShaderPath);
    defer allocator.free(shaderCode);

    const createInfo = c.VkShaderModuleCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = shaderCode.len,
        .pCode = std.mem.bytesAsSlice(u32, shaderCode).ptr,
        .pNext = null,
        .flags = 0,
    };

    const rContext = try RenderContext.GetInstance();
    var shaderModule: c.VkShaderModule = undefined;
    try vk.CheckVkSuccess(
        c.vkCreateShaderModule(rContext.m_logicalDevice, &createInfo, null, &shaderModule),
        ShaderError.FailedToCreateShader,
    );

    return shaderModule;
}
