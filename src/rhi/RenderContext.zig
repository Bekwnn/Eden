const Context = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    getInstance: *const fn (ctx: *anyopaque) void,
    init: *const fn (ctx: *anyopaque) void,
    deinit: *const fn (ctx: *anyopaque) void,
};

pub const RenderContextError = error{};
