usingnamespace @import("../c.zig");
const std = @import("std");

const Vec3 = @import("../math/Vec3.zig").Vec3;
const Vec2 = @import("../math/Vec2.zig").Vec2;
const mat4x4 = @import("../math/Mat4x4.zig");
const Mat4x4 = mat4x4.Mat4x4;

const Camera = @import("Camera.zig").Camera;

const ArrayList = std.ArrayList;

//TODO still useful post gl->vulkan changes? should maybe be defined in some util file w/ better name
const noPointerOffset: ?*const c_void = @intToPtr(?*c_void, 0);

pub const Mesh = struct {
    m_name: []const u8,

    m_vertices: ArrayList(Vec3),
    m_normals: ArrayList(Vec3),
    m_texCoords: ArrayList(Vec2), //currently only one coord channel
    m_indices: ArrayList(u32),

    m_vertexBO: u32,
    m_normalBO: u32,
    m_texCoordBO: u32,
    m_indexBO: u32,

    //TODO testing; handle different shaders and different attrib layouts
    pub fn Draw(self: *const Mesh, camera: *const Camera, shader: u32) void {
        //glUseProgram(shader);

        //var vao: GLuint = 0;
        //glGenVertexArrays(1, &vao);
        //glBindVertexArray(vao);

        //glBindBuffer(GL_ARRAY_BUFFER, self.m_vertexBO);
        //glBindBuffer(GL_ARRAY_BUFFER, self.m_normalBO);
        //glBindBuffer(GL_ARRAY_BUFFER, self.m_texCoordBO);
        //glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.m_indexBO);

        //glEnableVertexAttribArray(0);
        //glEnableVertexAttribArray(1);
        //glEnableVertexAttribArray(2);

        //glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, noPointerOffset);
        //glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, noPointerOffset);
        //glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 0, noPointerOffset);

        //TODO fix model
        const model = mat4x4.identity;
        const projection = camera.GetProjectionMatrix();
        const view = camera.GetViewMatrix();

        //const mLocation: GLint = glGetUniformLocation(shader, "model");
        //if (mLocation == -1) {
        //    std.debug.warn("failed to find camera matrix uniform location in shader\n", .{});
        //} else {
        //    glUniformMatrix4fv(mLocation, 1, GL_FALSE, &model.m[0][0]);
        //}
        //const pLocation: GLint = glGetUniformLocation(shader, "projection");
        //if (pLocation == -1) {
        //    std.debug.warn("failed to find camera matrix uniform location in shader\n", .{});
        //} else {
        //    glUniformMatrix4fv(pLocation, 1, GL_FALSE, &projection.m[0][0]);
        //}
        //const vLocation: GLint = glGetUniformLocation(shader, "view");
        //if (vLocation == -1) {
        //    std.debug.warn("failed to find camera matrix uniform location in shader\n", .{});
        //} else {
        //    glUniformMatrix4fv(vLocation, 1, GL_FALSE, &view.m[0][0]);
        //}

        //glDrawElements(GL_TRIANGLES, @intCast(c_int, self.m_indices.items.len), GL_UNSIGNED_INT, noPointerOffset);

        //glDisableVertexAttribArray(0);
        //glBindVertexArray(0);
        //glDisableVertexAttribArray(1);
        //glDisableVertexAttribArray(2);
    }

    pub fn PushDataToBuffers(self: *Mesh) void {
        //TODO clear any existing data
        self.m_vertexBO = try self.LoadMeshIntoVertexBO();
        self.m_normalBO = try self.LoadMeshIntoNormalBO();
        self.m_texCoordBO = try self.LoadMeshIntoTexCoordBO();
        self.m_indexBO = try self.LoadMeshIntoIndexBO();
    }

    fn LoadMeshIntoVertexBO(mesh: *const Mesh) !u32 {
        var vertexBuffer: u32 = 0;
        //var vertexBuffer: GLuint = 0;
        //glGenBuffers(1, &vertexBuffer);
        //glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        //glBufferData(GL_ARRAY_BUFFER, @intCast(c_longlong, mesh.m_vertices.items.len * @sizeOf(Vec3)), &mesh.m_vertices.items[0], GL_STATIC_DRAW);

        return vertexBuffer;
    }

    fn LoadMeshIntoNormalBO(mesh: *const Mesh) !u32 {
        var normalBuffer: u32 = 0;
        //var normalBuffer: GLuint = 0;
        //glGenBuffers(1, &normalBuffer);
        //glBindBuffer(GL_ARRAY_BUFFER, normalBuffer);
        //glBufferData(GL_ARRAY_BUFFER, @intCast(c_longlong, mesh.m_normals.items.len * @sizeOf(Vec3)), &mesh.m_normals.items[0], GL_STATIC_DRAW);

        return normalBuffer;
    }

    fn LoadMeshIntoTexCoordBO(mesh: *const Mesh) !u32 {
        var texCoordBuffer: u32 = 0;
        //var texCoordBuffer: GLuint = 0;
        //glGenBuffers(1, &texCoordBuffer);
        //glBindBuffer(GL_ARRAY_BUFFER, texCoordBuffer);
        //glBufferData(GL_ARRAY_BUFFER, @intCast(c_longlong, mesh.m_texCoords.items.len * @sizeOf(Vec2)), &mesh.m_texCoords.items[0], GL_STATIC_DRAW);

        return texCoordBuffer;
    }

    fn LoadMeshIntoIndexBO(mesh: *const Mesh) !u32 {
        var indexBuffer: u32 = 0;
        //var indexBuffer: GLuint = 0;
        //glGenBuffers(1, &indexBuffer);
        //glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
        //glBufferData(GL_ELEMENT_ARRAY_BUFFER, @intCast(c_longlong, mesh.m_indices.items.len * @sizeOf(u32)), &mesh.m_indices.items[0], GL_STATIC_DRAW);

        return indexBuffer;
    }
};

// how should actual instances come together between mesh, texture maps, shader, and instanced shader parameters?
pub const MeshInstance = struct {
    m_meshID: u32,
    m_transformID: u32,
};
