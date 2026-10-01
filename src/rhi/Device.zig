const std = @import("std");
const c = @import("../c.zig").cLib;
const Buffer = @import("Buffer.zig");

const Device = @This();

pub const VTable = struct {
    init: *const fn (
        allocator: std.mem.Allocator,
        window: *c.SDL_Window,
        application_name: []const u8,
        application_version: u32,
    ) DeviceError!Device,

    deinit: *const fn (
        device: *Device,
    ) void,

    create_buffer: *const fn (
        device: *Device,
        size: c.VkDeviceSize,
        usage: Buffer.Usage,
        //memory_properties: MemoryProperties,
    ) DeviceError!Buffer,

    destroy_buffer: *const fn (
        device: *Device,
        buffer: *Buffer,
    ) void,

    copy_buffer: *const fn (
        device: *Device,
        source: *Buffer,
        destination: *Buffer,
    ) DeviceError!void,

    find_memory_type: *const fn (
        device: *Device,
        type_filter: u32,
        //properties: MemoryProperties,
    ) DeviceError!u32,

    wait_idle: *const fn (device: *Device) DeviceError!void,
};

pub const DeviceError = error{};
