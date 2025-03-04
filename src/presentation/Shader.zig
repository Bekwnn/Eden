const c = @import("../c.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const vkUtil = @import("VulkanUtil.zig");
const RenderContext = @import("RenderContext.zig").RenderContext;

pub const ShaderError = error{
    FailedToCreateShader,
    FailedToReadShaderFile,
};

// This struct holds all programmable shader modules to render something with and handles putting together shader modules
// https://docs.vulkan.org/tutorial/latest/03_Drawing_a_triangle/02_Graphics_pipeline_basics/00_Introduction.html
pub const Shader = struct {
    m_vertShader: ?c.VkShaderModule,
    m_tessShader: ?c.VkShaderModule,
    m_geomShader: ?c.VkShaderModule,
    m_fragShader: ?c.VkShaderModule,

    // caller must CheckAndFree
    pub fn CreateBasicShader(
        allocator: Allocator,
        vertShaderSource: []const u8,
        fragShaderSource: []const u8,
    ) !Shader {
        //TODO how do we handle setting up shader stages and binding attribs or input state?
        return Shader{
            .m_vertShader = try CreateShaderModule(
                allocator,
                vertShaderSource,
            ),
            .m_tessShader = null,
            .m_geomShader = null,
            .m_fragShader = try CreateShaderModule(
                allocator,
                fragShaderSource,
            ),
        };
    }

    // caller must CheckAndFree
    pub fn CreateAdvancedShader(
        allocator: Allocator,
        vertShaderSource: ?[]const u8,
        tessShaderSource: ?[]const u8,
        geomShaderSource: ?[]const u8,
        fragShaderSource: ?[]const u8,
    ) !Shader {
        return Shader{
            .m_vertShader = if (vertShaderSource) |shaderSrc| try CreateShaderModule(
                allocator,
                shaderSrc,
            ) else null,
            .m_tessShader = if (tessShaderSource) |shaderSrc| try CreateShaderModule(
                allocator,
                shaderSrc,
            ) else null,
            .m_geomShader = if (geomShaderSource) |shaderSrc| try CreateShaderModule(
                allocator,
                shaderSrc,
            ) else null,
            .m_fragShader = if (fragShaderSource) |shaderSrc| try CreateShaderModule(
                allocator,
                shaderSrc,
            ) else null,
        };
    }

    pub fn FreeShader(self: *Shader) void {
        CheckAndFreeShaderModule(&self.m_vertShader);
        CheckAndFreeShaderModule(&self.m_tessShader);
        CheckAndFreeShaderModule(&self.m_geomShader);
        CheckAndFreeShaderModule(&self.m_fragShader);
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
fn ReadShaderFileAlloc(
    comptime alignment: comptime_int,
    allocator: Allocator,
    relativeShaderPath: []const u8,
) ![]align(alignment) const u8 {
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

                const shaderCode: []align(alignment) u8 = try allocator.allocAdvancedWithRetAddr(
                    u8,
                    alignment,
                    try shaderFile.getEndPos(),
                    @returnAddress(),
                );

                _ = try shaderFile.read(shaderCode);
                return shaderCode;
            }
        };
    }
    return ShaderError.FailedToReadShaderFile;
}

fn CreateShaderModule(allocator: Allocator, relativeShaderPath: []const u8) !c.VkShaderModule {
    const shaderCode: []align(@alignOf(u32)) const u8 = try ReadShaderFileAlloc(@alignOf(u32), allocator, relativeShaderPath);
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
    try vkUtil.CheckVkSuccess(
        c.vkCreateShaderModule(rContext.m_logicalDevice, &createInfo, null, &shaderModule),
        ShaderError.FailedToCreateShader,
    );

    return shaderModule;
}
