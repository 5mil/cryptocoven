//! build.zig -- Coven Bot build config
//! Requires: Zig 0.14+, libpq-dev
//! Build:  zig build
//! Run:    zig build run -- config/config.json
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target   = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // -- coven-bot executable -------------------------------------------------
    const bot_exe = b.addExecutable(.{
        .name   = "coven-bot",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    linkPq(bot_exe);
    b.installArtifact(bot_exe);

    // -- Run step -------------------------------------------------------------
    const run_cmd = b.addRunArtifact(bot_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run coven-bot");
    run_step.dependOn(&run_cmd.step);

    // -- Unit tests -----------------------------------------------------------
    const tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    linkPq(tests);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

fn linkPq(step: *std.Build.Step.Compile) void {
    step.linkLibC();
    step.linkSystemLibrary("pq");
    // Neon / Postgres headers -- adjust path if libpq-dev is in a non-standard location
    // e.g. on Ubuntu: /usr/include/postgresql
    step.addIncludePath(.{ .cwd_relative = "/usr/include/postgresql" });
}
