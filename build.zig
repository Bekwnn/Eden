const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const windows = b.option(bool, "windows", "create windows build") orelse false;
    const exe = b.addExecutable("sdl-zig-demo", "main.zig");
    exe.setBuildMode(mode);

    if (windows) {
        exe.setTarget(builtin.Arch.x86_64, builtin.Os.windows, builtin.Abi.gnu);
    }

    exe.addIncludeDir("dependency/SDL2/include");
    exe.addIncludeDir("dependency/glew-2.1.0/include/GL");
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("opengl32");
    exe.linkSystemLibrary("glew32");
    exe.linkSystemLibrary("glew32s");
    exe.linkSystemLibrary("SDL2");
    exe.install();

    const run_exe_cmd = exe.run();
    run_exe_cmd.step.dependOn(b.getInstallStep());

    const run_exe_step = b.step("run", "Run the demo");
    run_exe_step.dependOn(&run_exe_cmd.step);
}
