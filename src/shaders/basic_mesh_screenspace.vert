#version 460

//layout(push_constant, std430) uniform model {
//    mat4 model;
//};

layout(binding = 0, std140) uniform mvp_data {
    mat4 view;
    mat4 projection;
    mat4 viewProjection;
};

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;
layout(location = 2) in vec2 vertexTexCoord;

void main()
{
    gl_position = viewProjection * vec4(vertexPosition, 1.0);

    gl_Position.y = -gl_Position.y;
}
