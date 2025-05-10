const debug = @import("std").debug;
const stdmath = @import("std").math;

const Vec3 = @import("../math/Vec3.zig").Vec3;
const Mat4x4 = @import("../math/Mat4x4.zig").Mat4x4;
const Quat = @import("../math/Quat.zig").Quat;

const defaultAspect: f32 = 16.0 / 9.0; //16:9 //TODO initialize perspective
const defaultAspectInv: f32 = 1.0 / defaultAspect;
const defaultYFoV: f32 = 70.0 * stdmath.rad_per_deg * defaultAspectInv;

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

    pub fn GetViewMatrix(self: *const Camera) !Mat4x4 {
        //TODO this is not at all efficient, instead manually create the view matrix
        const cameraTranslation = Mat4x4.Translation(self.m_pos);
        //return cameraTranslation.Inverse() catch @panic("!");
        const cameraRotation = Mat4x4.FromQuat(self.m_rotation);
        const cameraModelMat = cameraTranslation.Mul(&cameraRotation);
        return cameraModelMat.Inverse() catch @panic("!");
    }

    pub fn GetProjectionMatrix(self: *const Camera) Mat4x4 {
        const tanHalfFoVY = @tan(self.m_fovY * 0.5);
        var perspectiveMat = Mat4x4.zero;
        perspectiveMat.m[0][0] = 1.0 / (tanHalfFoVY * self.m_aspectRatio);
        perspectiveMat.m[1][1] = 1.0 / tanHalfFoVY;
        perspectiveMat.m[2][2] = -(self.m_farPlane + self.m_nearPlane) / (self.m_farPlane - self.m_nearPlane);
        perspectiveMat.m[2][3] = -(2.0 * self.m_farPlane * self.m_nearPlane) / (self.m_farPlane - self.m_nearPlane);
        perspectiveMat.m[3][2] = -1.0;
        return perspectiveMat;
    }

    // untested
    pub fn GetOrthoMatrix(self: *const Camera, left: f32, right: f32, bottom: f32, top: f32) Mat4x4 {
        var orthoMat = Mat4x4.identity;
        orthoMat.m[0][0] = 2.0 / (right - left);
        orthoMat.m[1][1] = 2.0 / (top - bottom);
        orthoMat.m[2][2] = 1.0 / (self.m_farPlane - self.m_nearPlane);
        orthoMat.m[3][0] = -(right + left) / (right - left);
        orthoMat.m[3][1] = -(top + bottom) / (top - bottom);
        orthoMat.m[3][2] = self.m_nearPlane / (self.m_nearPlane - self.m_farPlane);
        return orthoMat;
    }

    // multiply clip.Mul(proj) to convert from opengl style clip space to vulkan style clip space
    pub const gl2VkClipSpace = Mat4x4{
        .m = [4][4]f32{
            [4]f32{ 1.0, 0.0, 0.0, 0.0 },
            [4]f32{ 0.0, -1.0, 0.0, 0.0 },
            [4]f32{ 0.0, 0.0, 0.5, 0.5 },
            [4]f32{ 0.0, 0.0, 0.0, 1.0 },
        },
    };

    // takes radians, gives radians
    pub fn XFoVToYFoV(xFoV: f32, aspectRatio: f32) f32 {
        return 2.0 * stdmath.atan(@tan(xFoV * 0.5) * aspectRatio);
    }

    pub fn LookAt(self: *Camera, target: Vec3) void {
        //self.m_rotation = Quat.LookAt(target.Sub(self.m_pos));
        self.m_rotation = Quat.LookAt(self.m_pos.Sub(target));
    }
};
