const Buffer = @import("Buffer.zig").Buffer;

pub const MaterialParam = struct {
    m_data: ?*anyopaque,
    m_dataSize: u32,
    m_buffer: Buffer,
};
