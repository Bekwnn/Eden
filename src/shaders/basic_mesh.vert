#version 330 core

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;
layout(location = 2) in vec2 vertexUV;

void main()
{
    gl_Position = vec4(vertexPosition.x * 0.5f, vertexPosition.y * 0.5f, vertexPosition.z * 0.5f, 1.0);
}
