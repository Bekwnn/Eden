pub usingnamespace @cImport({
    //SDL
    @cInclude("SDL.h");
    @cInclude("SDL_Vulkan.h");

    //IMGUI
    //@cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    //@cInclude("cimgui.h");
    //@cDefine("IMGUI_IMPL_API", {});
    //@cInclude("imgui_impl_sdl.h");
    //@cInclude("imgui_impl_vulkan.h");

    //Vulkan
    @cInclude("vulkan/vulkan.h");

    //Assimp
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");

    //Cgltf
    @cDefine("CGLTF_IMPLEMENTATION", {});
    @cInclude("cgltf/cgltf.h");

    //stb
    @cDefine("STBI_IMAGE_IMPLEMENTATION", {});
    @cDefine("STBI_NO_PNG", {});
    //@cDefine("STBI_NO_STDIO", {});
    @cInclude("stb_image.h");
});
