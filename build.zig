const std = @import("std");

pub fn build(b: *std.Build) void {
    const kickstart_file = b.option([]const u8, "kickstart_file", "path to the kickstart rom") orelse "kickstart.rom";
    const vlink_dep = b.dependency("vlink", .{ .optimize = .ReleaseFast });

    const main_mod = b.createModule(.{
        .target = b.resolveTargetQuery(.{
            .os_tag = .freestanding,
            .cpu_arch = .m68k,
            .cpu_model = .{ .baseline = {} },
        }),
        .optimize = .ReleaseFast,
        .root_source_file = b.path("src/main.zig"),
    });
    // main_mod.pic = false;
    main_mod.unwind_tables = .none;
    main_mod.omit_frame_pointer = false;
    main_mod.code_model = .medium;

    const main_obj = b.addObject(.{
        .name = "main",
        .root_module = main_mod,
    });
    // crashes llvm
    // main_obj.bundle_compiler_rt = true;

    const vlink_cmd = b.addRunArtifact(vlink_dep.artifact("vlink"));
    vlink_cmd.addArgs(&.{
        "-bamigahunk",
        "-s",
        "-Bstatic",
    });
    const hunk = vlink_cmd.addPrefixedOutputFileArg("-o", b.fmt("{s}.hunk", .{main_obj.name}));
    vlink_cmd.addArtifactArg(main_obj);

    const hunk_install = b.addInstallBinFile(hunk, b.fmt("{s}.hunk", .{main_obj.name}));
    b.getInstallStep().dependOn(&hunk_install.step);

    const startuop_sequence = b.addWriteFiles().add("Startup-Sequence", b.fmt("{s}.hunk", .{main_obj.name}));
    const startuop_sequence_install = b.addInstallBinFile(startuop_sequence, "S/Startup-Sequence");
    b.getInstallStep().dependOn(&startuop_sequence_install.step);

    const fs_uae_config = b.addWriteFiles().add("zig.fs-uae", b.fmt(
        \\# FS-UAE configuration saved by FS-UAE Launcher
        \\# Last saved: 2026-03-23 23:38:46
        \\
        \\[fs-uae]
        \\cpu = 68040
        \\floppy_drive_count = 0
        \\hard_drive_0 = ./zig-out/bin
        \\jit_compiler = 1
        \\kickstart_file = {s}
        \\console_debugger = 1
        \\
    , .{
        kickstart_file,
    }));
    const fs_uae_cmd = b.addSystemCommand(&.{"fs-uae"});
    fs_uae_cmd.addFileArg(fs_uae_config);
    fs_uae_cmd.step.dependOn(&hunk_install.step);
    fs_uae_cmd.step.dependOn(&startuop_sequence_install.step);

    const fs_uae_step = b.step("fs-uae", "run fsuae");
    fs_uae_step.dependOn(&fs_uae_cmd.step);
}
