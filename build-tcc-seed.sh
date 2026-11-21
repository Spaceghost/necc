#!/bin/sh
# The TinyCC checkout must have its upstream config.h and tccdefs_.h.
set -eu
if [ "$#" -ne 5 ]; then
    echo 'usage: build-tcc-seed.sh ZIG_ROOT CONFIGURED_TCC_SRC NELIBC_SRC NELIBC_ARCHIVE OUTPUT' >&2
    exit 2
fi
zig=$1
src=$2
# TinyCC's command-line preprocessor writes each token to its own stream.
# The single-threaded tool can use Nelibc's unlocked string output here.
"$zig/zig" cc -target x86_64-linux-musl -mcpu=x86_64 -std=gnu11 -O2 \
    -nostdinc -nostdlib -static -no-pie -fno-pie -ffreestanding \
    -fno-stack-protector -fno-builtin -fno-sanitize=all -DNELIBC_STANDALONE \
    -Dfputs=fputs_unlocked -DCONFIG_TCC_STATIC=1 -DCONFIG_TCC_BACKTRACE=0 -DCONFIG_TCC_BCHECK=0 \
    '-DCONFIG_TCCDIR="/usr/lib/necc/tcc"' -I"$src" -I"$3/include" \
    -isystem "$zig/lib/include" -isystem "$zig/lib/libc/include/x86-linux-any" \
    -isystem "$zig/lib/libc/include/any-linux-any" "$src/tcc.c" \
    -Wl,-e,_start -Wl,--build-id=none -Wl,--whole-archive "$4" -Wl,--no-whole-archive -o "$5"
