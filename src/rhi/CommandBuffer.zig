const CommandBuffer = @This();

ptr: *anyopaque,
vtable: VTable,

pub const VTable = struct {
    begin: *const fn (
        self: *CommandBuffer,
    ) void,

    end: *const fn (
        self: *CommandBuffer,
    ) void,

    begin_rendering: *const fn (
        self: *CommandBuffer,
    ) void,

    end_rendering: *const fn (
        self: *CommandBuffer,
    ) void,

    draw: *const fn (
        self: *CommandBuffer,
    ) void,

    draw_indexed: *const fn (
        self: *CommandBuffer,
    ) void,

    dispatch: *const fn (
        self: *CommandBuffer,
    ) void,

    bind_pipeline: *const fn (
        self: *CommandBuffer,
    ) void,

    bind_buffers: *const fn (
        self: *CommandBuffer,
    ) void,

    bind_descriptors: *const fn (
        self: *CommandBuffer,
    ) void,

    copy_buffer: *const fn (
        self: *CommandBuffer,
    ) void,
};
