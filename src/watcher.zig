const std = @import("std");
const platform = @import("platforms/mod.zig").platform;
const Event = @import("platforms/mod.zig").Event;
const eventToC = @import("platforms/mod.zig").eventToC;

pub const FileChangeCallback = *const fn ([*c]const u8, c_int) callconv(.c) void;

pub const file_watcher = struct {
    filepath: [:0]u8,
    callback: FileChangeCallback,
    is_watching: bool,
    platform_state: platform.Watcher,

    pub fn create(
        allocator: std.mem.Allocator,
        filepath: ?[*:0]const u8,
        callback: ?FileChangeCallback,
    ) ?*file_watcher {
        const path_ptr = filepath orelse return null;
        const cb = callback orelse return null;
        const path = std.mem.span(path_ptr);
        if (path.len == 0) return null;

        const self = allocator.create(file_watcher) catch return null;
        errdefer allocator.destroy(self);

        const owned = allocator.dupeZ(u8, path) catch {
            allocator.destroy(self);
            return null;
        };

        self.* = .{
            .filepath = owned,
            .callback = cb,
            .is_watching = false,
            .platform_state = .{},
        };

        return self;
    }

    pub fn destroy(allocator: std.mem.Allocator, self: *file_watcher) void {
        self.stop();
        allocator.free(self.filepath);
        allocator.destroy(self);
    }

    pub fn start(self: *file_watcher) i32 {
        if (self.is_watching) return -1;
        if (platform.start(&self.platform_state, self.filepath) != 0) return -1;
        self.is_watching = true;
        return 0;
    }

    pub fn stop(self: *file_watcher) void {
        if (!self.is_watching) return;
        platform.stop(&self.platform_state);
        self.is_watching = false;
    }

    pub fn poll(self: *file_watcher, blocking: bool) i32 {
        if (!self.is_watching) return -1;

        const result = platform.poll(&self.platform_state, blocking);
        if (result == 1) {
            const event = platform.lastEvent(&self.platform_state);
            self.callback(self.filepath.ptr, eventToC(event));
        }
        return result;
    }
};

pub fn eventString(event_type: c_int) [*:0]const u8 {
    return switch (event_type) {
        @intFromEnum(Event.modified) => "MODIFIED",
        @intFromEnum(Event.created) => "CREATED",
        @intFromEnum(Event.deleted) => "DELETED",
        else => "UNKNOWN",
    };
}
