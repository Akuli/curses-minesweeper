const std = @import("std");
const Builder = std.build.Builder;


pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("cursesminesweeper", "src/main.zig");
    exe.setBuildMode(mode);
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("ncursesw");
    exe.addIncludeDir(".");
    exe.addPackagePath("zig-clap", "zig-clap/index.zig");
    exe.setOutputDir("zig-cache");

    const valgrind_cmd = b.addSystemCommand([][]const u8{"valgrind"});
    valgrind_cmd.addArg("--leak-check=full");
    valgrind_cmd.addArg("--show-leak-kinds=all");
    valgrind_cmd.addArg("--log-file=valgrind.log");
    valgrind_cmd.addArg("--suppressions=curses.supp");
    valgrind_cmd.addArg("--gen-suppressions=all");
    valgrind_cmd.addArtifactArg(exe);
    const valgrind_step = b.step("valgrind", "Run the thing in valgrind");
    valgrind_step.dependOn(&valgrind_cmd.step);

    const run_cmd = exe.run();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
