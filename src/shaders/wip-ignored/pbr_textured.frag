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

layout(set = 2, binding = 1) uniform sampler2D texSampler;

layout(std140, set = 2, binding = 2) uniform struct {
    float metallic;
    float specular;
    float roughness;
    //TODO anisotropy amount (requires tangent map asset)
    //TODO ambient occlusion 0 to 1
} PbrData;

layout(location = 0) in vec2 fragTexCoord;

layout(location = 0) out vec4 outColor;

void main()
{
    vec3 baseColor = texture(texSampler, fragTexCoord).xyz;
}
