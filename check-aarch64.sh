#!/bin/sh
set -eu
necc=$(realpath "${1:?usage: check-aarch64.sh /path/to/necc-hosted}")
: "${NECC_NELUA:?set NECC_NELUA to the Nelua compiler path}"
: "${NECC_NELINKER:?set NECC_NELINKER to the Nelinker path}"
tmp=$(mktemp -d)
trap 'rm -r "$tmp"' EXIT
cd "$tmp"

cat > start.s <<'ASM'
.text
.global _start
_start:
    bl answer
    mov x8, #93
    svc #0
ASM
cat > answer.c <<'C'
extern int twice(int);
#ifndef UNIT
#define UNIT 1
#endif
int answer(void) { return twice(17) + UNIT; }
C
cat > twice.nelua <<'NELUA'
## pragmas.freestanding = true
local function twice(value: cint): cint <cexport, codename 'twice'>
  return 2 * value
end
NELUA

"$necc" --aarch64 -E -DUNIT=8 answer.c -o answer.i
"$necc" --aarch64 -c answer.i -o answer.o
"$necc" --aarch64 -S twice.nelua -o twice.s
"$necc" --aarch64 --emit-c twice.nelua -o twice.c
readelf -h answer.o | grep -q AArch64
"$NECC_NELINKER" --archive --aarch64 -o libanswer.a answer.o
"$necc" --aarch64 start.s twice.nelua libanswer.a -o program
readelf -h program | grep -q AArch64
if ./program; then exit 1; else test "$?" -eq 42; fi

"$necc" --aarch64 -DUNIT=8 start.s answer.c twice.nelua -o program
if ./program; then exit 1; else test "$?" -eq 42; fi
cp program expected
printf '%s\n' 'invalid c input' > broken.c
if "$necc" --aarch64 start.s broken.c -o program 2>errors; then exit 1; fi
cmp program expected
echo 'NeCC AArch64 C, assembly, Nelua, archive and atomic output checks passed'
