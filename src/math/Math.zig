// TODO rename to EdenMath.zig
// Public imports of common utils/types

pub const vec3 = @import("Vec3.zig");
pub const Vec3 = vec3.Vec3;
pub const vec2 = @import("Vec2.zig");
pub const Vec2 = vec2.Vec2;
pub const quat = @import("Quat.zig");
pub const Quat = quat.Quat;
pub const mat3x3 = @import("Mat3x3.zig");
pub const Mat3x3 = mat3x3.Mat3x3;
pub const mat4x4 = @import("Mat4x4.zig");
pub const Mat4x4 = mat4x4.Mat4x4;
pub const transform = @import("Transform.zig");
pub const Transform = transform.Transform;

pub const util = @import("MathUtil.zig");
