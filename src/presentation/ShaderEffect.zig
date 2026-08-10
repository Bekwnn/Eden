const c = @import("../c.zig").cLib;

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Io = std.Io;

const vkUtil = @import("VulkanUtil.zig");
const RenderContext = @import("RenderContext.zig").RenderContext;
const DescriptorLayoutBuilder = @import("DescriptorLayoutBuilder.zig").DescriptorLayoutBuilder;

pub const ShaderError = error{
    FailedToCreateShader,
    FailedToReadShaderFile,
};

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

    m_shaderStages: ArrayList(ShaderStage) = .empty,
    // set 0 descriptor layout: rContext gpuSceneData globals
    // set 1 descriptor layout: per shader layout
    m_shaderDescriptorSetLayout: ?c.VkDescriptorSetLayout = null,
    m_shaderSetParams: ArrayList(DescriptorParam) = .empty,
    // set 2 descriptor layout: per shader instance layout
    m_instanceDescriptorSetLayout: ?c.VkDescriptorSetLayout = null,
    m_instanceSetParams: ArrayList(DescriptorParam) = .empty,
    // set 3 per render object layout
    m_objectDescriptorSetLayout: ?c.VkDescriptorSetLayout = null,
    m_objectSetParams: ArrayList(DescriptorParam) = .empty,

    m_pushConstantRanges: ArrayList(c.VkPushConstantRange) = .empty,

    m_allocator: Allocator,

    pub const ShaderStage = struct {
        m_shader: c.VkShaderModule,
        m_flags: c.VkShaderStageFlagBits,
    };

    pub fn CreateEmptyShader(allocator: Allocator) ShaderEffect {
        return ShaderEffect{
            .m_allocator = allocator,
        };
    }

    // caller must CheckAndFree
    pub fn CreateBasicShader(
        allocator: Allocator,
        io: Io,
        vertShaderSource: []const u8,
        fragShaderSource: []const u8,
    ) !ShaderEffect {
        var newShader = ShaderEffect.CreateEmptyShader(allocator);

        try newShader.AddShaderStage(allocator, io, vertShaderSource, c.VK_SHADER_STAGE_VERTEX_BIT);
        try newShader.AddShaderStage(allocator, io, fragShaderSource, c.VK_SHADER_STAGE_FRAGMENT_BIT);

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
        io: Io,
        shaderSource: []const u8,
        flags: c.VkShaderStageFlags,
    ) !void {
        try self.m_shaderStages.append(
            self.m_allocator,
            ShaderStage{
                .m_shader = try CreateShaderModule(allocator, io, shaderSource),
                .m_flags = flags,
            },
        );
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
    allocator: Allocator,
    io: Io,
    comptime alignment: comptime_int,
    relativeShaderPath: []const u8,
) ![]align(alignment) const u8 {
    std.debug.print("Reading shader [{s}]...\n", .{relativeShaderPath});

    var shaderDir = Io.Dir.cwd();

    const shaderFile = try shaderDir.openFile(io, relativeShaderPath, .{});
    defer shaderFile.close(io);

    const shaderCode: []align(alignment) u8 = try allocator.allocAdvancedWithRetAddr(
        u8,
        std.mem.Alignment.fromByteUnits(alignment),
        try shaderFile.length(io),
        @returnAddress(),
    );

    var readBuf: [1024]u8 = undefined;
    var shaderReader = shaderFile.reader(io, &readBuf);
    try shaderReader.interface.readSliceAll(shaderCode);
    return shaderCode;
}

fn CreateShaderModule(allocator: Allocator, io: Io, relativeShaderPath: []const u8) !c.VkShaderModule {
    const shaderCode: []align(@alignOf(u32)) const u8 = try ReadShaderFileAlloc(
        allocator,
        io,
        @alignOf(u32),
        relativeShaderPath,
    );
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
