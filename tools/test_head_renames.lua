--[[
svof's mildconcussion and seriousconcussion are the game's damagedhead and
mangledhead (AFFLICTION SHOW, captured 2026-10-20), and now have those names.
A player's saved priorities and ignore list name them the old way, and both
loads read the old names as the new ones (svo.renamed_affs).

It runs svof's real loaders through tools/svof_world.lua.

  lua tools/test_head_renames.lua
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

do -- the entries and GMCP's names
  local w = world.new()
  local svo = w.svo
  eq(svo.dict.mildconcussion, nil, "mildconcussion is gone")
  eq(svo.dict.seriousconcussion, nil, "and seriousconcussion")
  eq(svo.dict.sstosvoa.damagedhead, "damagedhead", "GMCP's damagedhead is svof's")
  eq(svo.dict.sstosvoa.mangledhead, "mangledhead", "GMCP's mangledhead is svof's")
  eq(svo.dict.damagedhead.gamename, nil, "damagedhead needs no gamename")
  eq(svo.dict.mangledhead.gamename, nil, "nor mangledhead")
end

-- a saved list, as prio.export writes one, with the old names
local SAVED = [[
salve = {
  [3] = "mildconcussion",
  [4] = "seriousconcussion",
  [5] = "anorexia",
}
slowcuring = {
  [7] = "mildconcussion_salve",
  [8] = "seriousconcussion_salve",
  [9] = "anorexia_salve",
}
]]

local function import(text)
  local w = world.new()
  local svo = w.svo
  local path = "test_head_renames.tmp"
  local f = assert(io.open(path, "w"))
  f:write(text)
  f:close()
  w.env.invokeFileDialog = function() return path end
  local attributes = w.env.lfs.attributes
  w.env.lfs.attributes = function(p) if p == path then return {} end return attributes(p) end
  -- prio.import reads the list with Lua 5.1's loadstring and setfenv
  if not w.env.loadstring then
    w.env.loadstring = function(code, name) return load(code, name) end
    w.env.setfenv = function(fn, env) debug.setupvalue(fn, 1, env) return fn end
  end
  local done, ok = pcall(svo.prio.import, nil, false, false)
  w.env.lfs.attributes = attributes
  -- prio.import leaves the list open as io.input, which Windows won't delete
  io.input(io.stdin)
  collectgarbage()
  os.remove(path)
  if not done then error(ok, 0) end
  return w, ok
end

-- the same list saved under the new names, which the old one must import as
local SAVED_NEW = SAVED:gsub("mildconcussion", "damagedhead"):gsub("seriousconcussion", "mangledhead")

-- the places an import gives: dict_setup renumbers them, keeping the order
local function places(w)
  local d = w.svo.dict
  return table.concat({ d.damagedhead.salve.aspriority, d.mangledhead.salve.aspriority, d.anorexia.salve.aspriority,
    d.damagedhead.salve.spriority, d.mangledhead.salve.spriority, d.anorexia.salve.spriority }, " ")
end

do -- the saved priorities
  local w, ok = import(SAVED)
  local svo = w.svo
  local want = import(SAVED_NEW)
  eq(ok, true, "the saved list imports")
  eq(places(w), places(want), "the old names import as the new ones would, in slow curing too")
  local d = svo.dict
  eq(d.damagedhead.salve.aspriority < d.mangledhead.salve.aspriority and
    d.mangledhead.salve.aspriority < d.anorexia.salve.aspriority, true, "in the saved order")
  eq(d.damagedhead.salve.spriority < d.mangledhead.salve.spriority and
    d.mangledhead.salve.spriority < d.anorexia.salve.spriority, true, "and in slow curing's")
  for _, balance in ipairs({ "salve", "slowcuring" }) do
    for _, action in pairs(svo.prio.kept[balance] or {}) do
      eq(action:find("concussion"), nil, "the old names aren't kept as unknown ones in " .. balance)
    end
  end
end

do -- a list that has the new name already keeps it
  local both = [[
salve = {
  [3] = "mildconcussion",
  [6] = "anorexia",
  [9] = "damagedhead",
}
]]
  local d = import(both).svo.dict
  eq(d.anorexia.salve.aspriority < d.damagedhead.salve.aspriority, true, "a list with damagedhead keeps its place")
end

do -- the ignore list
  local w = world.new()
  local svo = w.svo
  w.env.table.load = function(_, t)
    t.mildconcussion = { because = "a test" }
    t.seriousconcussion = true
    t.mangledhead = { because = "already there" }
  end
  -- Setup.lua has its own lfs, from require
  local lfs = w.env.require('lfs')
  local attributes = lfs.attributes
  lfs.attributes = function(p)
    if p == "./svo/config/ignore" then return {} end
    return attributes(p)
  end
  svo.signals.systemstart:emit()
  lfs.attributes = attributes
  eq(type(svo.ignore.damagedhead), "table", "an ignored mildconcussion is an ignored damagedhead")
  eq(svo.ignore.damagedhead and svo.ignore.damagedhead.because, "a test", "with its reason")
  eq(svo.ignore.mangledhead and svo.ignore.mangledhead.because, "already there", "one already ignored keeps its reason")
  eq(svo.ignore.mildconcussion, nil, "and the old names are gone")
  eq(svo.ignore.seriousconcussion, nil, "both of them")
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
