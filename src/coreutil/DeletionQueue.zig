const std = @import("std");
const ArrayList = std.ArrayList;

//WIP
//can this take something like a lambda or fn ptr & context?
//basically want to use "m_deletionQueue.append(someCleanupFn)" the same way you use "defer someCleanupFn()"
pub const DeletionQueue = struct {
    const Self = @This();

    m_queue: ArrayList(fn () void),

    pub fn append(self: *Self, deleteFn: fn () void) !void {
        try self.m_queue.append(deleteFn);
    }

    pub fn flushQueue(self: *Self) void {
        while (self.m_queue.items.len > 0) {
            const deleteFn = self.m_queue.pop();
            deleteFn();
        }
    }
};
