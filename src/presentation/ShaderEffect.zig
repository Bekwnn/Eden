const c = @import("../c.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const vkUtil = @import("VulkanUtil.zig");
const RenderContext = @import("RenderContext.zig").RenderContext;
const DescriptorLayoutBuilder = @import("DescriptorLayoutBuilder.zig").DescriptorLayoutBuilder;

pub const ShaderError = error{
    FailedToCreateShader,
    FailedToReadShaderFile,
};

pub const MAX_DESCRIPTORS = 4;

// This struct holds multiple shader modules to be used with a single pipeline
// It also holds holds info about the parameters passed into the shader programs
// https://docs.vulkan.org/tutorial/latest/03_Drawing_a_triangle/02_Graphics_pipeline_basics/00_Introduction.html
pub const ShaderEffect = struct {
    const Self = @This();

    pub const DescriptorParam = struct {
        m_binding: u32,
        m_descriptorType: c.VkDescriptorType,
        m_shaderStageFlags: c.VkShaderStageFlags,
    };

    m_shaderStages: ArrayList(ShaderStage),
    // set 0 descriptor layout: rContext gpuSceneData globals
    // set 1 descriptor layout: per shader layout
    m_shaderDescriptorSetLayout: ?c.VkDescriptorSetLayout = null,
    m_shaderSetParams: ArrayList(DescriptorParam),
    // set 2 descriptor layout: per shader instance layout
    m_instanceDescriptorSetLayout: ?c.VkDescriptorSetLayout = null,
    m_instanceSetParams: ArrayList(DescriptorParam),
    // set 3 per render object layout
    m_objectDescriptorSetLayout: ?c.VkDescriptorSetLayout = null,
    m_objectSetParams: ArrayList(DescriptorParam),

    m_pushConstantRanges: ArrayList(c.VkPushConstantRange),

    pub const ShaderStage = struct {
        m_shader: c.VkShaderModule,
        m_flags: c.VkShaderStageFlagBits,
    };

    pub fn CreateEmptyShader(allocator: Allocator) ShaderEffect {
        return ShaderEffect{
            .m_shaderStages = ArrayList(ShaderStage).init(allocator),
            .m_pushConstantRanges = ArrayList(c.VkPushConstantRange).init(allocator),
        };
    }

    // caller must CheckAndFree
    pub fn CreateBasicShader(
        allocator: Allocator,
        vertShaderSource: []const u8,
        fragShaderSource: []const u8,
    ) !ShaderEffect {
        var newShader = ShaderEffect{
            .m_shaderStages = ArrayList(ShaderStage).init(allocator),
            .m_shaderSetParams = ArrayList(DescriptorParam).init(allocator),
            .m_instanceSetParams = ArrayList(DescriptorParam).init(allocator),
            .m_objectSetParams = ArrayList(DescriptorParam).init(allocator),
            .m_pushConstantRanges = ArrayList(c.VkPushConstantRange).init(allocator),
        };

        try newShader.AddShaderStage(allocator, vertShaderSource, c.VK_SHADER_STAGE_VERTEX_BIT);
        try newShader.AddShaderStage(allocator, fragShaderSource, c.VK_SHADER_STAGE_FRAGMENT_BIT);

        return newShader;
    }

    pub fn deinit(self: *Self) void {
        for (self.m_shaderStages) |stage| {
            CheckAndFreeShaderModule(stage);
        }
        self.m_shaderStages.deinit();
    }

    pub fn BuildLayouts(self: *Self, allocator: Allocator) !void {
        if (self.m_shaderSetParams.items.len != 0) {
            self.m_shaderDescriptorSetLayout = try BuildLayout(allocator, &self.m_shaderSetParams);
        }

        if (self.m_instanceSetParams.items.len != 0) {
            self.m_instanceDescriptorSetLayout = try BuildLayout(allocator, &self.m_instanceSetParams);
        }

        if (self.m_objectSetParams.items.len != 0) {
            self.m_objectDescriptorSetLayout = try BuildLayout(allocator, &self.m_objectSetParams);
        }
    }

    pub fn AddShaderStage(
        self: *Self,
        allocator: Allocator,
        shaderSource: []const u8,
        flags: c.VkShaderStageFlags,
    ) !void {
        try self.m_shaderStages.append(ShaderStage{
            .m_shader = try CreateShaderModule(allocator, shaderSource),
            .m_flags = flags,
        });
    }
};

fn BuildLayout(
    allocator: Allocator,
    params: *ArrayList(ShaderEffect.DescriptorParam),
) !c.VkDescriptorSetLayout {
    const rContext = try RenderContext.GetInstance();

    var layoutBuilder = DescriptorLayoutBuilder.init(allocator);
    defer layoutBuilder.deinit();
    var shaderStageFlags: c.VkShaderStageFlags = 0;
    for (params.items) |param| {
        try layoutBuilder.AddBinding(
            param.m_binding,
            param.m_descriptorType,
        );
        shaderStageFlags |= param.m_shaderStageFlags;
    }
    return try layoutBuilder.Build(rContext.m_logicalDevice, shaderStageFlags);
}

fn CheckAndFreeShaderModule(shader: c.VkShaderModule) void {
    const rContext = RenderContext.GetInstance() catch return;
    c.vkDestroyShaderModule(
        rContext.m_logicalDevice,
        shader,
        null,
    );
}

// returns owned slice; caller needs to free
fn ReadShaderFileAlloc(
    comptime alignment: comptime_int,
    allocator: Allocator,
    relativeShaderPath: []const u8,
) ![]align(alignment) const u8 {
    std.debug.print("Reading shader {s}...\n", .{relativeShaderPath});

    var shaderDir = std.fs.cwd();
    var splitShaderPath = std.mem.tokenizeScalar(u8, relativeShaderPath, '/');

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
