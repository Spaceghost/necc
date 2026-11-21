-- Render the complete Lua runtime for nebuild, using each original translation unit.
local lfs = require 'lfs'

local function absolute(path)
  if path:sub(1, 1) ~= '/' then path = lfs.currentdir() .. '/' .. path end
  return (path:gsub('/%./', '/'):gsub('/+$', ''))
end

assert(#arg == 3, 'usage: render-lua.lua NECC SYSROOT NELUA_SRC')
local necc, sdk, tree = absolute(arg[1]), absolute(arg[2]), absolute(arg[3])
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
  local obj = unit:gsub('%.c$', '.o'):gsub('/', '-')
  local file = src .. '/' .. unit
  local deps = dependencies(file)
  deps[#deps + 1] = tcc
  deps[#deps + 1] = necc
  edge(obj, deps, 'NECC_SYSROOT=' .. quote(sdk) .. ' ' ..
    command({necc, '-DNDEBUG', '-DLUA_USE_POSIX', '-DMAXRECLEVEL=400', '-isystem', src .. '/lua', '-c', file, '-o', obj}))
  objects[#objects + 1] = obj
end
local archive, support = sdk .. '/libnelibc.a', sdk .. '/tcc/libtcc1.a'
local deps = {necc, tcc, archive, support, table.unpack(objects)}
local args = {necc, table.unpack(objects)}
args[#args + 1] = '-o'
args[#args + 1] = 'nelua-lua'
edge('nelua-lua', deps, 'NECC_SYSROOT=' .. quote(sdk) .. ' ' .. command(args))
print('default nelua-lua')
