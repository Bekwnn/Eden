pub fn Array2D(comptime ValType: type, comptime DimsType: type, width: DimsType, height: DimsType) type {
    return struct {
        m_array: [height][width]ValType = undefined,
        m_width: DimsType = width,
        m_height: DimsType = height,

        pub fn Fill(self: *Array2D(ValType, DimsType, height, width), val: ValType) void {
            for (self.m_array) |col, i| {
                for (col) |_, j| {
                    self.m_array[i][j] = val;
                }
            }
        }

        pub fn GetValue(self: *const Array2D(ValType, DimsType, height, width), x: DimsType, y: DimsType) *const ValueType {
            //TODO assert within dims?
            return &m_array[y][x];
        }

        pub fn GetValuePtr(self: *Array2D(ValType, DimsType, height, width), x: DimsType, y: DimsType) *ValueType {
            //TODO assert within dims?
            return &m_array[y][x];
        }

        pub fn SetValue(self: *Array2D(ValType, DimsType, height, width), x: DimsType, y: DimsType, val: ValueType) void {
            m_array[y][x] = val;
        }
    };
}
