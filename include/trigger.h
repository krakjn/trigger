#ifndef TRIGGER_H
#define TRIGGER_H
// Get triggered
// ▗   ▘
// ▜▘▛▘▌▛▌▛▌█▌▛▘
// ▐▖▌ ▌▙▌▙▌▙▖▌
//      ▄▌▄▌
#ifdef __cplusplus
extern "C" {
#endif

// Thread safety:
//   - Each trigger_watcher_t must be owned by a single thread for its entire lifetime.
//   - Do not call trigger_* on the same watcher from multiple threads concurrently.
//   - Different watchers may be used on different threads (one watcher per thread).
//   - Callbacks run on the thread that called trigger_try_recv or trigger_recv;
//     do not re-enter the same watcher from a callback.

// Callback function type for file changes
typedef void (*trigger_callback_t)(const char* filepath, int event_type);

typedef enum {
    TRIGGER_OK = 0,
    TRIGGER_ERROR = -1,
    TRIGGER_EVENT_MODIFIED = 1,
    TRIGGER_EVENT_CREATED = 2,
    TRIGGER_EVENT_DELETED = 3,
} TRIGGER_RESULT;

// *Intentional* opaque watcher handle.
//
// The struct is incomplete here on purpose: callers only ever hold a pointer,
// so the library can change layout, size, and platform-specific state without
// breaking the C ABI. Do not cast this pointer or depend on its size.
//
// Conceptual fields (implementation detail — not accessible from C):
//   filepath        - owned null-terminated path being watched
//   callback        - user function pointer called when an event is received
//   is_watching     - [bool] whether the platform watch is currently active
//   platform_state  - OS-specific watch state (inotify, FSEvents, etc.)
//
// Defined in Zig as `trigger_watcher` in src/watcher.zig.
typedef struct trigger_watcher trigger_watcher_t;

// Initialize a new file watcher
// Returns a pointer to the watcher handle, or NULL if an error occurred
trigger_watcher_t* trigger_init(const char* filepath, trigger_callback_t callback);

// Start polling for file changes
TRIGGER_RESULT trigger_start(trigger_watcher_t* watcher);

// Stop polling for file changes
TRIGGER_RESULT trigger_stop(trigger_watcher_t* watcher);

// Try to receive a file change event (non-blocking)
TRIGGER_RESULT trigger_try_recv(trigger_watcher_t* watcher);

// Receive a file change event (blocking)
TRIGGER_RESULT trigger_recv(trigger_watcher_t* watcher);

// Clean up the watcher
TRIGGER_RESULT trigger_destroy(trigger_watcher_t* watcher);

#ifdef __cplusplus
}
#endif

#endif // TRIGGER_H
