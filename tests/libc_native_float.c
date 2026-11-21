#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int near_reference(long double actual, long double reference, long double epsilon_count) {
    return fabsl(actual - reference) <= epsilon_count * LDBL_EPSILON * fabsl(reference);
}

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
    if (parsed != 12.0L || tail != 42) return 4;

    /* x86-64 reference values from glibc powl. Keep the inputs at runtime
       so both compilers exercise the implementation in the archive. */
    volatile long double base = 1.0001L;
    if (!near_reference(powl(base, 12345.6789L), 0xd.bf294a887f7c1acp-2L, 2.0L)) return 5;
    if (!near_reference(powl(base, 1000000.0L), 0x9.9855885231fafcep+141L, 20.0L)) return 6;
    base = 0x1.000000000000001p0L;
    return near_reference(powl(base, 0x1p63L), 0xb.a4f53ea38636f58p+8L, 2.0L) ? 0 : 7;
}
