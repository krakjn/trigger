#include "harness.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <direct.h>
#include <errno.h>
#include <fcntl.h>
#include <io.h>
#include <windows.h>
static void sleep_ms(int ms) {
    Sleep((DWORD)ms);
}
#else
#include <unistd.h>
static void sleep_ms(int ms) {
    usleep((useconds_t)ms * 1000);
}
#endif

static int g_last_event = 0;
static int g_callback_count = 0;

static const char* event_name(int event_type) {
    switch (event_type) {
        case TRIGGER_EVENT_MODIFIED: return "MODIFIED";
        case TRIGGER_EVENT_CREATED: return "CREATED";
        case TRIGGER_EVENT_DELETED: return "DELETED";
        default: return "UNKNOWN";
    }
}

void on_file_change(const char* filepath, int event_type) {
    (void)filepath;
    g_last_event = event_type;
    g_callback_count++;
}

int wait_for_event(trigger_watcher_t* watcher, int expected, int timeout_ms) {
    g_last_event = 0;
    g_callback_count = 0;

    for (int elapsed = 0; elapsed < timeout_ms; elapsed += 10) {
        const TRIGGER_RESULT result = trigger_try_recv(watcher);
        if (result == TRIGGER_ERROR) {
            fprintf(stderr, "trigger_try_recv failed\n");
            return -1;
        }
        if (result != TRIGGER_OK && g_last_event == expected) {
            return 0;
        }
        sleep_ms(10);
    }

    fprintf(
        stderr,
        "timeout waiting for %s, last event was %s (%d callbacks)\n",
        event_name(expected),
        event_name(g_last_event),
        g_callback_count
    );
    return -1;
}

int wait_for_any_event(trigger_watcher_t* watcher, const int* expected, size_t count, int timeout_ms) {
    g_last_event = 0;
    g_callback_count = 0;

    for (int elapsed = 0; elapsed < timeout_ms; elapsed += 10) {
        const TRIGGER_RESULT result = trigger_try_recv(watcher);
        if (result == TRIGGER_ERROR) {
            fprintf(stderr, "trigger_try_recv failed\n");
            return -1;
        }
        if (result != TRIGGER_OK) {
            for (size_t i = 0; i < count; i++) {
                if (g_last_event == expected[i]) {
                    return 0;
                }
            }
        }
        sleep_ms(10);
    }

    fprintf(
        stderr,
        "timeout waiting for event, last event was %s (%d callbacks)\n",
        event_name(g_last_event),
        g_callback_count
    );
    return -1;
}

int make_temp_file_path(char* path, size_t cap, const char* tag) {
#ifdef _WIN32
    char tmp_dir[MAX_PATH];
    char tmp_file[MAX_PATH];
    (void)tag;
    if (GetTempPathA(sizeof(tmp_dir), tmp_dir) == 0) {
        return -1;
    }
    if (GetTempFileNameA(tmp_dir, "trg", 0, tmp_file) == 0) {
        return -1;
    }
    if (snprintf(path, cap, "%s", tmp_file) >= (int)cap) {
        _unlink(tmp_file);
        return -1;
    }
    return _open(path, _O_RDWR | _O_BINARY);
#else
    if (snprintf(path, cap, "/tmp/trigger-%s-XXXXXX", tag) >= (int)cap) {
        return -1;
    }
    return mkstemp(path);
#endif
}

int make_temp_dir(char* path, size_t cap) {
#ifdef _WIN32
    char tmp_dir[MAX_PATH];
    if (GetTempPathA(sizeof(tmp_dir), tmp_dir) == 0) {
        return -1;
    }
    for (unsigned attempt = 0; attempt < 100; attempt++) {
        if (snprintf(path, cap, "%strigger-dir-%08x", tmp_dir, (unsigned)(GetTickCount() ^ attempt)) >= (int)cap) {
            return -1;
        }
        if (_mkdir(path) == 0) {
            return 0;
        }
        if (errno != EEXIST) {
            return -1;
        }
    }
    return -1;
#else
    if (snprintf(path, cap, "/tmp/trigger-dir-XXXXXX") >= (int)cap) {
        return -1;
    }
    return mkdtemp(path) ? 0 : -1;
#endif
}

int run_tests(const char* platform, const test_case_t* cases, size_t count) {
    int failed = 0;

    for (size_t i = 0; i < count; i++) {
        printf("[%s] running %s... ", platform, cases[i].name);
        fflush(stdout);

        if (cases[i].run() == 0) {
            printf("ok\n");
        } else {
            printf("FAIL\n");
            failed++;
        }
    }

    if (failed != 0) {
        fprintf(stderr, "%d %s test(s) failed\n", failed, platform);
        return 1;
    }

    printf("all %zu %s file event tests passed\n", count, platform);
    return 0;
}
