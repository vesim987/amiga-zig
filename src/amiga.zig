fn SysCall(lvo: u16, BaseType: type, Ret: type, Params: anytype) type {
    const struct_ = @typeInfo(@TypeOf(Params)).@"struct";
    const fields = struct_.fields;

    const asm_code = blk: {
        var code: []const u8 =
            "move.l %%a6, -(%%sp)\n" ++
            "move.l %[vbase], %%a6\n";
        for (0.., fields) |i, field| {
            code = code ++ std.fmt.comptimePrint("move.l %[arg{}], %%{s}\n", .{ i, field.name });
        }
        break :blk code ++ "jsr (%%a0)\nmove.l (%%sp)+, %%a6\n";
    };

    const clobbers: std.builtin.assembly.Clobbers = blk: {
        var tmp: std.builtin.assembly.Clobbers = .{
            .d0 = true,
            .d1 = true,
            .a0 = true,
            .a1 = true,
            .a6 = true,
            .memory = true,
        };

        for (fields) |field| {
            @field(tmp, field.name) = true;
        }

        break :blk tmp;
    };

    const wrappers = struct {
        inline fn @"0"(base: *BaseType) Ret {
            const addr: usize = @intFromPtr(base) -% lvo;
            if (Ret == void) {
                asm volatile (asm_code
                    :
                    : [addr] "{a0}" (addr),
                      [vbase] "r" (@intFromPtr(base)),
                    : clobbers);
            } else {
                return asm volatile (asm_code
                    : [ret] "={d0}" (-> Ret),
                    : [addr] "{a0}" (addr),
                      [vbase] "r" (@intFromPtr(base)),
                    : clobbers);
            }
        }

        inline fn @"1"(
            base: *BaseType,
            arg0: @field(Params, fields[0].name),
        ) Ret {
            const addr: usize = @intFromPtr(base) -% lvo;
            if (Ret == void) {
                asm volatile (asm_code
                    :
                    : [addr] "{a0}" (addr),
                      [vbase] "r" (@intFromPtr(base)),
                      [arg0] "r" (arg0),
                    : clobbers);
            } else {
                return asm volatile (asm_code
                    : [ret] "={d0}" (-> Ret),
                    : [addr] "{a0}" (addr),
                      [vbase] "r" (@intFromPtr(base)),
                      [arg0] "r" (arg0),
                    : clobbers);
            }
        }
        inline fn @"2"(
            base: *BaseType,
            arg0: @field(Params, fields[0].name),
            arg1: @field(Params, fields[1].name),
        ) Ret {
            const addr: usize = @intFromPtr(base) -% lvo;
            if (Ret == void) {
                asm volatile (asm_code
                    :
                    : [addr] "{a0}" (addr),
                      [vbase] "r" (@intFromPtr(base)),
                      [arg0] "r" (arg0),
                      [arg1] "r" (arg1),
                    : clobbers);
            } else {
                return asm volatile (asm_code
                    : [ret] "={d0}" (-> Ret),
                    : [addr] "{a0}" (addr),
                      [vbase] "r" (@intFromPtr(base)),
                      [arg0] "r" (arg0),
                      [arg1] "r" (arg1),
                    : clobbers);
            }
        }
        inline fn @"3"(
            base: *BaseType,
            arg0: @field(Params, fields[0].name),
            arg1: @field(Params, fields[1].name),
            arg2: @field(Params, fields[2].name),
        ) Ret {
            const addr: usize = @intFromPtr(base) -% lvo;
            if (Ret == void) {
                asm volatile (asm_code
                    :
                    : [addr] "{a0}" (addr),
                      [vbase] "r" (@intFromPtr(base)),
                      [arg0] "r" (arg0),
                      [arg1] "r" (arg1),
                      [arg2] "r" (arg2),
                    : clobbers);
            } else {
                return asm volatile (asm_code
                    : [ret] "={d0}" (-> Ret),
                    : [addr] "{a0}" (addr),
                      [vbase] "r" (@intFromPtr(base)),
                      [arg0] "r" (arg0),
                      [arg1] "r" (arg1),
                      [arg2] "r" (arg2),
                    : clobbers);
            }
        }
    };

    return struct {
        const func = @field(wrappers, std.fmt.comptimePrint("{}", .{fields.len}));
    };
}

pub const ExecBase = opaque {
    pub fn get() *ExecBase {
        return @as(*const *ExecBase, @ptrFromInt(4)).*;
    }

    pub const openLibraryRaw = SysCall(552, ExecBase, ?*anyopaque, .{ .a1 = [*:0]const u8, .d0 = u32 }).func;
    pub fn openLibrary(exec: *ExecBase, T: type, name: [*:0]const u8, version: u32) error{NotFound}!*T {
        if (exec.openLibraryRaw(name, version)) |l| return @ptrCast(l) else return error.NotFound;
    }

    pub const closeLibrary = SysCall(414, ExecBase, void, .{ .a1 = *anyopaque }).func;
};

pub const DosBase = opaque {
    pub fn deinit(dos: *DosBase, exec_base: *ExecBase) void {
        exec_base.closeLibrary(dos);
    }
    pub const output = SysCall(60, DosBase, u32, .{}).func;
    pub const writeRaw = SysCall(48, DosBase, i32, .{ .d1 = u32, .d2 = [*]const u8, .d3 = u32 }).func;

    pub fn write(dos: *DosBase, fh: u32, buf: []const u8) i32 {
        return dos.writeRaw(fh, buf.ptr, buf.len);
    }
};

pub fn _start() callconv(.c) noreturn {
    @import("root").main() catch |err| std.debug.panic("main exited with error: {}", .{err});
    exit();
}

comptime {
    @export(&_start, .{ .name = "_start" });
}

pub const panic = std.debug.FullPanic(struct {
    fn panic(msg: []const u8, _: ?usize) noreturn {
        const exec = ExecBase.get();
        const dos = exec.openLibrary(DosBase, "dos.library", 0) catch {
            while (true) {}
        };
        const fh = dos.output();
        _ = dos.write(fh, "panic: ");
        _ = dos.write(fh, msg);
        _ = dos.write(fh, "\n");
        if (@errorReturnTrace()) |trace| {
            _ = dos.write(fh, "error return trace:\n");
            for (trace.instruction_addresses[0..trace.index]) |addr| {
                var buf: [32]u8 = undefined;
                const s = std.fmt.bufPrint(&buf, "  0x{x}\n", .{addr}) catch "  ???\n";
                _ = dos.write(fh, s);
            }
        }
        while (true) {}
    }
}.panic);

pub fn exit() noreturn {
    asm volatile ("unlk %%a6\nmoveq #0, %%d0\nrts");
    unreachable;
}

const std = @import("std");
