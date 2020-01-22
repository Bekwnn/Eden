const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("sdl-zig-demo", "main.zig");
    exe.setBuildMode(mode);

    exe.addIncludeDir("dependency/SDL2/include");
    exe.addIncludeDir("dependency/glew-2.1.0/include");
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("glew32");
    exe.install();

    const run_exe_cmd = exe.run();
    run_exe_cmd.step.dependOn(b.getInstallStep());

    const run_exe_step = b.step("run", "Run the demo");
    run_exe_step.dependOn(&run_exe_cmd.step);
}
