usingnamespace @import("../c.zig");

pub const Mesh = struct {
    m_name: []u8,
    m_meshVAO: GLuint,
    m_positionBO: GLuint,
    m_texCoordBO: GLuint,
    m_normalBO: GLuint,
    m_indexBO: GLuint,

    m_indexCount: GLuint,
    m_vertexCount: GLuint,
};

pub const MeshInstance = struct {
    m_meshID: u32,
    m_transformID: u32,
};
