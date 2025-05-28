#version 460

layout(set = 2, binding = 1) uniform Uniform0 {
    vec4 color;
} uniform0; 


layout(location = 0) out vec4 outColor;

void main()
{
    outColor = uniform0.color;
}
