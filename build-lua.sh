#!/bin/sh
# Build the fork's complete bundled interpreter using the installed SDK.
set -eu
if [ "$#" -ne 4 ]; then
    echo 'usage: build-lua.sh SYSROOT NELUA_SRC BUILD_DIR OUTPUT' >&2
    exit 2
fi
sdk=$1
src=$2/src
out=$3
exe=$4
mkdir -p "$out"
tcc=$sdk/tcc/tcc
set --
for unit in onelua luainit sys lfs hasher lpeglabel/lplcap lpeglabel/lplcode lpeglabel/lplprint lpeglabel/lpltree lpeglabel/lplvm; do
    obj=$out/${unit##*/}.o
    "$tcc" -B"$sdk/tcc" -std=gnu99 -nostdinc -DNELIBC_STANDALONE -I"$sdk/include" \
        -I"$sdk/tcc/include" -I"$sdk/uapi" -DNDEBUG -DLUA_USE_POSIX -DMAXRECLEVEL=400 \
        -I"$src/lua" -c "$src/$unit.c" -o "$obj"
    set -- "$@" "$obj"
done
"$tcc" -B"$sdk/tcc" -nostdlib -static -Wl,-e,_start "$@" \
    -Wl,--whole-archive "$sdk/libnelibc.a" -Wl,--no-whole-archive "$sdk/tcc/libtcc1.a" -o "$exe"
