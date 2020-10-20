usingnamespace @import("../c.zig");
const Mesh = @import("Mesh.zig").Mesh;
const std = @import("std");
const debug = @import("std").debug;

const ImportError = error{
    AIImportError, //assimp failed to import the scene
    ZeroMeshes, //scene contains 0 meshes
    MultipleMeshes, //scene contains more than 1 mesh
};

pub fn ImportMesh(filePath: [:0]const u8) !Mesh {
    //TODO verify existance of file
    //TODO set filename as m_name
    //TODO set and bind buffer objects (BO)

    //TODO Assimp WIP
    debug.warn("Import about to happen\n", .{});
    const importedScene: *const aiScene = aiImportFile(filePath, aiProcess_CalcTangentSpace |
        aiProcess_Triangulate | aiProcess_JoinIdenticalVertices | aiProcess_SortByPType) orelse
        {
        const errStr = aiGetErrorString();
        debug.warn("{}\n", .{errStr[0..std.mem.len(errStr)]});
        return ImportError.AIImportError;
    };
    debug.warn("Import happened\n", .{});
    defer aiReleaseImport(importedScene);

    if (importedScene.mNumMeshes > 1) {
        return ImportError.MultipleMeshes;
    } else if (importedScene.mNumMeshes == 0) {
        return ImportError.ZeroMeshes;
    }

    return Mesh{
        .m_name = "",
        .m_meshVAO = 0,
        .m_positionBO = 0,
        .m_texCoordBO = 0,
        .m_normalBO = 0,
        .m_indexBO = 0,
        .m_indexCount = 0,
        .m_vertexCount = 0,
    };
}

fn LoadMeshIntoVAO(mesh: *const aiMesh) !GLuint {
    return 0;
}

fn LoadMeshIntoPositionBO(mesh: *const aiMesh) !GLuint {
    return 0;
}

fn LoadMeshIntoTexCoordBO(mesh: *const aiMesh) !GLuint {
    return 0;
}

fn LoadMeshIntoNormalBO(mesh: *const aiMesh) !GLuint {
    return 0;
}

fn LoadMeshIntoIndexBO(mesh: *const aiMesh) !GLuint {
    return 0;
}
