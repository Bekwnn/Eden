const Vec3 = @import("../../math/Vec3.zig");
const Quat = @import("../../math/Quat.zig");

pub const PhysicsComp = struct {
    linearVelocity: Vec3 = Vec3{},
    angularVelocity: Quat = Quat{},
    linearDrag: f32 = 0.1,
    angularDrag: f32 = 0.1,
};
