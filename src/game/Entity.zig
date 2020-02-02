const Vec3 = @import("../math/Vec3.zig");

// [start, end), 1m entities for now (more...?)
const k_eidStart: u32 = 1000;
const k_eidEnd: u32 = 1001000;

pub const Entity = struct {
    m_eid: u32 = 0,
    m_pos: Vec3 = Vec3{},

    pub fn CheckEID(eid: u32) bool {
        return eid >= k_eidStart and eid < k_eidEnd;
    }
};
