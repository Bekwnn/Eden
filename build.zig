const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("sdl-zig-demo", "main.zig");
    exe.setBuildMode(mode);

    exe.addIncludeDir("dependency/SDL2/include");
    exe.addIncludeDir("dependency/glew-2.1.0/include/GL");
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("opengl32");
    exe.linkSystemLibrary("glew32s"); //only include 1 of the 2 glew libs
    exe.linkSystemLibrary("SDL2");
    exe.install();

    const run_exe_cmd = exe.run();
    run_exe_cmd.step.dependOn(b.getInstallStep());

    const run_exe_step = b.step("run", "Run the demo");
    run_exe_step.dependOn(&run_exe_cmd.step);
}
