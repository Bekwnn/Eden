#version 460

layout(std140, set = 0, binding = 0) uniform mvp_data {
    mat4 view;
    mat4 projection;
    mat4 viewProjection;
};

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;

void main()
{
    gl_Position = viewProjection * vec4(vertexPosition, 1.0);
}
