const std = @import("std");
const watcher = @import("watcher.zig");

const allocator = std.heap.page_allocator;

export fn trigger_init(
    filepath: ?[*:0]const u8,
    callback: ?watcher.TriggerCallback,
) ?*watcher.trigger_watcher {
    return watcher.trigger_watcher.init(allocator, filepath, callback);
}

export fn trigger_start(w: ?*watcher.trigger_watcher) c_int {
    const self = w orelse return @intFromEnum(watcher.TriggerResult.error_);
    return @intFromEnum(self.start());
}

export fn trigger_stop(w: ?*watcher.trigger_watcher) c_int {
    const self = w orelse return @intFromEnum(watcher.TriggerResult.error_);
    return @intFromEnum(self.stop());
}

export fn trigger_try_recv(w: ?*watcher.trigger_watcher) c_int {
    const self = w orelse return @intFromEnum(watcher.TriggerResult.error_);
    return @intFromEnum(self.poll(false));
}

export fn trigger_recv(w: ?*watcher.trigger_watcher) c_int {
    const self = w orelse return @intFromEnum(watcher.TriggerResult.error_);
    return @intFromEnum(self.poll(true));
}

export fn trigger_destroy(w: ?*watcher.trigger_watcher) c_int {
    const self = w orelse return @intFromEnum(watcher.TriggerResult.error_);
    return @intFromEnum(watcher.trigger_watcher.destroy(allocator, self));
}
