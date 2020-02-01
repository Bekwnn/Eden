const debug = @import("std").debug;
const EntityManager = @import("EntityManager.zig").EntityManager;

var instance = GameWorld{};

pub const GameWorld = struct {
    m_entityManager: EntityManager = EntityManager{},

    pub fn GameTick(self: GameWorld) void {
        //debug.warn("GameTick\n");
    }
};

pub fn Instance() *const GameWorld {
    return &instance;
}

pub fn WritableInstance() *GameWorld {
    return &instance;
}
