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
  * every affliction name the code reads, in affs.<name>, affs['<name>'],
    rmaff('<name>') and svo.dict.<name>, is an entry svof has in some class.
    It found asleep, a shield check reading mangledlrightarm, an arm check
    reading unwknowncrippledarm, two reading missing arms svof never had,
    and a hypochondria guard reading illness_constitution

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

-- bleeding's count is how much you bleed for, not a level: removeafflevel
-- took 1 HP off and left it tracked (review of #897)
ok, err = pcall(function()
  svo.addaffdict(svo.dict.bleeding)
  svo.dict.bleeding.count = 400
  eq(svo.removeafflevel('bleeding'), true, "removeafflevel on bleeding reports it removed")
  eq(svo.affs.bleeding, nil, "and takes bleeding off, whatever it bleeds for")
  eq(svo.dict.bleeding.count, 0, "with nothing left to bleed")
  svo.addaffdict(svo.dict.bleeding)
  svo.dict.bleeding.count = 400
  svo.removeafflevel('bleeding', nil, true)
  eq(svo.affs.bleeding ~= nil, true, "with keep, bleeding stays, as one that isn't counted")
  eq(svo.dict.bleeding.count, 400, "and bleeds for what it did")
end)
eq(ok, true, "removeafflevel on bleeding runs (" .. tostring(err) .. ")")

-- ===== 3. every name read is an entry =====

-- names read that aren't entries, and why. A fixed one fails until it's
-- taken off this list, so it can only get shorter
local NOT_ENTRIES = {
  -- sk.unparryable_symptom's guard: a weapon you can't parry with is in
  -- me.unparryables, and no affliction is unparryable
  unparryable = true,
  -- symp_asleep and transfixily, fixed by #893
  asleep = true,
}

local CLASSES = { "Alchemist", "Apostate", "Bard", "Blademaster", "Depthswalker", "Druid", "Infernal", "Jester",
  "Magi", "Monk", "None", "Occultist", "Paladin", "Pariah", "Priest", "Runewarden", "Sentinel", "Serpent",
  "Shaman", "Sylvan", "Psion", "Unnamable", "Earth Elemental Lord", "Fire Elemental Lord", "Air Elemental Lord",
  "Water Elemental Lord" }
local entries = {}
for _, class in ipairs(CLASSES) do
  for name, entry in pairs(world.new({ class = class }).svo.dict) do
    if type(entry) == 'table' then entries[name] = true end
  end
end

local READS = {
  "%f[%w_]affs%.([%a_][%w_]*)", "%f[%w_]affs%[%s*['\"]([%w_]+)['\"]%s*%]",
  "%f[%w_]rmaff%(%s*['\"]([%w_]+)['\"]", "%f[%w_]svo%.dict%.([%a_][%w_]*)",
}
-- an affliction entry's own fields, read through affs
local FIELDS = { p = true, sw = true, count = true }

local files = io.popen('git ls-files -- "src/*.lua"')
local found, scanned = {}, 0
for path in files:lines() do
  if not path:find("3rdparty", 1, true) and not path:find("src/resources/", 1, true) then
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    scanned = scanned + 1
    local n = 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
      n = n + 1
      local code = line:gsub("%-%-.*$", "")
      for _, pattern in ipairs(READS) do
        for name in code:gmatch(pattern) do
          if not entries[name] and not FIELDS[name] then
            found[name] = found[name] or (path .. ":" .. n)
          end
        end
      end
    end
  end
end
files:close()
eq(scanned > 1000, true, "the source files are there to read (" .. scanned .. ")")
for name, where in pairs(found) do
  eq(NOT_ENTRIES[name] or false, true, "the code reads " .. name .. ", which svof has no entry for (" .. where .. ")")
end
for name in pairs(NOT_ENTRIES) do
  eq(found[name] ~= nil, true, name .. " is still read somewhere; if not, take it off NOT_ENTRIES")
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
