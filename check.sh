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

echo "necc ABI, arithmetic and invalid input checks passed in $out"
