const std = @import("std");
const EntityBehaviour = @import("BehaviourSystems/EntityBehaviour.zig");
const TestMovementBehaviour = @import("BehaviourSystems/TestMovementBehaviour.zig");

pub const behaviourTypes = .{
    EntityBehaviour,
    TestMovementBehaviour,
};

// Variable frame-rate update
pub const entityUpdate_name = "EntityUpdate";
pub const entityUpdate_type = *const fn () void;
const s_updateLen = getBehaviourTypeLen(entityUpdate_name, entityUpdate_type);
pub const s_update = getBehaviourTypeFnArray(entityUpdate_name, entityUpdate_type, s_updateLen);

// Fixed delta time update
pub const entityFixedUpdate_name = "EntityFixedUpdate";
pub const entityFixedUpdate_type = *const fn () void;
const s_fixedUpdateLen = getBehaviourTypeLen(entityFixedUpdate_name, entityFixedUpdate_type);
pub const s_fixedUpdate = getBehaviourTypeFnArray(entityFixedUpdate_name, entityFixedUpdate_type, s_fixedUpdateLen);

// Entity spawn event
pub const entityOnSpawn_name = "EntityOnSpawn";
pub const entityOnSpawn_type = *const fn (u32) void;
const s_onSpawnLen = getBehaviourTypeLen(entityOnSpawn_name, entityOnSpawn_type);
pub const s_onSpawn = getBehaviourTypeFnArray(entityOnSpawn_name, entityOnSpawn_type, s_onSpawnLen);

// Entity destroyed event
pub const entityOnDestroy_name = "EntityOnDestroy";
pub const entityOnDestroy_type = *const fn (u32) void;
const s_onDestroyLen = getBehaviourTypeLen(entityOnSpawn_name, entityOnSpawn_type);
pub const s_onDestroy = getBehaviourTypeFnArray(entityOnSpawn_name, entityOnSpawn_type, s_onDestroyLen);

// based on std.meta.hasFn
inline fn getFn(
    comptime behaviourType: type,
    comptime fnType: type,
    comptime fnName: []const u8,
) ?fnType {
    const behaviourTypeInfo = @typeInfo(behaviourType);
    switch (behaviourTypeInfo) {
        .@"struct", .@"union", .@"enum", .@"opaque" => {},
        else => unreachable,
    }
    if (@hasDecl(behaviourType, fnName)) {
        const fnPtr = &@field(behaviourType, fnName);
        if (@TypeOf(fnPtr) == fnType) {
            return fnPtr;
        } else {
            // Hit if the function exists, but its signature/type is wrong
            @panic("Expected type \"" ++
                @typeName(fnType) ++
                "\" instead found \"" ++
                @typeName(@TypeOf(fnPtr)) ++
                "\"\n");
        }
    }
    return null;
}

inline fn getBehaviourTypeLen(
    comptime fnName: []const u8,
    comptime fnType: type,
) comptime_int {
    var count = 0;
    for (behaviourTypes) |behaviourType| {
        if (getFn(behaviourType, fnType, fnName) != null) {
            count += 1;
        }
    }
    return count;
}

inline fn getBehaviourTypeFnArray(
    comptime fnName: []const u8,
    comptime fnType: type,
    comptime len: comptime_int,
) [len]fnType {
    var fns: [len]fnType = undefined;
    var i = 0;
    for (behaviourTypes) |behaviourType| {
        if (getFn(behaviourType, fnType, fnName)) |fnPtr| {
            fns[i] = fnPtr;
            i += 1;
        }
    }
    return fns;
}
