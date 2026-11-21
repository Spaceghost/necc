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
        -nostdinc -DNELIBC_STANDALONE -I"$tree/include" -isystem "$builtin" -isystem "$sdk/uapi" -c "$1" -o "$2"
}
check() {
    name=$1; shift
    compile "$tree/tools/$name.c" "$name.o"
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
check lib_consumer_smoke
# GNU ld and the staged linker must use the same address for the x86-64
# allocator lock. A misplaced release store leaves the next malloc spinning.
"$gcc" -fuse-ld=bfd -nostdlib -static -no-pie -Wl,-e,_start -Wl,-z,noexecstack lib_consumer_smoke.o \
    -Wl,--whole-archive "$archive" -Wl,--no-whole-archive "$sdk/tcc/libtcc1.a" -o gnu-consumer
timeout 90 ./gnu-consumer
echo 'lib_consumer_smoke passed with GNU ld'
check errno_tls_smoke
check math_core_standalone_smoke
check complex_math_smoke
"$cc" --release --emit-c "$tree/tools/tls_fixture.nelua" -o tls_fixture.c
compile tls_fixture.c tls_fixture.o
compile "$tree/tools/tls_alignment_fixture.c" tls_alignment_fixture.o
check pthread_standalone_smoke tls_fixture.o tls_alignment_fixture.o
