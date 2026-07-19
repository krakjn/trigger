#ifndef TRIGGER_TEST_HARNESS_H
#define TRIGGER_TEST_HARNESS_H

#include <stddef.h>
#include "trigger.h"

typedef int (*test_fn)(void);

typedef struct {
    const char* name;
    test_fn run;
} test_case_t;

void on_file_change(const char* filepath, int event_type);
int wait_for_event(trigger_watcher_t* watcher, int expected, int timeout_ms);
int wait_for_any_event(trigger_watcher_t* watcher, const int* expected, size_t count, int timeout_ms);
int make_temp_file_path(char* path, size_t cap, const char* tag);
int make_temp_dir(char* path, size_t cap);
int run_tests(const char* platform, const test_case_t* cases, size_t count);

#endif
