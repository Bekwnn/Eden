#version 460

layout(binding = 0, std140) uniform mvp_data {
    mat4 model;
    mat4 view;
    mat4 projection;
};

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;
layout(location = 2) in vec2 vertexTexCoord;

void main()
{
    gl_position = projection * view * model vec4(vertexPosition, 1.0);
}
