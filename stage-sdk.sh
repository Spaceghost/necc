#!/bin/sh
set -eu
if [ "$#" -ne 10 ]; then
    echo 'usage: stage-sdk.sh DEST NELIBC_SRC NELIBC_ARCHIVE NELUA_SRC LUA TCC TCC_LIB X86_UAPI GENERIC_UAPI NLC' >&2
    exit 2
fi
dst=$1
libc=$2
archive=$3
nelua=$4
lua=$5
tcc=$6
tcclib=$7
arch_uapi=$8
common_uapi=$9
nlc=${10}
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$dst/include" "$dst/tcc/include" "$dst/uapi"
cp -R "$libc/include/." "$dst/include/"
cp "$here/include/stdint.h" "$dst/include/"
cp -R "$tcclib/include/." "$dst/tcc/include/"
cp -R "$common_uapi/." "$dst/uapi/"
cp -R "$arch_uapi/." "$dst/uapi/"
cp "$archive" "$dst/libnelibc.a"
cp "$tcclib/libtcc1.a" "$dst/tcc/"
cp "$tcc" "$dst/tcc/tcc"
cp "$nlc" "$dst/nlc"
cp "$lua" "$dst/nelua-lua"
mkdir -p "$dst/lib" "$dst/lualib"
cp -R "$nelua/lib/." "$dst/lib/"
cp -R "$nelua/lualib/." "$dst/lualib/"
