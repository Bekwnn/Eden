usingnamespace @import("c.zig");
usingnamespace @import("../math/math.zig");

pub const Scene = struct {
    //TODO create ID lookup tables (maybe even make a standardized one and also use it in entitymanager?)
    m_meshes: []Mesh,
    m_meshInstances: []MeshInstance,
    m_materials: []Material,
    m_shaders: []Shader,

    m_cameras: []Camera,
    m_currentCameraID: u32,

    //TODO add functions to add things to the scene
};

//TODO some of these may deserve their own file later
pub const Transform = struct {
    m_scale: Vec3,
    m_rotation: Quat,
    m_position: Vec3,
};

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

pub const Camera = struct {
    m_eye: Vec3,
    m_target: Vec3,
    m_up: Vec3,

    m_fovY: f32,
    m_aspectRatio: f32,
    m_nearPlane: f32,
};

pub const Material = struct {
    m_name: []u8,
    m_shader: u32,
    // parameters unique to this material but not to the shader
};

