#include "harness.h"

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <direct.h>
#include <io.h>
#include <sys/stat.h>
#define unlink _unlink
#define rmdir _rmdir
#define open _open
#define close _close
#ifndef O_CREAT
#define O_CREAT _O_CREAT
#endif
#ifndef O_WRONLY
#define O_WRONLY _O_WRONLY
#endif
#else
#include <unistd.h>
#endif

int test_created(void) {
    char dir[512];
    if (make_temp_dir(dir, sizeof(dir)) != 0) {
        perror("make_temp_dir");
        return -1;
    }

    char child[512];
    if (snprintf(child, sizeof(child), "%s/new-file", dir) >= (int)sizeof(child)) {
        fprintf(stderr, "child path too long\n");
        rmdir(dir);
        return -1;
    }

#if defined(_WIN32)
    trigger_watcher_t* watcher = trigger_init(child, on_file_change);
#else
    trigger_watcher_t* watcher = trigger_init(dir, on_file_change);
#endif
    if (!watcher || trigger_start(watcher) != TRIGGER_OK) {
        fprintf(stderr, "failed to watch for create test\n");
        rmdir(dir);
        return -1;
    }

#ifdef _WIN32
    const int fd = open(child, O_CREAT | O_WRONLY, _S_IREAD | _S_IWRITE);
#else
    const int fd = open(child, O_CREAT | O_WRONLY, 0644);
#endif
    if (fd < 0) {
        perror("open");
        trigger_destroy(watcher);
        rmdir(dir);
        return -1;
    }
    close(fd);

#if defined(__APPLE__)
    const int expected[] = { TRIGGER_EVENT_CREATED, TRIGGER_EVENT_MODIFIED };
    const int rc = wait_for_any_event(watcher, expected, 2, 5000);
#else
    const int rc = wait_for_event(watcher, TRIGGER_EVENT_CREATED, 5000);
#endif
    trigger_destroy(watcher);
    unlink(child);
    rmdir(dir);
    return rc;
}
