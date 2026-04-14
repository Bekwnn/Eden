const Vec3 = @import("../../math/Vec3.zig").Vec3;

// Holds state about the entity's ability to move
pub const MovementComp = struct {
    speed: f32 = 5.0,

    // TODO DELETE
    // initial pos is just for testing with TestMovementBehaviour
    initialPos: Vec3 = Vec3{ .x = 0.0, .y = 0.0, .z = 0.0 },
};
