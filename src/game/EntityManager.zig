const std = @import("std");
const GameWorld = @import("GameWorld.zig").GameWorld;
const Entity = @import("Entity.zig").Entity;

const ArrayList = std.ArrayList;
const mem = std.mem;

var allocator = std.heap.direct_allocator;
const k_entityAllocChunk = 100; //scales with Entity sizeof

const EntityError = error {
    MaxEntities,
};

const EntityFastLookup = struct {
    m_ptr: *Entity = null,
    m_eid: u32 = 0,
};

pub const EntityManager = struct {
    //TODO should probably allocate in chunks of entities or something to make things a bit slicker
    m_entityFastTable: ArrayList(EntityFastLookup),
    m_entities: ArrayList(Entity),
    m_endOfEids: u32 = 1000,

    pub fn Initialize() EntityManager {
        return EntityManager{
            .m_entityFastTable = ArrayList(EntityFastLookup).init(allocator),
            .m_entities = ArrayList(Entity).init(allocator),
        };
        // will probably do additional initialization later on...
    }

    pub fn CreateEntity(self: *EntityManager) !*Entity {

        if (!Entity.CheckEID(self.m_endOfEids)) return EntityError.MaxEntities;

        try self.m_entities.append(Entity{ .m_eid = self.m_endOfEids });
        const eptr: *Entity = &self.m_entities.items[self.m_endOfEids - 1000];
        try self.m_entityFastTable.append(EntityFastLookup{
            .m_eid = self.m_endOfEids,
            .m_ptr = eptr,
        });//TODO should delete entity if the lookup table has an issue

        self.m_endOfEids += 1;
        return eptr;
    }

    // this O(1) speed look up will be nice so long as I'm not caring about freeing resources... best way to free and still keep it fast? maybe the lookup table never frees but the list does?
    pub fn GetEntity(self: *EntityManager, eid: u32) ?*Entity {
        if (eid >= self.m_endOfEids) {
            return null;
        } else {
            return &self.m_entities.items[eid];
        }
    }
};
