const std = @import("std");
const platform = @import("platforms/mod.zig").platform;
const Event = @import("platforms/mod.zig").Event;
const eventToC = @import("platforms/mod.zig").eventToC;

pub const TriggerCallback = *const fn ([*c]const u8, c_int) callconv(.c) void;

pub const TriggerResult = enum(c_int) {
    ok = 0,
    error_ = -1,
    event_modified = 1,
    event_created = 2,
    event_deleted = 3,
};

pub const trigger_watcher = struct {
    filepath: [:0]u8,
    callback: TriggerCallback,
    is_watching: bool,
    platform_state: platform.Watcher,

    pub fn init(
        allocator: std.mem.Allocator,
        filepath: ?[*:0]const u8,
        callback: ?TriggerCallback,
    ) ?*trigger_watcher {
        const path_ptr = filepath orelse return null;
        const cb = callback orelse return null;
        const path = std.mem.span(path_ptr);
        if (path.len == 0) return null;

        const self = allocator.create(trigger_watcher) catch return null;
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

    pub fn destroy(allocator: std.mem.Allocator, self: *trigger_watcher) TriggerResult {
        _ = self.stop();
        allocator.free(self.filepath);
        allocator.destroy(self);
        return .ok;
    }

    pub fn start(self: *trigger_watcher) TriggerResult {
        if (self.is_watching) return .error_;
        if (platform.start(&self.platform_state, self.filepath) != 0) return .error_;
        self.is_watching = true;
        return .ok;
    }

    pub fn stop(self: *trigger_watcher) TriggerResult {
        if (!self.is_watching) return .ok;
        platform.stop(&self.platform_state);
        self.is_watching = false;
        return .ok;
    }

    pub fn poll(self: *trigger_watcher, blocking: bool) TriggerResult {
        if (!self.is_watching) return .error_;

        const result = platform.poll(&self.platform_state, blocking);
        if (result < 0) return .error_;
        if (result == 0) return .ok;

        const event = platform.lastEvent(&self.platform_state);
        self.callback(self.filepath.ptr, eventToC(event));
        return switch (event) {
            .modified => .event_modified,
            .created => .event_created,
            .deleted => .event_deleted,
        };
    }
};
