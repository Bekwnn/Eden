pub const EntityBehaviour = @import("BehaviourSystems/EntityBehaviour.zig");

//TODO ideally we somehow build out this list at compile time with each behaviour subscribing to it from their file
// rather than having to have a big centralized list with everything

// Variable frame-rate update
pub const s_update = [_]fn () void{
    EntityBehaviour.EntityUpdateBehaviour,
};

// Fixed delta time update
pub const s_fixedUpdate = [_]fn () void{
    EntityBehaviour.EntityFixedUpdateBehaviour,
};

// Entity spawn event
pub const s_onSpawn = [_]fn (u32) void{
    EntityBehaviour.EntityOnSpawnBehaviour,
};

// Entity destroyed event
pub const s_onDestroy = [_]fn (u32) void{
    EntityBehaviour.EntityOnDestroyBehaviour,
};

//TODO events
// Enable event
// Disable event
