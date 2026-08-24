const std = @import("std");
const EntityBehaviour = @import("BehaviourSystems/EntityBehaviour.zig");
const TestMovementBehaviour = @import("BehaviourSystems/TestMovementBehaviour.zig");

pub const behaviourTypes = .{
    EntityBehaviour,
    TestMovementBehaviour,
};

pub const behaviourName_EntityUpdate = "EntityUpdate";
pub const behaviourType_EntityUpdate = *const fn () void;

pub const behaviourName_EntityFixedUpdate = "EntityFixedUpdate";
pub const behaviourType_EntityFixedUpdate = *const fn () void;

pub const behaviourName_EntityOnSpawn = "EntityOnSpawn";
pub const behaviourType_EntityOnSpawn = *const fn (u32) void;

pub const behaviourName_EntityOnDestroy = "EntityOnDestroy";
pub const behaviourType_EntityOnDestroy = *const fn (u32) void;

//TODO these init blocks have a bunch of boiler-plate, should figure out how to
// move the init block out to a function
//TODO these arrays should only contain existing functions and not be optionals

// Variable frame-rate update
pub const s_update = init: {
    const fnName = behaviourName_EntityUpdate;
    const fnType = behaviourType_EntityUpdate;

    var fns: [behaviourTypes.len]?fnType = undefined;
    for (behaviourTypes, 0..) |behaviourType, i| {
        fns[i] = getFn(behaviourType, fnType, fnName);
    }
    break :init fns;
};

// Fixed delta time update
pub const s_fixedUpdate = init: {
    const fnName = behaviourName_EntityFixedUpdate;
    const fnType = behaviourType_EntityFixedUpdate;

    // is it possible to make this a function?
    var fns: [behaviourTypes.len]?fnType = undefined;
    for (behaviourTypes, 0..) |behaviourType, i| {
        fns[i] = getFn(behaviourType, fnType, fnName);
    }
    break :init fns;
};

// Entity spawn event
pub const s_onSpawn = init: {
    const fnName = behaviourName_EntityOnSpawn;
    const fnType = behaviourType_EntityOnSpawn;

    // is it possible to make this a function?
    var fns: [behaviourTypes.len]?fnType = undefined;
    for (behaviourTypes, 0..) |behaviourType, i| {
        fns[i] = getFn(behaviourType, fnType, fnName);
    }
    break :init fns;
};

// Entity destroyed event
pub const s_onDestroy = init: {
    const fnName = behaviourName_EntityOnDestroy;
    const fnType = behaviourType_EntityOnDestroy;

    // is it possible to make this a function?
    var fns: [behaviourTypes.len]?fnType = undefined;
    for (behaviourTypes, 0..) |behaviourType, i| {
        fns[i] = getFn(behaviourType, fnType, fnName);
    }
    break :init fns;
};

// based on std.meta.hasFn
inline fn getFn(
    behaviourType: type,
    fnType: type,
    fnName: []const u8,
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
