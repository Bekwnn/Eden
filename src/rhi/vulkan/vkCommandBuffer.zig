const CommandBuffer = @import("../CommandBuffer.zig");

pub const vtable: CommandBuffer.VTable = .{
    .begin = ,
    .end = ,

    .begin_rendering = ,
    .end_rendering = ,

    .bind_pipeline = ,
    .bind_descriptors = ,
    .bind_buffers = ,
    .copy_buffer = ,

    .draw = ,
    .draw_indexed = ,
    .dispatch = ,
};
