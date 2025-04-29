pub usingnamespace @cImport({
    //Vulkan
    @cInclude("vulkan/vulkan.h");

    //SDL
    @cInclude("SDL.h");
    @cInclude("SDL_Vulkan.h");

    //IMGUI
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cDefine("CIMGUI_USE_VULKAN", {});
    @cDefine("CIMGUI_USE_SDL2", {});
    @cInclude("cimgui/cimgui.h");
    @cInclude("cimgui/cimgui_impl.h");

    //Assimp
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");

    //Cgltf
    // TODO disabled currently
    //@cDefine("CGLTF_IMPLEMENTATION", {});
    //@cInclude("cgltf/cgltf.h");

    //vma (testing; not in use)
    //@cInclude("vma/vk_mem_alloc.h");

    //stb
    @cDefine("STBI_IMAGE_IMPLEMENTATION", {});
    @cDefine("STBI_NO_PNG", {});
    //@cDefine("STBI_NO_STDIO", {});
    @cInclude("stb_image.h");
});
