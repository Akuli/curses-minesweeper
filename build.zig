const std = @import("std");
const Builder = std.build.Builder;


pub fn build(b: *Builder) void {
    // Mostly copied from https://ziglearn.org/chapter-3/
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "cursesminesweeper",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("ncursesw");
    //exe.addIncludeDir(".");

    const zig_clap = b.addModule("zig-clap", .{
        .source_file = .{ .path = "zig-clap/clap.zig" }
    });
    exe.addModule("zig-clap", zig_clap);

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
