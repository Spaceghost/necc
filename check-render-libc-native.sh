#!/bin/sh
set -eu
if [ "$#" -ne 8 ]; then
    echo 'usage: check-render-libc-native.sh SEED_NECC NEBUILD SYSROOT NELIBC_SRC X86_64_GCC NELINKER_SRC NECC_SRC SCRATCH' >&2
    exit 2
fi

absolute_file() {
    directory=$(cd -P "$(dirname "$1")" && pwd -P)
    printf '%s/%s\n' "$directory" "$(basename "$1")"
}
absolute_dir() { (cd -P "$1" && pwd -P); }
command_file() {
    case "$1" in */*) absolute_file "$1";; *) command -v "$1";; esac
}

seed=$(absolute_file "$1")
nebuild=$(command_file "$2")
sdk=$(absolute_dir "$3")
nelibc=$(absolute_dir "$4")
gcc=$(command_file "$5")
nelinker_src=$(absolute_dir "$6")
necc_src=$(absolute_dir "$7")
mkdir -p "$8"
scratch=$(absolute_dir "$8")
script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd -P)
renderer=$script_dir/render-libc.lua
for input in "$seed" "$nebuild" "$sdk/nelua-lua" "$sdk/tcc/tcc" \
    "$sdk/tcc/libtcc1.a" "$sdk/libnelibc.a" "$nelibc/src" \
    "$nelinker_src/src/nelinker.nelua" "$necc_src/necc.nelua"; do
    test -e "$input" || {
        printf 'check-render-libc-native: missing input: %s\n' "$input" >&2
        exit 1
    }
done

out=$(mktemp -d "$scratch/necc-render-libc-native.XXXXXXXX")
export NECC_SYSROOT=$sdk TMPDIR=$out/tmp TMP=$out/tmp TEMP=$out/tmp
mkdir "$TMPDIR"

render() {
    directory=$1
    shift
    mkdir -p "$out/$directory"
    (cd "$out/$directory" && "$seed" --lua "$renderer" "$seed" "$sdk" \
        "$nelibc" "$gcc" "$@" > build.ne)
}
recipe() {
    awk -v target="$1" '$1 == "build" && $2 == target {getline; print; exit}' "$2"
}
legacy_objects='alloc crypt fenv inet regex spawn termios thread wordexp'
native_objects='slocale exit extras sys-linux sysops fcntl semaphore syscall alloc crypt fenv inet regex spawn termios thread wordexp'

# The source extension is opt-in: all existing 4-, 5-, and 6-argument graphs
# retain their compiler selection.
render legacy4
render legacy5 libc
render legacy6 libc "$nelinker_src"
for graph in legacy4 legacy5 legacy6; do
    for name in $legacy_objects; do
        if [ "$graph" = legacy4 ]; then target=$name.o; else target=libc/$name.o; fi
        line=$(recipe "$target" "$out/$graph/build.ne")
        case "$line" in *"$sdk/tcc/tcc"*) ;; *) echo "$graph unexpectedly selected native necc for $name" >&2; exit 1;; esac
    done
    test "$(grep -Fc "'$seed' '-c'" "$out/$graph/build.ne")" -eq 8
done

# Verify source mode and its exact compiler recipe, including an empty prefix.
render native libc "$nelinker_src" "$necc_src"
graph=$out/native/build.ne
stage=$(recipe libc/necc "$graph")
case "$stage" in *"'--release'"*"'$necc_src/necc.nelua'"*"'-o' 'libc/necc'"*) ;; *)
    echo 'native graph has the wrong stage compiler recipe' >&2; exit 1;; esac
case "$stage" in *"'--native'"*) echo 'stage bootstrap must use the released full Nelua frontend' >&2; exit 1;; esac
for name in $native_objects; do
    line=$(recipe "libc/$name.o" "$graph")
    case "$line" in *"'libc/necc' '-c'"*) ;; *) echo "native graph did not select libc/necc for $name" >&2; exit 1;; esac
done
test "$(grep -Fc "'libc/necc' '-c'" "$graph")" -eq 17

render prefixless '' "$nelinker_src" "$necc_src"
graph=$out/prefixless/build.ne
stage=$(recipe necc "$graph")
case "$stage" in *"'-o' 'necc'"*) ;; *) echo 'prefixless stage output path is wrong' >&2; exit 1;; esac
case "$stage" in *'mkdir -p'*) echo 'prefixless stage recipe should not create a prefix directory' >&2; exit 1;; esac
line=$(recipe alloc.o "$graph")
case "$line" in *"'./necc' '-c'"*"'-o' 'alloc.o'"*) ;; *) echo 'prefixless compiler command is not executable from the build directory' >&2; exit 1;; esac
line=$(recipe libnelibc.a "$graph")
case "$line" in *"'./nelinker' '--archive'"*) ;; *) echo 'prefixless archive command is not executable from the build directory' >&2; exit 1;; esac

cd "$out/native"
"$nebuild" -j 2 build.ne libc/libnelibc.a > first-build.log 2>&1
test -x libc/necc
test -x libc/nelinker
for name in $native_objects; do test -s "libc/$name.o"; done
test "$(grep -Fc "'libc/necc' '-c'" first-build.log)" -eq 17
"$script_dir/check-libc.sh" "$out/native/libc/necc" "$sdk" "$nelibc" \
    "$gcc" "$out/native/libc/libnelibc.a" "$out/checks"
"$nebuild" -j 2 build.ne libc/libnelibc.a > warm-build.log 2>&1
test ! -s warm-build.log

# Exercise the source -> stage driver -> native objects -> archive edge with
# a scratch-only copy, then change one compiler module without touching the
# supplied checkout.
mkdir "$out/compiler-source"
cp "$necc_src"/*.nelua "$out/compiler-source/"
(cd "$out/native" && "$seed" --lua "$renderer" "$seed" "$sdk" "$nelibc" \
    "$gcc" libc "$nelinker_src" "$out/compiler-source" > build.ne)
"$nebuild" -j 2 "$out/native/build.ne" libc/libnelibc.a > copy-source-build.log 2>&1
test "$(wc -l < copy-source-build.log)" -eq 19
test "$(grep -Fc "'libc/necc' '-c'" copy-source-build.log)" -eq 17
test "$(grep -Fc "'--release'" copy-source-build.log)" -eq 1
test "$(grep -Fc "'libc/nelinker' '--archive'" copy-source-build.log)" -eq 1
printf '\n-- source dependency regression comment\n' >> "$out/compiler-source/leaf.nelua"
"$nebuild" -j 2 "$out/native/build.ne" libc/libnelibc.a > changed-source-build.log 2>&1
test "$(wc -l < changed-source-build.log)" -eq 19
test "$(grep -Fc "'libc/necc' '-c'" changed-source-build.log)" -eq 17
test "$(grep -Fc "'--release'" changed-source-build.log)" -eq 1
test "$(grep -Fc "'libc/nelinker' '--archive'" changed-source-build.log)" -eq 1
"$nebuild" -j 2 "$out/native/build.ne" libc/libnelibc.a > final-warm-build.log 2>&1
test ! -s final-warm-build.log

printf '17 native libc objects, seed-mode compatibility, prefixless commands, archive consumers, 19-edge compiler-source rebuild, and zero-recipe warm rebuild passed in %s\n' "$out"
