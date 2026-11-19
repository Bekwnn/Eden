const std = @import("std");
const c = @import("../c.zig").cLib;
const Buffer = @import("Buffer.zig");

const Device = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const DeviceError = error{};

pub const VTable = struct {
    // consider making window *anyopaque
    // though support for non-SDL isn't planned
    init: *const fn (
        *anyopaque,
        allocator: std.mem.Allocator,
        window: *c.SDL_Window,
        application_name: []const u8,
        application_version: u32,
    ) DeviceError!Device,

    deinit: *const fn (
        *anyopaque,
    ) void,

    create_swapchain: *const fn () void,

    recreate_swapchain: *const fn () void,

    destroy_swapchain: *const fn () void,

    create_fence: *const fn () void,

    destroy_fence: *const fn () void,

    create_semaphore: *const fn () void,

    destroy_semaphore: *const fn () void,

    create_bind_group: *const fn () void,

    destroy_bind_group: *const fn () void,

    create_buffer: *const fn (
        *anyopaque,
        desc: Buffer.Desc,
    ) DeviceError!Buffer,

    destroy_buffer: *const fn (
        *anyopaque,
        buffer: Buffer,
    ) void,

    copy_buffer: *const fn (
        *anyopaque,
        source: Buffer,
        destination: Buffer,
        size: usize,
        srcOffset: usize,
        dstOffset: usize,
    ) DeviceError!void,

    upload_buffer: *const fn (
        *anyopaque,
        source: *Buffer,
        offset: usize,
        data: []const u8,
    ) DeviceError!void,

    create_texture: *const fn () void,

    destroy_texture: *const fn () void,

    create_texture_view: *const fn () void,

    destroy_texture_view: *const fn () void,

    wait_idle: *const fn (
        *anyopaque,
    ) DeviceError!void,
};
