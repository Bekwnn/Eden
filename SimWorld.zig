const debug = @import("std").debug;
const EntityManager = @import("EntityManager.zig").EntityManager;

var instance: SimWorld;

const SimWorld = struct {
    m_entityManager: EntityManager,

    pub fn GameTick(self: SimWorld) void {
        debug.warn("GameTick");
    }
};

pub fn Instance() *const SimWorld {
    return &instance;
}

pub fn WritableInstance() *SimWorld {
    return &instance;
}
