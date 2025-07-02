const std = @import("std");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const c = @import("../c.zig");

const ColorRGBA = @import("../math/Color.zig").ColorRGBA;
const Vec3 = @import("../math/Vec3.zig").Vec3;

const AssetInventory = @import("AssetInventory.zig").AssetInventory;
const Buffer = @import("Buffer.zig").Buffer;
const GPUSceneData = @import("Scene.zig").GPUSceneData;
const materialParam = @import("MaterialParam.zig");
const RenderContext = @import("RenderContext.zig").RenderContext;
const Scene = @import("Scene.zig").Scene;
const ShaderEffect = @import("ShaderEffect.zig").ShaderEffect;
const ShaderPass = @import("ShaderPass.zig").ShaderPass;
const MaterialParam = materialParam.MaterialParam;
const UniformParam = materialParam.UniformParam;

var debugLineShaderEffect: ShaderEffect = undefined;
pub var debugLineVertexBuffers = [_]?Buffer{null} ** 2; //double buffered per frame
pub var debugLines = std.ArrayList(DebugLine).init(allocator);
pub const DebugLine = struct {
    m_lines: [2]Vec3,
    m_color: ColorRGBA,
};
pub fn CreateDebugLine(start: Vec3, end: Vec3, color: ColorRGBA) !*DebugLine {
    try debugLines.append(DebugLine{
        .m_lines = [_]Vec3{
            start,
            end,
        },
        .m_color = color,
    });
    return &debugLines.items[debugLines.items.len - 1];
}

pub fn FillVertexBuffer() !void {
    const rContext = try RenderContext.GetInstance();
    const debugLineBuffer = &debugLineVertexBuffers[rContext.m_currentFrame];

    // recreating every frame because the number of verts and debug lines can change dynamically
    // might be a better way to handle this
    if (debugLineBuffer.*) |*buffer| {
        buffer.DestroyBuffer(rContext.m_logicalDevice);
        debugLineBuffer.* = null;
    }

    const vertCount = debugLines.items.len * 2;
    const bufferSize = vertCount * @sizeOf(Vec3);
    debugLineBuffer.* = try Buffer.CreateBuffer(
        bufferSize,
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
    );

    const tempVerts = (try allocator.alloc(Vec3, vertCount))[0..vertCount];
    defer allocator.free(tempVerts);

    for (debugLines.items, 0..) |debugLine, i| {
        tempVerts[i * 2] = debugLine.m_lines[0];
        tempVerts[i * 2 + 1] = debugLine.m_lines[1];
    }

    try debugLineBuffer.*.?.CopyStagingBuffer(tempVerts.ptr, bufferSize);
}

pub fn BindForDrawing(cmd: c.VkCommandBuffer) !void {
    const assetInventory = try AssetInventory.GetInstance();
    const debugLineMatInst = assetInventory.GetMaterialInst("debug_line_mat_inst") orelse @panic("!");
    try debugLineMatInst.m_parentMaterial.BindMaterial(cmd);
    try debugLineMatInst.BindMaterialInstance(cmd);

    const currentFrameIdx = (try RenderContext.GetInstance()).m_currentFrame;
    const offsets = [_]c.VkDeviceSize{0};
    const vertexBuffers = [_]c.VkBuffer{
        debugLineVertexBuffers[currentFrameIdx].?.m_buffer,
    };
    c.vkCmdBindVertexBuffers(
        cmd,
        0,
        1,
        &vertexBuffers,
        &offsets,
    );
}

pub fn BindDebugLine(cmd: c.VkCommandBuffer, pipelineLayout: c.VkPipelineLayout, debugLine: DebugLine) void {
    c.vkCmdPushConstants(
        cmd,
        pipelineLayout,
        c.VK_SHADER_STAGE_FRAGMENT_BIT,
        0,
        @sizeOf(ColorRGBA),
        &debugLine.m_color,
    );
}

pub fn Init() !void {
    const inventory = try AssetInventory.GetInstance();

    const debugLineMat = try inventory.CreateMaterial("debug_line_mat");
    _ = try inventory.CreateMaterialInstance("debug_line_mat_inst", debugLineMat);

    debugLineShaderEffect = try ShaderEffect.CreateBasicShader(
        allocator,
        "src\\shaders\\compiled\\debug_colored-vert.spv",
        "src\\shaders\\compiled\\debug_colored-frag.spv",
    );
    try debugLineShaderEffect.m_pushConstantRanges.append(c.VkPushConstantRange{
        .offset = 0,
        .size = @sizeOf(ColorRGBA),
        .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
    });
    try debugLineShaderEffect.BuildLayouts(allocator);

    const debugLineBindingDesc = c.VkVertexInputBindingDescription{
        .binding = 0,
        .stride = @sizeOf(Vec3),
        .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
    };
    const debugLineAttribDesc = [_]c.VkVertexInputAttributeDescription{
        c.VkVertexInputAttributeDescription{
            .binding = 0,
            .location = 0,
            .format = c.VK_FORMAT_R32G32B32_SFLOAT,
            .offset = 0,
        },
    };

    debug.print("Building debug line ShaderPass...\n", .{});
    debugLineMat.m_shaderPass = try ShaderPass.BuildShaderPass(
        allocator,
        &debugLineShaderEffect,
        c.VK_PRIMITIVE_TOPOLOGY_LINE_LIST,
        c.VK_POLYGON_MODE_LINE,
        &debugLineBindingDesc,
        &debugLineAttribDesc,
    );
}
