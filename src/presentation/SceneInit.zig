const std = @import("std");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const c = @import("../c.zig");

const ColorRGBA = @import("../math/Color.zig").ColorRGBA;
const Mat4x4 = @import("../math/Mat4x4.zig").Mat4x4;
const Vec3 = @import("../math/Vec3.zig").Vec3;
const Vec4 = @import("../math/Vec4.zig").Vec4;

const AssetInventory = @import("AssetInventory.zig").AssetInventory;
const Buffer = @import("Buffer.zig").Buffer;
const Camera = @import("Camera.zig").Camera;
const DebugDraw = @import("DebugDraw.zig");
const GPUSceneData = @import("Scene.zig").GPUSceneData;
const materialParam = @import("MaterialParam.zig");
const MaterialParam = materialParam.MaterialParam;
const Mesh = @import("Mesh.zig").Mesh;
const RenderContext = @import("RenderContext.zig").RenderContext;
const RenderObject = @import("RenderObject.zig").RenderObject;
const Scene = @import("Scene.zig").Scene;
const ShaderEffect = @import("ShaderEffect.zig").ShaderEffect;
const ShaderPass = @import("ShaderPass.zig").ShaderPass;
const Texture = @import("Texture.zig").Texture;
const TextureParam = materialParam.TextureParam;
const UniformParam = materialParam.UniformParam;

//TODO move scene out to world or something
var currentScene = Scene{};

var texturedShaderEffect: ShaderEffect = undefined;
var coloredShaderEffect: ShaderEffect = undefined;
var coloredShaderBuffer: Buffer = undefined;
pub var shaderColor = ColorRGBA{
    .r = 0.0,
    .g = 0.6,
    .b = 0.6,
    .a = 1.0,
};

pub fn GetCurrentScene() *Scene {
    return &currentScene;
}

pub fn InitializeScene() !void {
    try DebugDraw.Init();

    // init hardcoded test currentScene:
    var inventory = try AssetInventory.GetInstance();

    const mesh = try inventory.CreateMesh("monkey", "test-assets\\test.obj");

    const uvTexture = try inventory.CreateTexture("uv_test", "test-assets\\test.png");

    const texMaterial = try inventory.CreateMaterial("textured_mat");
    const texMaterialInst = try inventory.CreateMaterialInstance("textured_mat_inst", texMaterial);

    const coloredMat = try inventory.CreateMaterial("colored_mat");
    const coloredMatInst = try inventory.CreateMaterialInstance("colored_mat_inst", coloredMat);

    try currentScene.CreateCamera("default");

    const currentCamera = try currentScene.GetCurrentCamera();

    currentCamera.m_pos = Vec3{ .x = 0.0, .y = 0.0, .z = -25.0 };

    const cameraViewMat = currentCamera.GetViewMatrix();
    const cameraProjMat = currentCamera.GetProjectionMatrix();
    const cameraViewProj = cameraProjMat.Mul(cameraViewMat);

    const cameraAxesLoc = currentCamera.m_pos.Add(Vec3.yAxis.GetScaled(5.0));
    _ = try DebugDraw.CreateDebugLine(
        cameraAxesLoc,
        cameraAxesLoc.Add(currentCamera.m_rotation.GetForwardVec().GetScaled(3.0)),
        ColorRGBA.presets.Magenta,
    );
    _ = try DebugDraw.CreateDebugLine(
        cameraAxesLoc,
        cameraAxesLoc.Add(currentCamera.m_rotation.GetRightVec().GetScaled(3.0)),
        ColorRGBA.presets.Magenta,
    );
    _ = try DebugDraw.CreateDebugLine(
        cameraAxesLoc,
        cameraAxesLoc.Add(currentCamera.m_rotation.GetUpVec().GetScaled(3.0)),
        ColorRGBA.presets.Magenta,
    );

    //TODO should we include the clipspace mat?
    const rContext = try RenderContext.GetInstance();
    for (&rContext.m_frameData) |*frameData| {
        frameData.m_gpuSceneData = GPUSceneData{
            .m_view = cameraViewMat.Transpose(),
            .m_projection = cameraProjMat.Transpose(),
            .m_viewProj = Camera.gl2VkClipSpace.Mul(cameraViewProj).Transpose(),
            .m_ambientColor = Vec4{
                .x = 0.2,
                .y = 0.2,
                .z = 0.2,
                .w = 1.0,
            },
            .m_sunDirection = Vec4{
                .x = 0.0,
                .y = -1.0,
                .z = 0.0,
                .w = 10.0,
            },
            .m_sunColor = Vec4{
                .x = 1.0,
                .y = 1.0,
                .z = 1.0,
                .w = 1.0,
            },
            .m_time = Vec4{
                .x = 0.0,
                .y = 0.0,
                .z = 0.0,
                .w = 0.0,
            },
        };
    }

    // textured shader
    debug.print("Building basic_textured_mesh ShaderEffect...\n", .{});
    texturedShaderEffect = try ShaderEffect.CreateBasicShader(
        allocator,
        "src\\shaders\\compiled\\basic_textured_mesh-vert.spv",
        "src\\shaders\\compiled\\basic_textured_mesh-frag.spv",
    );

    // TODO make setting up a material parameter binding 1 call
    const textureParam = try TextureParam.init(allocator, uvTexture);
    try texMaterialInst.m_materialInstanceParams.append(MaterialParam.init(textureParam, 1));
    try texturedShaderEffect.m_instanceSetParams.append(ShaderEffect.DescriptorParam{
        .m_binding = 1,
        .m_descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .m_shaderStageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
    });

    try texturedShaderEffect.m_pushConstantRanges.append(c.VkPushConstantRange{
        .offset = 0,
        .size = @sizeOf(Mat4x4),
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    });
    try texturedShaderEffect.BuildLayouts(allocator);

    debug.print("Building basic_textured_mesh ShaderPass...\n", .{});
    texMaterial.m_shaderPass = try ShaderPass.BuildShaderPass(
        allocator,
        &texturedShaderEffect,
        c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        c.VK_POLYGON_MODE_FILL,
        Mesh.GetBindingDescription(),
        Mesh.GetAttributeDescriptions(),
    );

    // basic shader
    debug.print("Building basic_mesh ShaderEffect...\n", .{});
    coloredShaderEffect = try ShaderEffect.CreateBasicShader(
        allocator,
        "src\\shaders\\compiled\\basic_mesh-vert.spv",
        "src\\shaders\\compiled\\basic_mesh-frag.spv",
    );

    // TODO make setting up a material parameter binding 1 call
    // COLOR MESH MAT
    const colorParam = try UniformParam.init(allocator, &coloredShaderBuffer, @sizeOf(@TypeOf(shaderColor)), 0);
    try coloredMatInst.m_materialInstanceParams.append(MaterialParam.init(colorParam, 1));
    try coloredShaderEffect.m_instanceSetParams.append(ShaderEffect.DescriptorParam{
        .m_binding = 1,
        .m_descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .m_shaderStageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
    });
    try coloredShaderEffect.m_pushConstantRanges.append(c.VkPushConstantRange{
        .offset = 0,
        .size = @sizeOf(Mat4x4),
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    });
    try coloredShaderEffect.BuildLayouts(allocator);

    coloredShaderBuffer = try Buffer.CreateBuffer(
        @sizeOf(ColorRGBA),
        c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    );

    try coloredShaderBuffer.MapMemory(@ptrCast(&shaderColor), @sizeOf(ColorRGBA));

    debug.print("Building basic_mesh ShaderPass...\n", .{});
    coloredMat.m_shaderPass = try ShaderPass.BuildShaderPass(
        allocator,
        &coloredShaderEffect,
        c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        c.VK_POLYGON_MODE_FILL,
        Mesh.GetBindingDescription(),
        Mesh.GetAttributeDescriptions(),
    );

    const width = 20;
    const height = 20;
    for (0..height) |i| {
        for (0..width) |j| {
            const name = try std.fmt.allocPrint(allocator, "Monkey_Mesh_{d}.{d}", .{ i, j });
            try currentScene.m_renderables.put(
                name,
                RenderObject.init(
                    allocator,
                    name,
                    mesh,
                    if ((i + j) % 2 == 0) texMaterialInst else coloredMatInst,
                ),
            );
            const newRenderObj = currentScene.m_renderables.getPtr(name) orelse @panic("!");
            newRenderObj.m_transform = Mat4x4.Translation(Vec3{
                .x = (-5.0 * @divFloor(width, 2)) + (@as(f32, @floatFromInt(j)) * 5.0),
                .y = 0.0,
                .z = (-5.0 * @divFloor(height, 2)) + (@as(f32, @floatFromInt(i)) * 5.0),
            }).Transpose();
        }
    }
}

// TODO this should be automatic for all params that need updating
pub fn UpdateColoredShaderBuffer() !void {
    if (coloredShaderBuffer.m_mappedData) |mappedData| {
        const bufferSize = @sizeOf(ColorRGBA);
        @memcpy(
            @as([*]u8, @ptrCast(mappedData))[0..bufferSize],
            @as([*]u8, @ptrCast(&shaderColor))[0..bufferSize],
        );
    } else {
        const UpdateError = error{FailedToUpdateColorBuffer};
        return UpdateError.FailedToUpdateColorBuffer;
    }
}
