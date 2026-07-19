#include "harness.h"

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#include <io.h>
#define unlink _unlink
#define open _open
#define write _write
#define close _close
#ifndef O_WRONLY
#define O_WRONLY _O_WRONLY
#endif
#ifndef O_APPEND
#define O_APPEND _O_APPEND
#endif
#else
#include <unistd.h>
#endif

int test_modified(void) {
    char path[512];
    const int fd = make_temp_file_path(path, sizeof(path), "mod");
    if (fd < 0) {
        perror("make_temp_file_path");
        return -1;
    }
    if (write(fd, "hello", 5) != 5) {
        perror("write");
        close(fd);
        unlink(path);
        return -1;
    }
    close(fd);

    trigger_watcher_t* watcher = trigger_init(path, on_file_change);
    if (!watcher || trigger_start(watcher) != TRIGGER_OK) {
        fprintf(stderr, "failed to watch %s for modify test\n", path);
        unlink(path);
        return -1;
    }

    const int out_fd = open(path, O_WRONLY | O_APPEND);
    if (out_fd < 0) {
        perror("open");
        trigger_destroy(watcher);
        unlink(path);
        return -1;
    }
    if (write(out_fd, "!", 1) != 1) {
        perror("write");
        close(out_fd);
        trigger_destroy(watcher);
        unlink(path);
        return -1;
    }
    close(out_fd);

    const int rc = wait_for_event(watcher, TRIGGER_EVENT_MODIFIED, 5000);
    trigger_destroy(watcher);
    unlink(path);
    return rc;
}
