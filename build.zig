const std = @import("std");

pub fn build(b: *std.Build) void {
    const main_lib = b.addLibrary(.{
        .name = "main",
        .root_module = b.createModule(.{
            .target = b.resolveTargetQuery(.{ .os_tag = .freestanding, .cpu_arch = .m68k }),
            .optimize = .ReleaseFast,
            .root_source_file = b.path("src/main.zig"),
        }),
    });

    const mold_cmd = b.addSystemCommand(&.{ "mold", "-r" });
    mold_cmd.addArtifactArg(main_lib);
    const obj = mold_cmd.addPrefixedOutputFileArg("-o", b.fmt("{s}.obj", .{main_lib.name}));

    const vlink_cmd = b.addSystemCommand(&.{ "vlink", "-bamigahunk", "-s" });
    vlink_cmd.addPrefixedFileArg("-T", b.path("amiga.ld"));
    const hunk = vlink_cmd.addPrefixedOutputFileArg("-o", b.fmt("{s}.hunk", .{main_lib.name}));

    vlink_cmd.addFileArg(obj);

    const hunk_install = b.addInstallBinFile(hunk, b.fmt("{s}.hunk", .{main_lib.name}));
    b.getInstallStep().dependOn(&hunk_install.step);
}
