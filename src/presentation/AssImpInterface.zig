usingnamespace @import("../c.zig");
usingnamespace @import("../math/Math.zig");
const std = @import("std");
const ArrayList = std.ArrayList;
const debug = @import("std").debug;

const Mesh = @import("Mesh.zig").Mesh;

const allocator = std.heap.page_allocator;

const ImportError = error{
    AIImportError, //assimp failed to import the scene
    ZeroMeshes, //scene contains 0 meshes
    MultipleMeshes, //scene contains more than 1 mesh
    AssetPath, //issue with path to asset
    BadDataCounts, //issue with data not having matching quantities
};

pub fn ImportMesh(filePath: [:0]const u8) !Mesh {
    _ = try std.fs.openFileAbsolute(filePath, .{}); //sanity check accessing the file before trying to import

    const importedScene: *const aiScene = aiImportFile(filePath, aiProcess_Triangulate) orelse {
        const errStr = aiGetErrorString();
        debug.warn("{s}\n", .{errStr[0..std.mem.len(errStr)]});
        return ImportError.AIImportError;
    };
    defer aiReleaseImport(importedScene);

    if (importedScene.mNumMeshes > 1) {
        return ImportError.MultipleMeshes;
    } else if (importedScene.mNumMeshes == 0) {
        return ImportError.ZeroMeshes;
    }

    const importMesh: *const aiMesh = importedScene.mMeshes[0];
    const fileName = std.fs.path.basename(filePath);

    var returnMesh = Mesh{
        .m_name = fileName,
        .m_vertices = try ArrayList(Vec3).initCapacity(allocator, importMesh.mNumVertices),
        .m_normals = try ArrayList(Vec3).initCapacity(allocator, importMesh.mNumVertices),
        .m_texCoords = try ArrayList(Vec2).initCapacity(allocator, importMesh.mNumVertices), //TODO channels
        .m_indices = ArrayList(u32).init(allocator), //TODO can we make the capacity/resize handling better?
        .m_vertexBO = 0,
        .m_normalBO = 0,
        .m_texCoordBO = 0,
        .m_indexBO = 0,
    };

    // Copy data from the imported mesh structure to ours
    for (importMesh.mVertices[0..importMesh.mNumVertices]) |vert| {
        returnMesh.m_vertices.appendAssumeCapacity(.{
            .x = vert.x,
            .y = vert.y,
            .z = vert.z,
        });
    }
    for (importMesh.mNormals[0..importMesh.mNumVertices]) |normal| {
        returnMesh.m_normals.appendAssumeCapacity(.{
            .x = normal.x,
            .y = normal.y,
            .z = normal.z,
        });
    }
    for (importMesh.mTextureCoords[0][0..importMesh.mNumVertices]) |uvCoord| {
        returnMesh.m_texCoords.appendAssumeCapacity(.{
            .x = uvCoord.x,
            .y = uvCoord.y,
        });
    }
    for (importMesh.mFaces[0..importMesh.mNumFaces]) |face, i| {
        if (face.mNumIndices != 3) {
            debug.warn("Bad face count at face {} with count {}\n", .{ i, face.mNumIndices });
            return ImportError.BadDataCounts;
        }
        for (face.mIndices[0..face.mNumIndices]) |index| {
            try returnMesh.m_indices.append(index);
        }
    }

    debug.warn("Imported {s} successfully with {} vertices, {} normals, {} texCoords, and {} indices\n", .{
        fileName,
        returnMesh.m_vertices.items.len,
        returnMesh.m_normals.items.len,
        returnMesh.m_texCoords.items.len,
        returnMesh.m_indices.items.len,
    });
    return returnMesh;
}
