pub const EntityBehaviour = @import("BehaviourSystems/EntityBehaviour.zig");

//TODO ideally we somehow build out this list at compile time with each behaviour subscribing to it from their file
// rather than having to have a big centralized list with everything

// Variable frame-rate update
pub const s_update = [_]*const fn () void{
    EntityBehaviour.EntityUpdateBehaviour,
};

// Fixed delta time update
pub const s_fixedUpdate = [_]*const fn () void{
    EntityBehaviour.EntityFixedUpdateBehaviour,
};

// Entity spawn event
pub const s_onSpawn = [_]*const fn (u32) void{
    EntityBehaviour.EntityOnSpawnBehaviour,
};

// Entity destroyed event
pub const s_onDestroy = [_]*const fn (u32) void{
    EntityBehaviour.EntityOnDestroyBehaviour,
};

//TODO does enabling/disabling components or behaviours even make sense? I don't think it does...
// or at least components would just have an enabled bool on ones that are disable-able which behaviours could then process...
