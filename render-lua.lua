-- Render the complete Lua runtime for nebuild, using each original translation unit.
local lfs = require 'lfs'

local function absolute(path)
  if path:sub(1, 1) ~= '/' then path = lfs.currentdir() .. '/' .. path end
  return (path:gsub('/%./', '/'):gsub('/+$', ''))
end

assert(#arg == 3 or #arg == 4 or #arg == 5, 'usage: render-lua.lua NECC SYSROOT NELUA_SRC [OUTPUT_PREFIX [ARCHIVE_INPUT]]')
local necc, sdk, tree = absolute(arg[1]), absolute(arg[2]), absolute(arg[3])
local prefix = arg[4] and arg[4]:gsub('/+$', '') or ''
assert(not arg[4] or (prefix ~= '' and prefix:sub(1, 1) ~= '/' and not prefix:find('%s')),
  'output prefix must be a relative path without whitespace')
local function output(name)
  return prefix == '' and name or prefix .. '/' .. name
end
local archive_override = arg[5]
local src = tree .. '/src'
local tcc = sdk .. '/tcc/tcc'
local flags = {'-B' .. sdk .. '/tcc', '-std=gnu99', '-nostdinc', '-DNELIBC_STANDALONE',
  '-DNDEBUG', '-DLUA_USE_POSIX', '-DMAXRECLEVEL=400', '-I' .. sdk .. '/include',
  '-I' .. sdk .. '/tcc/include', '-I' .. sdk .. '/uapi', '-I' .. src .. '/lua'}

local function quote(word)
  return "'" .. word:gsub("'", "'\\''") .. "'"
end

local function command(args)
  local words = {}
  for i, word in ipairs(args) do words[i] = quote(word) end
  return table.concat(words, ' ')
end

local function compiler(...)
  local args = {tcc, table.unpack(flags)}
  for _, item in ipairs({...}) do args[#args + 1] = item end
  return command(args)
end

local function dependencies(file)
  local pipe = assert(io.popen(compiler('-nostdlib', '-M', file), 'r'))
  local report = assert(pipe:read('a'))
  assert(pipe:close(), 'preprocessing failed for ' .. file)
  -- TinyCC puts one actual prerequisite on each indented line.
  local deps = {}
  for line in report:gmatch('\n  ([^\n]+)') do
    deps[#deps + 1] = line:gsub(' \\$','')
  end
  assert(deps[1] == file, 'unexpected TinyCC dependency output for ' .. file)
  return deps
end

local function edge(target, deps, recipe)
  local words = {'build', target}
  local seen = {}
  for _, path in ipairs(deps) do
    assert(not path:find('%s'), 'nebuild manifest paths cannot contain whitespace: ' .. path)
    if not seen[path] then words[#words + 1], seen[path] = path, true end
  end
  if prefix ~= '' then recipe = 'mkdir -p ' .. quote(prefix) .. ' && ' .. recipe end
  io.write(table.concat(words, ' '), '\n\t', recipe, '\n')
end

local units = {'luainit.c', 'sys.c', 'lfs.c', 'hasher.c'}
for _, subdir in ipairs({'lua', 'lpeglabel'}) do
  for name in lfs.dir(src .. '/' .. subdir) do
    if name:match('%.c$') and name ~= 'luac.c' then
      units[#units + 1] = subdir .. '/' .. name
    end
  end
end
table.sort(units)
local objects = {}
for _, unit in ipairs(units) do
  local obj = output(unit:gsub('%.c$', '.o'):gsub('/', '-'))
  local file = src .. '/' .. unit
  local deps = dependencies(file)
  deps[#deps + 1] = tcc
  deps[#deps + 1] = necc
  edge(obj, deps, 'NECC_SYSROOT=' .. quote(sdk) .. ' ' ..
    command({necc, '-DNDEBUG', '-DLUA_USE_POSIX', '-DMAXRECLEVEL=400', '-isystem', src .. '/lua', '-c', file, '-o', obj}))
  objects[#objects + 1] = obj
end
local archive, support = archive_override or sdk .. '/libnelibc.a', sdk .. '/tcc/libtcc1.a'
local runtime = output('nelua-lua')
local deps = {tcc, archive, support, table.unpack(objects)}
if archive_override then
  local args = {tcc, '-B' .. sdk .. '/tcc', '-nostdlib', '-static', '-Wl,-e,_start', '-o', runtime}
  for _, obj in ipairs(objects) do args[#args + 1] = obj end
  for _, word in ipairs({'-Wl,--whole-archive', archive, '-Wl,--no-whole-archive', support}) do args[#args + 1] = word end
  edge(runtime, deps, command(args))
else
  deps[#deps + 1] = necc
  edge(runtime, deps, 'NECC_SYSROOT=' .. quote(sdk) .. ' ' .. command({necc, '-o', runtime, table.unpack(objects)}))
end
if prefix == '' then print('default ' .. runtime) end
