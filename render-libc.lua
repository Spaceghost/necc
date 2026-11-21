-- Generate the standalone x86-64 Nelibc archive from its original sources.
local lfs = require 'lfs'
assert(#arg >= 4 and #arg <= 7, 'usage: render-libc.lua NECC SYSROOT NELIBC_SRC X86_64_GCC [OUTPUT_PREFIX [NELINKER_SRC [NECC_SOURCE]]]')
assert(not arg[7] or arg[6], 'NECC_SOURCE requires NELINKER_SRC')

local function absolute(path)
  if path:sub(1, 1) ~= '/' then path = lfs.currentdir() .. '/' .. path end
  return (path:gsub('/%./', '/'):gsub('/+$', ''))
end

local function quote(word)
  return "'" .. word:gsub("'", "'\\''") .. "'"
end

local function command(args)
  local words = {}
  for i, word in ipairs(args) do words[i] = quote(word) end
  return table.concat(words, ' ')
end

local function files(dir, pattern, list)
  for name in lfs.dir(dir) do
    if name ~= '.' and name ~= '..' then
      local path = dir .. '/' .. name
      local kind = lfs.attributes(path, 'mode')
      if kind == 'directory' then
        files(path, pattern, list)
      elseif kind == 'file' and name:match(pattern) then
        list[#list + 1] = path
      end
    end
  end
end

local prefix = arg[5] and arg[5]:gsub('/+$', '') or ''
assert(not arg[5] or ((prefix == '' and arg[6]) or
    (prefix ~= '' and prefix:sub(1, 1) ~= '/' and not prefix:find('%s'))),
  'output prefix must be a relative path without whitespace')
assert(not arg[5] or prefix ~= '' or arg[5] == '',
  'an empty output prefix must be written as an empty argument')

local function output(name)
  return prefix == '' and name or prefix .. '/' .. name
end

local function executable(name)
  return prefix == '' and './' .. name or prefix .. '/' .. name
end

local function edge(target, inputs, recipe)
  local deps = {}
  for _, group in ipairs(inputs) do
    for _, name in ipairs(group) do
      assert(not name:find('%s'), 'nebuild manifest paths cannot contain whitespace: ' .. name)
      deps[name] = true
    end
  end
  local ordered = {}
  for name in pairs(deps) do ordered[#ordered + 1] = name end
  table.sort(ordered)
  if prefix ~= '' then recipe = 'mkdir -p ' .. quote(prefix) .. ' && ' .. recipe end
  io.write('build ', target, ' ', table.concat(ordered, ' '), '\n\t', recipe, '\n')
end

local necc, sdk, tree, gcc = absolute(arg[1]), absolute(arg[2]), absolute(arg[3]), absolute(arg[4])
local necc_source = arg[7] and absolute(arg[7])
assert(not necc_source or (lfs.attributes(necc_source, 'mode') == 'directory' and
    lfs.attributes(necc_source .. '/necc.nelua', 'mode') == 'file'),
  'NECC_SOURCE must be the source directory containing necc.nelua')
local tcc = sdk .. '/tcc/tcc'
local src = tree .. '/src'
local pipe = assert(io.popen(command({gcc, '-print-file-name=include'}), 'r'))
local builtin = assert(pipe:read('l'), 'GCC did not report its builtin headers')
assert(pipe:close() and lfs.attributes(builtin, 'mode') == 'directory', 'invalid GCC builtin header directory')

local headers, gcc_headers = {}, {}
for _, dir in ipairs({tree .. '/include', src, sdk .. '/include', sdk .. '/uapi', sdk .. '/tcc/include'}) do
  files(dir, '%.h$', headers)
end
files(builtin, '%.h$', gcc_headers)
local frontend = {necc, tcc, sdk .. '/nelua-lua'}
files(sdk .. '/lib', '%.nelua$', frontend)
files(sdk .. '/lualib', '%.lua$', frontend)

-- The builder records a producer's successful run in each consumer stamp.
-- Sharing these dependency lists also keeps the graph small on the target.
local function stamp(name, inputs)
  edge(name, {inputs}, ': > ' .. quote(name))
  return {name}
end
local target_headers = stamp(output('target-headers.stamp'), headers)
local compiler_headers = stamp(output('gcc-headers.stamp'), gcc_headers)
local nelua_frontend = stamp(output('nelua-frontend.stamp'), frontend)

-- Build the archive writer with the seed libc, before the new libc exists.
local archiver
if arg[6] then
  local dir = absolute(arg[6]) .. '/src'
  local sources = {}
  files(dir, '%.nelua$', sources)
  archiver = output('nelinker')
  edge(archiver, {sources, nelua_frontend, target_headers, {sdk .. '/libnelibc.a', sdk .. '/tcc/libtcc1.a'}},
    'NECC_NELINKER= NECC_SYSROOT=' .. quote(sdk) .. ' ' ..
    command({necc, '--release', '-L', dir, dir .. '/nelinker.nelua', '-o', archiver}))
end

-- This opt-in bootstrap compiles the supplied full necc source with the
-- released driver and seed SDK. The resulting driver handles native C codegen
-- for the broader allowlist below; its own link still uses the seed TCC.
local native_driver
if necc_source then
  local source_dir = necc_source
  local modules = {}
  for name in lfs.dir(source_dir) do
    if name:match('%.nelua$') then modules[#modules + 1] = source_dir .. '/' .. name end
  end
  table.sort(modules)
  native_driver = output('necc')
  local native_driver_command = executable('necc')
  local inputs = {modules, nelua_frontend, target_headers,
    {necc, sdk .. '/nelua-lua', sdk .. '/libnelibc.a', tcc, sdk .. '/tcc/libtcc1.a'}}
  edge(native_driver, inputs, 'NECC_SYSROOT=' .. quote(sdk) .. ' NECC_NELINKER= ' ..
    command({necc, '--release', '-L', source_dir, source_dir .. '/necc.nelua', '-o', native_driver}))
  native_driver = {target=native_driver, command=native_driver_command}
end

-- Keep the standalone TinyCC profile's archive order. Compiler runtime
-- routines come from the SDK's separate libtcc1.a at executable link time.
-- TinyCC's ar stores 15-byte names. Short, unique member names also let
-- other archive tools extract each implementation independently.
local units = [[
slocale.o       string_locale_standalone.nelua
string.o        string.nelua
inet.o          inet.nelua
memory.o        memory.nelua
memhelper.o     memory_tcc_x86_64.c
memx86.o        memory_x86_64.S
ctype.o         ctype.nelua
stdlib.o        stdlib.nelua
locale.o        locale_standalone.nelua
exit.o          stdlib_exit_standalone.nelua
search.o        search_standalone.nelua
regex.o         regex_standalone.nelua
pwd.o           pwd_standalone.nelua
termios.o       termios_standalone.nelua
wordexp.o       wordexp_standalone.nelua
crypt.o         crypt_standalone.nelua
extras.o        extras_standalone.nelua
iconv.o         iconv_standalone.nelua
strfloat.o      stdlib_float.nelua
sys-linux.o     sys/linux_x86_64.nelua
syscall-asm.o   sys/linux_x86_64.S
sysops.o        sys/linux_x86_64_ops.c
start.o         sys/start_linux_x86_64_standalone.S
errno.o         errno/standalone.nelua
thread.o        thread.nelua
alloc.o         alloc.nelua
alloc-exports.o alloc/standalone_exports.c
spawn.o         spawn_standalone.nelua
unistd.o        unistd.nelua
stdio.o         stdio.nelua
stdio-varargs.o stdio_varargs.c
fcntl.o         fcntl_adapter.c
credentials.o   credential_adapter.c
stdio-lock.o    stdio_lock_standalone.c
stdio-startup.o stdio_startup_stub.c
environment.o   environment_adapter.c
mqueue.o        mqueue_adapter.c
semaphore.o     semaphore_adapter.c
math-core.o     math_core.nelua
fenv.o          fenv_standalone.nelua
math-x86.o      math_core_x86_64.S
exec.o          exec_adapter.c
syscall.o       syscall_adapter.c
ipc.o           ipc_adapter.c
stdio-extras.o  stdio_extras_adapter.c
setjmp.o        setjmp_x86_64.S
complex-abi.o   complex_abi.c
]]
-- GCC handles local-exec TLS, GNU atomics, and the SysV complex ABI.
-- Its assembler also emits RIP-relative relocation addends accepted by
-- both linkers when a displacement is followed by an immediate operand.
local bootstrap = {}
for name in ([[
errno/standalone.nelua stdlib.nelua environment_adapter.c credential_adapter.c stdio_lock_standalone.c complex_abi.c
]]):gmatch('%S+') do bootstrap[name] = true end

-- These C adapters and generated Nelua modules fit necc's native C frontend
-- and have passed the standalone archive consumers. Keep the rest on TinyCC
-- until its frontend checks cover their constructs.
local native_objects = {
  ['string_locale_standalone.nelua'] = true,
  ['stdlib_exit_standalone.nelua'] = true,
  ['extras_standalone.nelua'] = true,
  ['sys/linux_x86_64.nelua'] = true,
  ['sys/linux_x86_64_ops.c'] = true,
  ['fcntl_adapter.c'] = true,
  ['semaphore_adapter.c'] = true,
  ['syscall_adapter.c'] = true,
}
if native_driver then
  for _, name in ipairs({
      'alloc.nelua', 'alloc/standalone_exports.c', 'crypt_standalone.nelua', 'ctype.nelua', 'fenv_standalone.nelua',
      'iconv_standalone.nelua', 'inet.nelua', 'ipc_adapter.c', 'locale_standalone.nelua', 'memory.nelua',
      'mqueue_adapter.c', 'pwd_standalone.nelua', 'regex_standalone.nelua',
      'search_standalone.nelua', 'spawn_standalone.nelua',
      'stdio.nelua', 'stdio_startup_stub.c', 'stdio_varargs.c', 'stdlib_float.nelua',
      'string.nelua', 'termios_standalone.nelua', 'thread.nelua', 'unistd.nelua',
      'wordexp_standalone.nelua'}) do
    native_objects[name] = true
  end
end

local objects, members = {}, {}
for object, name in units:gmatch('(%S+)%s+(%S+)') do
  assert(#object <= 15 and not members[object], 'invalid or repeated archive member ' .. object)
  members[object] = true
  local source = src .. '/' .. name
  local is_nelua = name:match('%.nelua$')
  if is_nelua then
    -- A named intermediate keeps TinyCC's ELF FILE symbol independent of
    -- necc's private temporary directory on each invocation.
    local generated = output(object .. '.c')
    edge(generated, {{source}, nelua_frontend}, 'NECC_SYSROOT=' .. quote(sdk) .. ' ' ..
      command({necc, '--release', '--emit-c', source, '-o', generated}))
    source = generated
  end
  if bootstrap[name] or name:match('%.S$') then
    local args = {gcc, '-m64', '-O2', '-fno-pie', '-ffreestanding', '-fno-builtin', '-fno-stack-protector',
      '-fno-tree-loop-distribute-patterns', '-ftls-model=local-exec', '-nostdinc', '-DNELIBC_STANDALONE',
      '-I' .. tree .. '/include', '-isystem', builtin, '-isystem', sdk .. '/uapi'}
    if name == 'memory_x86_64.S' then args[#args + 1] = '-DNELIBC_TCC_PUBLIC_MEMCPY' end
    for _, word in ipairs({'-c', source, '-o', output(object)}) do args[#args + 1] = word end
    edge(output(object), {{source, gcc}, target_headers, compiler_headers}, command(args))
  elseif native_objects[name] then
    local compiler_target = native_driver and native_driver.target or necc
    local compiler = native_driver and native_driver.command or necc
    local args = {compiler, '-c', '-DNELIBC_STANDALONE'}
    for _, dir in ipairs({tree .. '/include', sdk .. '/include', sdk .. '/tcc/include', sdk .. '/uapi'}) do
      args[#args + 1] = '-I' .. dir
    end
    for _, word in ipairs({source, '-o', output(object)}) do args[#args + 1] = word end
    edge(output(object), {{source, compiler_target, tcc}, target_headers}, 'NECC_SYSROOT=' .. quote(sdk) .. ' ' .. command(args))
  else
    local args = {tcc, '-B' .. sdk .. '/tcc', '-std=c11', '-ffreestanding', '-nostdinc', '-DNELIBC_STANDALONE',
      '-I' .. tree .. '/include', '-I' .. sdk .. '/include', '-I' .. sdk .. '/tcc/include', '-I' .. sdk .. '/uapi',
      '-c', source, '-o', output(object)}
    edge(output(object), {{source, tcc}, target_headers}, command(args))
  end
  objects[#objects + 1] = output(object)
end

local archive = output('libnelibc.a')
if archiver then
  edge(archive, {{archiver}, objects}, command({executable('nelinker'), '--archive', '-o', archive, table.unpack(objects)}))
else
  edge(archive, {{tcc}, objects}, command({tcc, '-ar', 'rcs', archive, table.unpack(objects)}))
end
if prefix == '' then print('default ' .. archive) end
