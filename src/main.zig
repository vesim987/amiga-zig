pub fn main() !void {
    const exec_base = amiga.ExecBase.get();

    const dos = try exec_base.openLibrary(amiga.DosBase, "dos.library", 0);
    defer dos.deinit(exec_base);

    const stdout = dos.output();
    _ = dos.write(stdout, "Hello, World!\n");
}

pub const panic = amiga.panic;
comptime {
    _ = amiga;
}

const std = @import("std");
const amiga = @import("amiga.zig");
