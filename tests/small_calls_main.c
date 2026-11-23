#include <assert.h>
extern long small_calls(long *, int, unsigned);
long observe(long *value) {
    *value += 7;
    return *value;
}
long combine(long a, int b, unsigned c, long d, unsigned e, int f) {
    return a + 2L*b + 3L*c + 5*d + 7L*e + 11L*f;
}
extern long empty_calls(long);
struct Empty { };
static int visits;
struct Empty note_empty(void) {
    ++visits;
    return (struct Empty){};
}
long accept_empty(long a, struct Empty x, long b, struct Empty y) {
    (void)x;
    (void)y;
    return 2*a + b;
}
int main(void) {
    assert(empty_calls(23) == 63 && visits == 2);
    long guard = 1234567890123L;
    long expected = combine(guard + 30, -123, 0xfedcba98U, guard, 17U, -9) + 6 + guard;
    assert(small_calls(&guard, -123, 0xfedcba98U) == expected);
    assert(guard == 1234567890123L);
}
