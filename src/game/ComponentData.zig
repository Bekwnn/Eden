// TODO this is a lot of annoying typing per component, anyway to comptime it?
pub const HealthComp = @import("ComponentData/HealthComp.zig").HealthComp;
pub const InputComp = @import("ComponentData/InputComp.zig").InputComp;
pub const MovementComp = @import("ComponentData/MovementComp.zig").MovementComp;
pub const SceneComp = @import("ComponentData/SceneComp.zig").SceneComp;
pub const TransformComp = @import("ComponentData/TransformComp.zig").TransformComp;
pub const PhysicsComp = @import("ComponentData/PhysicsComp.zig").PhysicsComp;

const std = @import("std");

const ArrayList = std.ArrayList;
const allocator = std.heap.page_allocator;

pub const compTypeEnumCount: comptime u32 = @typeInfo(EComponentType).Enum.fields.len;
pub const EComponentType = enum {
    Health,
    Input,
    Movement,
    Scene,
    Transform,
    Physics,
};

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
        m_compData: ArrayList(ComponentDataPair(compType)) = ArrayList(ComponentDataPair(compType)).init(allocator),

        pub fn GetComp(self: *ComponentDataArray(compType), id: u16) ?*compType {
            if (id >= self.m_compData.len) {
                return null;
            } else {
                return &self.m_compData.items[id].m_data;
            }
        }

        pub fn GetOwnerId(self: *ComponentDataArray(compType), id: u16) ?u32 {
            if (id >= self.m_compData.len) {
                return null;
            } else {
                return self.m_compData.items[id].m_ownerEid;
            }
        }

        pub fn AddComp(self: *ComponentDataArray(compType), owner: u32) u16 {
            self.m_compData.append(ComponentDataPair(compType){ .m_ownerEid = owner }) catch |err| {
                @panic("Could not add new component to array.");
            };
            const addedCompId = @intCast(u16, self.m_compData.len - 1);
            //TODO add compId to entity's m_componentIds
            return addedCompId;
        }
    };
}

pub const ComponentManager = struct {
    m_healthCompData: ComponentDataArray(HealthComp) = ComponentDataArray(HealthComp){},
    m_inputCompData: ComponentDataArray(InputComp) = ComponentDataArray(InputComp){},
    m_movementCompData: ComponentDataArray(MovementComp) = ComponentDataArray(MovementComp){},
    m_sceneCompData: ComponentDataArray(SceneComp) = ComponentDataArray(SceneComp){},
    m_transformCompData: ComponentDataArray(TransformComp) = ComponentDataArray(TransformComp){},
    m_physicsCompData: ComponentDataArray(PhysicsComp) = ComponentDataArray(PhysicsComp){},

    pub fn Initialize() ComponentManager {
        return ComponentManager{};
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
    pub fn GetComponent(self: *ComponentManager, comptime compType: type, compID: u16) ?*compType {
        return self.SwitchOnCompType(compType).GetComp(compID);
    }

    pub fn GetComponentOwnerId(self: *ComponentManager, comptime compType: type, compID: u16) ?u32 {
        return self.SwitchOnCompType(compType).GetOwnerId(compID);
    }

    // returns componentID
    pub fn AddComponent(self: *ComponentManager, comptime compType: type, ownerEid: u32) u16 {
        return self.SwitchOnCompType(compType).AddComp(ownerEid);
    }
};
