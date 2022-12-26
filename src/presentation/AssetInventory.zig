const std = @import("std");
const c = @import("c.zig");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

const Mesh = @import("Mesh.zig").Mesh;
const Material = @import("Material.zig").Material;

const assetImport = @import("AssetImport.zig");

const filePathUtils = @import("../coreutil/FilePathUtils.zig");

var instance: ?AssetInventory = null;

const InventoryError = error{
    AlreadyInitialized,
    NotInitialized,
};

//TODO we index by unique string names, but also store the name as part of the data, could we fix that so the field isn't duplicated?
pub const AssetInventory = struct {
    m_meshes: StringHashMap(Mesh) = StringHashMap(Mesh).init(allocator),
    m_materials: StringHashMap(Material) = StringHashMap(Material).init(allocator),

    pub fn GetInstance() !*RenderContext {
        return &instance orelse InventoryError.NotInitialized;
    }

    pub fn Initialize() !void {
        if (instance != null) return InventoryError.AlreadyInitialized;
        instance = AssetInventory{};
    }

    pub fn CreateMaterial(
        self: *Scene,
        name: []const u8,
        pipeline: c.VkPipeline,
        pipelineLayout: c.VkPipelineLayout,
    ) !*Material {
        //TODO init pipeline
        try self.m_materials.put(name, Material{
            .m_name = name,
            .m_pipeline = pipeline,
            .m_pipelineLayout = pipelineLayout,
        });
        const entry = self.m_materials.getPtr(name);
        return entry orelse @panic("Material just created does not exist in hash map");
    }

    pub fn GetMaterial(self: *Scene, name: []const u8) ?*Material {
        return self.m_materials.getPtr(name);
    }

    pub fn CreateMesh(self: *Scene, name: []const u8, filePath: []const u8) !*Mesh {
        const meshPath = try filePathUtils.CwdToAbsolute(allocator, filepath);
        defer allocator.free(meshPath);
        if (assetImport.ImportMesh(meshPath)) |mesh| {
            try mesh.InitBuffers();
            try self.m_meshes.put(name, mesh);
            const entry = self.m_meshes.getPtr(name);
            return entry orelse @panic("Mesh just created does not exist in hash map");
        } else |meshErr| {
            return meshErr;
        }
    }

    pub fn GetMesh(self: *Scene, name: []const u8) ?*Mesh {
        return self.m_meshes.getPtr(name);
    }
};
