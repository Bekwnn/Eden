const entityManager = @import("EntityManager.zig");

//TODO ideally we somehow build out this list at compile time with each behaviour subscribing to it from their file
// rather than having to have a big centralized list with everything
pub const updateBehaviourList = [_]fn () void{
    entityManager.EntityUpdateBehaviour,
};
pub const fixedUpdateBehaviourList = [_]fn () void{
    entityManager.EntityFixedUpdateBehaviour,
};
