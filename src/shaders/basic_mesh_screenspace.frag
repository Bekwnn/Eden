#version 460

layout(binding = 1) uniform sampler2D texSampler;

layout(location = 0) out vec4 outColor;

void main()
{
    outColor = texture(texSampler, /*???*/);
}
