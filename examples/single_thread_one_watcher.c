#include <stdio.h>
#include <stdlib.h>
#include "trigger.h"

static void on_file_change(const char* filepath, int event_type) {
    printf("File '%s' was %s\n", filepath, trigger_get_event_string(event_type));
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <filepath>\n", argv[0]);
        return 1;
    }

    file_watcher_t* watcher = trigger_create_watcher(argv[1], on_file_change);
    if (!watcher) {
        fprintf(stderr, "Failed to create file watcher\n");
        return 1;
    }

    if (trigger_start_watching(watcher) != 0) {
        fprintf(stderr, "Failed to start watching '%s'\n", argv[1]);
        trigger_destroy_watcher(watcher);
        return 1;
    }

    printf("Watching %s (single thread, single watcher). Ctrl+C to stop.\n", argv[1]);

    while (1) {
        int result = trigger_wait_for_changes(watcher);
        if (result < 0) {
            fprintf(stderr, "Error waiting for changes\n");
            break;
        }
    }

    trigger_destroy_watcher(watcher);
    return 0;
}
