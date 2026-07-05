const std = @import("std");
const watcher = @import("watcher.zig");

const allocator = std.heap.page_allocator;

export fn trigger_create_watcher(
    filepath: ?[*:0]const u8,
    callback: watcher.FileChangeCallback,
) ?*watcher.file_watcher {
    const path = filepath orelse return null;
    return watcher.file_watcher.create(allocator, path, callback);
}

export fn trigger_start_watching(w: ?*watcher.file_watcher) c_int {
    const self = w orelse return -1;
    return self.start();
}

export fn trigger_stop_watching(w: ?*watcher.file_watcher) void {
    const self = w orelse return;
    self.stop();
}

export fn trigger_check_changes(w: ?*watcher.file_watcher) c_int {
    const self = w orelse return -1;
    return self.poll(false);
}

export fn trigger_wait_for_changes(w: ?*watcher.file_watcher) c_int {
    const self = w orelse return -1;
    return self.poll(true);
}

export fn trigger_destroy_watcher(w: ?*watcher.file_watcher) void {
    const self = w orelse return;
    watcher.file_watcher.destroy(allocator, self);
}

export fn trigger_get_event_string(event_type: c_int) [*:0]const u8 {
    return watcher.eventString(event_type);
}
