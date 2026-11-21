#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    char *end;
    long double adjacent = strtold("0x8.000000000000001p-3!", &end);
    if (*end != '!' || adjacent - 1.0L != 0x1p-63L) return 1;

    char formatted[80];
    int n = snprintf(formatted, sizeof formatted, "%d|%.20Lf|%d", 17, adjacent, 29);
    if (n != 28 || strcmp(formatted, "17|1.00000000000000000011|29")) return 2;

    long double parsed;
    int tail;
    if (sscanf("0x1.8p3 42", "%Lf %d", &parsed, &tail) != 2) return 3;
    return parsed == 12.0L && tail == 42 ? 0 : 4;
}
