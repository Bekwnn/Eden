const c = @import("../c.zig");
const std = @import("std");
const StringHashMap = std.StringHashMap;
const allocator = std.heap.page_allocator;

const vkUtil = @import("VulkanUtil.zig");
const texture = @import("Texture.zig");
const Texture = texture.Texture;
const RenderContext = @import("RenderContext.zig").RenderContext;
const ShaderPass = @import("ShaderPass.zig").ShaderPass;

pub var materialCache = StringHashMap(Material).init(allocator);

pub const Material = struct {
    //TODO multiple pass shaders?
    m_shaderPass: ShaderPass = undefined,
};
