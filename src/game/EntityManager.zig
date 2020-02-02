const std = @import("std");
const GameWorld = @import("GameWorld.zig").GameWorld;
const ent = @import("Entity.zig");

const Entity = ent.Entity;
const ArrayList = std.ArrayList;
const mem = std.mem;

var allocator = std.heap.direct_allocator;
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
    //TODO should probably allocate in chunks of entities or something to make things a bit slicker
    m_entityFastTable: ArrayList(EntityFastLookup),
    m_entities: ArrayList(EntityEntry),
    m_endOfEids: u32 = Entity.GetEidStart(),
    m_firstFreeEntitySlot: u32 = 0, // potentially speed up KillEntity a bit on average...

    pub fn Initialize() EntityManager {
        return EntityManager{
            .m_entityFastTable = ArrayList(EntityFastLookup).init(allocator),
            .m_entities = ArrayList(EntityEntry).init(allocator),
        };
        // will probably do additional initialization later on...
    }

    pub fn CreateEntity(self: *EntityManager) !*Entity {
        if (!Entity.CheckEid(self.m_endOfEids)) return EntityError.MaxEntities;

        var newEntityIdx: u32 = 0;
        if (self.m_firstFreeEntitySlot == self.m_entities.count()) { // append new
            const newEntry = Entity{ .m_eid = self.m_endOfEids };
            try self.m_entities.append(EntityEntry{ .m_e = newEntry });
            newEntityIdx = @intCast(u32, self.m_entities.count()) - 1;
            self.m_firstFreeEntitySlot += 1;
        } else { // use existing freed slot
            self.m_entities.items[self.m_firstFreeEntitySlot].m_e = Entity{ .m_eid = self.m_endOfEids };
            newEntityIdx = self.m_firstFreeEntitySlot;
            while (self.m_firstFreeEntitySlot < self.m_entities.count() and self.m_entities.items[self.m_firstFreeEntitySlot].m_e != null) {
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
        if (!Entity.CheckEid(eid) or eid >= self.m_endOfEids) {
            return null;
        }
        return &self.m_entityFastTable.items[eid - Entity.GetEidStart()];
    }
};
