const MovementComp = @import("../ComponentData/MovementComp.zig").MovementComp;
const TransformComp = @import("../ComponentData/TransformComp.zig").TransformComp;

const gameWorld = @import("../GameWorld.zig");
const EntityManager = @import("../EntityManager.zig");
const ComponentManager = @import("../ComponentData.zig").ComponentManager;

const Vec3 = @import("../../math/Vec3.zig").Vec3;

// TEST BEHAVIOUR
// This is just a weird nonsense test behaviour meant to make things
// move in a circle. It's just meant to serve as a general test of the
// entire behaviour system as a whole to identify pain points and
// further streamlining of its api.
//

const BehaviourTuple = struct {
    m_movement: *MovementComp,
    m_transform: *TransformComp,
};

// there's no current game time in game world
var movementCurTime: f32 = 0.0;
const arbitrarySpeedMod = 0.3;

// moves transform in an arbitrary circleish motion
fn TestMovementUpdate(data: BehaviourTuple) void {
    const tVal: f32 = movementCurTime * arbitrarySpeedMod;
    data.m_transform.position = Vec3{
        .x = data.m_movement.initialPos.x + 3.0 * @cos(tVal),
        .y = data.m_movement.initialPos.y + 3.0 * @sin(tVal),
        .z = data.m_movement.initialPos.z,
    };
}

fn TestMovementOnSpawn(data: BehaviourTuple) void {
    // save initial position
    data.m_movement.initialPos = data.m_transform.position;
}

// TODO create a generic version of this "gather component tuple"
// pattern to reduce typing so much
pub fn TestMovementUpdateBehaviour() void {
    movementCurTime += gameWorld.deltaTime;
    const gw = &gameWorld.WritableInstance();
    const entityManager: *EntityManager = &gw.m_entityManager;
    const compManager: *ComponentManager = &gw.m_componentManager;
    for (entityManager.m_entities.items) |*entityPair| {
        const entity = &(entityPair.m_e orelse continue);
        const entTransform = compManager.GetComponentFromEntity(TransformComp, entity) orelse continue;
        const entMovement = compManager.GetComponentFromEntity(MovementComp, entity) orelse continue;
        TestMovementUpdate(.{
            .m_movement = entMovement,
            .m_transform = entTransform,
        });
    }
}

pub fn TestMovementOnSpawnBehaviour(eid: u32) void {
    const gw = &gameWorld.WritableInstance();
    const entityManager: *EntityManager = &gw.m_entityManager;
    const compManager: *ComponentManager = &gw.m_componentManager;
    const entity = entityManager.GetEntity(eid) orelse return;
    const entTransform = compManager.GetComponentFromEntity(TransformComp, entity) orelse return;
    const entMovement = compManager.GetComponentFromEntity(MovementComp, entity) orelse return;
    TestMovementOnSpawn(.{
        .m_movement = entMovement,
        .m_transform = entTransform,
    });
}
