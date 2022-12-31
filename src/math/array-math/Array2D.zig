const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub fn Array2D(comptime ValType: type, width: usize, height: usize) type {
    const Self = @This();

    return struct {
        m_array: [height][width]ValType = undefined,
        m_width: usize = width,
        m_height: usize = height,

        pub fn Fill(self: *Self, val: ValType) void {
            for (self.m_array) |col, i| {
                for (col) |_, j| {
                    self.m_array[i][j] = val;
                }
            }
        }

        pub fn GetValue(self: *const Self, x: usize, y: usize) *const ValueType {
            //TODO assert within dims?
            return &m_array[y][x];
        }

        pub fn GetValuePtr(self: *Self, x: usize, y: usize) *ValueType {
            //TODO assert within dims?
            return &m_array[y][x];
        }

        pub fn SetValue(self: *Self, x: usize, y: usize, val: ValueType) void {
            m_array[y][x] = val;
        }
    };
}

// Should this just be one ArrayList under the hood?
pub fn ArrayList2D(comptime ValType: type) type {
    return struct {
        const Self = @This();

        m_array: ArrayList(ValType),
        m_width: usize,
        m_height: usize,

        // This resizes and does init, how should it handle resizing after already being initialized
        pub fn Resize(width: usize, height: usize, allocator: *Allocator) !void {
            try m_array.initCapacity(allocator, height);
            try m_array.resize(height);
            for (m_array) |*row| {
                try row.initCapacity(allocator, width);
                try row.resize(width);
            }
            m_width = width;
            m_height = height;
        }

        //TODO
        //pub fn CellIdxToCoords(cellIdx: usize) void {}

        pub fn GetValue(self: *const Self, x: usize, y: usize) *const ValueType {
            //TODO assert within dims?
            return &m_array.items[y * width + x];
        }

        pub fn GetValuePtr(self: *Self, x: usize, y: usize) *ValueType {
            //TODO assert within dims?
            return &m_array.items[y * width + x];
        }

        pub fn SetValue(self: *Self, x: usize, y: usize, val: ValueType) void {
            m_array.items[y * width + x] = val;
        }
    };
}
