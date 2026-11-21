#!/bin/sh
# Compare bytes at the Lua VM table symbol in default and Unicode builds.
set -eu
if [ "$#" -ne 4 ]; then
    echo 'usage: check-lua-table.sh NECC SYSROOT NELUA_SRC SCRATCH' >&2
    exit 2
fi
necc=$1
export NECC_SYSROOT=$2
src=$3/src/lua
mkdir -p "$4"
out=$(mktemp -d "$4/necc-lctype.XXXXXXXX")
export TMPDIR=$out TMP=$out TEMP=$out
compare_table() {
    unit=$1; symbol=$2; count=$3; profile=$4
    shift 4
    "$necc" -isystem "$src" -DNDEBUG "$@" -c "$src/$unit.c" -o "$out/$profile-native.o"
    "$NECC_SYSROOT/tcc/tcc" -B"$NECC_SYSROOT/tcc" -std=c11 -nostdinc \
        -DNELIBC_STANDALONE -DNDEBUG "$@" -I"$NECC_SYSROOT/include" \
        -I"$NECC_SYSROOT/tcc/include" -I"$NECC_SYSROOT/uapi" -I"$src" \
        -c "$src/$unit.c" -o "$out/$profile-ref.o"
    for compiler in native ref; do
        obj=$out/$profile-$compiler.o
        section=$(objdump -t "$obj" | awk -v name="$symbol" '$NF == name {print $(NF-2)}')
        test -n "$section"
        objcopy -O binary --only-section="$section" "$obj" "$obj.bin"
        test "$(wc -c < "$obj.bin")" -eq "$count"
    done
    cmp "$out/$profile-native.o.bin" "$out/$profile-ref.o.bin"
}
compare_table lctype luai_ctype_ 257 ascii
compare_table lctype luai_ctype_ 257 unicode -DLUA_UCID
if cmp -s "$out/ascii-native.o.bin" "$out/unicode-native.o.bin"; then exit 1; fi
compare_table lopcodes luaP_opmodes 83 opcodes
echo 'Both 257-byte character tables and the 83-byte opcode table matched the reference'
