const gameWorld = @import("../GameWorld.zig");
const EntityManager = @import("../EntityManager.zig").EntityManager;
const Entity = @import("../Entity.zig").Entity;

const std = @import("std");

fn EntityUpdate(self: *Entity) void {
    std.debug.warn("Entity Update! ");
}

pub fn EntityUpdateBehaviour() void {
    const entityManager: *EntityManager = &gameWorld.WritableInstance().m_entityManager;
    var i: u32 = 0;
    const count = entityManager.m_entities.count();
    while (i < count) {
        defer i += 1;
        var entity = &(entityManager.m_entities.items[i].m_e orelse continue);
        EntityUpdate(entity);
    }
}

fn EntityFixedUpdate(self: *Entity) void {
    std.debug.warn("Entity Fixed Update! ");
}

pub fn EntityFixedUpdateBehaviour() void {
    const entityManager: *EntityManager = &gameWorld.WritableInstance().m_entityManager;
    var i: u32 = 0;
    const count = entityManager.m_entities.count();
    while (i < count) {
        defer i += 1;
        var entity = &(entityManager.m_entities.items[i].m_e orelse continue);
        EntityFixedUpdate(entity);
    }
}
