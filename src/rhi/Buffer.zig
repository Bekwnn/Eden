const Buffer = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    deinit: *const fn (ctx: *anyopaque) void,
    size: *const fn (ctx: *anyopaque) usize,
    usage: *const fn (ctx: *anyopaque) Usage,

    map: *const fn (ctx: *anyopaque, offset: usize, length: usize) BufferError![]u8,
    unmap: *const fn (ctx: *anyopaque) void,

    read: *const fn (ctx: *anyopaque, offset: usize, data: []const u8) BufferError!void,
    write: *const fn (ctx: *anyopaque, offset: usize, data: []const u8) BufferError!void,
};

pub const BufferError = error{
    FailedToMap,
    FailedToRead,
    FailedToWrite,
};

pub const Usage = packed struct {
    uniform: bool = false,
    storage: bool = false,
    index: bool = false,
    vertex: bool = false,
    indirect: bool = false,

    cpu_read: bool = false,
    cpu_write: bool = false,
};

pub const MemoryProperties = packed struct {};

pub fn deinit(self: Buffer) void {
    self.vtable.deinit(self.ptr);
}

pub fn size(self: Buffer) usize {
    return self.vtable.size(self.ptr);
}

pub fn usage(self: Buffer) Usage {
    return self.vtable.usage(self.ptr);
}

pub fn map(self: Buffer, offset: usize, length: usize) BufferError![]u8 {
    return self.vtable.map(self.ptr, offset, length);
}

pub fn unmap(self: Buffer) void {
    self.vtable.unmap(self.ptr);
}

pub fn read(self: Buffer, offset: usize, destination: []u8) BufferError!void {
    return self.vtable.read(self.ptr, offset, destination);
}

pub fn write(self: Buffer, offset: usize, data: []const u8) BufferError!void {
    return self.vtable.write(self.ptr, offset, data);
}
