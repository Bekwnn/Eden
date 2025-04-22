const debug = @import("std").debug;
const stdmath = @import("std").math;
const mathutil = @import("../math/MathUtil.zig");

const Vec3 = @import("../math/Vec3.zig").Vec3;
const Mat4x4 = @import("../math/Mat4x4.zig").Mat4x4;
const Quat = @import("../math/Quat.zig").Quat;

const defaultAspect: f32 = 16.0 / 9.0; //16:9 //TODO initialize perspective
const defaultYFoV: f32 = 1.353540; // 110 degrees hfov -> 77.55 vfov at 16:9 -> then convert to rad

// 1.0 aspect ratio
//const defaultAspect: comptime f32 = 1.0; //1:1
//const defaultYFoV: comptime f32 = 1.570796; // 90 deg -> convert to rad

pub const Camera = struct {
    m_pos: Vec3 = Vec3.zero,
    m_rotation: Quat = Quat.identity,
    m_up: Vec3 = Vec3.yAxis,

    m_fovY: f32 = defaultYFoV, //110 deg default
    m_aspectRatio: f32 = defaultAspect, //16:9
    m_nearPlane: f32 = 0.1,
    m_farPlane: f32 = 100.0,

    pub fn GetViewMatrix(self: *const Camera) Mat4x4 {
        const viewDirection = Vec3.zAxis.RotatedByQuat(self.m_rotation);
        const lookAtMat = Mat4x4.LookAt(self.m_pos, viewDirection, Vec3.yAxis);
        return lookAtMat;
    }

    pub fn GetProjectionMatrix(self: *const Camera) Mat4x4 {
        var returnMat = Mat4x4.zero;
        const tanHalfFoVY = @tan(self.m_fovY * 0.5);
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
        var returnMat = Mat4x4.identity;
        returnMat.m[0][0] = 2.0 / (right - left);
        returnMat.m[1][1] = 2.0 / (top - bottom);
        returnMat.m[2][2] = 1.0 / (self.m_farPlane - self.m_nearPlane);
        returnMat.m[3][0] = -(right + left) / (right - left);
        returnMat.m[3][1] = -(top + bottom) / (top - bottom);
        returnMat.m[3][2] = -self.m_nearPlane / (self.m_farPlane - self.m_nearPlane);
        return returnMat;
    }

    // takes radians, gives radians
    pub fn XFoVToYFoV(xFoV: f32, aspectRatio: f32) f32 {
        return 2.0 * stdmath.atan(@tan(xFoV * 0.5) * aspectRatio);
    }

    //pub fn LookAt(self: *Camera, target: Vec3) void {
    //
    //}

    pub const FrameUBO = struct {
        m_view: Mat4x4,
        m_projection: Mat4x4,
        m_viewProjection: Mat4x4,

        pub fn CreateFrameUBO(view: Mat4x4, projection: Mat4x4) FrameUBO {
            return FrameUBO{
                .m_view = view,
                .m_projection = projection,
                .m_viewProjection = view.Mul(projection), //TODO order correct?
            };
        }
    };
};
