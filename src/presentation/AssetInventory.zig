const std = @import("std");
const c = @import("../c.zig");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

const Material = @import("Material.zig").Material;
const Mesh = @import("Mesh.zig").Mesh;
const RenderContext = @import("RenderContext.zig").RenderContext;
const Scene = @import("Scene.zig").Scene;

const assetImport = @import("AssetImport.zig");

const filePathUtils = @import("../coreutil/FilePathUtils.zig");

var instance: ?AssetInventory = null;

const InventoryError = error{
    AlreadyInitialized,
    NotInitialized,
};

//TODO we index by unique string names, but also store the name as part of the data, could we fix that so the field isn't duplicated?
// ie key set based on m_name value instead of a map?
pub const AssetInventory = struct {
    m_meshes: StringHashMap(Mesh) = StringHashMap(Mesh).init(allocator),
    m_materials: StringHashMap(Material) = StringHashMap(Material).init(allocator),

    pub fn GetInstance() !*AssetInventory {
        if (instance) |*inst| {
            return inst;
        } else {
            return InventoryError.NotInitialized;
        }
    }

    pub fn Initialize() !void {
        if (instance != null) return InventoryError.AlreadyInitialized;
        instance = AssetInventory{};
    }

    pub fn CreateMaterial(
        self: *AssetInventory,
        name: []const u8,
    ) !*Material {
        //TODO init pipeline
        try self.m_materials.put(name, Material{});
        const entry = self.m_materials.getPtr(name);
        return entry orelse @panic("Material just created does not exist in hash map");
    }

    pub fn GetMaterial(self: *AssetInventory, name: []const u8) ?*Material {
        return self.m_materials.getPtr(name);
    }

    pub fn CreateMesh(self: *AssetInventory, name: []const u8, filePath: []const u8) !*Mesh {
        const meshPath = try filePathUtils.CwdToAbsolute(allocator, filePath);
        defer allocator.free(meshPath);
        //TODO avoid unnecessary copyingo on creation
        var importResult = assetImport.ImportMesh(meshPath, name);
        if (importResult) |*mesh| {
            try mesh.*.InitMesh();
            try self.m_meshes.put(name, mesh.*);
            const entry = self.m_meshes.getPtr(name);
            return entry orelse @panic("Mesh just created does not exist in hash map");
        } else |meshErr| {
            return meshErr;
        }
    }

    pub fn GetMesh(self: *AssetInventory, name: []const u8) ?*Mesh {
        return self.m_meshes.getPtr(name);
    }
};
