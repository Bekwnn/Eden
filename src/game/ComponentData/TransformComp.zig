const Vec3 = @import("../../math/Vec3.zig");
const Quat = @import("../../math/Quat.zig");

pub const TransformComp = struct {
    position: Vec3 = Vec3{},
    rotation: Quat = Quat{},
    scale: Vec3 = Vec3{ .x = 1.0, .y = 1.0, .z = 1.0 },
};
