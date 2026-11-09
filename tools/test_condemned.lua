--[[
condemned: a Paladin's 40-second affliction that nothing cures, and that
keeps ablaze from being cured while it lasts (AFFLICTION SHOW, captured
2026-10-20, claude-notes/reference/affliction_show.lua).

It runs svof's real loaders through tools/svof_world.lua: GMCP's name maps
to the entry, gaining it starts its 40 seconds, the wore-off line and the
time each take it off, and no burn salve is advisable while it lasts. An
empty tree touch or mending while it lasts says nothing about the burns.

  lua tools/test_condemned.lua
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local function gmcp_aff_add(w, name)
  w.env.gmcp.Char.Afflictions.Add = { name = name, cure = "", desc = "" }
  w.svo.signals.gmcpcharafflictionsadd:emit()
end

-- burning, at every level the old ladder had
local BURNS = { 1, 2, 3, 4, 5 }

do -- GMCP's name, and its time
  local w = world.new()
  local svo = w.svo
  eq(svo.dict.sstosvoa.condemned, "condemned", "GMCP's condemned is svof's")
  gmcp_aff_add(w, "condemned")
  eq(not not svo.affs.condemned, true, "GMCP adds it")
  eq(w.inflight(), "condemned_waitingfor", "which starts its time")
  w.advance(39)
  eq(not not svo.affs.condemned, true, "it's still there after 39s")
  w.advance(2)
  eq(svo.affs.condemned, nil, "and it's gone after 40s")
  eq(w.inflight(), "", "leaving nothing in flight")
end

do -- the wore-off line
  local w = world.new()
  local svo = w.svo
  svo.addaffdict(svo.dict.condemned)
  svo.valid.condemned_woreoff()
  w.prompt()
  eq(svo.affs.condemned, nil, "the wore-off line takes it off")
  eq(w.inflight(), "", "and stops its time")
end

do -- DIAGNOSE
  local w = world.new()
  local svo = w.svo
  svo.valid.diag('condemned')
  eq(svo.sk.diag_list.condemned, true, "DIAGNOSE reports it")
end

for _, level in ipairs(BURNS) do -- no burn salve while condemned
  local w = world.new()
  local svo = w.svo
  svo.addaffdict(svo.dict.ablaze)
  svo.dict.ablaze.count = level
  local burn = "burning " .. level
  eq(svo.dict.ablaze.salve.isadvisable(), true, burn .. "'s salve is advisable")
  svo.addaffdict(svo.dict.condemned)
  eq(svo.dict.ablaze.salve.isadvisable(), false, "but not while condemned")
  svo.rmaff('condemned')
  eq(svo.dict.ablaze.salve.isadvisable(), true, "and is again once it's gone")
end

do -- the tree: ablaze can't be cured while condemned, so a touch can't cure it
  local w = world.new()
  local svo = w.svo
  svo.addaffdict(svo.dict.ablaze)
  eq(table.concat(svo.gettreeableaffs(), ","), "ablaze", "the tree can cure ablaze")
  svo.addaffdict(svo.dict.condemned)
  eq(table.concat(svo.gettreeableaffs(), ","), "", "but not while condemned")
  -- with GMCP off, an empty touch while condemned used to rule ablaze out
  eq(svo.gmcp_live(), false, "GMCP isn't live here")
  svo.empty.tree()
  eq(not not svo.affs.ablaze, true, "so an empty touch while condemned keeps ablaze")
  svo.rmaff('condemned')
  eq(table.concat(svo.gettreeableaffs(), ","), "ablaze", "and the tree can cure it again once condemned is gone")
end

-- an empty mending while condemned says nothing about burning either. With
-- GMCP off it took it off, and once condemned wore off nothing cured it
-- (review of #888)
for _, level in ipairs(BURNS) do
  local w = world.new()
  local svo = w.svo
  local burn = "burning " .. level
  svo.addaffdict(svo.dict.ablaze)
  svo.dict.ablaze.count = level
  svo.addaffdict(svo.dict.crippledleftarm)
  svo.addaffdict(svo.dict.condemned)
  eq(svo.gmcp_live(), false, burn .. ": GMCP isn't live here")
  svo.empty.apply_mending()
  eq(not not svo.affs.ablaze, true, burn .. ": an empty mending while condemned keeps it")
  eq(svo.dict.ablaze.count, level, burn .. ": at its level")
  eq(not not svo.affs.crippledleftarm, false, burn .. ": and still rules out what mending cures")
  svo.rmaff('condemned')
  eq(svo.dict.ablaze.salve.isadvisable(), true, burn .. ": and its salve is advisable once condemned is gone")
  svo.empty.apply_mending()
  eq(not not svo.affs.ablaze, false, burn .. ": then an empty mending rules it out, as before")
end

do -- its abbreviation in the @affs prompt tag
  local f = assert(io.open("src/scripts/svo (core)/svo Utilities/Custom prompt tags/@affs.lua", "r"))
  local tag = f:read("*a")
  f:close()
  eq(tag:match('\n%s*condemned%s*=%s*"([^"]*)"'), "cond", "@affs shows it as cond")
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
