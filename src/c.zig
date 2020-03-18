pub usingnamespace @cImport({
    @cInclude("GL/glewmodified.h"); // macro functions aren't supported in zig 0.5.0, https://github.com/ziglang/zig/issues/1085
    @cInclude("SDL.h");
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");
});
