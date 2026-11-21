#!/bin/sh
set -eu
if [ "$#" -ne 5 ]; then
    echo 'usage: check-direct-sdk.sh NECC SYSROOT STAGE3_RESULTS DIRECT_COMPILER_SRC SCRATCH' >&2
    exit 2
fi
necc=$1
export NECC_SYSROOT=$2
results=$3
src=$4
mkdir -p "$5"
out=$(mktemp -d "$5/necc-corpus.XXXXXXXX")
export TMPDIR=$out TMP=$out TEMP=$out
cd "$out"
printf 'standard input\nsecond line\n' > input
for name in integer compound stdio records; do
    "$necc" --direct "$src/corpus/$name.nelua" -o "$name"
    actual=0; expected=0
    "./$name" < input > "$name.out" 2> "$name.err" || actual=$?
    "$results/$name-stage3" < input > "$name.ref" 2> "$name.referr" || expected=$?
    cmp "$name.out" "$name.ref"
    cmp "$name.err" "$name.referr"
    test "$actual" = "$expected"
    echo "$name exit $actual"
done
"$necc" -c "$results/stage3.c" -o frontend.o
"$NECC_SYSROOT/tcc/tcc" -B"$NECC_SYSROOT/tcc" -nostdlib -static -Wl,-e,_start \
    frontend.o "$results/runtime.o" -Wl,--whole-archive "$NECC_SYSROOT/libnelibc.a" \
    -Wl,--no-whole-archive "$NECC_SYSROOT/tcc/libtcc1.a" -o frontend
NLC_INPUT="$src/selfhost/compiler.nelua" NLC_OUTPUT="$out/rebuilt.c" ./frontend
cmp "$results/stage3.c" rebuilt.c
for name in integer compound stdio records; do
    NLC_INPUT="$src/corpus/$name.nelua" NLC_OUTPUT="$out/$name.c" ./frontend
    cmp "$results/$name-stage3.c" "$name.c"
done
echo 'The native C frontend built the direct compiler against the SDK and reproduced the complete reference corpus'
