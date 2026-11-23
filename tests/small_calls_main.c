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
extern int always_left(int), always_right(int), choose_twice(int, unsigned);
int on_left(int n) { return n + 2; }
int on_right(int n) { return n * 3; }
int main(void) {
    assert(always_left(5) == 7 && always_right(5) == 15);
    assert(choose_twice(5, 3U) == 9 && choose_twice(5, 4U) == 45);
    assert(empty_calls(23) == 63 && visits == 2);
    long guard = 1234567890123L;
    long expected = combine(guard + 30, -123, 0xfedcba98U, guard, 17U, -9) + 6 + guard;
    assert(small_calls(&guard, -123, 0xfedcba98U) == expected);
    assert(guard == 1234567890123L);
}
