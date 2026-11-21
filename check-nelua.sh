#!/bin/sh
# Consume the C emitted by check-selfhost-nelibc.sh's third frontend stage.
set -eu
if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
    echo 'usage: check-nelua.sh NECC NELIBC_ARCHIVE SELFHOST_RESULTS SCRATCH [DIRECT_COMPILER_SRC]' >&2
    exit 2
fi
necc=$1
archive=$2
results=$3
mkdir -p "$4"
out=$(mktemp -d "$4/necc-nelua.XXXXXXXX")
cc=${CC:-cc}
as=${AS:-as}
ld=${LD:-ld}
export TMPDIR=$out TMP=$out TEMP=$out

# The preprocessed subset needs only the target's type, constant and function
# declarations below. Keep the full libc headers out of this limited parser.
mkdir "$out/include"
cat > "$out/include/stdint.h" <<'HEADER'
#define int64_t long
#define INT64_C(value) value ## L
HEADER
cat > "$out/include/stdbool.h" <<'HEADER'
#define bool _Bool
#define false 0
#define true 1
HEADER
cat > "$out/include/stdio.h" <<'HEADER'
extern int getchar(void);
extern int putchar(int);
extern int puts(const char *);
HEADER

for name in integer compound stdio records; do
    "$cc" -E -P -nostdinc -I"$out/include" "$results/$name-stage3.c" -o "$out/$name.i"
    "$necc" "$out/$name.i" -o "$out/$name.s"
    "$as" --64 "$out/$name.s" -o "$out/$name.o"
    "$ld" -m elf_x86_64 -static -e _start "$out/$name.o" \
        --whole-archive "$archive" --no-whole-archive -o "$out/$name"
    printf 'standard input\nsecond line\n' > "$out/input"
    expected=0
    "$results/$name-stage3" < "$out/input" > "$out/$name.expected" 2> "$out/$name.expected.err" || expected=$?
    actual=0
    "$out/$name" < "$out/input" > "$out/$name.stdout" 2> "$out/$name.stderr" || actual=$?
    cmp "$out/$name.expected" "$out/$name.stdout"
    cmp "$out/$name.expected.err" "$out/$name.stderr"
    test "$actual" -eq "$expected"
    echo "necc compiled the emitted C for $name (exit $actual)"
done

if [ "$#" -eq 5 ]; then
    source=$5
    "$cc" -E -P -nostdinc -I"$out/include" "$results/stage3.c" -o "$out/compiler.i"
    "$necc" "$out/compiler.i" -o "$out/compiler.s"
    "$as" --64 "$out/compiler.s" -o "$out/compiler.o"
    "$ld" -m elf_x86_64 -static -e _start "$out/compiler.o" "$results/runtime.o"         --whole-archive "$archive" --no-whole-archive -o "$out/nlc"
    NLC_INPUT="$source/selfhost/compiler.nelua" NLC_OUTPUT="$out/rebuilt.c" "$out/nlc"
    cmp "$results/stage3.c" "$out/rebuilt.c"
    for name in integer compound stdio records; do
        NLC_INPUT="$source/corpus/$name.nelua" NLC_OUTPUT="$out/$name-rebuilt.c" "$out/nlc"
        cmp "$results/$name-stage3.c" "$out/$name-rebuilt.c"
    done
    echo "necc-built Nelua frontend reproduced its own C and all four corpus outputs in $out"
fi
