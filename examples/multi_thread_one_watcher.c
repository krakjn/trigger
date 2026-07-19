#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "trigger.h"

#define QUEUE_CAP 64

typedef struct {
    char path[4096];
    int event_type;
} queued_event_t;

typedef struct {
    queued_event_t items[QUEUE_CAP];
    size_t head;
    size_t tail;
    size_t len;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
} event_queue_t;

static event_queue_t g_queue;
static volatile int g_shutdown = 0;
static trigger_watcher_t* g_watcher = NULL;

static const char* event_name(int event_type) {
    switch (event_type) {
        case TRIGGER_EVENT_MODIFIED: return "MODIFIED";
        case TRIGGER_EVENT_CREATED: return "CREATED";
        case TRIGGER_EVENT_DELETED: return "DELETED";
        default: return "UNKNOWN";
    }
}

static void queue_push(const char* path, int event_type) {
    pthread_mutex_lock(&g_queue.mutex);
    if (g_queue.len < QUEUE_CAP) {
        queued_event_t* slot = &g_queue.items[g_queue.tail];
        strncpy(slot->path, path, sizeof(slot->path) - 1);
        slot->path[sizeof(slot->path) - 1] = '\0';
        slot->event_type = event_type;
        g_queue.tail = (g_queue.tail + 1) % QUEUE_CAP;
        g_queue.len++;
        pthread_cond_signal(&g_queue.cond);
    }
    pthread_mutex_unlock(&g_queue.mutex);
}

static int queue_pop(queued_event_t* out) {
    pthread_mutex_lock(&g_queue.mutex);
    while (g_queue.len == 0 && !g_shutdown) {
        pthread_cond_wait(&g_queue.cond, &g_queue.mutex);
    }
    if (g_queue.len == 0) {
        pthread_mutex_unlock(&g_queue.mutex);
        return 0;
    }
    *out = g_queue.items[g_queue.head];
    g_queue.head = (g_queue.head + 1) % QUEUE_CAP;
    g_queue.len--;
    pthread_mutex_unlock(&g_queue.mutex);
    return 1;
}

static void on_file_change(const char* filepath, int event_type) {
    queue_push(filepath, event_type);
}

static void* watcher_thread_main(void* arg) {
    const char* path = (const char*)arg;

    g_watcher = trigger_init(path, on_file_change);
    if (!g_watcher || trigger_start(g_watcher) != TRIGGER_OK) {
        fprintf(stderr, "Watcher thread failed to start on '%s'\n", path);
        g_shutdown = 1;
        pthread_cond_broadcast(&g_queue.cond);
        return NULL;
    }

    while (!g_shutdown) {
        TRIGGER_RESULT result = trigger_recv(g_watcher);
        if (result == TRIGGER_ERROR) {
            break;
        }
    }

    trigger_stop(g_watcher);
    trigger_destroy(g_watcher);
    g_watcher = NULL;
    g_shutdown = 1;
    pthread_cond_broadcast(&g_queue.cond);
    return NULL;
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <filepath>\n", argv[0]);
        return 1;
    }

    pthread_mutex_init(&g_queue.mutex, NULL);
    pthread_cond_init(&g_queue.cond, NULL);

    pthread_t watcher_thread;
    if (pthread_create(&watcher_thread, NULL, watcher_thread_main, argv[1]) != 0) {
        fprintf(stderr, "Failed to create watcher thread\n");
        return 1;
    }

    printf("Watching %s (dedicated watcher thread). Ctrl+C to stop.\n", argv[1]);

    queued_event_t event;
    while (queue_pop(&event)) {
        printf("File '%s' was %s\n", event.path, event_name(event.event_type));
    }

    pthread_join(watcher_thread, NULL);
    pthread_mutex_destroy(&g_queue.mutex);
    pthread_cond_destroy(&g_queue.cond);
    return 0;
}
