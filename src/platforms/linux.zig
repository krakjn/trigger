const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;
const c = std.c;
const Event = @import("mod.zig").Event;

const IN_MODIFY: u32 = 0x0000_0002;
const IN_CREATE: u32 = 0x0000_0100;
const IN_DELETE: u32 = 0x0000_0200;
const IN_MOVE: u32 = 0x0000_00c0;
const IN_DELETE_SELF: u32 = 0x0000_0400;

pub const Watcher = struct {
    watch_fd: posix.fd_t = -1,
    last_event: Event = .modified,

    pub fn start(self: *Watcher, path: [:0]const u8) i32 {
        if (self.watch_fd >= 0) return -1;

        const fd = linux.inotify_init1(0);
        if (@as(isize, @bitCast(fd)) < 0) return -1;
        self.watch_fd = @intCast(fd);

        const mask = IN_MODIFY | IN_CREATE | IN_DELETE | IN_MOVE;
        const wd = linux.inotify_add_watch(self.watch_fd, path.ptr, mask);
        if (@as(isize, @bitCast(wd)) < 0) {
            _ = c.close(self.watch_fd);
            self.watch_fd = -1;
            return -1;
        }

        return 0;
    }

    pub fn stop(self: *Watcher) void {
        if (self.watch_fd >= 0) {
            _ = c.close(self.watch_fd);
            self.watch_fd = -1;
        }
    }

    pub fn poll(self: *Watcher, blocking: bool) i32 {
        if (self.watch_fd < 0) return -1;

        var fds = [1]posix.pollfd{
            .{ .fd = self.watch_fd, .events = posix.POLL.IN, .revents = 0 },
        };

        const timeout_ms: i32 = if (blocking) -1 else 0;
        const ready = posix.poll(&fds, timeout_ms) catch return -1;
        if (ready == 0) return 0;

        var buffer: [1024]u8 = undefined;
        const length = posix.read(self.watch_fd, &buffer) catch return -1;
        if (length == 0) return 0;

        return self.parseEvents(&buffer, length);
    }

    pub fn lastEvent(self: *const Watcher) Event {
        return self.last_event;
    }

    fn parseEvents(self: *Watcher, buffer: []const u8, length: usize) i32 {
        var i: usize = 0;
        var found = false;

        while (i < length) {
            const event: *const linux.inotify_event = @ptrCast(@alignCast(buffer.ptr + i));

            if (event.mask & (IN_DELETE | IN_DELETE_SELF) != 0) {
                self.last_event = .deleted;
            } else if (event.mask & IN_CREATE != 0) {
                self.last_event = .created;
            } else if (event.mask & IN_MODIFY != 0) {
                self.last_event = .modified;
            } else {
                self.last_event = .modified;
            }

            found = true;
            i += @sizeOf(linux.inotify_event) + event.len;
        }

        return if (found) 1 else 0;
    }
};

pub const start = Watcher.start;
pub const stop = Watcher.stop;
pub const poll = Watcher.poll;
pub const lastEvent = Watcher.lastEvent;
