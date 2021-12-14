usingnamespace @import("../c.zig");
usingnamespace @import("../math/Math.zig");
const std = @import("std");
const ArrayList = std.ArrayList;
const debug = @import("std").debug;

const Mesh = @import("Mesh.zig").Mesh;
const VertexData = @import("Mesh.zig").VertexData;

const allocator = std.heap.page_allocator;

const ImportError = error{
    AIImportError, //assimp failed to import the scene
    ZeroMeshes, //scene contains 0 meshes
    MultipleMeshes, //scene contains more than 1 mesh
    AssetPath, //issue with path to asset
    BadDataCounts, //issue with data not having matching quantities
};

pub fn ImportMesh(filePath: []const u8) !Mesh {
    _ = try std.fs.openFileAbsolute(filePath, .{}); //sanity check accessing the file before trying to import

    const importedScene: *const aiScene = aiImportFile(filePath.ptr, aiProcess_Triangulate) orelse {
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
        .m_vertexData = try ArrayList(VertexData).initCapacity(allocator, importMesh.mNumVertices),
        .m_indices = ArrayList(u32).init(allocator), //TODO can we make the capacity/resize handling better?
    };

    // Copy data from the imported mesh structure to ours
    var i: usize = 0;
    while (i < importMesh.mNumVertices) : (i += 1) {
        const vert = importMesh.mVertices[i];
        const normal = importMesh.mNormals[i];
        const uvCoord = importMesh.mTextureCoords[0][i];
        returnMesh.m_vertexData.appendAssumeCapacity(.{
            .m_pos = Vec3{
                .x = vert.x,
                .y = vert.y,
                .z = vert.z,
            },
            .m_normal = Vec3{
                .x = normal.x,
                .y = normal.y,
                .z = normal.z,
            },
            .m_uvCoord = Vec2{
                .x = uvCoord.x,
                .y = uvCoord.y,
            },
        });
    }
    for (importMesh.mFaces[0..importMesh.mNumFaces]) |face, j| {
        if (face.mNumIndices != 3) {
            debug.warn("Bad face count at face {} with count {}\n", .{ j, face.mNumIndices });
            return ImportError.BadDataCounts;
        }
        for (face.mIndices[0..face.mNumIndices]) |index| {
            try returnMesh.m_indices.append(index);
        }
    }

    debug.warn("Imported {s} successfully:\n{} vertexData instances and {} indices\n", .{
        fileName,
        returnMesh.m_vertexData.items.len,
        returnMesh.m_indices.items.len,
    });
    return returnMesh;
}
