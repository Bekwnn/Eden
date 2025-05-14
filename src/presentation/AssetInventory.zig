const std = @import("std");
const c = @import("../c.zig");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

const MaterialInstance = @import("MaterialInstance.zig").MaterialInstance;
const Material = @import("Material.zig").Material;
const Mesh = @import("Mesh.zig").Mesh;
const Texture = @import("Texture.zig").Texture;

const RenderContext = @import("RenderContext.zig").RenderContext;
const Scene = @import("Scene.zig").Scene;
const assetImport = @import("AssetImport.zig");
const filePathUtils = @import("../coreutil/FilePathUtils.zig");

var instance: ?AssetInventory = null;

const InventoryError = error{
    AlreadyInitialized,
    NotInitialized,
};

// TODO we index by unique string names, but also store the name as part of the data, could we fix that so the field isn't
// duplicated? ie key set based on m_name value instead of a map?
// At some point we might want to create dedicated structs/files for the inventory of each asset type (eg mesh, texture,
// video, materials, etc)

pub const AssetInventory = struct {
    m_meshes: StringHashMap(Mesh) = StringHashMap(Mesh).init(allocator),
    m_materials: StringHashMap(Material) = StringHashMap(Material).init(allocator),
    m_materialInstances: StringHashMap(MaterialInstance) = StringHashMap(MaterialInstance).init(allocator),
    m_textures: StringHashMap(Texture) = StringHashMap(Texture).init(allocator),

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

    pub fn CreateMaterialInstance(
        self: *AssetInventory,
        name: []const u8,
        parentMaterial: *Material,
    ) !*MaterialInstance {
        try self.m_materialInstances.put(name, MaterialInstance{
            .m_parentMaterial = parentMaterial,
        });
        const entry = self.m_materialInstances.getPtr(name);
        return entry orelse @panic("MaterialInstance just created does not exist in hash map");
    }

    pub fn GetMaterialInst(self: *AssetInventory, name: []const u8) ?*MaterialInstance {
        return self.m_materialInstances.getPtr(name);
    }

    pub fn CreateMesh(
        self: *AssetInventory,
        name: []const u8,
        filePath: []const u8,
    ) !*Mesh {
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

    pub fn CreateTexture(self: *AssetInventory, name: []const u8, imagePath: []const u8) !*Texture {
        const texture = try Texture.CreateTexture(imagePath);
        try self.m_textures.put(name, texture);
        return self.m_textures.getPtr(name) orelse @panic("Texture just created does not exist in hash map");
    }

    pub fn GetTexture(self: *AssetInventory, name: []const u8) ?*Texture {
        return self.m_textures.getPtr(name);
    }
};
