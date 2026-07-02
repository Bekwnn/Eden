const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const FastLookupError = error{
    TableFullError,
    Unknown,
};

//TODO genericize u32 usage to any integer type
const FastLookupIndex = struct {
    m_idx: ?u32,
    m_id: u32,
};

// wrap entity optional because ArrayList hates optionals
pub fn FastLookupEntry(ItemType: type) type {
    return struct {
        entry: ?ItemType,
    };
}

pub fn FastLookupTable(ItemType: type, startId: u32, endId: u32) type {
    return struct {
        const Self = @This();

        m_lookupTable: ArrayList(FastLookupIndex) = .empty,
        m_entries: ArrayList(FastLookupEntry(ItemType)) = .empty,
        m_minId: u32 = startId,
        m_maxId: u32 = endId,
        m_endOfIds: u32 = startId,
        m_firstFreeSlot: u32 = 0,

        pub fn InsertEntry(self: *Self, allocator: Allocator, item: ItemType) !u32 {
            if (!self.IsValidId(self.m_endOfIds)) {
                return FastLookupError.TableFullError;
            }

            var newEntryIdx: u32 = 0;
            if (self.m_firstFreeSlot == self.m_entries.len) { // append new
                try self.m_entries.append(
                    allocator,
                    FastLookupEntry{ .entry = item },
                );
                newEntryIdx = @as(u32, self.m_entries.len) - 1;
                self.m_firstFreeSlot += 1;
            } else { // use existing freed slot
                self.m_entries.items[self.m_firstFreeSlot].entry = item;
                newEntryIdx = self.m_firstFreeSlot;
                while (self.m_firstFreeSlot < self.m_entries.len and self.m_entries.items[self.m_firstFreeSlot].m_e != null) {
                    self.m_firstFreeSlot += 1;
                }
            }
            try self.m_entityFastTable.append(
                allocator,
                FastLookupIndex{
                    .m_id = self.m_endOfIds,
                    .m_idx = newEntryIdx,
                },
            ); //TODO should go back and delete entity if the lookup table has an issue
            self.m_endOfIds += 1;

            return newEntryIdx;
        }

        // returns null if entity has been destoryed or doesn't exist
        pub fn GetItem(self: *Self, id: u32) ?*ItemType {
            const lookup = self.FastLookup(id) orelse return null;
            const entryIdx: u32 = lookup.m_idx orelse return null;
            return self.m_entries.items[entryIdx].entry orelse return null;
        }

        pub fn RemoveItem(self: *Self, id: u32) bool {
            const lookup = self.FastLookup(id) orelse return false;
            const entryIdx: u32 = lookup.m_idx orelse return false;

            // free the entity data
            self.m_entries.items[entryIdx].entry = null;
            if (entryIdx < self.m_firstFreeSlot) {
                self.m_firstFreeSlot = entryIdx;
            }

            // the eid is now forever null in the lookup table
            lookup.m_idx = null;

            return true;
        }

        pub fn IsValidId(self: *Self, id: u32) bool {
            return id >= self.m_minId and id < self.m_maxId;
        }

        fn FastLookup(self: *Self, id: u32) ?*FastLookupIndex {
            if (!self.IsValidId(id) or id >= self.m_endOfIds) {
                return null;
            }
            return &self.m_lookupTable.items[id - self.m_minId];
        }
    };
}
