const Buffer = @This();

ptr: *anyopaque,
vtable: VTable,

pub const VTable = struct {};

pub const Desc = struct {
    size: usize,
    usage: UsageFlags,
};

// zig fmt: off
pub const UsageFlags = enum(u32) {
    TransferSrcBit          = 0x00000001,
    TransferDstBit          = 0x00000002,
    UniformTexelBufferBit   = 0x00000004,
    StorageTexelBufferBit   = 0x00000008,
    UniformBufferBit        = 0x00000010,
    StorageBufferBit        = 0x00000020,
    IndexBufferBit          = 0x00000040,
    VertexBufferBit         = 0x00000080,
    IndirectBufferBit       = 0x00000100,
};
// zig fmt: on
