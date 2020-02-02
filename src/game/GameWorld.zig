const std = @import("std");
const EntityManager = @import("EntityManager.zig").EntityManager;
const Entity = @import("Entity.zig").Entity; // TODO delete

const debug = std.debug;
const time = std.time;
const Timer = time.Timer;

var instance: GameWorld = undefined;

pub const GameWorld = struct {
    m_entityManager: EntityManager,

    pub fn GameTick(self: GameWorld) void {
        //debug.warn("GameTick\n");
    }

    pub fn CreateEntity() *Entity {
        return instance.m_entityManager.CreateEntity() catch |err| {
            debug.panic("{}", err);
        };
    }
};

pub fn Initialize() void {
    instance = GameWorld{ .m_entityManager = EntityManager.Initialize() };
}

//TODO delete
fn LogEntities() void {
    for (instance.m_entityManager.m_entities.items) |item| {
        if (item.m_e) |entity| {
            std.debug.warn("Entity: {}\n", entity.m_eid);
        } else {
            std.debug.warn("null\n");
        }
    }
}

pub fn Instance() *const GameWorld {
    return &instance;
}

pub fn WritableInstance() *GameWorld {
    return &instance;
}
