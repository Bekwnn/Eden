const debug = @import("std").debug;
const stdmath = @import("std").math;
const mathutil = @import("../math/MathUtil.zig");

const vec3 = @import("../math/Vec3.zig");
const mat4x4 = @import("../math/Mat4x4.zig");
const quat = @import("../math/Quat.zig");

const Vec3 = vec3.Vec3;
const Mat4x4 = mat4x4.Mat4x4;
const Quat = quat.Quat;

const defaultAspect: f32 = 16.0 / 9.0; //16:9 //TODO initialize perspective
const defaultYFoV: f32 = 1.353540; // 110 degrees hfov -> 77.55 vfov at 16:9 -> then convert to rad

// 1.0 aspect ratio
//const defaultAspect: comptime f32 = 1.0; //1:1
//const defaultYFoV: comptime f32 = 1.570796; // 90 deg -> convert to rad

pub const Camera = struct {
    m_name: []const u8,

    m_pos: Vec3 = vec3.zero,
    m_rotation: Quat = quat.identity,
    m_up: Vec3 = vec3.yAxis,

    m_fovY: f32 = defaultYFoV, //110 deg default
    m_aspectRatio: f32 = defaultAspect, //16:9
    m_nearPlane: f32 = 0.1,
    m_farPlane: f32 = 100.0,

    pub fn GetViewMatrix(self: *const Camera) Mat4x4 {
        const viewDirection = vec3.zAxis.RotatedByQuat(self.m_rotation);
        var lookAtMat = mat4x4.LookDirMat4x4(self.m_pos, viewDirection, vec3.yAxis);
        return lookAtMat;
    }

    pub fn GetProjectionMatrix(self: *const Camera) Mat4x4 {
        var returnMat = mat4x4.zero;
        const tanHalfFoVY = stdmath.tan(self.m_fovY * 0.5);
        const frustrumDepth = self.m_farPlane - self.m_nearPlane;
        returnMat.m[0][0] = 1.0 / (tanHalfFoVY * self.m_aspectRatio);
        returnMat.m[1][1] = 1.0 / tanHalfFoVY;
        returnMat.m[2][2] = self.m_farPlane / frustrumDepth;
        returnMat.m[2][3] = 1.0;
        returnMat.m[3][2] = -(self.m_farPlane * self.m_nearPlane) / frustrumDepth;
        return returnMat;
    }

    // untested
    pub fn GetOrthoMatrix(self: *const Camera, left: f32, right: f32, bottom: f32, top: f32) Mat4x4 {
        var returnMat = mat4x4.identity;
        returnMat.m[0][0] = 2.0 / (right - left);
        returnMat.m[1][1] = 2.0 / (top - bottom);
        returnMat.m[2][2] = 1.0 / (self.m_farPlane - self.m_nearPlane);
        returnMat.m[3][0] = -(right + left) / (right - left);
        returnMat.m[3][1] = -(top + bottom) / (top - bottom);
        returnMat.m[3][2] = -self.m_nearPlane / (self.m_farPlane - self.m_nearPlane);
        return returnMat;
    }
};

// takes radians, gives radians
pub fn XFoVToYFoV(xFoV: f32, aspectRatio: f32) f32 {
    return 2.0 * stdmath.atan(stdmath.tan(xFoV * 0.5) * aspectRatio);
}
