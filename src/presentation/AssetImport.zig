const c = @import("../c.zig");
const em = @import("../math/Math.zig");
const std = @import("std");
const ArrayList = std.ArrayList;
const debug = @import("std").debug;

const Mesh = @import("Mesh.zig").Mesh;
const VertexData = @import("Mesh.zig").VertexData;

const allocator = std.heap.page_allocator;

const ImportError = error{
    AIImportError, //assimp failed to import the scene
    CgltfImportError, //cgltf failed to import the scene

    ZeroMeshes, //scene contains 0 meshes
    MultipleMeshes, //scene contains more than 1 mesh (not supported)
    AssetPath, //issue with path to asset
    BadDataCounts, //issue with mesh data having a mismatched amount of data
};

const ImporterLib = enum {
    AssImp,
    Cgltf,
};

const meshImportLib = ImporterLib.AssImp;

pub fn ImportMesh(filePath: []const u8) !Mesh {
    _ = try std.fs.openFileAbsolute(filePath, .{}); //sanity check accessing the file before trying to import

    switch (meshImportLib) {
        ImporterLib.AssImp => {
            return AssImp_ImportMesh(filePath);
        },
        ImporterLib.Cgltf => {
            return Cgltf_ImportMesh(filePath);
        },
    }
}

fn GetMeshNameFromFile(filePath: []const u8) []const u8 {
    return std.fs.path.basename(filePath);
}

fn AssImp_ImportMesh(filePath: []const u8, meshName: []const u8) !Mesh {
    _ = try std.fs.openFileAbsolute(filePath, .{}); //sanity check accessing the file before trying to import

    const importedScene: *const c.aiScene = c.aiImportFile(filePath.ptr, c.aiProcess_Triangulate) orelse {
        const errStr = c.aiGetErrorString();
        debug.print("{s}\n", .{errStr[0..std.mem.len(errStr)]});
        return ImportError.AIImportError;
    };
    defer c.aiReleaseImport(importedScene);

    if (importedScene.mNumMeshes > 1) {
        return ImportError.MultipleMeshes;
    } else if (importedScene.mNumMeshes == 0) {
        return ImportError.ZeroMeshes;
    }

    const importMesh: *const c.aiMesh = importedScene.mMeshes[0];
    const meshName = GetMeshNameFromFile(filePath);

    var returnMesh = Mesh{
        .m_name = meshName,
        .m_vertexData = try ArrayList(VertexData).initCapacity(allocator, importMesh.mNumVertices),
        .m_indices = ArrayList(u32).init(allocator), //TODO can we make the capacity/resize handling better?
        .m_bufferData = null,
    };

    // Copy data from the imported mesh structure to ours
    var i: usize = 0;
    while (i < importMesh.mNumVertices) : (i += 1) {
        const vert = importMesh.mVertices[i];
        const normal = importMesh.mNormals[i];
        const uvCoord = importMesh.mTextureCoords[0][i];
        returnMesh.m_vertexData.appendAssumeCapacity(.{
            .m_pos = em.Vec3{
                .x = vert.x,
                .y = vert.y,
                .z = vert.z,
            },
            .m_normal = em.Vec3{
                .x = normal.x,
                .y = normal.y,
                .z = normal.z,
            },
            .m_uvCoord = em.Vec2{
                .x = uvCoord.x,
                .y = uvCoord.y,
            },
        });
    }
    for (importMesh.mFaces[0..importMesh.mNumFaces]) |face, j| {
        if (face.mNumIndices != 3) {
            debug.print("Bad face count at face {} with count {}\n", .{ j, face.mNumIndices });
            return ImportError.BadDataCounts;
        }
        for (face.mIndices[0..face.mNumIndices]) |index| {
            try returnMesh.m_indices.append(index);
        }
    }

    debug.print("Imported {s} successfully:\n{} vertexData instances and {} indices\n", .{
        fileName,
        returnMesh.m_vertexData.items.len,
        returnMesh.m_indices.items.len,
    });
    return returnMesh;
}

fn Cgltf_ImportMesh(filePath: []const u8) !Mesh {
    var options: c.cgltf_options = .{0};
    var data: *?c.cgltf_data = null;
    const result = c.cgltf_parse_file(&options, filePath.ptr, &data);
    if (result != c.cgltf_result_success) {
        return ImportError.CgltfImportError;
    }
    defer cgltf_free(data);

    const meshName = GetMeshNameFromFile(filePath);

    //TODO create a mesh from data and return it
}
