const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const static = b.option(bool, "static", "Build static library") orelse false;

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const lib = b.addLibrary(.{
        .name = "trigger",
        .linkage = if (static) .static else .dynamic,
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const install_header = b.addInstallFile(b.path("include/trigger.h"), "include/trigger.h");
    b.getInstallStep().dependOn(&install_header.step);

    const examples = [_]struct { name: []const u8, needs_pthread: bool }{
        .{ .name = "single_thread_one_watcher", .needs_pthread = false },
        .{ .name = "single_thread_multi_watcher", .needs_pthread = false },
        .{ .name = "multi_thread_one_watcher", .needs_pthread = true },
        .{ .name = "multi_thread_multi_watcher", .needs_pthread = true },
    };

    for (examples) |example| {
        if (example.needs_pthread and target.result.os.tag == .windows) continue;

        const example_mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        example_mod.addIncludePath(b.path("include"));
        example_mod.addCSourceFile(.{
            .file = b.path(b.fmt("examples/{s}.c", .{example.name})),
        });
        example_mod.linkLibrary(lib);
        if (example.needs_pthread) {
            example_mod.linkSystemLibrary("pthread", .{});
        }

        const exe = b.addExecutable(.{
            .name = example.name,
            .root_module = example_mod,
        });
        b.installArtifact(exe);
    }

    if (target.result.os.tag == .linux) {
        const test_mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        test_mod.addIncludePath(b.path("include"));
        test_mod.addCSourceFile(.{
            .file = b.path("examples/test_linux_events.c"),
        });
        test_mod.linkLibrary(lib);

        const test_exe = b.addExecutable(.{
            .name = "test_linux_events",
            .root_module = test_mod,
        });
        b.installArtifact(test_exe);

        const run_test = b.addRunArtifact(test_exe);
        if (b.args) |args| run_test.addArgs(args);

        const test_step = b.step("test", "Run Linux file event integration tests");
        test_step.dependOn(&run_test.step);
    }

    const cross_step = b.step("cross", "Build for all supported targets");
    const cross_targets = [_]struct { query: std.Target.Query, name: []const u8 }{
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl }, .name = "x86_64-linux-musl" },
        .{ .query = .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .musl }, .name = "aarch64-linux-musl" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .macos, .abi = .none, .ofmt = .macho }, .name = "x86_64-macos" },
        .{ .query = .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none, .ofmt = .macho }, .name = "aarch64-macos" },
        .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu }, .name = "x86_64-windows-gnu" },
        .{ .query = .{ .cpu_arch = .aarch64, .os_tag = .windows, .abi = .gnu }, .name = "aarch64-windows-gnu" },
    };

    for (cross_targets) |entry| {
        const cross_target = b.resolveTargetQuery(entry.query);
        const cross_mod = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = cross_target,
            .optimize = .ReleaseFast,
            .link_libc = true,
        });

        const cross_lib = b.addLibrary(.{
            .name = "trigger",
            .linkage = if (std.mem.endsWith(u8, entry.name, "-musl")) .static else .dynamic,
            .root_module = cross_mod,
        });

        const dest_path = b.dupe(b.fmt("cross/{s}", .{entry.name}));
        const install = b.addInstallArtifact(cross_lib, .{
            .dest_dir = .{ .override = .{ .custom = dest_path } },
        });
        cross_step.dependOn(&install.step);

        if (entry.query.os_tag == .windows) {
            const implib_path = b.dupe(b.fmt("cross/{s}/trigger.lib", .{entry.name}));
            const install_implib = b.addInstallFile(cross_lib.getEmittedImplib(), implib_path);
            cross_step.dependOn(&install_implib.step);
        }
    }
}
