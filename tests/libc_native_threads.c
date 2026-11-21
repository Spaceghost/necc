#include <pthread.h>
#include <stdio.h>
#include <unistd.h>

static int worker_ok;

static void *try_locked_stream(void *unused) {
    if (ftrylockfile(stdout) == 0) {
        funlockfile(stdout);
        return NULL;
    }
    /* Keep every UID unchanged while exercising synchronization with the
       parent thread in pthread_join. This also works without privileges. */
    if (setreuid((uid_t)-1, (uid_t)-1) != 0) return NULL;
    return &worker_ok;
}

static void *try_unlocked_stream(void *unused) {
    if (ftrylockfile(stdout) != 0) return NULL;
    funlockfile(stdout);
    return &worker_ok;
}

int main(void) {
    pthread_t thread;
    void *result;
    flockfile(stdout);
    if (ftrylockfile(stdout) != 0) return 1;
    funlockfile(stdout);
    if (pthread_create(&thread, NULL, try_locked_stream, NULL) != 0) return 2;
    if (pthread_join(thread, &result) != 0 || result != &worker_ok) return 3;
    funlockfile(stdout);
    if (pthread_create(&thread, NULL, try_unlocked_stream, NULL) != 0) return 4;
    if (pthread_join(thread, &result) != 0 || result != &worker_ok) return 5;
    return 0;
}
