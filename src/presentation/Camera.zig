const debug = @import("std").debug;
const stdmath = @import("std").math;

const Mat4x4 = @import("../math/Mat4x4.zig").Mat4x4;
const Plane = @import("../math/Plane.zig").Plane;
const Quat = @import("../math/Quat.zig").Quat;
const Vec3 = @import("../math/Vec3.zig").Vec3;

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

    pub fn GetViewMatrix(self: *const Camera) Mat4x4 {
        const forward = self.m_rotation.GetForwardVec();
        const right = self.m_up.Cross(forward).Normalized();
        const upAxis = right.Cross(forward).Normalized(); //differs from m_up
        return Mat4x4{
            .m = [4][4]f32{
                [4]f32{ right.x, right.y, right.z, -right.Dot(self.m_pos) },
                [4]f32{ upAxis.x, upAxis.y, upAxis.z, -upAxis.Dot(self.m_pos) },
                [4]f32{ forward.x, forward.y, forward.z, -forward.Dot(self.m_pos) },
                [4]f32{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
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

    pub const FrustumData = struct {
        m_planes: [6]Plane,

        pub const FrustumPlane = enum {
            Near,
            Far,
            Left,
            Right,
            Top,
            Bottom,
        };
    };

    pub fn GetFrustumData(self: *const Camera) FrustumData {
        const forward: Vec3 = self.m_rotation.GetForwardVec().Negate(); //cam looks in -Z
        const right: Vec3 = self.m_rotation.GetRightVec();
        const up: Vec3 = self.m_rotation.GetUpVec();

        const halfVSide: f32 = self.m_farPlane * @tan(self.m_fovY * 0.5);
        const halfHSide: f32 = halfVSide * self.m_aspectRatio;
        const forwardFarPos: Vec3 = self.m_pos.Add(forward.GetScaled(self.m_farPlane));

        const rightHalfHFovScaled = right.GetScaled(halfHSide);
        const rightNorm = Vec3.Cross(up, forwardFarPos.Add(rightHalfHFovScaled)).Normalized();
        const leftNorm = Vec3.Cross(forwardFarPos.Sub(rightHalfHFovScaled), up).Normalized();

        const upHalfVFovScaled = up.GetScaled(halfVSide);
        const botNorm = Vec3.Cross(right, forwardFarPos.Sub(upHalfVFovScaled)).Normalized();
        const topNorm = Vec3.Cross(forwardFarPos.Add(upHalfVFovScaled), right).Normalized();

        return FrustumData{
            .m_planes = [_]Plane{
                Plane{
                    .m_origin = self.m_pos.Add(forward.GetScaled(self.m_nearPlane)),
                    .m_normal = forward,
                },
                Plane{
                    .m_origin = forwardFarPos,
                    .m_normal = forward.Negate(),
                },
                Plane{
                    .m_origin = self.m_pos,
                    .m_normal = leftNorm,
                },
                Plane{
                    .m_origin = self.m_pos,
                    .m_normal = rightNorm,
                },
                Plane{
                    .m_origin = self.m_pos,
                    .m_normal = topNorm,
                },
                Plane{
                    .m_origin = self.m_pos,
                    .m_normal = botNorm,
                },
            },
        };
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
