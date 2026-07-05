const std = @import("std");
const windows = std.os.windows;
const Event = @import("mod.zig").Event;

const FILE_LIST_DIRECTORY: windows.DWORD = 0x0001;
const FILE_SHARE_READ: windows.DWORD = 0x0000_0001;
const FILE_SHARE_WRITE: windows.DWORD = 0x0000_0002;
const FILE_SHARE_DELETE: windows.DWORD = 0x0000_0004;
const OPEN_EXISTING: windows.DWORD = 3;
const FILE_FLAG_BACKUP_SEMANTICS: windows.DWORD = 0x0200_0000;
const FILE_FLAG_OVERLAPPED: windows.DWORD = 0x4000_0000;

const FILE_NOTIFY_CHANGE_FILE_NAME: windows.DWORD = 0x0000_0001;
const FILE_NOTIFY_CHANGE_DIR_NAME: windows.DWORD = 0x0000_0002;
const FILE_NOTIFY_CHANGE_LAST_WRITE: windows.DWORD = 0x0000_0010;

const FILE_ACTION_ADDED: u32 = 0x0000_0001;
const FILE_ACTION_REMOVED: u32 = 0x0000_0002;
const FILE_ACTION_MODIFIED: u32 = 0x0000_0003;
const FILE_ACTION_RENAMED_OLD_NAME: u32 = 0x0000_0004;
const FILE_ACTION_RENAMED_NEW_NAME: u32 = 0x0000_0005;

const INFINITE: windows.DWORD = 0xffff_ffff;
const WAIT_OBJECT_0: windows.DWORD = 0;
const WAIT_TIMEOUT: windows.DWORD = 0x0000_0102;
const TRUE = windows.BOOL.TRUE;
const FALSE = windows.BOOL.FALSE;

const FILE_NOTIFY_INFORMATION = extern struct {
    NextEntryOffset: windows.DWORD,
    Action: windows.DWORD,
    FileNameLength: windows.DWORD,
    FileName: [1]windows.WCHAR,
};

const OVERLAPPED = extern struct {
    Internal: usize,
    InternalHigh: usize,
    Offset: windows.DWORD,
    OffsetHigh: windows.DWORD,
    hEvent: windows.HANDLE,
};

extern "kernel32" fn CreateFileW(
    lpFileName: [*:0]const windows.WCHAR,
    dwDesiredAccess: windows.DWORD,
    dwShareMode: windows.DWORD,
    lpSecurityAttributes: ?*anyopaque,
    dwCreationDisposition: windows.DWORD,
    dwFlagsAndAttributes: windows.DWORD,
    hTemplateFile: ?windows.HANDLE,
) callconv(.winapi) windows.HANDLE;

extern "kernel32" fn GetLastError() callconv(.winapi) windows.Win32Error;

extern "kernel32" fn CreateEventW(
    lpEventAttributes: ?*anyopaque,
    bManualReset: windows.BOOL,
    bInitialState: windows.BOOL,
    lpName: ?[*:0]const windows.WCHAR,
) callconv(.winapi) ?windows.HANDLE;

extern "kernel32" fn ResetEvent(hEvent: windows.HANDLE) callconv(.winapi) windows.BOOL;
extern "kernel32" fn CancelIo(hFile: windows.HANDLE) callconv(.winapi) windows.BOOL;
extern "kernel32" fn WaitForSingleObject(hHandle: windows.HANDLE, dwMilliseconds: windows.DWORD) callconv(.winapi) windows.DWORD;
extern "kernel32" fn GetOverlappedResult(
    hFile: windows.HANDLE,
    lpOverlapped: *OVERLAPPED,
    lpNumberOfBytesTransferred: *windows.DWORD,
    bWait: windows.BOOL,
) callconv(.winapi) windows.BOOL;

extern "kernel32" fn ReadDirectoryChangesW(
    hDirectory: windows.HANDLE,
    lpBuffer: [*]u8,
    nBufferLength: windows.DWORD,
    bWatchSubtree: windows.BOOL,
    dwNotifyFilter: windows.DWORD,
    lpBytesReturned: ?*windows.DWORD,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?*anyopaque,
) callconv(.winapi) windows.BOOL;

pub const Watcher = struct {
    dir_handle: windows.HANDLE = windows.INVALID_HANDLE_VALUE,
    event_handle: windows.HANDLE = windows.INVALID_HANDLE_VALUE,
    filename_utf16: []windows.WCHAR = &[_]windows.WCHAR{},
    buffer: [8192]u8 = undefined,
    overlapped: OVERLAPPED = std.mem.zeroes(OVERLAPPED),
    read_pending: bool = false,
    last_event: Event = .modified,

    pub fn start(self: *Watcher, path: [:0]const u8) i32 {
        if (self.dir_handle != windows.INVALID_HANDLE_VALUE) return -1;

        const split = splitPath(path) orelse return -1;
        const dir_utf16 = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, split.dir) catch return -1;
        defer std.heap.page_allocator.free(dir_utf16);

        self.filename_utf16 = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, split.base) catch return -1;

        const event = CreateEventW(null, TRUE, FALSE, null) orelse {
            std.heap.page_allocator.free(self.filename_utf16);
            self.filename_utf16 = &[_]windows.WCHAR{};
            return -1;
        };
        self.event_handle = event;

        self.dir_handle = CreateFileW(
            dir_utf16.ptr,
            FILE_LIST_DIRECTORY,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            null,
            OPEN_EXISTING,
            FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
            null,
        );
        if (self.dir_handle == windows.INVALID_HANDLE_VALUE) {
            windows.CloseHandle(self.event_handle);
            self.event_handle = windows.INVALID_HANDLE_VALUE;
            std.heap.page_allocator.free(self.filename_utf16);
            self.filename_utf16 = &[_]windows.WCHAR{};
            return -1;
        }

        self.overlapped.hEvent = self.event_handle;
        return 0;
    }

    pub fn stop(self: *Watcher) void {
        if (self.read_pending) {
            _ = CancelIo(self.dir_handle);
            self.read_pending = false;
        }
        if (self.dir_handle != windows.INVALID_HANDLE_VALUE) {
            windows.CloseHandle(self.dir_handle);
            self.dir_handle = windows.INVALID_HANDLE_VALUE;
        }
        if (self.event_handle != windows.INVALID_HANDLE_VALUE) {
            windows.CloseHandle(self.event_handle);
            self.event_handle = windows.INVALID_HANDLE_VALUE;
        }
        if (self.filename_utf16.len > 0) {
            std.heap.page_allocator.free(self.filename_utf16);
            self.filename_utf16 = &[_]windows.WCHAR{};
        }
    }

    pub fn poll(self: *Watcher, blocking: bool) i32 {
        if (self.dir_handle == windows.INVALID_HANDLE_VALUE) return -1;

        if (!self.read_pending) {
            self.overlapped.Internal = 0;
            self.overlapped.InternalHigh = 0;
            self.overlapped.Offset = 0;
            self.overlapped.OffsetHigh = 0;
            _ = ResetEvent(self.event_handle);

            var bytes_returned: windows.DWORD = 0;
            const ok = ReadDirectoryChangesW(
                self.dir_handle,
                &self.buffer,
                @intCast(self.buffer.len),
                FALSE,
                FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME | FILE_NOTIFY_CHANGE_LAST_WRITE,
                &bytes_returned,
                &self.overlapped,
                null,
            );

            if (ok == FALSE) {
                const err = GetLastError();
                if (err != .IO_PENDING) return -1;
                self.read_pending = true;
            } else {
                return self.parseBuffer(bytes_returned);
            }
        }

        const timeout: windows.DWORD = if (blocking) INFINITE else 0;
        const wait = WaitForSingleObject(self.event_handle, timeout);
        if (wait == WAIT_TIMEOUT) return 0;
        if (wait != WAIT_OBJECT_0) return -1;

        var bytes_returned: windows.DWORD = 0;
        if (GetOverlappedResult(self.dir_handle, &self.overlapped, &bytes_returned, FALSE) == FALSE) {
            self.read_pending = false;
            return -1;
        }

        self.read_pending = false;
        return self.parseBuffer(bytes_returned);
    }

    pub fn lastEvent(self: *const Watcher) Event {
        return self.last_event;
    }

    fn parseBuffer(self: *Watcher, bytes_returned: windows.DWORD) i32 {
        if (bytes_returned == 0) return 0;

        var offset: usize = 0;
        var found = false;

        while (offset < bytes_returned) {
            const info: *const FILE_NOTIFY_INFORMATION = @ptrCast(@alignCast(self.buffer[offset..].ptr));
            const name_bytes = info.FileNameLength;
            const name_ptr: [*]const windows.WCHAR = @alignCast(@ptrCast(&self.buffer[offset + @offsetOf(FILE_NOTIFY_INFORMATION, "FileName")]));
            const name_wide: []const windows.WCHAR = name_ptr[0 .. name_bytes / 2];

            if (std.mem.eql(u16, name_wide, self.filename_utf16)) {
                self.last_event = mapAction(info.Action);
                found = true;
            }

            if (info.NextEntryOffset == 0) break;
            offset += info.NextEntryOffset;
        }

        return if (found) 1 else 0;
    }

    fn mapAction(action: windows.DWORD) Event {
        return switch (action) {
            FILE_ACTION_ADDED, FILE_ACTION_RENAMED_NEW_NAME => .created,
            FILE_ACTION_REMOVED, FILE_ACTION_RENAMED_OLD_NAME => .deleted,
            FILE_ACTION_MODIFIED => .modified,
            else => .modified,
        };
    }
};

fn splitPath(path: [:0]const u8) ?struct { dir: []const u8, base: []const u8 } {
    var last: ?usize = null;
    var i: usize = 0;
    while (i < path.len) : (i += 1) {
        if (path[i] == '/' or path[i] == '\\') last = i;
    }

    if (last) |idx| {
        if (idx + 1 >= path.len) return null;
        const dir = if (idx == 0) "/" else path[0..idx];
        return .{ .dir = dir, .base = path[idx + 1 ..] };
    }

    return .{ .dir = ".", .base = path };
}

pub const start = Watcher.start;
pub const stop = Watcher.stop;
pub const poll = Watcher.poll;
pub const lastEvent = Watcher.lastEvent;
