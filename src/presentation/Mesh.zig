usingnamespace @import("../c.zig");
const std = @import("std");

const Vec3 = @import("../math/Vec3.zig").Vec3;
const Vec2 = @import("../math/Vec2.zig").Vec2;

const ArrayList = std.ArrayList;

const noPointerOffset: ?*const c_void = @intToPtr(?*c_void, 0);

pub const Mesh = struct {
    m_name: []const u8,

    m_vertices: ArrayList(Vec3),
    m_normals: ArrayList(Vec3),
    m_texCoords: ArrayList(Vec2), //currently only one coord channel
    m_indices: ArrayList(u32), 

    m_vertexBO: GLuint,
    m_normalBO: GLuint,
    m_texCoordBO: GLuint,
    m_indexBO: GLuint,

    //TODO testing; handle different shaders and different attrib layouts
    pub fn Draw(self: *const Mesh, shader: GLuint) void {
        glUseProgram(shader);

        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, self.m_vertexBO);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, noPointerOffset);

        glEnableVertexAttribArray(1);
        glBindBuffer(GL_ARRAY_BUFFER, self.m_normalBO);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, noPointerOffset);

        glEnableVertexAttribArray(2);
        glBindBuffer(GL_ARRAY_BUFFER, self.m_texCoordBO);
        glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 0, noPointerOffset);

        glDrawElements(GL_TRIANGLES, @intCast(c_int, self.m_indices.items.len), GL_UNSIGNED_INT, &self.m_indices.items[0]);

        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
        glDisableVertexAttribArray(2);
    }

    pub fn PushDataToBuffers(self: *Mesh) void {
        //TODO clear any existing data
        self.m_vertexBO = try self.LoadMeshIntoVertexBO();
        self.m_normalBO = try self.LoadMeshIntoNormalBO();
        self.m_texCoordBO = try self.LoadMeshIntoTexCoordBO();
    }

    fn LoadMeshIntoVertexBO(mesh: *const Mesh) !GLuint {
        var vertexBuffer: GLuint = 0;
        glGenBuffers(1, &vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, @intCast(c_longlong, mesh.m_vertices.items.len * @sizeOf(Vec3)), &mesh.m_vertices.items[0], GL_STATIC_DRAW);

        return vertexBuffer;
    }

    fn LoadMeshIntoNormalBO(mesh: *const Mesh) !GLuint {
        var normalBuffer: GLuint = 0;
        glGenBuffers(1, &normalBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, normalBuffer);
        glBufferData(GL_ARRAY_BUFFER, @intCast(c_longlong, mesh.m_normals.items.len * @sizeOf(Vec3)), &mesh.m_normals.items[0], GL_STATIC_DRAW);

        return normalBuffer;
    }

    fn LoadMeshIntoTexCoordBO(mesh: *const Mesh) !GLuint {
        var texCoordBuffer: GLuint = 0;
        glGenBuffers(1, &texCoordBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, texCoordBuffer);
        glBufferData(GL_ARRAY_BUFFER, @intCast(c_longlong, mesh.m_texCoords.items.len * @sizeOf(Vec2)), &mesh.m_texCoords.items[0], GL_STATIC_DRAW);

        return texCoordBuffer;
    }

    fn LoadMeshIntoIndexBO(mesh: *const Mesh) !GLuint {
        var indexBuffer: GLuint = 0;
        glGenBuffers(1, &indexBuffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, @intCast(c_longlong, mesh.m_indices.items.len * @sizeOf(u32)), &mesh.m_indices.items[0], GL_STATIC_DRAW);

        return indexBuffer;
    }
};

// how should actual instances come together between mesh, texture maps, shader, and instanced shader parameters?
pub const MeshInstance = struct {
    m_meshID: u32,
    m_transformID: u32,
};
