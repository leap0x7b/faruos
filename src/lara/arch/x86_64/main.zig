const std = @import("std");
const limine = @import("limine");
const arch = @import("../x86_64.zig");
const gdt = @import("gdt.zig");
const interrupt = @import("interrupt.zig");
const framebuffer = @import("framebuffer.zig");
const lara = @import("../../main.zig");
const writer = @import("../../writer.zig");
pub const panic = @import("panic.zig").panic;

pub const std_options = struct {
    pub fn logFn(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
        const scope_prefix = if (scope == .default) "main" else @tagName(scope);
        const prefix = "\x1b[32m[lara:" ++ scope_prefix ++ "] " ++ switch (level) {
            .err => "\x1b[31merror",
            .warn => "\x1b[33mwarning",
            .info => "\x1b[36minfo",
            .debug => "\x1b[90mdebug",
        } ++ ": \x1b[0m";
        writer.writer.print(prefix ++ format ++ "\n", args) catch unreachable;
    }
};

pub const os = .{
    .heap = .{
        .page_allocator = arch.mm.slab.allocator,
    },
};

pub export fn _start() callconv(.C) void {
    // Initialize x87 FPU
    asm volatile ("fninit");

    // Enable SSE
    var cr0 = arch.cr.read(0);
    cr0 &= ~(@intCast(u64, 1) << 2);
    cr0 |= @intCast(u64, 1) << 1;
    arch.cr.write(0, cr0);

    var cr4 = arch.cr.read(4);
    cr4 |= @intCast(u64, 3) << 9;
    arch.cr.write(4, cr4);

    framebuffer.init();
    writer.init();
    gdt.init();
    interrupt.init();
    lara.main() catch unreachable;
    arch.halt();
}
