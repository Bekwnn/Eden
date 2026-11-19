const BindGroup = @This();

ptr: *anyopaque,
vtable: VTable,

pub const VTable = struct {
    update: *const fn (
        writes: []const WriteDesc,
    ) void,
};

pub const Layout = struct {};

pub const WriteDesc = struct {};

pub const BindType = enum {
    UniformBuffer,
    StorageBuffer,
    SampledTexture,
    Sampler,
};
