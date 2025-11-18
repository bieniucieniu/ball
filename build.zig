const std = @import("std");
const rlz = @import("raylib_zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library
    //

    const mod = b.addModule("ball", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "raylib", .module = raylib },
            .{ .name = "raygui", .module = raygui },
        },
    });

    mod.linkLibrary(raylib_artifact);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ball", .module = mod },
        },
    });
    const exe = b.addExecutable(.{
        .name = "ball",
        .root_module = exe_mod,
    });

    if (optimize != .Debug)
        switch (target.result.os.tag) {
            .linux, .macos => exe.subsystem = .Posix,
            .windows => exe.subsystem = .Windows,
            else => {},
        };

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    if (target.query.os_tag == .emscripten) {
        const emsdk = rlz.emsdk;
        const wasm = b.addLibrary(.{
            .name = "ball",
            .root_module = exe_mod,
        });

        const install_dir: std.Build.InstallDir = .{ .custom = "web" };
        const emcc_flags = emsdk.emccDefaultFlags(b.allocator, .{ .optimize = optimize });
        const emcc_settings = emsdk.emccDefaultSettings(b.allocator, .{ .optimize = optimize });

        const emcc_step = emsdk.emccStep(b, raylib_artifact, wasm, .{
            .optimize = optimize,
            .flags = emcc_flags,
            .settings = emcc_settings,
            .install_dir = install_dir,
        });
        b.getInstallStep().dependOn(emcc_step);

        const html_filename = std.fmt.allocPrint(b.allocator, "{s}.html", .{wasm.name}) catch @panic("allocPrint failed");
        const emrun_step = emsdk.emrunStep(
            b,
            b.getInstallPath(install_dir, html_filename),
            &.{},
        );

        emrun_step.dependOn(emcc_step);
        run_step.dependOn(emrun_step);
    } else {
        const clap_dep = b.dependency("clap", .{});
        mod.addImport("clap", clap_dep.module("clap"));
    }

    const run_cmd = b.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
