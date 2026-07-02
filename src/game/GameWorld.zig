const std = @import("std");
const Entity = @import("Entity.zig").Entity;
const EntityManager = @import("EntityManager.zig").EntityManager;
const behaviourSystems = @import("BehaviourSystems.zig");
const compData = @import("ComponentData.zig");
const ComponentManager = compData.ComponentManager;
const allocator = @import("../coreutil/Allocators.zig").defaultAllocator;

const debug = std.debug;
const time = std.time;
const Timer = time.Timer;
const ArrayList = std.ArrayList;

var instance: GameWorld = undefined;

pub const fixedDeltaTime: f32 = 1.0 / 60.0;
pub var deltaTime: f32 = 1.0 / 60.0;

pub const GameWorld = struct {
    m_entityManager: EntityManager,
    m_componentManager: ComponentManager,
    m_updateBehaviours: [behaviourSystems.s_update.len]*const fn () void = behaviourSystems.s_update,
    m_fixedUpdateBehaviours: [behaviourSystems.s_fixedUpdate.len]*const fn () void = behaviourSystems.s_fixedUpdate,
    m_onSpawnBehaviours: [behaviourSystems.s_onSpawn.len]*const fn (u32) void = behaviourSystems.s_onSpawn,
    m_onDestroyBehaviours: [behaviourSystems.s_onDestroy.len]*const fn (u32) void = behaviourSystems.s_onDestroy,

    pub fn Update(self: *GameWorld, deltaT: f32) void {
        deltaTime = deltaT;

        for (self.m_updateBehaviours) |updateBehaviour| {
            updateBehaviour();
        }
    }

    pub fn FixedUpdate(self: *GameWorld) void {
        for (self.m_fixedUpdateBehaviours) |fixedUpdateBehaviour| {
            fixedUpdateBehaviour();
        }
    }

    //TODO we probably want to be able to create entities with all their
    // components in place instead of creating them and then adding them
    pub fn CreateEntity(self: *GameWorld) *Entity {
        const newEntity = instance.m_entityManager.CreateEntity() catch |err| {
            debug.panic("{}", .{err});
        };
        for (self.m_onSpawnBehaviours) |onSpawnBehaviour| {
            onSpawnBehaviour(newEntity.m_eid);
        }
        return newEntity;
    }

    pub fn KillEntity(self: *GameWorld, eid: u32) bool {
        for (self.m_onDestroyBehaviours) |onDestroyBehaviour| {
            onDestroyBehaviour(eid);
        }
        return self.m_entityManager.KillEntity(eid);
    }

    // TODO actual error return values
    // in one case failedToFindComponentType
    // in another failedToFindCreatedComponent
    pub fn AddComponent(self: *GameWorld, compType: type, entity: *Entity) *compType {
        const newCompId = self.m_componentManager.AddComponent(compType, entity.m_eid);
        const compIdx = compData.GetCompIdx() orelse @panic("!");
        entity.m_compIds[compIdx] = newCompId;
        return self.m_componentManager.GetComponent(compType, newCompId) orelse @panic("!");
    }

    pub fn RemoveComponent(self: *GameWorld, compType: type, entity: *Entity) void {
        const compId = self.m_componentManager.GetComponentFromEntity(compType, entity) orelse return;
        self.m_componentManager.RemoveComponent(compType, compId);
    }
};

pub fn Initialize() void {
    instance = GameWorld{
        .m_entityManager = EntityManager.init(allocator),
        .m_componentManager = ComponentManager.init(allocator),
    };
}

pub fn Instance() *const GameWorld {
    return &instance;
}

pub fn WritableInstance() *GameWorld {
    return &instance;
}
