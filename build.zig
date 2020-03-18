const std = @import("std");
const buildns = std.build;
const fs = std.fs;
const Builder = buildns.Builder;
const Version = buildns.Version;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("sdl-zig-demo", "src/main.zig");
    exe.setBuildMode(mode);

    // would be nice to run the makefile for cimgui if it hasn't been run. . .

    // for build debugging
    //exe.setVerboseLink(true);
    //exe.setVerboseCC(true);

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("opengl32");

    exe.addIncludeDir("src");

    exe.addIncludeDir("dependency/glew-2.1.0/include");
    exe.addLibPath("dependency/glew-2.1.0/lib/Release/x64");
    exe.linkSystemLibrary("glew32s"); //only include 1 of the 2 glew libs

    exe.addIncludeDir("dependency/SDL2/include");
    exe.addLibPath("dependency/SDL2/lib/x64");
    exe.linkSystemLibrary("SDL2");

    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");

    exe.addIncludeDir("dependency/cimgui");
    exe.addIncludeDir("dependency/cimgui/imgui");
    exe.addIncludeDir("dependency/cimgui/imgui/examples");
    const imgui_flags = &[_][]const u8{
        "-std=c++11",
        "-Wno-return-type-c-linkage",
        "-DIMGUI_IMPL_OPENGL_LOADER_GLEW=1",
        "-fno-exceptions",
        "-fno-rtti",
    };
    exe.addCSourceFile("dependency/cimgui/cimgui.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/imgui.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/imgui_demo.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/imgui_draw.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/imgui_widgets.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/examples/imgui_impl_sdl.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/examples/imgui_impl_opengl3.cpp", imgui_flags);

    exe.install();

    const run_exe_cmd = exe.run();
    run_exe_cmd.step.dependOn(b.getInstallStep());

    const run_exe_step = b.step("run", "Run the demo");
    run_exe_step.dependOn(&run_exe_cmd.step);
}
