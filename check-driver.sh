#!/bin/sh
# Exercise the installed public entry point and the target libc ABI.
set -eu
if [ "$#" -ne 3 ]; then
    echo 'usage: check-driver.sh NECC SYSROOT SCRATCH' >&2
    exit 2
fi
necc=$1
export NECC_SYSROOT=$2
mkdir -p "$3"
work=$(mktemp -d "$3/necc-driver.XXXXXXXX")
export TMPDIR="$work/tmp" TMP="$work/tmp" TEMP="$work/tmp"
mkdir "$TMPDIR" "$work/user headers"
cd "$work"
cat > 'user headers/answer.h' <<'C'
#define ANSWER(x) ((x) + INC)
C
cat > 'hello world.c' <<'C'
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "answer.h"
int main(void) {
    int64_t n = INT64_C(3000000000);
    printf("native %ld %d\n", n, ANSWER(abs(-40)));
    return 23;
}
C
check_c() {
    code=0
    "$1" > actual || code=$?
    test "$code" -eq 23
    test "$(cat actual)" = 'native 3000000000 42'
}
"$necc" '-Iuser headers' -D INC=2 'hello world.c' -o one
check_c ./one
"$necc" -I 'user headers' -DINC=2 -E 'hello world.c' -o pp.i
"$necc" -S pp.i -o output.s
grep -q 'Lnecc_' output.s
"$necc" -c output.s -o output.o
"$necc" output.o -o two
check_c ./two
"$necc" '-Iuser headers' -DINC=2 -c 'hello world.c' -o native.o
"$necc" native.o -o three
check_c ./three
if readelf -lW one | grep -q INTERP; then exit 1; fi
test -z "$(nm -u one)"
cat > helper.c <<'C'
static int offset(void) { return 2; }
int helper(int n) { return n + offset(); }
C
cat > entry.c <<'C'
int helper(int);
static int offset(void) { return 40; }
int main(void) { return helper(offset()); }
C
check_link() {
    status=0
    "$1" || status=$?
    test "$status" -eq 42
}
"$necc" entry.c helper.c -o linked
check_link ./linked
"$necc" -c helper.c -o 'helper unit.o'
"$NECC_SYSROOT/tcc/tcc" -ar rcs 'helper library.a' 'helper unit.o'
"$necc" -c entry.c -o entry.o
"$necc" entry.o 'helper library.a' -o linked-archive
check_link ./linked-archive
cat > caller.nelua <<'NELUA'
local function helper(n: cint): cint <cimport> end
print(helper(40))
NELUA
"$necc" --release caller.nelua 'helper unit.o' -o mixed
test "$(./mixed)" = 42
cp linked preserved-link
printf 'int main(void) { return missing; }\n' > rejected-link.c
if "$necc" helper.c rejected-link.c -o preserved-link 2> rejected; then exit 1; fi
cmp linked preserved-link
if "$necc" entry.o entry.o -o preserved-link 2> rejected; then exit 1; fi
cmp linked preserved-link
ln 'helper library.a' archive-alias
if "$necc" entry.c 'helper library.a' -o archive-alias 2> rejected; then exit 1; fi
grep -q 'same file' rejected
cmp archive-alias 'helper library.a'
if "$necc" -c entry.c helper.c -o ambiguous.o 2> rejected; then exit 1; fi
test ! -e ambiguous.o
echo 'Multi-file native C, ordered static archives, mixed Nelua/C, and atomic failed links passed'
cat > bytes.c <<'C'
const unsigned char table[3 + 2] = {0x41, 0377, 0x80};
unsigned char values[] = {0, 0, 0};
char signed_one = -1;
int update(unsigned char *p, int i) {
    p[i] += table[i];
    return p[i];
}
int main(void) {
    values[1] = 2;
    return (update(values, 1) == 1) + (table[2] == 128) + (table[4] == 0) + (signed_one == -1);
}
C
mkdir 'other scratch'
"$necc" -c bytes.c -o first.o
TMPDIR="$PWD/other scratch" "$necc" -c bytes.c -o second.o
cmp first.o second.o
"$necc" bytes.c -o bytes
code=0
./bytes || code=$?
test "$code" -eq 4
printf 'const unsigned char a[1] = {1, 2};\n' > invalid-bytes.c
if "$necc" -c invalid-bytes.c -o invalid.o 2> rejected; then exit 1; fi
grep -q 'excess array initializer' rejected
cat > 'user headers/mode.h' <<'C'
enum Mode { Negative = -4, First = 2, Next, Mask = (Next << 3) | First };
typedef enum { Low, High = Low + 1 } Flag;
C
cat > modes.c <<'C'
#include "mode.h"
enum { Bounds = (int)(Next) + 1, Sign = Negative >> 1, };
const unsigned char packed[Bounds] = {Mask, ~Low & 7, 1 ^ 3 & 1, (1L << 33) >> 32};
int main(void) {
    int Next = 6;
    long shift = 1;
    return (packed[0] == 26) + (packed[1] == 7) + (packed[2] == 0)
         + (packed[3] == 2) + (Next == 6) + (Sign == -2) + (High == 1)
         + ((-8 >> shift) == -4) + ((1L << 37) == 137438953472L)
         + ((~2 ^ 5 & 1 | 3) == -1);
}
C
"$necc" -isystem 'user headers' modes.c -o modes
code=0
./modes || code=$?
test "$code" -eq 10
for constant in '1 << 32' '1 << -1' '2147483647 + 1' 'missing'; do
    printf 'int invalid = %s;\n' "$constant" > invalid.c
    if "$necc" -c invalid.c -o invalid.o 2> rejected; then exit 1; fi
    grep -q 'invalid or unsupported integer constant expression' rejected
done
printf 'int first = 1; enum E {first};\n' > invalid.c
if "$necc" -c invalid.c -o invalid.o 2> rejected; then exit 1; fi
grep -q 'conflicting enumerator' rejected
cat > arrays.nelua <<'NELUA'
local t: [3]integer = {10, 12, 20}
print(t[0] + t[1] + t[2])
NELUA
"$necc" arrays.nelua -o full
test "$(./full)" = 42
# Use the full frontend with the native backend for each driver entry point.
"$necc" --native arrays.nelua -o native-arrays
test "$(./native-arrays)" = 42
printf '%s\n' "print 'hello world'" > greeting.nelua
"$necc" --native --release greeting.nelua -o greeting
test "$(./greeting)" = 'hello world'
"$necc" --native --release -S arrays.nelua -o native-arrays.s
grep -q '^main:' native-arrays.s
"$necc" --native --release -c arrays.nelua -o native-arrays.o
"$necc" native-arrays.o -o native-linked
test "$(./native-linked)" = 42
"$necc" --native --release caller.nelua 'helper unit.o' -o native-mixed
test "$(./native-mixed)" = 42
if "$necc" --native --direct arrays.nelua -o native-mixed 2> rejected; then exit 1; fi
test "$(./native-mixed)" = 42
"$necc" --emit-c arrays.nelua -o emitted.c
grep -q 'Generated by Nelua' emitted.c
cat > direct.nelua <<'NELUA'
do return 42 end
NELUA
"$necc" --direct direct.nelua -o direct
code=0
./direct || code=$?
test "$code" -eq 42
"$necc" --direct --emit-c direct.nelua -o direct.c
"$necc" direct.c -o direct-c
code=0
./direct-c || code=$?
test "$code" -eq 42
cat > args.lua <<'LUA'
assert(arg[1] == "two words" and arg[2] == "-x")
assert(require("lfs").attributes(arg[0], "mode") == "file")
print(_VERSION)
os.exit(19)
LUA
code=0
"$necc" args.lua 'two words' -x > lua.out || code=$?
test "$code" -eq 19
test "$(cat lua.out)" = 'Lua 5.4'
test "$("$necc" --lua -e 'print(6*7)')" = 42
cp one preserved
printf 'int main(void) { return missing; }\n' > invalid.c
if "$necc" invalid.c -o preserved 2> rejected; then exit 1; fi
grep -q 'undeclared local missing' rejected
cmp one preserved
ln 'hello world.c' alias.c
if "$necc" 'hello world.c' -o alias.c 2> rejected; then exit 1; fi
grep -q 'same file' rejected
cmp 'hello world.c' alias.c
test -z "$(find "$TMPDIR" . -name '.necc-*' -print -quit)"
echo "Native C, full and direct Nelua, Lua argv, output preservation and cleanup passed in $work"
