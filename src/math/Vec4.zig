pub const zero = Vec4{};
pub const one = Vec4{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 };
pub const xAxis = Vec4{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 0.0 };
pub const yAxis = Vec4{ .x = 0.0, .y = 1.0, .z = 0.0, .w = 0.0 };
pub const zAxis = Vec4{ .x = 0.0, .y = 0.0, .z = 1.0, .w = 0.0 };
pub const wAxis = Vec4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 };

pub const Vec4 = packed struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    w: f32 = 0.0,
};
