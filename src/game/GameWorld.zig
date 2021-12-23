const std = @import("std");
const Entity = @import("Entity.zig").Entity;
const EntityManager = @import("EntityManager.zig").EntityManager;
const behaviourSystems = @import("BehaviourSystems.zig");
const ComponentManager = @import("ComponentData.zig").ComponentManager;

const debug = std.debug;
const time = std.time;
const Timer = time.Timer;
const ArrayList = std.ArrayList;
const allocator = std.heap.direct_allocator;

var instance: GameWorld = undefined;

pub const fixedDeltaTime: f32 = 1.0 / 60.0;
pub var deltaTime: f32 = 1.0 / 60.0;

pub const GameWorld = struct {
    m_entityManager: EntityManager,
    m_componentManager: ComponentManager,
    m_updateBehaviours: [behaviourSystems.s_update.len]fn () void = behaviourSystems.s_update,
    m_fixedUpdateBehaviours: [behaviourSystems.s_fixedUpdate.len]fn () void = behaviourSystems.s_fixedUpdate,
    m_onSpawnBehaviours: [behaviourSystems.s_onSpawn.len]fn (u32) void = behaviourSystems.s_onSpawn,
    m_onDestroyBehaviours: [behaviourSystems.s_onDestroy.len]fn (u32) void = behaviourSystems.s_onDestroy,

    pub fn Update(self: *GameWorld, deltaT: f32) void {
        deltaTime = deltaT;

        var i: u32 = 0;
        while (i < self.m_updateBehaviours.len) {
            defer i += 1;
            self.m_updateBehaviours[i]();
        }
    }

    pub fn FixedUpdate(self: *GameWorld) void {
        var i: u32 = 0;
        while (i < self.m_fixedUpdateBehaviours.len) {
            defer i += 1;
            self.m_fixedUpdateBehaviours[i]();
        }
    }

    pub fn CreateEntity(self: *GameWorld) *Entity {
        const newEntity = instance.m_entityManager.CreateEntity() catch |err| {
            debug.panic("{}", .{err});
        };
        var i: u32 = 0;
        while (i < self.m_onSpawnBehaviours.len) {
            defer i += 1;
            self.m_onSpawnBehaviours[i](newEntity.m_eid);
        }
        return newEntity;
    }

    pub fn KillEntity(self: *GameWorld, eid: u32) bool {
        var i: u32 = 0;
        while (i < self.m_onDestroyBehaviours.len) {
            defer i += 1;
            self.m_onDestroyBehaviours[i](eid);
        }
        return self.m_entityManager.KillEntity(eid);
    }
};

pub fn Initialize() void {
    instance = GameWorld{
        .m_entityManager = EntityManager.Initialize(),
        .m_componentManager = ComponentManager.Initialize(),
    };
}

pub fn Instance() *const GameWorld {
    return &instance;
}

pub fn WritableInstance() *GameWorld {
    return &instance;
}
