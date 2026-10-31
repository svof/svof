--[[
condemned: a Paladin's 40-second affliction that nothing cures, and that
keeps ablaze from being cured while it lasts (AFFLICTION SHOW, captured
2026-10-20, claude-notes/reference/affliction_show.lua).

It runs svof's real loaders through tools/svof_world.lua: GMCP's name maps
to the entry, gaining it starts its 40 seconds, the wore-off line and the
time each take it off, and no burn salve is advisable while it lasts.

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

local BURNS = { 'ablaze', 'severeburn', 'extremeburn', 'charredburn', 'meltingburn' }

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

for _, burn in ipairs(BURNS) do -- no burn salve while condemned
  local w = world.new()
  local svo = w.svo
  svo.addaffdict(svo.dict[burn])
  eq(svo.dict[burn].salve.isadvisable(), true, burn .. "'s salve is advisable")
  svo.addaffdict(svo.dict.condemned)
  eq(svo.dict[burn].salve.isadvisable(), false, "but not while condemned")
  svo.rmaff('condemned')
  eq(svo.dict[burn].salve.isadvisable(), true, "and is again once it's gone")
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
