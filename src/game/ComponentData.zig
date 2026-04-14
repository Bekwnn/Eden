// TODO this is a lot of annoying typing per component, anyway to comptime it?
pub const HealthComp = @import("ComponentData/HealthComp.zig").HealthComp;
pub const InputComp = @import("ComponentData/InputComp.zig").InputComp;
pub const MovementComp = @import("ComponentData/MovementComp.zig").MovementComp;
pub const PhysicsComp = @import("ComponentData/PhysicsComp.zig").PhysicsComp;
pub const SceneComp = @import("ComponentData/SceneComp.zig").SceneComp;
pub const TransformComp = @import("ComponentData/TransformComp.zig").TransformComp;

const Entity = @import("Entity.zig").Entity;

pub const componentTypes = type[_]{
    HealthComp,
    InputComp,
    MovementComp,
    PhysicsComp,
    SceneComp,
    TransformComp,
};

pub fn GetCompIdx(compType: type) ?usize {
    for (componentTypes, 0..) |curType, i| {
        if (curType == compType) return i;
    }
}

const std = @import("std");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

//TODO
// There should be some sanity checking/assurance that we're fetching the component
// of a living entity and not one that has died, with another entity back-filling the
// component data in the array
fn ComponentDataPair(comptime compType: type) type {
    return struct {
        m_ownerEid: u32,
        m_data: compType = compType{}, // components must have defaults
    };
}

fn ComponentDataArray(comptime compType: type) type {
    return struct {
        m_compData: ArrayList(ComponentDataPair(compType)) = .empty,
        m_allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return Self{
                .m_allocator = allocator,
            };
        }

        pub fn GetComp(self: *ComponentDataArray(compType), id: u16) ?*compType {
            if (id >= self.m_compData.len) {
                return null;
            } else {
                return &self.m_compData.items[id].m_data;
            }
        }

        pub fn GetEntityComp(self: *ComponentDataArray(compType), entity: *const Entity) ?*compType {
            // TODO fetch compId from entity and GetComp with that instead
            for (self.m_compData) |*compDataPair| {
                if (compDataPair.m_ownerEid == entity.m_eid) {
                    return &compDataPair.m_data;
                }
            }
            return null;
        }

        pub fn GetOwnerId(self: *ComponentDataArray(compType), id: u16) ?u32 {
            if (id >= self.m_compData.len) {
                return null;
            } else {
                return self.m_compData.items[id].m_ownerEid;
            }
        }

        pub fn AddComp(self: *ComponentDataArray(compType), owner: u32) u16 {
            self.m_compData.append(self.m_allocator, ComponentDataPair(compType){ .m_ownerEid = owner }) catch {
                @panic("Could not add new component to array.");
            };
            const addedCompId = @as(u16, self.m_compData.len - 1);
            //TODO add compId to entity's m_componentIds
            return addedCompId;
        }

        pub fn RemoveComp(self: *ComponentDataArray(compType), compId: u16) void {
            //TODO we need to handle removal, but it's an arraylist
        }
    };
}

pub const ComponentManager = struct {
    m_healthCompData: ComponentDataArray(HealthComp),
    m_inputCompData: ComponentDataArray(InputComp),
    m_movementCompData: ComponentDataArray(MovementComp),
    m_physicsCompData: ComponentDataArray(PhysicsComp),
    m_sceneCompData: ComponentDataArray(SceneComp),
    m_transformCompData: ComponentDataArray(TransformComp),

    pub fn init(allocator: Allocator) ComponentManager {
        return ComponentManager{
            .m_healthCompData = ComponentDataArray(HealthComp).init(allocator),
            .m_inputCompData = ComponentDataArray(InputComp).init(allocator),
            .m_movementCompData = ComponentDataArray(MovementComp).init(allocator),
            .m_sceneCompData = ComponentDataArray(SceneComp).init(allocator),
            .m_transformCompData = ComponentDataArray(TransformComp).init(allocator),
            .m_physicsCompData = ComponentDataArray(PhysicsComp).init(allocator),
        };
    }

    fn SwitchOnCompType(self: *ComponentManager, comptime compType: type) *ComponentDataArray(compType) {
        return switch (compType) {
            HealthComp => &self.m_healthCompData,
            InputComp => &self.m_inputCompData,
            MovementComp => &self.m_movementCompData,
            SceneComp => &self.m_sceneCompData,
            TransformComp => &self.m_transformCompData,
            PhysicsComp => &self.m_physicsCompData,
            else => @compileError("Component type not known."),
        };
    }

    //TODO const?
    pub fn GetComponent(self: *ComponentManager, comptime compType: type, compId: u16) ?*compType {
        return self.SwitchOnCompType(compType).GetComp(compId);
    }

    pub fn GetComponentFromEntity(self: *ComponentManager, comptime compType: type, entity: *const Entity) ?*compType {
        return self.SwitchOnCompType(compType).GetEntityComp(entity);
    }

    pub fn GetComponentOwnerId(self: *ComponentManager, comptime compType: type, compID: u16) ?u32 {
        return self.SwitchOnCompType(compType).GetOwnerId(compID);
    }

    // returns componentID
    pub fn AddComponent(self: *ComponentManager, comptime compType: type, ownerEid: u32) u16 {
        return self.SwitchOnCompType(compType).AddComp(ownerEid);
    }

    pub fn RemoveComponent(self: *ComponentManager, comptime compType: type, compId: u16) void {
        self.SwitchOnCompType(compType).RemoveComp(compId);
    }
};
