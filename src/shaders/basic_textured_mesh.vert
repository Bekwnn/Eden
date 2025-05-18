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

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;
layout(location = 2) in vec2 vertexTexCoord;

layout(location = 0) out vec2 fragTexCoord;

void main()
{
    gl_Position = sceneUbo.viewProjection * vec4(vertexPosition, 1.0);
    fragTexCoord = vertexTexCoord;
}

