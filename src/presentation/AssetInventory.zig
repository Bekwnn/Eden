const std = @import("std");
const c = @import("c.zig");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

const Mesh = @import("Mesh.zig").Mesh;
const Material = @import("Material.zig").Material;

const filePathUtils = @import("../coreutil/FilePathUtils.zig");

pub const AssetInventory = struct {
    m_meshes: StringHashMap(Mesh) = StringHashMap(Mesh).init(allocator),
    m_materials: StringHashMap(Material) = StringHashMap(Material).init(allocator),

    pub fn CreateMaterial(
        self: *Scene,
        name: []const u8,
        pipeline: c.VkPipeline,
        pipelineLayout: c.VkPipelineLayout,
    ) !void {
        //TODO init pipeline
        try self.m_materials.put(name, Material{
            .m_name = name,
            .m_pipeline = pipeline,
            .m_pipelineLayout = pipelineLayout,
        });
    }

    pub fn GetMaterial(self: *Scene, name: []const u8) ?*Material {
        return self.m_materials.getPtr(name);
    }

    pub fn CreateMesh(self: *Scene, name: []const u8, filePath: []const u8) !void {
        const meshPath = filePathUtils.CwdToAbsolute(allocator, "test-assets\\test.obj") catch {
            @panic("!");
        };
        defer allocator.free(meshPath);
        //TODO calling import mesh and init buffers should be somewhere in mesh or mesh import files
        if (assimp.ImportMesh(meshPath)) |mesh| {
            try mesh.InitBuffers();
            try self.m_meshes.put(name, mesh);
        } else |meshErr| {
            debug.print("Error importing mesh: {}\n", .{meshErr});
        }
    }

    pub fn GetMesh(self: *Scene, name: []const u8) ?*Mesh {
        return self.m_meshes.getPtr(name);
    }
};
