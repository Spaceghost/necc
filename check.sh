#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    echo 'usage: check.sh NECC NELIBC_ARCHIVE SCRATCH' >&2
    exit 2
fi
necc=$1
archive=$2
mkdir -p "$3"
out=$(mktemp -d "$3/necc.XXXXXXXX")
cc=${CC:-cc}
as=${AS:-as}
ld=${LD:-ld}
export TMPDIR=$out TMP=$out TEMP=$out
repo=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

cat > "$out/abi.c" <<'C'
/* Exercise System V arguments, calls inside expressions,
   int division and remainder, and libc linkage. */
extern int abs(int);
int sum(int, int, int, int, int, int);
int sum(int a, int b, int c, int d, int e, int f) {
    int ab = a + b;
    return ab + c + d + e + f;
}
int power(int base, int exponent) {
    int value = 1;
    while (exponent > 0) {
        value = value * base;
        exponent = exponent - 1;
    }
    if (value > 0) return value;
    else return 0;
}
static long wide(long value, int factor) {
    value += 3000000000L;
    return value * factor / 3L;
}
int main(void) {
    long extended = wide(-14L, 3);
    if (2147483648 != 2147483648L) return 99;
    long high = 4294967296L;
    int narrowing = high;
    int value = 20 - (sum(1, 2, 3, 4, 5, abs(-6)) - 4);
    int check = (-20 / 3 == -6) + (-20 % 3 == -2) + (3 != 4);
    int relations = (4 > 1) + (1 < 4) + (4 >= 4) + (4 <= 4) + !0;
    return value * power(3, 2) + check + relations + (extended != 2999999986L) + narrowing; // 35
}
C
"$necc" "$out/abi.c" -o "$out/abi.s"
"$as" --64 "$out/abi.s" -o "$out/abi.o"
set --
if [ -n "${NECC_SYSROOT:-}" ] && [ -r "$NECC_SYSROOT/tcc/libtcc1.a" ]; then
    set -- "$NECC_SYSROOT/tcc/libtcc1.a"
fi
"$ld" -m elf_x86_64 -static -e _start "$out/abi.o" \
    --whole-archive "$archive" --no-whole-archive "$@" -o "$out/abi"
"$cc" -std=c11 -Wall -Wextra -Werror "$out/abi.c" -o "$out/reference"
expected=0
actual=0
"$out/reference" || expected=$?
"$out/abi" || actual=$?
test "$expected" -eq 35
test "$actual" -eq "$expected"
test -z "$(nm -u "$out/abi")"

cat > "$out/static-address.c" <<'C'
struct Leaf { int values[3]; char tail; };
struct Node { char tag; struct Leaf leaves[2]; int end; };
static struct Node node = {
    17,
    {{{0, 0, 0}, 0}, {{23, 0, 42}, 0}},
    61
};
static int *nested_address = &node.leaves[1].values[2];
static char *field_address = &node.tag;
static int *decayed_array = node.leaves[1].values;
static int *one_past = &node.leaves[1].values[3];
static void *cast_address = (void *)(&node.end);
static void *null_address = (void *)0;
struct StringView { unsigned char *bytes; unsigned long size; };
static struct StringView names[] = {{(unsigned char *)"ab" "cd", 4}};
static unsigned char *representation = (unsigned char *)&node.leaves[1].values[2];
int main(void) {
    return *nested_address != 42
        || *field_address != 17
        || *decayed_array != 23
        || one_past != &node.leaves[1].values[3]
        || cast_address != &node.end
        || null_address != 0
        || names[0].size != 4 || names[0].bytes[3] != 'd'
        || representation != (unsigned char *)nested_address;
}
C
"$necc" "$out/static-address.c" -o "$out/static-address.s"
"$as" --64 "$out/static-address.s" -o "$out/static-address.o"
"$ld" -m elf_x86_64 -static -e _start "$out/static-address.o" \
    --whole-archive "$archive" --no-whole-archive "$@" -o "$out/static-address"
"$cc" -std=c11 -Wall -Wextra -Werror "$out/static-address.c" -o "$out/static-address-reference"
"$out/static-address-reference"
"$out/static-address"

cat > "$out/static-address-extern.c" <<'C'
extern int external_values[];
int *external_second = &external_values[2];
C
"$necc" "$out/static-address-extern.c" -o "$out/static-address-extern.s"
"$as" --64 "$out/static-address-extern.s" -o "$out/static-address-extern.o"
readelf -rW "$out/static-address-extern.o" | grep -E 'external_values \+ 8$' >/dev/null
"$cc" -std=c11 -Wall -Wextra -Werror -c "$out/static-address-extern.c" -o "$out/static-address-extern-reference.o"
readelf -rW "$out/static-address-extern-reference.o" | grep -E 'external_values \+ 8$' >/dev/null

reject_static_address() {
    name=$1
    source=$2
    printf '%s\n' "$source" > "$out/$name.c"
    if "$necc" "$out/$name.c" -o "$out/$name.s" 2> "$out/$name.error"; then
        echo "expected $name to be rejected" >&2
        exit 1
    fi
}
reject_static_address invalid-member 'struct Value { int member; }; static struct Value value; static int *invalid = &value.missing;'
reject_static_address invalid-bound 'struct Value { int members[2]; }; static struct Value value; static int *invalid = &value.members[3];'
reject_static_address invalid-index 'struct Value { int members[2]; }; static struct Value value; extern int index; static int *invalid = &value.members[index];'
reject_static_address invalid-type 'struct Value { int members[2]; }; static struct Value value; static char *invalid = &value.members[0];'
reject_static_address implicit-string-type 'static unsigned char *bad = "bytes";'
reject_static_address cast-result-type 'static int *bad = (unsigned char *)"bytes";'
reject_static_address invalid-one-past-decay 'struct Value { int matrix[2][3]; }; static struct Value value; static int *invalid = value.matrix[2];'

cat > "$out/aggregate-zero.c" <<'C'
struct Inner { int value; void *pointer; };
struct Outer { struct Inner items[2]; int tail; };
struct Reset { struct Inner item; };
struct Small { char bytes[3]; char sentinel; };
struct Pair { int first, second; };
union PairUnion { struct Inner item; long word; };
struct Outer global = {0};
struct Outer globals[2] = {{0}, {0,}};
struct Reset reset_global = {.item = {.value = 5, .pointer = &global}, .item = {0}};
struct Small small_global = {.sentinel = 77, .bytes = {0}};
struct Pair pair_global = {0, 9};
union PairUnion union_global = {0,};
int scalar_global = {0};
int main(void) {
    struct Outer local = {0,};
    struct Outer locals[2] = {{0}, {0}};
    struct Reset reset_local = {.item = {.value = 5, .pointer = &global}, .item = {0,}};
    struct Small small_local = {.sentinel = 77, .bytes = {0}};
    struct Pair pair_local = {0, 8};
    union PairUnion union_local = {0};
    int scalar_local = {0,};
    return global.items[1].value + (global.items[0].pointer != 0)
         + globals[1].items[1].value + (globals[0].items[0].pointer != 0)
         + local.items[1].value + (local.items[0].pointer != 0)
         + locals[1].items[1].value + (locals[0].items[0].pointer != 0)
         + reset_global.item.value + (reset_global.item.pointer != 0)
         + reset_local.item.value + (reset_local.item.pointer != 0)
         + (small_global.sentinel != 77) + (small_local.sentinel != 77)
         + pair_global.first + (pair_global.second != 9)
         + pair_local.first + (pair_local.second != 8)
         + union_global.item.value + union_local.item.value
         + scalar_global + scalar_local;
}
C
"$necc" "$out/aggregate-zero.c" -o "$out/aggregate-zero.s"
"$as" --64 "$out/aggregate-zero.s" -o "$out/aggregate-zero.o"
"$ld" -m elf_x86_64 -static -e _start "$out/aggregate-zero.o" \
    --whole-archive "$archive" --no-whole-archive "$@" -o "$out/aggregate-zero"
"$cc" -std=c11 -Wall -Wextra -Werror -Wno-missing-braces -Wno-override-init "$out/aggregate-zero.c" -o "$out/aggregate-zero-reference"
"$out/aggregate-zero-reference"
"$out/aggregate-zero"

reject() {
    printf '%s\n' "$1" > "$out/bad.i"
    if "$necc" "$out/bad.i" -o "$out/rejected.s" 2> "$out/error"; then
        echo 'expected an error' >&2
        exit 1
    fi
    grep -F "$2" "$out/error"
    test ! -e "$out/rejected.s"
}
reject 'int main(void) { return 1++; }' 'expected'
reject 'int main(void) { return 18446744073709551616ULL; }' 'integer constant out of range'
reject 'int f(int); int main(void) { return f(); }' 'wrong number of arguments'
reject 'int f(int); int f(void);' 'conflicting declaration'
reject 'int main(void) { return lost; }' 'undeclared local'
reject 'int main(void) { while (1) { return 0;' 'expected identifier'
reject 'int main(void) { missing = 1; }' 'undeclared local'
reject '/* unterminated' 'unterminated comment'

"$necc" "$repo/tests/long_double_abi.c" -o "$out/long-double-abi.s"
"$as" --64 "$out/long-double-abi.s" -o "$out/long-double-abi.o"
"$cc" -std=c11 -O0 -Wall -Wextra -Werror -frounding-math \
    "$repo/tests/long_double_abi_main.c" "$out/long-double-abi.o" -lm -o "$out/long-double-abi"
"$out/long-double-abi"

echo "necc ABI, arithmetic and invalid input checks passed in $out"
