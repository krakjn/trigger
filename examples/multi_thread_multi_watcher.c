#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include "trigger.h"

typedef struct {
    const char* path;
    int index;
} worker_arg_t;

static void on_file_change(const char* filepath, int event_type) {
    printf("[thread] File '%s' was %s\n", filepath, trigger_get_event_string(event_type));
}

static void* worker_main(void* arg) {
    worker_arg_t* warg = (worker_arg_t*)arg;
    file_watcher_t* watcher = trigger_create_watcher(warg->path, on_file_change);
    if (!watcher) {
        fprintf(stderr, "Worker %d: failed to create watcher for '%s'\n", warg->index, warg->path);
        return NULL;
    }

    if (trigger_start_watching(watcher) != 0) {
        fprintf(stderr, "Worker %d: failed to start watching '%s'\n", warg->index, warg->path);
        trigger_destroy_watcher(watcher);
        return NULL;
    }

    printf("Worker %d watching %s\n", warg->index, warg->path);

    while (1) {
        int result = trigger_wait_for_changes(watcher);
        if (result < 0) {
            break;
        }
    }

    trigger_destroy_watcher(watcher);
    return NULL;
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <file1> <file2> [...]\n", argv[0]);
        return 1;
    }

    int count = argc - 1;
    pthread_t* threads = calloc((size_t)count, sizeof(pthread_t));
    worker_arg_t* args = calloc((size_t)count, sizeof(worker_arg_t));
    if (!threads || !args) {
        fprintf(stderr, "Out of memory\n");
        free(threads);
        free(args);
        return 1;
    }

    for (int i = 0; i < count; i++) {
        args[i].path = argv[i + 1];
        args[i].index = i;
        if (pthread_create(&threads[i], NULL, worker_main, &args[i]) != 0) {
            fprintf(stderr, "Failed to create worker thread %d\n", i);
            count = i;
            break;
        }
    }

    printf("Watching %d files (one thread per watcher). Modify files to see events. Ctrl+C to stop.\n", count);

    for (int i = 0; i < count; i++) {
        pthread_join(threads[i], NULL);
    }

    free(threads);
    free(args);
    return 0;
}
