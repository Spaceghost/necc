#!/bin/sh
set -eu
if [ "$#" -ne 6 ]; then
    echo 'usage: check-libc.sh NECC SYSROOT NELIBC_SRC X86_64_GCC ARCHIVE SCRATCH' >&2
    exit 2
fi
absolute() { case "$1" in /*) printf '%s\n' "$1";; *) printf '%s/%s\n' "$PWD" "$1";; esac; }
cc=$(absolute "$1")
sdk=$(absolute "$2")
tree=$(absolute "$3")
gcc=$(absolute "$4")
archive=$(absolute "$5")
scratch=$(absolute "$6")
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
mkdir -p "$scratch"
work=$(mktemp -d "$scratch/necc-libc.XXXXXXXX")
cd "$work"
mkdir sdk
for component in "$sdk"/*; do
    name=${component##*/}
    if [ "$name" != libnelibc.a ]; then ln -s "$component" "sdk/$name"; fi
done
ln -s "$archive" sdk/libnelibc.a
export NECC_SYSROOT="$work/sdk" TMPDIR="$work" TMP="$work" TEMP="$work"
builtin=$("$gcc" -print-file-name=include)
compile() {
    "$gcc" -m64 -O2 -fno-pie -fno-stack-protector -ffreestanding -fno-builtin -ftls-model=local-exec \
        -nostdinc -DNELIBC_STANDALONE -I"$tree/include" -isystem "$builtin" -isystem "$sdk/uapi" -c "$@"
}
check_source() {
    name=$1 source=$2; shift 2
    compile "$source" -o "$name.o"
    "$cc" "$name.o" "$@" -o "$name"
    readelf -lW "$name" > "$name.segments"
    readelf -dW "$name" > "$name.dynamic"
    if grep -q INTERP "$name.segments" || grep -q NEEDED "$name.dynamic"; then
        echo "unexpected dynamic dependency in $name" >&2
        exit 1
    fi
    "./$name"
    printf '%s passed\n' "$name"
}
check() {
    name=$1; shift
    check_source "$name" "$tree/tools/$name.c" "$@"
}
check lib_consumer_smoke
check_source libc_native_data "$script_dir/tests/libc_native_data.c"
check_source libc_native_float "$script_dir/tests/libc_native_float.c"
"$cc" -DNELIBC_STANDALONE "$script_dir/tests/libc_native_float.c" -o native-float
./native-float
printf 'shutdown\nexit_atexit_smoke passed\n' > exit_atexit_smoke.expected
check_source exit_atexit_smoke "$script_dir/tests/exit_atexit_smoke.c" > exit_atexit_smoke.actual
cmp exit_atexit_smoke.expected exit_atexit_smoke.actual
# GNU ld and the staged linker must use the same address for the x86-64
# allocator lock. A misplaced release store leaves the next malloc spinning.
"$gcc" -fuse-ld=bfd -nostdlib -static -no-pie -Wl,-e,_start -Wl,-z,noexecstack lib_consumer_smoke.o \
    -Wl,--whole-archive "$archive" -Wl,--no-whole-archive "$sdk/tcc/libtcc1.a" -o gnu-consumer
timeout 90 ./gnu-consumer
echo 'lib_consumer_smoke passed with GNU ld'
# Static applications may replace malloc alone or supply aligned_alloc too.
# Compile the existing standalone consumer with both policies.
for replacement in ordinary aligned; do
    set --
    if [ "$replacement" = aligned ]; then set -- -DREPLACE_ALIGNED; fi
    compile "$tree/tools/malloc_replace_smoke.c" "$@" -o replace.o
    "$cc" replace.o -o replace
    timeout 90 ./replace
done
check errno_tls_smoke
check math_core_standalone_smoke
check complex_math_smoke
"$cc" --release --emit-c "$tree/tools/tls_fixture.nelua" -o tls_fixture.c
compile tls_fixture.c -o tls_fixture.o
compile "$tree/tools/tls_alignment_fixture.c" -o tls_alignment_fixture.o
check pthread_standalone_smoke tls_fixture.o tls_alignment_fixture.o
