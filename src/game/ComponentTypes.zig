pub const HealthComp = @import("ComponentData/HealthComp.zig").HealthComp;
pub const InputComp = @import("ComponentData/InputComp.zig").InputComp;
pub const MovementComp = @import("ComponentData/MovementComp.zig").MovementComp;
pub const PhysicsComp = @import("ComponentData/PhysicsComp.zig").PhysicsComp;
pub const SceneComp = @import("ComponentData/SceneComp.zig").SceneComp;
pub const TransformComp = @import("ComponentData/TransformComp.zig").TransformComp;

pub const componentTypes = .{
    HealthComp,
    InputComp,
    MovementComp,
    PhysicsComp,
    SceneComp,
    TransformComp,
};

pub fn GetCompIdx(compType: type) ?usize {
    for (componentTypes, 0..) |curType, i| {
        if (curType == compType) return i;
    }
}
