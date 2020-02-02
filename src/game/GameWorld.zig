const std = @import("std");
const EntityManager = @import("EntityManager.zig").EntityManager;
const Entity = @import("Entity.zig").Entity;

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

pub fn Instance() *const GameWorld {
    return &instance;
}

pub fn WritableInstance() *GameWorld {
    return &instance;
}

