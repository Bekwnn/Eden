const std = @import("std");

const gameWorld = @import("GameWorld.zig");
const ent = @import("Entity.zig");
const componentData = @import("ComponentData.zig");

const FastLookupTable = @import("../coreutil/FastLookupTable.zig").FastLookupTable;

const GameWorld = gameWorld.GameWorld;
const Entity = ent.Entity;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const k_entityAllocChunk = 100; //scales with Entity sizeof

const EntityError = error{
    MaxEntities,
    Unknown,
};

pub const EntityManager = struct {
    const EntityTable = FastLookupTable(Entity, ent.k_eidStart, ent.k_eidEnd);

    m_entityTable: EntityTable,
    m_allocator: Allocator,

    pub fn init(allocator: Allocator) EntityManager {
        return EntityManager{
            .m_allocator = allocator,
            .m_entityTable = EntityTable{},
        };
    }

    pub fn CreateEntity(self: *EntityManager) !*Entity {
        if (!ent.CheckEid(self.m_endOfEids)) return EntityError.MaxEntities;

        return try self.m_entityTable.InsertEntry(Entity{});
    }

    // returns null if entity has been destoryed or doesn't exist
    pub fn GetEntity(self: *EntityManager, eid: u32) ?*Entity {
        return self.m_entityTable.GetItem(eid);
    }

    pub fn KillEntity(self: *EntityManager, eid: u32) bool {
        return self.m_entityTable.RemoveItem(eid);
    }
};
