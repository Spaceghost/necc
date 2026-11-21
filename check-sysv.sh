#!/bin/sh
set -eu
if [ "$#" -ne 3 ]; then
    echo 'usage: check-sysv.sh NECC SYSROOT SCRATCH' >&2
    exit 2
fi
necc=$1
export NECC_SYSROOT=$2
cc=${CC:-cc}
mkdir -p "$3"
out=$(mktemp -d "$3/sysv.XXXXXXXX")
export TMPDIR=$out TMP=$out TEMP=$out
cd "$out"

cat > empty-records.c <<'C'
#include <stddef.h>
struct Empty {};
struct OtherEmpty {};
struct EmptyFirst { struct Empty empty; char value; };
struct EmptyTail { char value; struct Empty empty; };
union EmptyUnion { struct Empty empty; };
struct EmptyMixed { char first; struct Empty empty; long last; };
struct EmptySequence { void *impl; struct Empty allocator; };
_Static_assert(sizeof(struct Empty) == 0 && _Alignof(struct Empty) == 1, "GNU empty record");
_Static_assert(sizeof(struct OtherEmpty) == 0 && _Alignof(struct OtherEmpty) == 1, "distinct empty tag");
_Static_assert(sizeof(struct EmptyFirst) == 1 && _Alignof(struct EmptyFirst) == 1, "empty first member");
_Static_assert(sizeof(struct EmptyTail) == 1 && _Alignof(struct EmptyTail) == 1, "empty tail member");
_Static_assert(offsetof(struct EmptyTail, empty) == 1, "empty tail offset");
_Static_assert(sizeof(union EmptyUnion) == 0 && _Alignof(union EmptyUnion) == 1, "empty union member");
_Static_assert(sizeof(struct EmptyMixed) == 16 && _Alignof(struct EmptyMixed) == 8 &&
    offsetof(struct EmptyMixed, empty) == 1 && offsetof(struct EmptyMixed, last) == 8, "empty mixed layout");
_Static_assert(sizeof(struct EmptySequence) == 8 && _Alignof(struct EmptySequence) == 8, "empty tail does not grow pointer record");
C
"$necc" -c empty-records.c -o empty-records.o
printf '%s\n' 'struct Holder { int values[]; }; static struct Holder holder;' > incomplete-array-member.c
if "$necc" -c incomplete-array-member.c -o incomplete-array-member.o 2>error; then
    echo 'expected an incomplete array member to be rejected' >&2
    exit 1
fi
printf '%s\n' 'struct Opaque; void assign(struct Opaque *a, struct Opaque *b) { *a = *b; }' > incomplete-assignment.c
if "$necc" -c incomplete-assignment.c -o incomplete-assignment.o 2>error; then
    echo 'expected an incomplete record assignment to be rejected' >&2
    exit 1
fi
printf '%s\n' 'struct Opaque; struct Opaque value = {};' > incomplete-initializer.c
if "$necc" -c incomplete-initializer.c -o incomplete-initializer.o 2>error; then
    echo 'expected an incomplete record initializer to be rejected' >&2
    exit 1
fi

cat > empty-values.c <<'C'
struct Empty {};
struct Sequence { void *impl; struct Empty allocator; };
static int effects;
static struct Empty empty_value(int amount) {
    effects += amount;
    return (struct Empty){};
}
static int sequence_push(struct Sequence *self, struct Empty ignored, int value) {
    return self != 0 ? value : 0;
}
static struct Empty global_empty = {};
int main(void) {
    struct Sequence sequence = {0};
    struct Empty local = {};
    struct Empty *address = &local;
    local = empty_value(2);
    if (effects != 2 || address != &local) return 1;
    if (sequence_push(&sequence, empty_value(3), 42) != 42 || effects != 5) return 2;
    return sizeof(global_empty) != 0;
}
C
"$necc" -c empty-values.c -o empty-values.o
"$cc" -std=gnu11 -O2 -o empty-values-gcc empty-values.c
"$cc" -no-pie empty-values.o -o empty-values-necc
./empty-values-gcc
./empty-values-necc

cat > shared.h <<'C'
#include <stdarg.h>
#include <stddef.h>
typedef struct { unsigned char tag; double data[3]; } Row;
typedef struct { int prefix; Row rows[2]; } Table;
typedef struct { float x, y; int tag; } Vector;
typedef struct { int tag; double value; } Tagged;
typedef struct { double a, b; } Reals;
typedef struct { long a, b; } Integers;
typedef struct { unsigned char bytes[3]; } Three;
Vector vector(Vector v);
Tagged tagged(Tagged t);
Reals reals(Reals v);
Three three(Three t);
long spill_gp(long, long, long, long, long, Integers, long);
double spill_sse(double, double, double, double, double, double, double, Reals, double);
double scan(int count, ...);
double fixed(long a, double b, long c, double d, long e, double f, long g, double h,
             long i, double j, long k, double l, long m, double n, double o, double p, ...);
double real_math(double x, float y);
int forward(const char *, va_list);
int delegate(const char *, ...);
int layout(Table *, Row *);
C
cat > functions.c <<'C'
#include "shared.h"
_Static_assert(sizeof(Table) == 72 && _Alignof(Table) == 8, "table layout");
_Static_assert(0 || (1 ? 42 : 1 / 0), "unselected operand");
static const int slots[] = {[4] = 9, [1] = 4, [4] = 11};
static const Row seed = {.data = {1., 2., 3.}, .tag = 7};
Vector vector(Vector v) { v.x += 1; v.y += 2; v.tag += 3; return v; }
Tagged tagged(Tagged t) { t.tag += 4; t.value += 0.25; return t; }
Reals reals(Reals v) { return (Reals){.b = v.a, .a = v.b}; }
Three three(Three t) { t.bytes[1]++; return t; }
long spill_gp(long a, long b, long c, long d, long e, Integers t, long last) {
    return a+b+c+d+e+t.a+t.b+last;
}
double spill_sse(double a, double b, double c, double d, double e, double f,
                 double g, Reals t, double last) {
    return a+b+c+d+e+f+g+t.a+t.b+last;
}
double scan(int count, ...) {
    va_list ap, copy;
    va_start(ap, count);
    va_copy(copy, ap);
    double total = 0;
    for (int i = 0; i < count; ++i) {
        total += va_arg(ap, long);
        total += va_arg(ap, double);
    }
    if (va_arg(copy, long) != 1 || va_arg(copy, double) != 0.5) total = -1;
    va_end(copy);
    va_end(ap);
    return total;
}
double fixed(long a, double b, long c, double d, long e, double f, long g, double h,
             long i, double j, long k, double l, long m, double n, double o, double p, ...) {
    va_list ap;
    va_start(ap, p);
    long extra = va_arg(ap, long);
    double last = va_arg(ap, double);
    va_end(ap);
    return a+b+c+d+e+f+g+h+i+j+k+l+m+n+o+p+extra+last;
}
int delegate(const char *s, ...) {
    va_list ap;
    va_start(ap, s);
    int value = forward(s, ap);
    va_end(ap);
    return value;
}
int layout(Table *t, Row *out) {
    Row original = t->rows[1];
    *out = t->rows[0] = original;
    Row checked = {.data = {1., 2., 3.}, .tag = 7};
    return sizeof(Table) == 72 && offsetof(Table, rows[1].data[2]) == 64 &&
           sizeof(slots) == 5 * sizeof(int) && slots[0] == 0 && slots[1] == 4 && slots[4] == 11 &&
           seed.tag == checked.tag && seed.data[2] == checked.data[2];
}
static const float fraction = -0x1.8p-1f;
static const double large = 9223372036854775808ULL;
double real_math(double x, float y) {
    unsigned long wide = (unsigned long)(large + 2048.0);
    unsigned char byte = 255;
    if (++byte != 0 || (double)wide != large + 2048.0 || wide != 0x8000000000000800UL) return -100;
    double saved = x++;
    y += fraction;
    return (saved + --x) * y;
}
C
cat > caller.c <<'C'
#include "shared.h"
int forward(const char *s, va_list ap) {
    int i = va_arg(ap, int);
    double d = va_arg(ap, double);
    return s[0] == 'v' && i == 42 && d == 4.25;
}
int main(void) {
    Vector v = vector((Vector){1.5f, 2.5f, 7});
    if (v.x != 2.5f || v.y != 4.5f || v.tag != 10) return 7;
    Tagged t = tagged((Tagged){3, 8.5});
    if (t.tag != 7 || t.value != 8.75) return 8;
    Reals swapped = reals((Reals){3.25, 7.5});
    if (swapped.a != 7.5 || swapped.b != 3.25) return 9;
    Three bytes = three((Three){{11, 22, 33}});
    if (bytes.bytes[0] != 11 || bytes.bytes[1] != 23 || bytes.bytes[2] != 33) return 10;
    if (spill_gp(1,2,3,4,5,(Integers){6,7},8) != 36) return 11;
    if (spill_sse(1,2,3,4,5,6,7,(Reals){8,9},10) != 55) return 12;
    double (*callback)(int, ...) = scan;
    if (callback(10, 1L,.5f, 2L,1., 3L,1.5, 4L,2., 5L,2.5, 6L,3., 7L,3.5,
                     8L,4., 9L,4.5, 10L,5.) != 82.5) return 1;
    if (fixed(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17L,18.) != 171.) return 2;
    if (real_math(3., 2.75f) != 12.) return 3;
    if (!delegate("va", 42, 4.25)) return 4;
    Table table = {0, {{2, {1., 2., 3.}}, {7, {4., 5., 6.}}}};
    Row dest;
    if (!layout(&table, &dest) || dest.tag != 7 || table.rows[0].data[2] != 6.) return 5;
    double zero = 0, nan = zero / zero;
    if (!nan || nan == nan || nan < 1. || nan >= 1. || !(nan != 1.)) return 6;
    return 0;
}
C
printf '%s\n' '_Static_assert(0 && (1 / 0), "wrong target");' > wrong.c
if "$necc" -c wrong.c -o wrong.o 2>error; then exit 1; fi
grep -q 'static assertion failed.*wrong target' error
test ! -e wrong.o
for unit in functions caller; do
    "$necc" -c "$unit.c" -o "$unit-native.o"
    "$cc" -std=c11 -O2 -fno-pie -fno-stack-protector -c "$unit.c" -o "$unit-reference.o"
done
for caller in native reference; do
    for function in native reference; do
        "$necc" "caller-$caller.o" "functions-$function.o" -o exercise
        ./exercise
        printf 'SysV caller %s, callee %s passed\n' "$caller" "$function"
    done
done
