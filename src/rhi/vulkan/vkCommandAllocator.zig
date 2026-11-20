const CommandAllocator = @import("../CommandAllocator.zig");

pub const vtable: CommandAllocator.VTable = .{
    .init = ,
    .deinit = ,
    .allocate = ,
    .free = ,
    .reset = ,
}
