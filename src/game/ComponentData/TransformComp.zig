const math = @import("../../math/Math.zig");
const Vec3 = math.Vec3;
const Quat = math.Quat;

pub const TransformComp = struct {
    position: Vec3 = Vec3{},
    rotation: Quat = Quat{},
    scale: Vec3 = Vec3{ .x = 1.0, .y = 1.0, .z = 1.0 },
};
