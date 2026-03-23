const ExecBase = *anyopaque;
const DosBase = *anyopaque;

fn openLibrary(exec: ExecBase, name: [*:0]const u8, version: u32) ?*anyopaque {
    const addr: usize = @intFromPtr(exec) -% 552;
    return asm volatile ("jsr (%%a0)"
        : [ret] "={d0}" (-> ?*anyopaque),
        : [addr] "{a0}" (addr),
          [base] "{a6}" (exec),
          [name] "{a1}" (name),
          [ver] "{d0}" (version),
        : .{ .d1 = true, .a0 = true, .a1 = true, .memory = true });
}

fn closeLibrary(exec: ExecBase, lib: *anyopaque) void {
    const addr: usize = @intFromPtr(exec) -% 414;
    asm volatile ("jsr (%%a0)"
        :
        : [addr] "{a0}" (addr),
          [base] "{a6}" (exec),
          [lib] "{a1}" (lib),
        : .{ .d0 = true, .d1 = true, .a0 = true, .a1 = true, .memory = true });
}

fn dosOutput(dos: DosBase) u32 {
    const addr: usize = @intFromPtr(dos) -% 60;
    return asm volatile ("jsr (%%a0)"
        : [ret] "={d0}" (-> u32),
        : [addr] "{a0}" (addr),
          [base] "{a6}" (dos),
        : .{ .d1 = true, .a0 = true, .a1 = true, .memory = true });
}

fn dosWrite(dos: DosBase, fh: u32, buf: [*]const u8, len: u32) i32 {
    const addr: usize = @intFromPtr(dos) -% 48;
    return asm volatile ("jsr (%%a0)"
        : [ret] "={d0}" (-> i32),
        : [addr] "{a0}" (addr),
          [base] "{a6}" (dos),
          [fh] "{d1}" (fh),
          [buf] "{d2}" (@intFromPtr(buf)),
          [len] "{d3}" (len),
        : .{ .d1 = true, .a0 = true, .a1 = true, .memory = true });
}

export fn _start() noreturn {
    const frame_ptr: usize = asm volatile (""
        : [fp] "={a6}" (-> usize),
    );

    const exec_base = @as(*const *anyopaque, @ptrFromInt(4)).*;

    if (openLibrary(exec_base, "dos.library", 0)) |dos| {
        const stdout = dosOutput(dos);
        const msg = "Hello, World!\n";
        _ = dosWrite(dos, stdout, msg.ptr, msg.len);
        closeLibrary(exec_base, dos);
    }

    // Restore frame pointer → UNLK restores SP and old A6 → RTS
    asm volatile (
        \\unlk %%a6
        \\moveq #0, %%d0
        \\rts
        :
        : [fp] "{a6}" (frame_ptr),
    );
    unreachable;
}
