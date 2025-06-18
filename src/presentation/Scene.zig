const std = @import("std");
const c = @import("../c.zig");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

const Camera = @import("Camera.zig").Camera;
const RenderObject = @import("RenderObject.zig").RenderObject;
const renderContext = @import("RenderContext.zig");
const RenderContext = @import("RenderContext.zig").RenderContext;

const mat4x4 = @import("../math/Mat4x4.zig");
const Mat4x4 = mat4x4.Mat4x4;
const Vec4 = @import("../math/Vec4.zig").Vec4;

pub const CameraError = error{
    NoCurrent,
    FailedToSet,
};

//TODO move probably
pub const GPUSceneData = struct {
    m_view: Mat4x4,
    m_projection: Mat4x4,
    m_viewProj: Mat4x4,
    m_ambientColor: Vec4,
    m_sunDirection: Vec4, // .w is sun power
    m_sunColor: Vec4,
    m_time: Vec4, //(t/10, t, t*2, t*3)

    pub fn CreateTimeVec(time: f32) Vec4 {
        return Vec4{
            .x = time * 0.1,
            .y = time,
            .z = time * 2.0,
            .w = time * 3.0,
        };
    }
};

pub const Scene = struct {
    const Self = @This();
    pub const RenderableContainer = StringHashMap(RenderObject);
    pub const RenderableIter = RenderableContainer.Iterator;
    pub const RenderableEntry = RenderableContainer.Entry;

    //TODO init and take an allocator instead?
    m_cameras: StringHashMap(Camera) = StringHashMap(Camera).init(allocator),
    m_renderables: RenderableContainer = RenderableContainer.init(allocator),

    m_currentCamera: ?*Camera = null,
    m_defaultCamera: ?*Camera = null,

    pub fn CreateCamera(self: *Self, name: []const u8) !void {
        try self.m_cameras.put(name, Camera{});
        if (self.m_currentCamera == null) {
            self.m_currentCamera = self.m_cameras.getPtr(name);
        }
        if (self.m_defaultCamera == null) {
            self.m_defaultCamera = self.m_cameras.getPtr(name);
        }
    }

    pub fn GetCurrentCamera(self: *Self) !*Camera {
        return self.m_currentCamera orelse CameraError.NoCurrent;
    }

    pub fn GetCamera(self: *Self, name: []const u8) ?*Camera {
        return self.m_cameras.get(name);
    }

    pub fn SetDefaultCamera(self: *Self, name: []const u8) !void {
        var newDefault = self.m_cameras.getPtr(name);
        if (newDefault == null) {
            return CameraError.FailedToSet;
        } else {
            self.m_defaultCamera = &newDefault;
        }
    }

    pub fn SetCurrentCamera(self: *Self, name: []const u8) !void {
        var newCurrent = self.m_cameras.getPtr(name);
        if (newCurrent == null) {
            return CameraError.FailedToSet;
        } else {
            self.m_currentCamera = &newCurrent;
        }
    }
};
