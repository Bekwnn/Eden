const std = @import("std");
const fs = std.fs;
const path = fs.path;

const filePathUtils = @import("src/coreutil/FilePathUtils.zig");

fn deleteOldDll(dllNameExt: []const u8) !void {
    // delete existing dll if it's there
    const workingDir = fs.cwd();
    var binDir = try workingDir.openDir("zig-out", .{});
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
    var dstPath = try workingDir.openDir("zig-out", .{});
    dstPath = try dstPath.openDir("bin", .{});
    return dstPath;
}

// Copy files to zig-out/bin
fn copyDllToBin(comptime dllDir: []const []const u8, comptime dllName: []const u8) !void {
    const dllNameExt = dllName ++ ".dll";

    deleteOldDll(dllNameExt) catch { // this is allowed to fail
        // make dir if it doesn't exist
        const workingDir = fs.cwd();
        workingDir.makeDir("zig-out") catch {}; // may already exist
        var cacheDir = try workingDir.openDir("zig-out", .{});
        cacheDir.makeDir("bin") catch {}; // may already exist
    };

    const srcPath = openDllSrcDir(dllDir) catch |e| {
        std.debug.print("Unable to resolve src path\n", .{});
        return e;
    };
    const dstPath = openDllDstDir() catch |e| {
        std.debug.print("Unable to resolve dst path\n", .{});
        return e;
    };
    srcPath.copyFile(dllNameExt, dstPath, dllNameExt, .{}) catch |e| {
        std.debug.print("Unable to copy file from {} to {}\n", .{ srcPath, dstPath });
        return e;
    };
}

const ShaderCleanError = error{
    Delete,
    Remake,
};
fn cleanCompiledShaders() !void {
    const cwdDir = fs.cwd();

    // delete entire compiled dir and remake
    cwdDir.deleteTree(compiledShaderDirName) catch return ShaderCleanError.Delete;
    cwdDir.makeDir(compiledShaderDirName) catch return ShaderCleanError.Remake;
}

const shaderDirName = "src\\shaders";
const compiledShaderDirName = "src\\shaders\\compiled"; //TODO: output shaders to build location/bin?

// ex usage: buildVKShaders(b, exe, "oceanshader", "vert");
// will compile "shaders/oceanshader.vert" to "shaders/compiled/oceanshader-vert.spv"
fn buildVKShaders(b: *std.Build, exe: anytype, shaderName: []const u8, shaderExt: []const u8) !void {

    // TODO iterate over shaders directory and compile
    // .vert .frag .geom .tesc .tese .comp
    // to shaders/compiled .spv automatically (shaders/compiled should be skipped)

    // TODO if a shader has a compile error, replace it with an error shader that renders all pink

    // TODO create a directory for excluded shaders which are not compiled; it will allow for you to have wip shaders or to move shaders which currently have errors/bugs

    // For now, call this per file
    var inFileName = std.ArrayList(u8).init(b.allocator);
    try inFileName.appendSlice(shaderName);
    try inFileName.appendSlice(".");
    try inFileName.appendSlice(shaderExt);

    const compiledExt = ".spv";
    var outFileName = std.ArrayList(u8).init(b.allocator);
    try outFileName.appendSlice(shaderName);
    try outFileName.appendSlice("-");
    try outFileName.appendSlice(shaderExt);
    try outFileName.appendSlice(compiledExt);

    const relativeIn = try path.join(b.allocator, &[_][]const u8{ shaderDirName, inFileName.items });
    const relativeOut = try path.join(b.allocator, &[_][]const u8{ compiledShaderDirName, outFileName.items });

    // example glslc usage: glslc -o oceanshader-vert.spv oceanshader.vert
    const glslc_cmd = b.addSystemCommand(&[_][]const u8{
        "glslc",
        "-o",
        relativeOut,
        relativeIn,
    });
    exe.step.dependOn(&glslc_cmd.step);
}

const BuildConfig = struct {
    VulkanPath: []u8,
    VerboseBuild: bool,
    OptimizationMode: []u8,
};

fn LoadBuildConfig(b: *std.Build, configFileName: []const u8) !BuildConfig {
    const buildConfigFile = try std.fs.cwd().openFile(configFileName, .{});
    defer buildConfigFile.close();

    const buildConfigContents = try buildConfigFile.readToEndAlloc(b.allocator, 4096); //arbitrary max file size
    defer b.allocator.free(buildConfigContents);

    const parsedBuildConfig = try std.json.parseFromSlice(BuildConfig, b.allocator, buildConfigContents, .{});
    return parsedBuildConfig.value;
}

fn GetVulkanRootPath(b: *std.Build, buildConfig: *const BuildConfig) ![]const u8 {
    const buffer = try b.allocator.alloc(u8, buildConfig.VulkanPath.len);
    const configVulkanPathLower = std.ascii.lowerString(buffer, buildConfig.VulkanPath);
    if (!std.mem.eql(u8, configVulkanPathLower, "default")) {
        return buildConfig.VulkanPath;
    } else {
        // If build config just has "default" instead of a path, we have to dig it up ourselves. Assumes default install location
        // TODO: non-windows maybe
        var dir: std.fs.Dir = try std.fs.openDirAbsolute("C:/VulkanSDK", .{ .iterate = true });
        defer dir.close();

        std.debug.print("Vulkan dirs found:\n", .{});

        var dirIter = dir.iterate();
        var newestVulkanDir: ?[]const u8 = null;
        while (try dirIter.next()) |entry| {
            if (entry.kind == .directory) {
                std.debug.print("{s}\n", .{entry.name});
                if (newestVulkanDir == null) {
                    newestVulkanDir = b.dupe(entry.name);
                } else {
                    if (std.mem.order(u8, newestVulkanDir.?, entry.name) == .lt) {
                        // not a great pattern, would be better to alloc a single buffer
                        b.allocator.free(newestVulkanDir.?);
                        newestVulkanDir = b.dupe(entry.name);
                    }
                }
            }
        }

        if (newestVulkanDir == null) {
            const VulkanPathError = error{DefaultRootPathNotFound};
            return VulkanPathError.DefaultRootPathNotFound;
        } else {
            return dir.realpathAlloc(b.allocator, newestVulkanDir.?);
        }
    }
}

pub fn build(b: *std.Build) !void {
    const buildConfigFileName = b.option(
        []const u8,
        "configFile",
        "Specify a build config file. Default searches for \"DefaultBuildConfig.json\". Any build config json files in root will be ignored by git tracking.",
    ) orelse "DefaultBuildConfig.json";
    const buildConfig = try LoadBuildConfig(b, buildConfigFileName);

    const isDebug = true;
    const optimizationMode = b.standardOptimizeOption(.{});
    const targetOptions = b.standardTargetOptions(.{});
    const exe = b.addExecutable(.{
        .name = "sdl-zig-demo",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimizationMode,
        .target = targetOptions,
    });

    exe.setVerboseLink(buildConfig.VerboseBuild);
    exe.setVerboseCC(buildConfig.VerboseBuild);

    exe.addIncludePath(b.path("dependency"));

    exe.linkSystemLibrary("c");

    const vulkanRootPath = try GetVulkanRootPath(b, &buildConfig);
    std.debug.print("Chosen Vulkan dir:\n{s}\n", .{vulkanRootPath});
    const vulkanPathLib = try std.fmt.allocPrint(b.allocator, "{s}/Lib", .{vulkanRootPath});
    exe.addLibraryPath(.{
        .cwd_relative = vulkanPathLib,
    });
    exe.linkSystemLibrary("vulkan-1");

    const vulkanPathInclude = try std.fmt.allocPrint(b.allocator, "{s}/Include", .{vulkanRootPath});
    exe.addIncludePath(.{
        .cwd_relative = vulkanPathInclude,
    });

    exe.addIncludePath(b.path("src"));

    //exe.addIncludeDir("dependency/cimgui");
    //exe.addIncludeDir("dependency/cimgui/imgui");
    //exe.addIncludeDir("dependency/cimgui/imgui/examples");
    //const imgui_flags = &[_][]const u8{
    //    "-std=c++17",
    //    "-Wno-return-type-c-linkage",
    //    "-fno-exceptions",
    //    "-DIMGUI_STATIC=yes",
    //    "-fno-threadsafe-statics",
    //    "-fno-rtti",
    //    "-Wno-pragma-pack",
    //};
    //exe.addCSourceFile("dependency/cimgui/cimgui.cpp", imgui_flags);
    //exe.addCSourceFile("dependency/cimgui/imgui/imgui.cpp", imgui_flags);
    //exe.addCSourceFile("dependency/cimgui/imgui/imgui_demo.cpp", imgui_flags);
    //exe.addCSourceFile("dependency/cimgui/imgui/imgui_draw.cpp", imgui_flags);
    //exe.addCSourceFile("dependency/cimgui/imgui/imgui_widgets.cpp", imgui_flags);
    //exe.addCSourceFile("dependency/cimgui/imgui/examples/imgui_impl_sdl.cpp", imgui_flags);
    //exe.addCSourceFile("dependency/cimgui/imgui/examples/imgui_impl_vulkan.cpp", imgui_flags);

    exe.addIncludePath(b.path("dependency/SDL2/include"));
    exe.addLibraryPath(b.path("dependency/SDL2/lib/x64"));
    exe.linkSystemLibrary("SDL2");

    //TODO this might be automatic now with newer zig? (0.13.0+)
    const sdl2DllPath = &[_][]const u8{ "dependency", "SDL2", "lib", "x64" };
    copyDllToBin(sdl2DllPath, "SDL2") catch |e| {
        std.debug.print("Could not copy SDL2.dll, {}\n", .{e});
        @panic("Build failure.");
    };

    exe.addIncludePath(b.path("dependency/assimp/include"));
    exe.linkSystemLibrary("assimp-vc142-mt");
    if (isDebug) {
        exe.addLibraryPath(b.path("dependency/assimp/lib/RelWithDebInfo"));
    } else {
        exe.addLibraryPath(b.path("dependency/assimp/lib/Release"));
    }
    const assimpDllPath = if (isDebug) &[_][]const u8{ "dependency", "assimp", "bin", "RelWithDebInfo" } else &[_][]const u8{ "dependency", "assimp", "bin", "Release" };
    copyDllToBin(assimpDllPath, "assimp-vc142-mt") catch |e| {
        std.debug.print("Could not copy assimp-vc142-mt.dll, {}\n", .{e});
        @panic("Build failure.");
    };

    exe.addIncludePath(b.path("dependency/stb"));
    const stb_flags = &[_][]const u8{
        "-std=c17",
    };
    exe.addCSourceFile(.{
        .file = b.path("dependency/stb/stb_image_impl.c"),
        .flags = stb_flags,
    });

    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");

    b.installArtifact(exe);

    const run_exe_cmd = b.addRunArtifact(exe);
    run_exe_cmd.step.dependOn(b.getInstallStep());

    const run_exe_step = b.step("run", "Run the demo");
    run_exe_step.dependOn(&run_exe_cmd.step);

    try cleanCompiledShaders();
    try buildVKShaders(b, exe, "basic_mesh", "vert");
    try buildVKShaders(b, exe, "basic_mesh", "frag");
}
