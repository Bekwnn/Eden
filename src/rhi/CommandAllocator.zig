const CommandAllocator = @This();

ptr: *anyopaque,
vtable: VTable,

pub const VTable = struct{
    init: *const fn(),

    deinit: *const fn(),

    allocate: *const fn(),

    free: *const fn(),

    reset: *const fn(),
};
