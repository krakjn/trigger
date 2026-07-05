const std = @import("std");
const c = std.c;
const Event = @import("mod.zig").Event;

pub const Watcher = struct {
    kq: c_int = -1,
    file_fd: c_int = -1,
    last_event: Event = .modified,

    pub fn start(self: *Watcher, path: [:0]const u8) i32 {
        if (self.kq >= 0) return -1;

        self.kq = c.kqueue();
        if (self.kq < 0) return -1;

        self.file_fd = c.open(path.ptr, .{}, @as(c.mode_t, 0));
        if (self.file_fd < 0) {
            _ = c.close(self.kq);
            self.kq = -1;
            return -1;
        }

        var changes = [1]c.Kevent{.{
            .ident = @intCast(self.file_fd),
            .filter = c.EVFILT.VNODE,
            .flags = c.EV.ADD | c.EV.ENABLE | c.EV.CLEAR,
            .fflags = c.NOTE.DELETE | c.NOTE.WRITE | c.NOTE.EXTEND | c.NOTE.ATTRIB | c.NOTE.LINK | c.NOTE.RENAME | c.NOTE.REVOKE,
            .data = 0,
            .udata = 0,
        }};

        var no_events: [0]c.Kevent = .{};
        if (c.kevent(self.kq, &changes, 1, &no_events, 0, null) < 0) {
            _ = c.close(self.file_fd);
            _ = c.close(self.kq);
            self.file_fd = -1;
            self.kq = -1;
            return -1;
        }

        return 0;
    }

    pub fn stop(self: *Watcher) void {
        if (self.kq >= 0) {
            _ = c.close(self.kq);
            self.kq = -1;
        }
        if (self.file_fd >= 0) {
            _ = c.close(self.file_fd);
            self.file_fd = -1;
        }
    }

    pub fn poll(self: *Watcher, blocking: bool) i32 {
        if (self.kq < 0) return -1;

        var events = [1]c.Kevent{undefined};
        var empty: [0]c.Kevent = .{};
        const timeout = if (blocking)
            c.timespec{ .sec = 1, .nsec = 0 }
        else
            c.timespec{ .sec = 0, .nsec = 0 };

        const nevents = c.kevent(self.kq, &empty, 0, &events, 1, &timeout);
        if (nevents < 0) return -1;
        if (nevents == 0) return 0;

        self.last_event = mapKeventFlags(events[0].fflags);
        return 1;
    }

    pub fn lastEvent(self: *const Watcher) Event {
        return self.last_event;
    }

    fn mapKeventFlags(fflags: u32) Event {
        if ((fflags & c.NOTE.DELETE) != 0) return .deleted;
        if ((fflags & c.NOTE.WRITE) != 0 or (fflags & c.NOTE.EXTEND) != 0) return .modified;
        return .modified;
    }
};

pub const start = Watcher.start;
pub const stop = Watcher.stop;
pub const poll = Watcher.poll;
pub const lastEvent = Watcher.lastEvent;
