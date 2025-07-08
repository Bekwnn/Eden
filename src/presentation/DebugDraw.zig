const std = @import("std");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const c = @import("../c.zig");

const ColorRGBA = @import("../math/Color.zig").ColorRGBA;
const Quat = @import("../math/Quat.zig").Quat;
const Vec3 = @import("../math/Vec3.zig").Vec3;

const AssetInventory = @import("AssetInventory.zig").AssetInventory;
const Buffer = @import("Buffer.zig").Buffer;
const GPUSceneData = @import("Scene.zig").GPUSceneData;
const materialParam = @import("MaterialParam.zig");
const MaterialInstance = @import("MaterialInstance.zig").MaterialInstance;
const RenderContext = @import("RenderContext.zig").RenderContext;
const Scene = @import("Scene.zig").Scene;
const ShaderEffect = @import("ShaderEffect.zig").ShaderEffect;
const ShaderPass = @import("ShaderPass.zig").ShaderPass;
const MaterialParam = materialParam.MaterialParam;
const UniformParam = materialParam.UniformParam;

var debugShaderEffect: ShaderEffect = undefined;

//TODO reduce repeating for different primitives
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

pub var debugCircleVertexBuffers = [_]?Buffer{null} ** 2;
pub var debugCircles = std.ArrayList(DebugCircle).init(allocator);
pub const DebugCircle = struct {
    m_pos: Vec3,
    m_upDir: Vec3,
    m_radius: f32,
    m_color: ColorRGBA,
};
pub fn CreateDebugCircle(pos: Vec3, upDir: Vec3, radius: f32, color: ColorRGBA) !*DebugCircle {
    try debugCircles.append(DebugCircle{
        .m_pos = pos,
        .m_upDir = upDir,
        .m_radius = radius,
        .m_color = color,
    });
    return &debugCircles.items[debugCircles.items.len - 1];
}

pub var debugBoxVertexBuffers = [_]?Buffer{null} ** 2;
pub var debugBoxes = std.ArrayList(DebugBox).init(allocator);
pub const DebugBox = struct {
    m_center: Vec3,
    m_extents: Vec3,
    m_color: ColorRGBA,
};
pub fn CreateDebugBox(center: Vec3, extents: Vec3, color: ColorRGBA) !*DebugBox {
    try debugBoxes.append(DebugBox{
        .m_center = center,
        .m_extents = extents,
        .m_color = color,
    });
    return &debugBoxes.items[debugBoxes.items.len - 1];
}

pub fn ShouldDraw() bool {
    return debugLines.items.len != 0 or debugCircles.items.len != 0;
}

pub fn FillDebugVertexBuffers() !void {
    if (debugLines.items.len != 0) {
        try FillDebugLineVertexBuffer();
    }
    if (debugCircles.items.len != 0) {
        try FillDebugCircleVertexBuffer();
    }
    if (debugBoxes.items.len != 0) {
        try FillDebugBoxVertexBuffer();
    }
}

//TODO don't recreate vertex buffer every frame
fn FillDebugLineVertexBuffer() !void {
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

    const tempVerts = try allocator.alloc(Vec3, vertCount);
    defer allocator.free(tempVerts);

    for (debugLines.items, 0..) |debugLine, i| {
        tempVerts[i * 2] = debugLine.m_lines[0];
        tempVerts[i * 2 + 1] = debugLine.m_lines[1];
    }

    try debugLineBuffer.*.?.CopyStagingBuffer(tempVerts.ptr, bufferSize);
}

// TODO we should accomodate varying vert counts and have m_sides field per circle
const debugCircleNumSides = 8;
//TODO don't recreate vertex buffer every frame
fn FillDebugCircleVertexBuffer() !void {
    const rContext = try RenderContext.GetInstance();
    const debugCircleBuffer = &debugCircleVertexBuffers[rContext.m_currentFrame];

    // recreating every frame because the number of verts and debug lines can change dynamically
    // might be a better way to handle this
    if (debugCircleBuffer.*) |*buffer| {
        buffer.DestroyBuffer(rContext.m_logicalDevice);
        debugCircleBuffer.* = null;
    }

    const numSides = debugCircleNumSides;
    const vertCount = debugCircles.items.len * (numSides + 1);
    const bufferSize = vertCount * @sizeOf(Vec3);
    debugCircleBuffer.* = try Buffer.CreateBuffer(
        bufferSize,
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
    );

    const tempVerts = try allocator.alloc(Vec3, vertCount);
    defer allocator.free(tempVerts);

    for (debugCircles.items, 0..) |debugCircle, circleIdx| {
        const otherVec = if (!debugCircle.m_upDir.Equals(Vec3.yAxis)) Vec3.yAxis else Vec3.zAxis;
        const planeVec = debugCircle.m_upDir.Cross(otherVec).Normalized();
        const firstVertIdx = circleIdx * (numSides + 1);

        for (0..numSides) |vertIdx| {
            const offset = planeVec.GetScaled(debugCircle.m_radius);
            const offsetRotation = Quat.GetAxisRotation(
                debugCircle.m_upDir,
                45.0 * std.math.rad_per_deg * @as(f32, @floatFromInt(vertIdx)),
            );
            tempVerts[firstVertIdx + vertIdx] = debugCircle.m_pos.Add(offsetRotation.Rotate(offset));
        }
        tempVerts[firstVertIdx + numSides] = tempVerts[firstVertIdx]; // add first vert to end
    }

    try debugCircleBuffer.*.?.CopyStagingBuffer(tempVerts.ptr, bufferSize);
}

const debugBoxNumVerts = 24;
fn FillDebugBoxVertexBuffer() !void {
    const rContext = try RenderContext.GetInstance();
    const debugBoxBuffer = &debugBoxVertexBuffers[rContext.m_currentFrame];

    // recreating every frame because the number of verts and debug lines can change dynamically
    // might be a better way to handle this
    if (debugBoxBuffer.*) |*buffer| {
        buffer.DestroyBuffer(rContext.m_logicalDevice);
        debugBoxBuffer.* = null;
    }

    const vertCount = debugBoxes.items.len * debugBoxNumVerts; // 12 lines
    const bufferSize = vertCount * @sizeOf(Vec3);
    debugBoxBuffer.* = try Buffer.CreateBuffer(
        bufferSize,
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
    );

    const tempVerts = try allocator.alloc(Vec3, vertCount);
    defer allocator.free(tempVerts);

    for (debugBoxes.items, 0..) |debugBox, boxIdx| {
        const firstIdx = boxIdx * debugBoxNumVerts;
        const corner = debugBox.m_center.Sub(debugBox.m_extents);
        const extents2 = debugBox.m_extents.GetScaled(2.0);

        //xy
        for (0..2) |i| {
            const x = corner.x + extents2.x * @as(f32, @floatFromInt(i));
            for (0..2) |j| {
                const y = corner.y + extents2.y * @as(f32, @floatFromInt(j));
                tempVerts[firstIdx + i * 4 + j * 2] = Vec3{
                    .x = x,
                    .y = y,
                    .z = corner.z,
                };
                tempVerts[firstIdx + i * 4 + j * 2 + 1] = Vec3{
                    .x = x,
                    .y = y,
                    .z = corner.z + extents2.z,
                };
            }
        }
        //xz
        const xzFirstIdx = firstIdx + 8;
        for (0..2) |i| {
            const x = corner.x + extents2.x * @as(f32, @floatFromInt(i));
            for (0..2) |j| {
                const z = corner.z + extents2.z * @as(f32, @floatFromInt(j));
                tempVerts[xzFirstIdx + i * 4 + j * 2] = Vec3{
                    .x = x,
                    .y = corner.y,
                    .z = z,
                };
                tempVerts[xzFirstIdx + i * 4 + j * 2 + 1] = Vec3{
                    .x = x,
                    .y = corner.y + extents2.y,
                    .z = z,
                };
            }
        }
        //yz
        const yzFirstIdx = firstIdx + 16;
        for (0..2) |i| {
            const y = corner.y + extents2.y * @as(f32, @floatFromInt(i));
            for (0..2) |j| {
                const z = corner.z + extents2.z * @as(f32, @floatFromInt(j));
                tempVerts[yzFirstIdx + i * 4 + j * 2] = Vec3{
                    .x = corner.x,
                    .y = y,
                    .z = z,
                };
                tempVerts[yzFirstIdx + i * 4 + j * 2 + 1] = Vec3{
                    .x = corner.x + extents2.x,
                    .y = y,
                    .z = z,
                };
            }
        }
    }

    try debugBoxBuffer.*.?.CopyStagingBuffer(tempVerts.ptr, bufferSize);
}

pub fn BindForDrawing(
    cmd: c.VkCommandBuffer,
    matInst: *MaterialInstance,
    vertexBuffers: []const c.VkBuffer,
) !void {
    try matInst.m_parentMaterial.BindMaterial(cmd);
    try matInst.BindMaterialInstance(cmd);

    const offsets = [_]c.VkDeviceSize{0};
    c.vkCmdBindVertexBuffers(
        cmd,
        0,
        1,
        vertexBuffers.ptr,
        &offsets,
    );
}

pub fn PushDebugColor(cmd: c.VkCommandBuffer, pipelineLayout: c.VkPipelineLayout, debugColor: *const ColorRGBA) void {
    c.vkCmdPushConstants(
        cmd,
        pipelineLayout,
        c.VK_SHADER_STAGE_FRAGMENT_BIT,
        0,
        @sizeOf(ColorRGBA),
        debugColor,
    );
}

pub fn Draw(cmd: c.VkCommandBuffer) !void {
    try FillDebugVertexBuffers();

    const assetInventory = try AssetInventory.GetInstance();
    const currentFrameIdx = (try RenderContext.GetInstance()).m_currentFrame;

    // Draw lines
    if (debugLines.items.len != 0) {
        const debugLineListMatInst = assetInventory.GetMaterialInst("debug_line_list_mat_inst") orelse @panic("!");
        const vertBuffers = [_]c.VkBuffer{debugLineVertexBuffers[currentFrameIdx].?.m_buffer};
        try BindForDrawing(cmd, debugLineListMatInst, &vertBuffers);

        for (debugLines.items, 0..) |debugLine, i| {
            PushDebugColor(
                cmd,
                debugLineListMatInst.m_parentMaterial.m_shaderPass.m_pipelineLayout,
                &debugLine.m_color,
            );

            const vertexCount = 2;
            c.vkCmdDraw(
                cmd,
                vertexCount,
                1,
                @intCast(i * vertexCount),
                @intCast(i),
            );
        }
    }

    // Draw circles
    if (debugCircles.items.len != 0) {
        const debugLineStripMatInst = assetInventory.GetMaterialInst("debug_line_strip_mat_inst") orelse @panic("!");
        const vertBuffers = [_]c.VkBuffer{debugCircleVertexBuffers[currentFrameIdx].?.m_buffer};
        try BindForDrawing(cmd, debugLineStripMatInst, &vertBuffers);

        for (debugCircles.items, 0..) |debugCircle, i| {
            PushDebugColor(
                cmd,
                debugLineStripMatInst.m_parentMaterial.m_shaderPass.m_pipelineLayout,
                &debugCircle.m_color,
            );

            const vertexCount = debugCircleNumSides + 1;
            c.vkCmdDraw(
                cmd,
                vertexCount,
                1,
                @intCast(i * vertexCount),
                @intCast(i),
            );
        }
    }

    if (debugBoxes.items.len != 0) {
        const debugLineListMatInst = assetInventory.GetMaterialInst("debug_line_list_mat_inst") orelse @panic("!");
        const vertBuffers = [_]c.VkBuffer{debugBoxVertexBuffers[currentFrameIdx].?.m_buffer};
        try BindForDrawing(cmd, debugLineListMatInst, &vertBuffers);

        for (debugBoxes.items, 0..) |debugBox, i| {
            PushDebugColor(
                cmd,
                debugLineListMatInst.m_parentMaterial.m_shaderPass.m_pipelineLayout,
                &debugBox.m_color,
            );

            const vertexCount = debugBoxNumVerts;
            c.vkCmdDraw(
                cmd,
                vertexCount,
                1,
                @intCast(i * vertexCount),
                @intCast(i),
            );
        }
    }
}

pub fn Init() !void {
    const inventory = try AssetInventory.GetInstance();

    // build base shader effect
    debugShaderEffect = try ShaderEffect.CreateBasicShader(
        allocator,
        "src\\shaders\\compiled\\debug_colored-vert.spv",
        "src\\shaders\\compiled\\debug_colored-frag.spv",
    );
    try debugShaderEffect.m_pushConstantRanges.append(c.VkPushConstantRange{
        .offset = 0,
        .size = @sizeOf(ColorRGBA),
        .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
    });
    try debugShaderEffect.BuildLayouts(allocator);

    // create line list mat
    const debugLineListMat = try inventory.CreateMaterial("debug_line_list_mat");
    _ = try inventory.CreateMaterialInstance("debug_line_list_mat_inst", debugLineListMat);

    debug.print("Building debug line ShaderPass...\n", .{});
    debugLineListMat.m_shaderPass = try InitDebugMat(
        c.VK_PRIMITIVE_TOPOLOGY_LINE_LIST,
        c.VK_POLYGON_MODE_LINE,
    );

    // create line strip mat
    const debugLineStripMat = try inventory.CreateMaterial("debug_line_strip_mat");
    _ = try inventory.CreateMaterialInstance("debug_line_strip_mat_inst", debugLineStripMat);

    debug.print("Building debug line strip ShaderPass...\n", .{});
    debugLineStripMat.m_shaderPass = try InitDebugMat(
        c.VK_PRIMITIVE_TOPOLOGY_LINE_STRIP,
        c.VK_POLYGON_MODE_LINE,
    );
}

fn InitDebugMat(topology: c.VkPrimitiveTopology, polygonMode: c.VkPolygonMode) !ShaderPass {
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

    return try ShaderPass.BuildShaderPass(
        allocator,
        &debugShaderEffect,
        topology,
        polygonMode,
        &debugLineBindingDesc,
        &debugLineAttribDesc,
    );
}
