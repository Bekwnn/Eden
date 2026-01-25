const std = @import("std");
const builtin = @import("builtin");

pub var debugAllocator = std.heap.DebugAllocator(.{}).init;
pub const defaultAllocator: std.mem.Allocator = blk: {
    if (builtin.mode == .Debug) {
        break :blk debugAllocator.allocator();
    } else {
        break :blk std.heap.page_allocator;
    }
};

// std.heap.Check is an enum not an error
pub fn deinitDefaultAllocator() void {
    if (builtin.mode == .Debug) {
        const deinitStatus = debugAllocator.deinit();
        if (deinitStatus == .leak) {
            @panic("Memory leak detected in default allocator.");
        }
    }
}
