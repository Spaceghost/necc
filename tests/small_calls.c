extern long observe(long *);
extern long combine(long, int, unsigned, long, unsigned, int);
static long read_local(long n) {
    long value = n + 3;
    return observe(&value);
}
static long conditional(long n) {
    return n < 0 ? -n : n;
}
static long seventh(long a, long b, long c, long d, long e, long f, long g) {
    return g - a;
}
long small_calls(long *guard, int i, unsigned u) {
    long saved = *guard;
    long first = read_local(saved);
    long second = read_local(first);
    long (*volatile indirect)(long) = read_local;
    long third = indirect(second);
    return combine(conditional(-third), i, u, saved, 17U, -9)
         + seventh(1,2,3,4,5,6,7) + *guard;
}

/* An empty SysV argument still evaluates its expression. It occupies no ABI
   register and can leave instructions between two apparent scalar arguments. */
struct Empty { };
extern struct Empty note_empty(void);
extern long accept_empty(long, struct Empty, long, struct Empty);
long empty_calls(long n) {
    return accept_empty(n, note_empty(), 17, note_empty());
}

extern int on_left(int);
extern int on_right(int);
static int choose(int value, unsigned mode) {
    if (mode == 3U) return on_left(value);
    return on_right(value);
}
int always_left(int n) { return choose(n, 3U); }
int always_right(int n) { return choose(n, 4U); }
int choose_twice(int n, unsigned mode) {
    int first = choose(n, mode);
    return choose(first, mode);
}
