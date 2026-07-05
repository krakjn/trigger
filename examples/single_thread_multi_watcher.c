#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "trigger.h"

typedef struct {
    file_watcher_t* watcher;
    const char* path;
} watched_file_t;

static void on_file_change(const char* filepath, int event_type) {
    printf("File '%s' was %s\n", filepath, trigger_get_event_string(event_type));
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <file1> [file2 ...]\n", argv[0]);
        return 1;
    }

    int count = argc - 1;
    watched_file_t* files = calloc((size_t)count, sizeof(watched_file_t));
    if (!files) {
        fprintf(stderr, "Out of memory\n");
        return 1;
    }

    for (int i = 0; i < count; i++) {
        files[i].path = argv[i + 1];
        files[i].watcher = trigger_create_watcher(files[i].path, on_file_change);
        if (!files[i].watcher) {
            fprintf(stderr, "Failed to create watcher for '%s'\n", files[i].path);
            goto cleanup;
        }
        if (trigger_start_watching(files[i].watcher) != 0) {
            fprintf(stderr, "Failed to start watching '%s'\n", files[i].path);
            goto cleanup;
        }
        printf("Watching %s\n", files[i].path);
    }

    printf("Polling %d files (single thread, multi watcher). Ctrl+C to stop.\n", count);

    while (1) {
        for (int i = 0; i < count; i++) {
            int result = trigger_check_changes(files[i].watcher);
            if (result < 0) {
                fprintf(stderr, "Error checking '%s'\n", files[i].path);
                goto cleanup;
            }
        }
        usleep(100000);
    }

cleanup:
    for (int i = 0; i < count; i++) {
        if (files[i].watcher) {
            trigger_destroy_watcher(files[i].watcher);
        }
    }
    free(files);
    return 0;
}
