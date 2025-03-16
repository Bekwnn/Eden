const c = @import("../c.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const vkUtil = @import("VulkanUtil.zig");
const RenderContext = @import("RenderContext.zig").RenderContext;

pub const ShaderError = error{
    FailedToCreateShader,
    FailedToReadShaderFile,
};

pub const UniformBufferObject = struct {
    m_dataType: type,
    m_binding: u32,
};

pub const PushConstant = struct {
    m_dataType: type,
};

pub const MAX_DESCRIPTORS = 4;

// This struct holds all programmable shader modules to render something with and handles putting together shader modules
// It also holds holds info about the parameters passed into the shader programs
// https://docs.vulkan.org/tutorial/latest/03_Drawing_a_triangle/02_Graphics_pipeline_basics/00_Introduction.html
pub const Shader = struct {
    m_shaderStages: ArrayList(ShaderStage),
    m_descriptorSetLayouts: [MAX_DESCRIPTORS]c.VkDescriptorSetLayouts,

    pub const ShaderStage = struct {
        m_shader: c.VkShaderModule,
        m_flags: c.VkShaderStageFlagBits,
    };

    pub fn CreateEmptyShader(allocator: Allocator) Shader {
        return Shader{
            .m_shaderStages = ArrayList(ShaderStage).init(allocator),
            .m_descriptorSetLayouts = ArrayList(c.VkDescriptorSetLayouts).init(allocator),
            .m_uniformBufferObjects = ArrayList(UniformBufferObject).init(allocator),
        };
    }

    // caller must CheckAndFree
    pub fn CreateBasicShader(
        allocator: Allocator,
        vertShaderSource: []const u8,
        fragShaderSource: []const u8,
    ) !Shader {
        var newShader = Shader{
            .m_shaderStages = ArrayList(ShaderStage).init(allocator),
            .m_uniformBufferObjects = ArrayList(UniformBufferObject).init(allocator),
        };

        try newShader.AddShaderStage(allocator, vertShaderSource, c.VK_SHADER_STAGE_VERTEX_BIT);
        try newShader.AddShaderStage(allocator, fragShaderSource, c.VK_SHADER_STAGE_FRAGMENT_BIT);

        return newShader;
    }

    pub fn deinit(self: *Shader) void {
        for (self.m_shaderStages) |*stage| {
            CheckAndFreeShaderModule(stage);
        }
        self.m_shaderStages.deinit();
        self.m_uniformBufferObjects.deinit();
    }

    pub fn AddShaderStage(self: *Shader, allocator: Allocator, shaderSource: []const u8, flags: c.VkShaderStageFlagBits) !void {
        try self.m_shaderStages.add(ShaderStage{
            .m_shader = try CreateShaderModule(allocator, shaderSource),
            .m_flags = flags,
        });
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
