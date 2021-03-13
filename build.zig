const std = @import("std");
const buildns = std.build;
const fs = std.fs;
const Builder = buildns.Builder;
const Version = buildns.Version;

fn deleteOldDll(dllNameExt: []const u8) !void {
    // delete existing dll if it's there
    const workingDir = fs.cwd();
    var binDir = try workingDir.openDir("zig-cache", .{});
    binDir = try binDir.openDir("bin", .{});
    try binDir.deleteFile(dllNameExt);
}

fn openDllSrcDir(comptime dllDir: []const []const u8) !fs.Dir {
    var srcPath = fs.cwd();
    for (dllDir) |dir| {
        srcPath = try srcPath.openDir(dir, .{});
    }
    return srcPath;
}

fn openDllDstDir() !fs.Dir {
    const workingDir = fs.cwd();
    var dstPath = try workingDir.openDir("zig-cache", .{});
    dstPath = try dstPath.openDir("bin", .{});
    return dstPath;
}

fn copyDllToBin(comptime dllDir: []const []const u8, comptime dllName: []const u8) !void {
    // Copy files to zig-cache/bin
    const dllNameExt = dllName ++ ".dll";

    deleteOldDll(dllNameExt) catch |e| { // this is allowed to fail
        // make dir if it doesn't exist
        const workingDir = fs.cwd();
        workingDir.makeDir("zig-cache") catch |e2| {}; // may already exist
        var cacheDir = try workingDir.openDir("zig-cache", .{});
        cacheDir.makeDir("bin") catch |e2| {}; // may already exist
    };

    const srcPath = openDllSrcDir(dllDir) catch |e| {
        std.debug.warn("Unable to resolve src path\n", .{});
        return e;
    };
    const dstPath = openDllDstDir() catch |e| {
        std.debug.warn("Unable to resolve dst path\n", .{});
        return e;
    };
    srcPath.copyFile(dllNameExt, dstPath, dllNameExt, .{}) catch |e| {
        std.debug.warn("Unable to copy file from {} to {}\n", .{ srcPath, dstPath });
        return e;
    };
}

pub fn build(b: *Builder) void {
    const isDebug = false;
    const mode = if (isDebug) std.builtin.Mode.Debug else b.standardReleaseOptions();
    const exe = b.addExecutable("sdl-zig-demo", "src/main.zig");
    exe.setBuildMode(mode);

    // would be nice to run the makefile for cimgui if it hasn't been run. . .

    // for build debugging
    //exe.setVerboseLink(true);
    //exe.setVerboseCC(true);

    const wkdir = "F:/Dev-Demos-and-Content/Zig/Eden/";

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("opengl32");

    exe.addIncludeDir("src");

    exe.addIncludeDir("dependency/glew-2.1.0/include");
    exe.addLibPath("dependency/glew-2.1.0/lib/Release/x64");
    exe.linkSystemLibrary("glew32s"); //only include 1 of the 2 glew libs

    exe.addIncludeDir("dependency/cimgui");
    exe.addIncludeDir("dependency/cimgui/imgui");
    exe.addIncludeDir("dependency/cimgui/imgui/examples");
    const imgui_flags = &[_][]const u8{
        "-std=c++17",
        "-Wno-return-type-c-linkage",
        "-DIMGUI_IMPL_OPENGL_LOADER_GLEW=1",
        "-fno-exceptions",
        "-fno-rtti",
        "-Wno-pragma-pack",
    };
    exe.addCSourceFile("dependency/cimgui/cimgui.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/imgui.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/imgui_demo.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/imgui_draw.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/imgui_widgets.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/examples/imgui_impl_sdl.cpp", imgui_flags);
    exe.addCSourceFile("dependency/cimgui/imgui/examples/imgui_impl_opengl3.cpp", imgui_flags);

    exe.addIncludeDir("dependency/SDL2/include");
    exe.addLibPath("dependency/SDL2/lib/x64");
    exe.linkSystemLibrary("SDL2");
    const sdl2DllPath = &[_][]const u8{ "dependency", "SDL2", "lib", "x64" };
    copyDllToBin(sdl2DllPath, "SDL2") catch |e| {
        std.debug.warn("Could not copy SDL2.dll, {}\n", .{e});
        @panic("Build failure.");
    };

    exe.addIncludeDir("dependency/assimp/include");
    exe.linkSystemLibrary("assimp-vc142-mt");
    if (isDebug) {
        exe.addLibPath("dependency/assimp/lib/RelWithDebInfo");
    } else {
        exe.addLibPath("dependency/assimp/lib/Release");
    }
    const assimpDllPath = if (isDebug) &[_][]const u8{ "dependency", "assimp", "bin", "RelWithDebInfo" } else &[_][]const u8{ "dependency", "assimp", "bin", "Release" };
    copyDllToBin(assimpDllPath, "assimp-vc142-mt") catch |e| {
        std.debug.warn("Could not copy assimp-vc142-mt.dll, {}\n", .{e});
        @panic("Build failure.");
    };

    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");

    exe.install();

    const run_exe_cmd = exe.run();
    run_exe_cmd.step.dependOn(b.getInstallStep());

    const run_exe_step = b.step("run", "Run the demo");
    run_exe_step.dependOn(&run_exe_cmd.step);
}
