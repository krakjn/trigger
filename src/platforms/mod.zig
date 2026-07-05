const std = @import("std");
const builtin = @import("builtin");

pub const Event = enum(c_int) {
    modified = 1,
    created = 2,
    deleted = 3,
};

const impl = switch (builtin.os.tag) {
    .linux => @import("linux.zig"),
    .macos => @import("macos.zig"),
    .windows => @import("windows.zig"),
    else => @compileError("unsupported OS"),
};

pub const Watcher = impl.Watcher;

pub const Platform = struct {
    Watcher: type,
    start: *const fn (*Watcher, [:0]const u8) i32,
    stop: *const fn (*Watcher) void,
    poll: *const fn (*Watcher, blocking: bool) i32,
    lastEvent: *const fn (*const Watcher) Event,
};

pub const platform: Platform = .{
    .Watcher = impl.Watcher,
    .start = impl.start,
    .stop = impl.stop,
    .poll = impl.poll,
    .lastEvent = impl.lastEvent,
};

pub fn eventToC(event: Event) c_int {
    return @intFromEnum(event);
}
