#include <stdlib.h>
#include <unistd.h>

static void shutdown_marker(void) {
    (void)write(1, "shutdown\n", 9);
}

int main(void) {
    if (atexit(shutdown_marker) != 0) return 1;
    return 0;
}
