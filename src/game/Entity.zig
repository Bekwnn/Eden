const Vec3 = @import("../math/Vec3.zig");
const debug = @import("std").debug;
const componentData = @import("ComponentData.zig");
const componentTypes = @import("ComponentTypes.zig").componentTypes;

// [start, end), 1m entities for now (more...?)
pub const k_eidCount: u32 = 1000000;
pub const k_eidStart: u32 = 1000;
pub const k_eidEnd: u32 = k_eidStart + k_eidCount;

pub const Entity = struct {
    m_eid: u32 = 0,
    // TODO hash map instead?
    m_componentIds: [componentTypes.len]?u16 = [_]?u16{null} ** componentTypes.len,
};

// Just says whether or not an eid is in the range of [eidStart, eidEnd)
pub fn CheckEid(eid: u32) bool {
    return eid >= k_eidStart and eid < k_eidEnd;
}

pub fn GetEntityMaxCount() u32 {
    return k_eidCount;
}

pub fn GetEidStart() u32 {
    return k_eidStart;
}
