pub usingnamespace @cImport({
    //Glew
    @cInclude("GL/glewmodified.h"); // macro functions aren't supported, see https://github.com/ziglang/zig/issues/1085

    //SDL
    @cInclude("SDL.h");

    //IMGUI
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");
    @cDefine("IMGUI_IMPL_API", {});
    @cDefine("IMGUI_IMPL_OPENGL_LOADER_GLEW", {});
    @cInclude("imgui_impl_sdl.h");
    @cInclude("imgui_impl_opengl3.h");

    //Assimp
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");

    //stb
    @cDefine("STBI_IMAGE_IMPLEMENTATION", {});
    @cDefine("STBI_NO_PNG", {});
    //@cDefine("STBI_NO_STDIO", {});
    @cInclude("stb_image.h");
});
