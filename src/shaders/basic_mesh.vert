#version 460

layout(binding = 0, std140) uniform mvp_data {
    mat4 model;
    mat4 view;
    mat4 projection;
};

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;
layout(location = 2) in vec2 vertexTexCoord;

layout(location = 0) out vec2 fragTexCoord;

void main()
{
    gl_Position = projection * view * model * vec4(vertexPosition, 1.0);
    fragTexCoord = vertexTexCoord;
}
