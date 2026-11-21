#!/bin/sh
# Bootstrap a standalone TinyCC executable from its configured source and SDK.
set -eu
if [ "$#" -ne 3 ]; then
    echo 'usage: rebuild-tcc.sh SYSROOT CONFIGURED_TCC_SRC OUTPUT' >&2
    exit 2
fi
sdk=$1
src=$2
cc=${TCC:-"$sdk/tcc/tcc"}
# TinyCC's command-line preprocessor writes each token to its own stream.
# The single-threaded tool can use Nelibc's unlocked string output here.
"$cc" -B"$sdk/tcc" -std=gnu11 -nostdinc -nostdlib -static -Wl,-e,_start \
    -DNELIBC_STANDALONE -Dfputs=fputs_unlocked -DCONFIG_TCC_STATIC=1 -DCONFIG_TCC_BACKTRACE=0 \
    -DCONFIG_TCC_BCHECK=0 '-DCONFIG_TCCDIR="/usr/lib/necc/tcc"' \
    -I"$src" -I"$sdk/include" -I"$sdk/tcc/include" -I"$sdk/uapi" "$src/tcc.c" \
    -Wl,--whole-archive "$sdk/libnelibc.a" -Wl,--no-whole-archive "$sdk/tcc/libtcc1.a" -o "$3"
