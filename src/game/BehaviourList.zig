const entityBehaviour = @import("BehaviourSystems/EntityBehaviour.zig");

//TODO ideally we somehow build out this list at compile time with each behaviour subscribing to it from their file
// rather than having to have a big centralized list with everything

// Variable frame-rate update
pub const updateBehaviourList = [_]fn () void{
    entityBehaviour.EntityUpdateBehaviour,
};

// Fixed delta time update
pub const fixedUpdateBehaviourList = [_]fn () void{
    entityBehaviour.EntityFixedUpdateBehaviour,
};

//TODO events
// Spawn event
// Destroyed event
// Enable event
// Disable event
