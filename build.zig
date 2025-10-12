const std = @import("std");
const ArrayList = std.ArrayList;
const fs = std.fs;
const path = fs.path;

const filePathUtils = @import("src/coreutil/FilePathUtils.zig");

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
const compiledShaderDirName = "src\\shaders\\compiled";

//TODO building shaders should maybe occur as a secondary step since adding system command like this
// results in build failures if the shader doesn't compile. Ideally we want to instead have a runtime
// crash or detect a shader error and use a bright pink error shader material or something.
fn buildAllShaders(b: *std.Build, exe: anytype, shouldDebugLog: bool) !void {
    const cwd = std.fs.cwd();
    var shaderDir = (try cwd.openDir(shaderDirName, std.fs.Dir.OpenOptions{ .iterate = true })).iterate();
    while (try shaderDir.next()) |dirItem| {
        if (dirItem.kind == std.fs.Dir.Entry.Kind.file) {
            // skip vim files
            // TODO would be nice if there was instead some pattern matching .gitignore type file in the directory
            // or a list of valid shader file extensions
            if (std.mem.startsWith(u8, dirItem.name, ".") or std.mem.endsWith(u8, dirItem.name, "~")) {
                continue;
            }

            const relativeIn = try std.fmt.allocPrint(b.allocator, "{s}\\{s}", .{ shaderDirName, dirItem.name });

            const newStrSize = std.mem.replacementSize(u8, dirItem.name, ".", "-");
            const compiledName = try b.allocator.alloc(u8, newStrSize);
            defer b.allocator.free(compiledName);
            _ = std.mem.replace(u8, dirItem.name, ".", "-", compiledName);
            const relativeOut = try std.fmt.allocPrint(
                b.allocator,
                "{s}\\{s}.spv",
                .{ compiledShaderDirName, compiledName },
            );

            if (shouldDebugLog) {
                std.debug.print("relative shader path: {s}\n", .{relativeIn});
                std.debug.print("relative compiled shader path: {s}\n", .{relativeOut});
            }

            // example glslc usage: glslc -o oceanshader-vert.spv oceanshader.vert
            const glslc_cmd = b.addSystemCommand(&[_][]const u8{
                "glslc",
                "-o",
                relativeOut,
                relativeIn,
            });
            exe.step.dependOn(&glslc_cmd.step);
        }
    }
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

fn GetVulkanRootPathAlloc(b: *std.Build, buildConfig: *const BuildConfig) ![]const u8 {
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
        "Specify a build config file. Default searches for \"DefaultBuildConfig.json\". " ++
            "Any build config json files in root will be ignored by git tracking.",
    ) orelse "DefaultBuildConfig.json";
    const buildConfig = try LoadBuildConfig(b, buildConfigFileName);
    const optimizationMode = std.meta.stringToEnum(
        std.builtin.OptimizeMode,
        buildConfig.OptimizationMode,
    ) orelse .Debug;
    std.debug.print("optimizationMode: {any}\n", .{optimizationMode});
    const targetOptions = b.standardTargetOptions(.{});
    const exe = b.addExecutable(.{
        .name = "sdl-zig-demo",
        .version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 },
        .root_module = b.addModule(
            "root_module",
            std.Build.Module.CreateOptions{
                .root_source_file = b.path("src/main.zig"),
                .optimize = optimizationMode,
                .target = targetOptions,
            },
        ),
    });

    exe.setVerboseLink(buildConfig.VerboseBuild);
    exe.setVerboseCC(buildConfig.VerboseBuild);

    exe.root_module.addIncludePath(b.path("dependency"));
    exe.root_module.addIncludePath(b.path("src"));
    exe.root_module.link_libc = true;
    exe.root_module.link_libcpp = true;
    exe.root_module.linkSystemLibrary("user32", .{});
    exe.root_module.linkSystemLibrary("gdi32", .{});

    // --- VULKAN START ---
    const vulkanRootPath = try GetVulkanRootPathAlloc(b, &buildConfig);
    defer b.allocator.free(vulkanRootPath);
    std.debug.print("Chosen Vulkan dir:\n{s}\n", .{vulkanRootPath});
    const vulkanPathLib = try std.fmt.allocPrint(b.allocator, "{s}/Lib", .{vulkanRootPath});
    exe.root_module.addLibraryPath(.{
        .cwd_relative = vulkanPathLib,
    });
    const vulkanPathInclude = try std.fmt.allocPrint(b.allocator, "{s}/Include", .{vulkanRootPath});
    exe.root_module.addIncludePath(.{
        .cwd_relative = vulkanPathInclude,
    });
    exe.root_module.linkSystemLibrary("vulkan-1", .{});
    // --- VULKAN END ---

    // copies dlls to the build cache, which then get copied to the output.
    // Allows the copying process to be cached.
    const dll_wfs = b.addNamedWriteFiles("dll-copying");

    // --- SDL START ---
    _ = dll_wfs.addCopyFile(b.path("dependency/SDL2/lib/x64/SDL2.dll"), "SDL2.dll");
    exe.root_module.addIncludePath(b.path("dependency/SDL2/include"));
    exe.root_module.addLibraryPath(b.path("dependency/SDL2/lib/x64"));
    exe.root_module.linkSystemLibrary("SDL2", .{});
    // --- SDL END ---

    // --- IMGUI START ---
    const imgui_lib = b.addLibrary(.{
        .name = "cimgui",
        .linkage = .static,
        .root_module = b.addModule(
            "ImGui_root_module",
            .{
                .optimize = optimizationMode,
                .target = targetOptions,
            },
        ),
    });
    imgui_lib.root_module.addIncludePath(b.path("dependency/cimgui/"));
    imgui_lib.root_module.addIncludePath(b.path("dependency/cimgui/imgui/"));
    imgui_lib.root_module.addIncludePath(b.path("dependency/cimgui/imgui/backends/"));
    imgui_lib.root_module.addIncludePath(b.path("dependency/SDL2/include/"));
    imgui_lib.root_module.link_libc = true;
    imgui_lib.root_module.link_libcpp = true;
    imgui_lib.root_module.linkSystemLibrary("vulkan-1", .{});
    imgui_lib.root_module.addCSourceFiles(.{
        .files = &.{
            "dependency/cimgui/cimgui.cpp",
            "dependency/cimgui/cimgui_impl.cpp",
            "dependency/cimgui/imgui/imgui.cpp",
            "dependency/cimgui/imgui/imgui_demo.cpp",
            "dependency/cimgui/imgui/imgui_draw.cpp",
            "dependency/cimgui/imgui/imgui_tables.cpp",
            "dependency/cimgui/imgui/imgui_widgets.cpp",
            "dependency/cimgui/imgui/backends/imgui_impl_sdl2.cpp",
            "dependency/cimgui/imgui/backends/imgui_impl_vulkan.cpp",
        },
        .flags = &[_][]const u8{
            "-std=c++17",
            "-fno-rtti",
            "-fno-threadsafe-statics",
            "-fno-exceptions",
            "-fno-sanitize=undefined",
            "-DIMGUI_STATIC=yes",
            "-DIMGUI_IMPL_API=extern \"C\"",
            "-Wno-return-type-c-linkage",
            "-Wno-pragma-pack",
        },
    });
    imgui_lib.root_module.addLibraryPath(.{ .cwd_relative = vulkanPathLib });
    imgui_lib.root_module.addIncludePath(.{ .cwd_relative = vulkanPathInclude });
    exe.linkLibrary(imgui_lib);
    // --- IMGUI END ---

    // --- ASSIMP START ---
    _ = dll_wfs.addCopyFile(
        b.path("dependency/assimp/lib/assimp-vc142-mt.dll"),
        "assimp-vc142-mt.dll",
    );
    const assimp_lib_path = switch (optimizationMode) {
        .Debug => b.path("dependency/assimp/lib/Release/"),
        else => b.path("dependency/assimp/lib/RelWithDebInfo/"),
    };
    exe.root_module.addLibraryPath(assimp_lib_path);
    exe.root_module.addIncludePath(b.path("dependency/assimp/include"));
    exe.root_module.linkSystemLibrary("assimp-vc142-mt", .{});
    // --- ASSIMP END ---

    // --- STB START ---
    exe.addIncludePath(b.path("dependency/stb"));
    const stb_flags = &[_][]const u8{
        "-std=c17",
    };
    exe.addCSourceFile(.{
        .file = b.path("dependency/stb/stb_image_impl.c"),
        .flags = stb_flags,
    });
    // --- STB END ---

    // --- VMA START ---
    exe.addIncludePath(b.path("dependency/vma"));
    const vma_flags = &[_][]const u8{};
    exe.addCSourceFile(.{
        .file = b.path("dependency/vma/vk_mem_alloc.cpp"),
        .flags = vma_flags,
    });
    // --- VMA END ---

    // --- TESTS BEGIN ---
    const test_files = [_][]const u8{
        "src/math/Math.zig",
    };

    const test_step = b.step("test", "Run tests");
    for (test_files) |test_file| {
        const test_artifact = b.addTest(.{
            .root_source_file = b.path(test_file),
            .optimize = optimizationMode,
            .target = targetOptions,
        });
        const run_test = b.addRunArtifact(test_artifact);
        test_step.dependOn(&run_test.step);
    }
    // --- TESTS END ---

    // copy dlls previously copied to the cache to bin
    b.installDirectory(.{
        .install_dir = .bin,
        .source_dir = dll_wfs.getDirectory(),
        .install_subdir = "",
    });
    b.installArtifact(exe);

    const run_exe_cmd = b.addRunArtifact(exe);
    run_exe_cmd.step.dependOn(b.getInstallStep());

    const run_exe_step = b.step("run", "Run the demo");
    run_exe_step.dependOn(&run_exe_cmd.step);

    //TODO would be nice to make shader building its own separate process and allow
    // shaders to fail to compile without blocking the build. References to failed
    // or missing shaders would instead display with a generic error shader.
    const logShaderCompilation = true;
    try cleanCompiledShaders();
    try buildAllShaders(b, exe, logShaderCompilation);
}
