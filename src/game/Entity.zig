const Vec3 = @import("../math/Vec3.zig");
const debug = @import("std").debug;

const assert = debug.assert;
const warn = debug.warn;

// [start, end), 1m entities for now (more...?)
const k_eidCount: u32 = 1000000;
const k_eidStart: u32 = 1000;
const k_eidEnd: u32 = k_eidStart + k_eidCount;

pub const Entity = struct {
    m_eid: u32 = 0,
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
