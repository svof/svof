--[[
Removal paths, through tools/svof_world.lua and the real loaders. The bugs
this class hides are quiet: svo.rmaff returns before it consults svo.dict,
by design, so a handler that removes the wrong name does nothing and says
nothing (mindravaged removed "burning"; two handlers checked "asleep").

  * every affliction entry's gone removes that entry
  * svo.removeaff and svo.removeafflevel, the public removals, take every
    affliction off, and keep leaves an uncounted one. removeaff recursed
    into itself on the eight check* entries, and removeafflevel raised on
    every entry with no general_cure, 168 of them

  lua tools/test_removal_paths.lua
]]

local world = dofile("tools/svof_world.lua")

-- entries whose gone is meant to leave the affliction tracked, and why
local GONE_KEEPS = {
  -- the insomnia defence, which has an affliction block too: its gone takes
  -- the defence off (the svof-insomnia-defence-and-cure memory)
  insomnia = true,
}

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local base = world.new()
local names = {}
for name, entry in pairs(base.svo.dict) do
  if type(entry) == 'table' and entry.aff then names[#names + 1] = name end
end
table.sort(names)
eq(#names > 150, true, "there are affliction entries to check (" .. #names .. ")")

-- ===== 1. gone removes its own entry =====

local seen = {}
for _, name in ipairs(names) do
  local entry = base.svo.dict[name]
  if entry.gone and entry.gone.oncompleted and not GONE_KEEPS[name] then
    local w = world.new()
    local svo = w.svo
    local ok, err = pcall(function()
      svo.addaffdict(svo.dict[name])
      svo.dict[name].gone.oncompleted()
    end)
    eq(ok and svo.affs[name] == nil, true, name .. "'s gone removes it" .. (ok and "" or (": " .. tostring(err))))
  end
end
for name in pairs(GONE_KEEPS) do
  eq(base.svo.dict[name] ~= nil and base.svo.dict[name].gone ~= nil, true, name .. " is still an entry with a gone")
end

-- ===== 2. the public removals =====

local w = world.new()
local svo = w.svo
for _, name in ipairs(names) do
  for _, fn in ipairs({ 'removeaff', 'removeafflevel' }) do
    if not (GONE_KEEPS[name] and svo.dict[name].gone) then
      local ok, err = pcall(function()
        svo.addaffdict(svo.dict[name])
        svo[fn](name)
      end)
      eq(ok and svo.affs[name] == nil, true, "svo." .. fn .. " takes " .. name .. " off" .. (ok and "" or (": " .. tostring(err))))
      svo.affs[name] = nil
    end
  end
end

-- keep leaves an affliction that isn't counted, and a counted one at its
-- first level
local ok, err = pcall(function()
  svo.addaffdict(svo.dict.asthma)
  svo.removeafflevel('asthma', nil, true)
  eq(svo.affs.asthma ~= nil, true, "removeafflevel with keep leaves asthma, which isn't counted")
  svo.rmaff('asthma')
  svo.addaffdict(svo.dict.skullfractures)
  svo.dict.skullfractures.count = 3
  svo.removeafflevel('skullfractures', 1)
  eq(svo.dict.skullfractures.count, 2, "removeafflevel takes a level off skullfractures")
  svo.removeafflevel('skullfractures', 5, true)
  eq(svo.affs.skullfractures ~= nil, true, "and with keep, leaves it at its first")
  eq(svo.dict.skullfractures.count, 1, "at a count of 1")
end)
eq(ok, true, "removeafflevel with keep runs (" .. tostring(err) .. ")")

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
