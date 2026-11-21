#!/bin/sh
set -eu
if [ "$#" -ne 6 ]; then
    echo 'usage: check-render-lua-linker.sh NECC NEBUILD SYSROOT NELUA_SRC NELINKER SCRATCH' >&2
    exit 2
fi

absolute_file() {
    directory=$(cd -P "$(dirname "$1")" && pwd -P)
    printf '%s/%s\n' "$directory" "$(basename "$1")"
}

necc=$(absolute_file "$1")
nebuild=$(absolute_file "$2")
sysroot=$(cd -P "$3" && pwd -P)
nelua_src=$(cd -P "$4" && pwd -P)
nelinker=$(absolute_file "$5")
scratch=$(cd -P "$6" && pwd -P)
renderer=$(CDPATH= cd -P "$(dirname "$0")" && pwd -P)/render-lua.lua

for input in "$necc" "$nebuild" "$renderer" "$nelinker" "$sysroot/tcc/tcc" \
    "$sysroot/tcc/libtcc1.a" "$sysroot/libnelibc.a" "$nelua_src/src/lua" \
    "$nelua_src/src/lpeglabel"; do
    test -e "$input" || {
        printf 'check-render-lua-linker: missing input: %s\n' "$input" >&2
        exit 1
    }
done

out=$(mktemp -d "$scratch/necc-render-lua.XXXXXXXX")
mkdir "$out/libc"
cp -a "$sysroot" "$out/sdk"
cp "$nelinker" "$out/libc/nelinker"
cp "$out/sdk/libnelibc.a" "$out/libc/libnelibc.a"
export NECC_SYSROOT=$out/sdk
export TMPDIR=$out/tmp TMP=$out/tmp TEMP=$out/tmp
mkdir "$TMPDIR"
cd "$out"

install_runtime() {
    rm -f "$NECC_SYSROOT/nelua-lua"
    cp runtime/nelua-lua "$NECC_SYSROOT/nelua-lua"
}

# The compiler does not exist at render time. Its relative graph target must
# be built before any runtime object, even on a parallel clean build.
cp "$necc" seed-necc
render_staged() {
    printf 'build libc/necc seed-necc\n\tcp seed-necc libc/necc\n'
    NECC_NELINKER=libc/nelinker "$necc" --lua "$renderer" libc/necc "$NECC_SYSROOT" \
        "$nelua_src" runtime "$@"
}
render_staged > default.ne
target=$(sed -n 's/^build runtime\/nelua-lua //p' default.ne)
case " $target " in
    *" libc/nelinker "*) ;;
    *) echo 'rendered default link does not depend on the selected linker' >&2; exit 1 ;;
esac
grep -F "'$out/libc/nelinker' '--tcc-relocs' '-e' '_start'" default.ne >/dev/null
NECC_NELINKER= "$necc" --lua "$renderer" "$necc" "$NECC_SYSROOT" \
    "$nelua_src" fallback-runtime > fallback.ne
grep -F 'NECC_NELINKER= ' fallback.ne >/dev/null
if grep -F 'libc/nelinker' fallback.ne >/dev/null; then
    echo 'unselected linker leaked into the fallback graph' >&2
    exit 1
fi

: > default.recipes
NECC_NELINKER=/not/the/rendered/linker "$nebuild" -j 4 default.ne runtime/nelua-lua \
    > default.recipes
test -x runtime/nelua-lua
test "$(grep -Fc "'$out/libc/necc' '-DNDEBUG'" default.recipes)" -eq 42
install_runtime

render_staged libc/libnelibc.a > override.ne
target=$(sed -n 's/^build runtime\/nelua-lua //p' override.ne)
case " $target " in
    *" libc/libnelibc.a "*" libc/nelinker "*) ;;
    *) echo 'rendered archive override does not track both relative inputs' >&2; exit 1 ;;
esac
grep -F "'$out/libc/nelinker' '--tcc-relocs' '-e' '_start'" override.ne >/dev/null

NECC_NELINKER=/not/the/rendered/linker "$nebuild" -j 4 override.ne runtime/nelua-lua \
    > override.recipes
test "$(wc -l < override.recipes)" -eq 1
grep -F 'libc/libnelibc.a' override.recipes >/dev/null
test -x runtime/nelua-lua
install_runtime

NECC_NELINKER=/not/the/rendered/linker "$nebuild" -j 4 override.ne runtime/nelua-lua \
    > warm.recipes
test ! -s warm.recipes
touch libc/nelinker
NECC_NELINKER=/not/the/rendered/linker "$nebuild" -j 4 override.ne runtime/nelua-lua \
    > linker-changed.recipes
test "$(wc -l < linker-changed.recipes)" -eq 1
grep -F "'$out/libc/nelinker'" linker-changed.recipes >/dev/null
install_runtime

touch seed-necc
"$nebuild" -j 4 override.ne runtime/nelua-lua > compiler-changed.recipes
test "$(wc -l < compiler-changed.recipes)" -eq 44
test "$(grep -Fc "'$out/libc/necc' '-DNDEBUG'" compiler-changed.recipes)" -eq 42
"$nebuild" override.ne runtime/nelua-lua > warm.recipes
test ! -s warm.recipes
install_runtime

cat > hello.nelua <<'NELUA'
print(6 * 7)
NELUA
NECC_NELINKER=$out/libc/nelinker "$necc" --release hello.nelua -o hello
test "$(./hello)" = 42
"$NECC_SYSROOT/nelua-lua" -e 'assert(_VERSION == "Lua 5.4")'
printf 'The staged necc rebuilt 42 runtime objects. Archive and linker changes rebuilt only the final link.\n'
