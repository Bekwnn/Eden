const std = @import("std");
const Entity = @import("Entity.zig").Entity;
const EntityManager = @import("EntityManager.zig").EntityManager;
const behaviourLists = @import("BehaviourList.zig");

const debug = std.debug;
const time = std.time;
const Timer = time.Timer;
const ArrayList = std.ArrayList;

const allocator = std.heap.direct_allocator;
const fixedDeltaTime: comptime f32 = 1.0 / 60.0;

var instance: GameWorld = undefined;
var deltaTime: f32 = 1.0 / 60.0;

pub const GameWorld = struct {
    m_entityManager: EntityManager,
    m_updateBehaviours: [behaviourLists.updateBehaviourList.len]fn () void = behaviourLists.updateBehaviourList,
    m_fixedUpdateBehaviours: [behaviourLists.fixedUpdateBehaviourList.len]fn () void = behaviourLists.fixedUpdateBehaviourList,

    pub fn Update(self: *GameWorld, deltaT: f32) void {
        deltaTime = deltaT;

        var i: u32 = 0;
        while (i < self.m_updateBehaviours.len) {
            self.m_updateBehaviours[i]();
            i += 1;
        }
    }

    pub fn FixedUpdate(self: *GameWorld) void {
        var i: u32 = 0;
        while (i < self.m_fixedUpdateBehaviours.len) {
            self.m_fixedUpdateBehaviours[i]();
            i += 1;
        }
    }

    pub fn CreateEntity(self: *GameWorld) *Entity {
        return instance.m_entityManager.CreateEntity() catch |err| {
            debug.panic("{}", err);
        };
    }
};

pub fn Initialize() void {
    instance = GameWorld{ .m_entityManager = EntityManager.Initialize() };
}

pub fn Instance() *const GameWorld {
    return &instance;
}

pub fn WritableInstance() *GameWorld {
    return &instance;
}
