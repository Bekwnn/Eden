const std = @import("std");
const gameWorld = @import("GameWorld.zig");
const ent = @import("Entity.zig");
const componentData = @import("ComponentData.zig");

const GameWorld = gameWorld.GameWorld;
const Entity = ent.Entity;
const ArrayList = std.ArrayList;
const mem = std.mem;

const allocator = std.heap.direct_allocator;
const k_entityAllocChunk = 100; //scales with Entity sizeof

const EntityError = error{
    MaxEntities,
    Unknown,
};

const EntityFastLookup = struct {
    m_idx: ?u32,
    m_eid: u32,
};

// wrap entity optional because ArrayList hates optionals for some reason...
const EntityEntry = struct {
    m_e: ?Entity,
};

pub const EntityManager = struct {
    m_entityFastTable: ArrayList(EntityFastLookup) = ArrayList(EntityFastLookup).init(allocator),
    m_entities: ArrayList(EntityEntry) = ArrayList(EntityEntry).init(allocator),
    m_endOfEids: u32 = ent.GetEidStart(),
    m_firstFreeEntitySlot: u32 = 0, // potentially speed up KillEntity a bit on average...

    pub fn Initialize() EntityManager {
        return EntityManager{};
        // will probably do additional initialization later on...
    }

    pub fn CreateEntity(self: *EntityManager) !*Entity {
        if (!ent.CheckEid(self.m_endOfEids)) return EntityError.MaxEntities;

        var newEntityIdx: u32 = 0;
        if (self.m_firstFreeEntitySlot == self.m_entities.len) { // append new
            const newEntry = Entity{ .m_eid = self.m_endOfEids };
            try self.m_entities.append(EntityEntry{ .m_e = newEntry });
            newEntityIdx = @intCast(u32, self.m_entities.len) - 1;
            self.m_firstFreeEntitySlot += 1;
        } else { // use existing freed slot
            self.m_entities.items[self.m_firstFreeEntitySlot].m_e = Entity{ .m_eid = self.m_endOfEids };
            newEntityIdx = self.m_firstFreeEntitySlot;
            while (self.m_firstFreeEntitySlot < self.m_entities.len and self.m_entities.items[self.m_firstFreeEntitySlot].m_e != null) {
                self.m_firstFreeEntitySlot += 1;
            }
        }
        try self.m_entityFastTable.append(EntityFastLookup{
            .m_eid = self.m_endOfEids,
            .m_idx = newEntityIdx,
        }); //TODO should go back and delete entity if the lookup table has an issue
        self.m_endOfEids += 1;

        return &(self.m_entities.items[newEntityIdx].m_e orelse return EntityError.Unknown);
    }

    // returns null if entity has been destoryed or doesn't exist
    pub fn GetEntity(self: *EntityManager, eid: u32) ?Entity {
        const lookup = self.FastLookup(eid) orelse return null;
        const entityIdx: u32 = lookup.m_idx orelse return null;
        return self.m_entities.items[entityIdx].m_e orelse return null;
    }

    pub fn KillEntity(self: *EntityManager, eid: u32) bool {
        const lookup = self.FastLookup(eid) orelse return false;
        const entityIdx: u32 = lookup.m_idx orelse return false;

        // free the entity data
        self.m_entities.items[entityIdx].m_e = null;
        if (entityIdx < self.m_firstFreeEntitySlot) {
            self.m_firstFreeEntitySlot = entityIdx;
        }

        // the eid is now forever null in the lookup table
        lookup.m_idx = null;

        return true;
    }

    fn FastLookup(self: *EntityManager, eid: u32) ?*EntityFastLookup {
        if (!ent.CheckEid(eid) or eid >= self.m_endOfEids) {
            return null;
        }
        return &self.m_entityFastTable.items[eid - ent.GetEidStart()];
    }
};
