//WIP
#version 460

layout(std140, set = 0, binding = 0) uniform SceneData {
    mat4 view;
    mat4 projection;
    mat4 viewProjection;
    vec4 ambientColor;
    vec4 sunDirection; // .w is sun power
    vec4 sunColor;
    vec4 time; //(t/10, t, t*2, t*3)
} sceneUbo;

layout(push_constant) uniform PushConstants {
    mat4 model;
} pushConstants;

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;
layout(location = 2) in vec2 vertexTexCoord;
layout(location = 3) in vec3 vertexTangent;

layout(location = 0) out vec2 fragTexCoord;
layout(location = 1) out vec3 pos;
layout(location = 2) out mat3 TBN;

void main()
{
    pos = pushConstants.model * vec4(vertexPosition, 1.0);
    gl_Position = sceneUbo.viewProjection * pos;
    fragTexCoord = vertexTexCoord;
    vec3 T = normalize(vec3(pushConstants.model * vec4(vertexTangent, 0.0)));
    vec3 B = normalize(vec3(pushConstants.model * vec4(cross(vertexNormal, vertexTangent, 0.0)));
    vec3 N = normalize(vec3(pushConstants.model * vec4(vertexNormal, 0.0)));
    TBN = mat3(T, B, N);
}
