# Get Triggered

A cross-platform C library for watching files and calling callbacks when events occur.

## Features

- **Cross-platform**: Linux (inotify), macOS (kqueue), Windows (`ReadDirectoryChangesW`)
- **Simple API**: Callback-based interface
- **Event types**: Modifications, creations, deletions
- **Blocking and non-blocking**: `trigger_wait_for_changes` or `trigger_check_changes`

## Building

```bash
zig build
```

Cross-compile all library targets:

```bash
zig build cross
```

Static library:

```bash
zig build -Dstatic=true
```

Artifacts install to `zig-out/lib/` and `zig-out/include/trigger.h`.

## Examples

Four example programs live in [`examples/`](examples/). Build them with `zig build`; binaries are in `zig-out/bin/`.

| Binary | Pattern |
|--------|---------|
| `single_thread_one_watcher` | One thread, one file, blocking wait |
| `single_thread_multi_watcher` | One thread polls many watchers |
| `multi_thread_one_watcher` | Dedicated watcher thread + event queue (POSIX) |
| `multi_thread_multi_watcher` | One thread per watcher (POSIX) |

See [`examples/README.md`](examples/README.md) for usage.

```bash
zig-out/bin/single_thread_one_watcher /tmp/test.txt
# in another terminal:
echo hello >> /tmp/test.txt
```

## API Reference

### Functions

- `trigger_create_watcher(filepath, callback)` — create a watcher
- `trigger_start_watching(watcher)` — start watching (`0` ok, `-1` error)
- `trigger_stop_watching(watcher)` — stop watching
- `trigger_check_changes(watcher)` — non-blocking poll (`1` event, `0` none, `-1` error)
- `trigger_wait_for_changes(watcher)` — blocking wait (same return codes)
- `trigger_destroy_watcher(watcher)` — free the watcher
- `trigger_get_event_string(event_type)` — `"MODIFIED"`, `"CREATED"`, `"DELETED"`, or `"UNKNOWN"`

### Event types

- `FILE_EVENT_MODIFIED`
- `FILE_EVENT_CREATED`
- `FILE_EVENT_DELETED`

### Callback

```c
typedef void (*file_change_callback_t)(const char* filepath, int event_type);
```

The callback runs on the thread that called `trigger_check_changes` or `trigger_wait_for_changes`.

## Thread safety

The library does **not** use internal locking. Each `file_watcher_t` must be driven from **one thread** for its entire lifetime.

| Pattern | Supported? |
|---------|------------|
| One thread owns one watcher | Yes |
| One thread polls many watchers (`trigger_check_changes` loop) | Yes |
| Different watchers on different threads (one watcher per thread) | Yes |
| Dedicated watcher thread; other threads consume events via your own queue | Yes (application pattern) |
| Two or more threads calling `trigger_*` on the **same** watcher | **No** |
| `trigger_destroy_watcher` while another thread is in `trigger_wait_for_changes` | **No** |
| Calling `trigger_*` on the same watcher from inside its callback | **No** |

Example mapping:

1. **Single-thread, single watcher** → `single_thread_one_watcher`
2. **Single-thread, multi watcher** → `single_thread_multi_watcher`
3. **Multi-thread, single watcher** → `multi_thread_one_watcher` (only the watcher thread touches the API)
4. **Multi-thread, multi watcher** → `multi_thread_multi_watcher`

### Anti-patterns

**Two threads, one watcher** — undefined behavior; OS handles are not shared this way.

```c
// Thread A                          Thread B
trigger_wait_for_changes(w);         trigger_stop_watching(w);  // race
```

**Destroy while waiting** — use-after-free risk; blocked `wait` is not woken up.

```c
// Thread A: trigger_wait_for_changes(w);  (blocked)
// Thread B: trigger_destroy_watcher(w);
```

**Re-enter from callback** — callback runs on the waiter thread; nested calls deadlock or corrupt state.

```c
void on_change(const char* path, int type) {
    trigger_check_changes(watcher);  // do not do this
}
```

**Shared global watcher** — multiple threads calling `trigger_check_changes(same_w)` is not supported.

Full per-watcher thread safety (including safe destroy-during-wait) may be added in a future release; it is not in scope today.

## Platform support

| OS | Backend |
|----|---------|
| Linux | inotify |
| macOS | kqueue |
| Windows | `ReadDirectoryChangesW` (watches parent directory, filters by filename) |

## Error handling

- `0` — success (start/stop)
- `-1` — error
- `1` — change detected (`check` / `wait`)
