const gameWorld = @import("../GameWorld.zig");
const EntityManager = @import("../EntityManager.zig").EntityManager;
const Entity = @import("../Entity.zig").Entity;

const std = @import("std");

fn EntityUpdate(self: *Entity) void {
    std.debug.print("Entity {} Update! ", .{self.m_eid});
}

pub fn EntityUpdateBehaviour() void {
    const entityManager: *EntityManager = &gameWorld.WritableInstance().m_entityManager;
    var i: u32 = 0;
    while (i < entityManager.m_entities.items.len) {
        defer i += 1;
        const entity = &(entityManager.m_entities.items[i].m_e orelse continue);
        EntityUpdate(entity);
    }
}

fn EntityFixedUpdate(self: *Entity) void {
    std.debug.print("Entity {} Fixed Update! ", .{self.m_eid});
}

pub fn EntityFixedUpdateBehaviour() void {
    const entityManager: *EntityManager = &gameWorld.WritableInstance().m_entityManager;
    var i: u32 = 0;
    while (i < entityManager.m_entities.items.len) {
        defer i += 1;
        const entity = &(entityManager.m_entities.items[i].m_e orelse continue);
        EntityFixedUpdate(entity);
    }
}

pub fn EntityOnSpawnBehaviour(eid: u32) void {
    std.debug.print("Entity {} spawned. ", .{eid});
}

pub fn EntityOnDestroyBehaviour(eid: u32) void {
    std.debug.print("Entity {} destroyed. ", .{eid});
}
