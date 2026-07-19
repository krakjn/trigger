#include <stdio.h>
#include <stdlib.h>
#include "trigger.h"

static const char* event_name(int event_type) {
    switch (event_type) {
        case TRIGGER_EVENT_MODIFIED: return "MODIFIED";
        case TRIGGER_EVENT_CREATED: return "CREATED";
        case TRIGGER_EVENT_DELETED: return "DELETED";
        default: return "UNKNOWN";
    }
}

static void on_file_change(const char* filepath, int event_type) {
    printf("File '%s' was %s\n", filepath, event_name(event_type));
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <filepath>\n", argv[0]);
        return 1;
    }

    trigger_watcher_t* watcher = trigger_init(argv[1], on_file_change);
    if (!watcher) {
        fprintf(stderr, "Failed to create file watcher\n");
        return 1;
    }

    if (trigger_start(watcher) != TRIGGER_OK) {
        fprintf(stderr, "Failed to start watching '%s'\n", argv[1]);
        trigger_destroy(watcher);
        return 1;
    }

    printf("Watching %s (single thread, single watcher). Ctrl+C to stop.\n", argv[1]);

    while (1) {
        TRIGGER_RESULT result = trigger_recv(watcher);
        if (result == TRIGGER_ERROR) {
            fprintf(stderr, "Error waiting for changes\n");
            break;
        }
    }

    trigger_destroy(watcher);
    return 0;
}
