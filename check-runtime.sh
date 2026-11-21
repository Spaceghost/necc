#!/bin/sh
set -eu
if [ "$#" -ne 3 ]; then
    echo 'usage: check-runtime.sh NECC SYSROOT SCRATCH' >&2
    exit 2
fi
necc=$1
export NECC_SYSROOT=$2
mkdir -p "$3"
out=$(mktemp -d "$3/runtime.XXXXXXXX")
export TMPDIR=$out TMP=$out TEMP=$out

cat > "$out/runtime.lua" <<'LUA'
assert(_VERSION == 'Lua 5.4')
assert(require('lfs').currentdir())
assert(type(require('hasher')) == 'table')
local peg = require 'lpeglabel'
local word = peg.C(peg.R('az')^1)
assert(word:match('nelua42') == 'nelua')
local pieces, i = {'ret', 'urn ', '6*7'}, 0
local chunk = assert(load(function() i = i + 1; return pieces[i] end))
assert(chunk() == 42 and assert(load(string.dump(chunk)))() == 42)
local co = coroutine.create(function(x) coroutine.yield(x + 1); return x + 2 end)
assert(select(2, coroutine.resume(co, 40)) == 41)
assert(select(2, coroutine.resume(co)) == 42)
assert(utf8.len(utf8.char(65, 0x3bb, 0x1f418)) == 3)
local values = {}
for n = 1, 2000 do values[n] = {n, tostring(n), n * 0.25} end
collectgarbage('collect')
assert(values[168][3] == 42 and math.modf(-2.5) == -2)
assert(string.pack('<I4', 0x12345678) == '\x78\x56\x34\x12')
local file = assert(io.tmpfile())
assert(file:write('nelua\n')); assert(file:seek('set') == 0)
assert(file:read('l') == 'nelua'); assert(file:close())
print('Lua readers, bytecode, modules, coroutines, UTF-8, GC, math and I/O passed')
LUA
"$necc" --lua "$out/runtime.lua"
cat > "$out/sum.nelua" <<'NELUA'
local values: [4]integer = {3, 7, 11, 21}
local total: integer = 0
for i = 0, #values - 1 do total = total + values[i] end
print(total)
NELUA
"$necc" --release "$out/sum.nelua" -o "$out/sum"
test "$("$out/sum")" = 42
echo 'Bundled Lua ran the full Nelua frontend and compiled the array sum to 42'
