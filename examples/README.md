# Examples

Four programs demonstrating supported usage patterns. See the root [README](../README.md) for thread-safety rules and anti-patterns.

| Binary | Threads | Watchers | Pattern |
|--------|---------|----------|---------|
| `single_thread_one_watcher` | 1 | 1 | Blocking wait loop |
| `single_thread_multi_watcher` | 1 | N | Round-robin `trigger_check_changes` |
| `multi_thread_one_watcher` | 2+ | 1 | Dedicated watcher thread + event queue |
| `multi_thread_multi_watcher` | N | N | One pthread owns each watcher |

Build all examples:

```bash
zig build
```

Binaries are installed to `zig-out/bin/`.

## single_thread_one_watcher

```bash
zig-out/bin/single_thread_one_watcher /tmp/test.txt
```

## single_thread_multi_watcher

```bash
zig-out/bin/single_thread_multi_watcher /tmp/a.txt /tmp/b.txt
```

## multi_thread_one_watcher

Only the watcher thread calls `trigger_*`. The main thread prints events from a queue.

```bash
zig-out/bin/multi_thread_one_watcher /tmp/test.txt
```

Requires POSIX (`pthread`). Not built on Windows targets.

## multi_thread_multi_watcher

Each worker thread creates, watches, and destroys its own watcher.

```bash
zig-out/bin/multi_thread_multi_watcher /tmp/a.txt /tmp/b.txt
```

Requires POSIX (`pthread`). Not built on Windows targets.

## Linux event tests

Integration tests verify that inotify events (`modified`, `created`, `deleted`) reach callbacks. Linux only.

Build and run locally:

```bash
zig build test
```

Run in Docker (requires `just img` first):

```bash
just test-linux
```

The test binary is `zig-out/bin/test_linux_events`.

## Unsupported

Do not call `trigger_*` on the same watcher from multiple threads concurrently. See root README anti-patterns.
