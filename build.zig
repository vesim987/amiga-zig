const std = @import("std");

pub fn build(b: *std.Build) void {
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
    main_mod.pic = false;
    main_mod.unwind_tables = .none;
    main_mod.omit_frame_pointer = false;
    main_mod.code_model = .medium;

    const main_obj = b.addObject(.{
        .name = "main",
        .root_module = main_mod,
    });

    main_obj.pie = false;
    main_obj.link_emit_relocs = false;

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
}
