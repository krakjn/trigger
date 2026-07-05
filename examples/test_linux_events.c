#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "trigger.h"

static int g_last_event = 0;
static int g_callback_count = 0;

static void on_file_change(const char* filepath, int event_type) {
    (void)filepath;
    g_last_event = event_type;
    g_callback_count++;
}

static int wait_for_event(file_watcher_t* watcher, int expected, int timeout_ms) {
    g_last_event = 0;
    g_callback_count = 0;

    for (int elapsed = 0; elapsed < timeout_ms; elapsed += 10) {
        const int result = trigger_check_changes(watcher);
        if (result < 0) {
            fprintf(stderr, "trigger_check_changes failed\n");
            return -1;
        }
        if (result == 1 && g_last_event == expected) {
            return 0;
        }
        usleep(10000);
    }

    fprintf(
        stderr,
        "timeout waiting for %s, last event was %s (%d callbacks)\n",
        trigger_get_event_string(expected),
        trigger_get_event_string(g_last_event),
        g_callback_count
    );
    return -1;
}

static int test_modified(void) {
    char path[] = "/tmp/trigger-test-mod-XXXXXX";
    const int fd = mkstemp(path);
    if (fd < 0) {
        perror("mkstemp");
        return -1;
    }
    if (write(fd, "hello", 5) != 5) {
        perror("write");
        close(fd);
        unlink(path);
        return -1;
    }
    close(fd);

    file_watcher_t* watcher = trigger_create_watcher(path, on_file_change);
    if (!watcher || trigger_start_watching(watcher) != 0) {
        fprintf(stderr, "failed to watch %s for modify test\n", path);
        unlink(path);
        return -1;
    }

    const int out_fd = open(path, O_WRONLY | O_APPEND);
    if (out_fd < 0) {
        perror("open");
        trigger_destroy_watcher(watcher);
        unlink(path);
        return -1;
    }
    if (write(out_fd, "!", 1) != 1) {
        perror("write");
        close(out_fd);
        trigger_destroy_watcher(watcher);
        unlink(path);
        return -1;
    }
    close(out_fd);

    const int rc = wait_for_event(watcher, FILE_EVENT_MODIFIED, 5000);
    trigger_destroy_watcher(watcher);
    unlink(path);
    return rc;
}

static int test_deleted(void) {
    char path[] = "/tmp/trigger-test-del-XXXXXX";
    const int fd = mkstemp(path);
    if (fd < 0) {
        perror("mkstemp");
        return -1;
    }
    close(fd);

    file_watcher_t* watcher = trigger_create_watcher(path, on_file_change);
    if (!watcher || trigger_start_watching(watcher) != 0) {
        fprintf(stderr, "failed to watch %s for delete test\n", path);
        unlink(path);
        return -1;
    }

    if (unlink(path) != 0) {
        perror("unlink");
        trigger_destroy_watcher(watcher);
        return -1;
    }

    const int rc = wait_for_event(watcher, FILE_EVENT_DELETED, 5000);
    trigger_destroy_watcher(watcher);
    return rc;
}

static int test_created(void) {
    char dir[] = "/tmp/trigger-test-dir-XXXXXX";
    if (!mkdtemp(dir)) {
        perror("mkdtemp");
        return -1;
    }

    char child[512];
    if (snprintf(child, sizeof(child), "%s/new-file", dir) >= (int)sizeof(child)) {
        fprintf(stderr, "child path too long\n");
        rmdir(dir);
        return -1;
    }

    file_watcher_t* watcher = trigger_create_watcher(dir, on_file_change);
    if (!watcher || trigger_start_watching(watcher) != 0) {
        fprintf(stderr, "failed to watch %s for create test\n", dir);
        rmdir(dir);
        return -1;
    }

    const int fd = open(child, O_CREAT | O_WRONLY, 0644);
    if (fd < 0) {
        perror("open");
        trigger_destroy_watcher(watcher);
        rmdir(dir);
        return -1;
    }
    close(fd);

    const int rc = wait_for_event(watcher, FILE_EVENT_CREATED, 5000);
    trigger_destroy_watcher(watcher);
    unlink(child);
    rmdir(dir);
    return rc;
}

typedef int (*test_fn)(void);

static const struct {
    const char* name;
    test_fn run;
} tests[] = {
    { "modified", test_modified },
    { "deleted", test_deleted },
    { "created", test_created },
};

int main(void) {
    int failed = 0;

    for (size_t i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        printf("running %s... ", tests[i].name);
        fflush(stdout);

        if (tests[i].run() == 0) {
            printf("ok\n");
        } else {
            printf("FAIL\n");
            failed++;
        }
    }

    if (failed != 0) {
        fprintf(stderr, "%d test(s) failed\n", failed);
        return 1;
    }

    printf("all %zu linux event tests passed\n", sizeof(tests) / sizeof(tests[0]));
    return 0;
}
