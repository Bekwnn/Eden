#version 460

layout(set = 2, binding = 1) uniform sampler2D texSampler;

layout(location = 0) in vec2 fragTexCoord;

layout(location = 0) out vec4 outColor;

void main()
{
    //outColor = vec4(0.8, 0.8, 0.8, 1.0);
    outColor = texture(texSampler, fragTexCoord);
}
