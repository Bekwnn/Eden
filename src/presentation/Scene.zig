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
