--[[
Burning as one counted affliction. Achaea replaced the burn ladder with one
affliction, `burning`, which GMCP reports with a level, and svof's five rungs
(ablaze, severeburn, extremeburn, charredburn, meltingburn) are one counted
entry now, still called ablaze (the repo owner, 2026-09-25).

It runs svof's real loaders through tools/svof_world.lua, and checks how the
level moves: GMCP's level, catching fire again and the four escalation lines
(a level up each), DIAGNOSE's rung lines (levels 2 to 5), mending and a tree
touch (a level down each, the user, 2026-10-31), the line that ends it, and
pyre, which keeps ablaze from being cured below its own level (AFFLICTION
SHOW).

  lua tools/test_burning.lua
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local function read(path)
  local f = assert(io.open(path, "r"))
  local s = f:read("*a")
  f:close()
  return s
end

local T = "src/triggers/svo (aliases, triggers)/svo/"

-- the level svof has, or nil without burning
local function level(svo)
  if not svo.affs.ablaze then return nil end
  return svo.dict.ablaze.count
end

-- burning at n, as a text gain and then GMCP's level would leave it
local function burning(w, n)
  w.svo.addaffdict(w.svo.dict.ablaze)
  w.svo.dict.ablaze.count = n
end

do -- one entry
  local w = world.new()
  local svo = w.svo
  for _, rung in ipairs({ "severeburn", "extremeburn", "charredburn", "meltingburn" }) do
    eq(svo.dict[rung], nil, rung .. " is gone")
  end
  eq(svo.dict.sstosvoa.burning, "ablaze", "GMCP's burning is ablaze")
  eq(svo.dict.ablaze.count, 0, "with a count")
  eq(svo.sk.burns, nil, "and no ladder")
  local tag = read("src/scripts/svo (core)/svo Utilities/Custom prompt tags/@affs.lua")
  eq(tag:find("[2345]burn") , nil, "@affs has no rung tags")
  for _, path in ipairs({ "default_prios", "src/resources/default_prios" }) do
    eq(read(path):find("severeburn", 1, true), nil, path .. " has no rungs")
  end
end

do -- GMCP's level
  local w = world.new()
  local svo = w.svo
  w.env.gmcp.Char.Afflictions.Add = { name = "burning (3)", cure = "", desc = "" }
  svo.signals.gmcpcharafflictionsadd:emit()
  eq(level(svo), 3, "GMCP's burning (3) is ablaze at 3")
  w.env.gmcp.Char.Afflictions.Add = { name = "burning (4)", cure = "", desc = "" }
  svo.signals.gmcpcharafflictionsadd:emit()
  eq(level(svo), 4, "and a later burning (4) moves it to 4")
end

-- With GMCP, its Add carries the level a line brought, before the prompt
-- that settles the line, so the line must not move it again
local function gmcp_list(w, names)
  local list = {}
  for i, name in ipairs(names) do list[i] = { name = name, cure = "", desc = "" } end
  w.env.gmcp.Char.Afflictions.List = list
  w.svo.signals.gmcpcharafflictionslist:emit()
end
local function gmcp_add(w, name)
  w.env.gmcp.Char.Afflictions.Add = { name = name, cure = "", desc = "" }
  w.svo.signals.gmcpcharafflictionsadd:emit()
end

do -- catching fire again with GMCP
  local w = world.new()
  local svo = w.svo
  gmcp_list(w, { "burning (2)" })
  eq(level(svo), 2, "GMCP's list has burning at 2")
  gmcp_add(w, "burning (3)")
  svo.valid.proper_ablaze()
  w.prompt()
  eq(level(svo), 3, "catching fire again with GMCP is GMCP's 3, not 4")
end

do -- mending with GMCP
  local w = world.new()
  local svo = w.svo
  gmcp_list(w, { "burning (3)" })
  svo.doaction(svo.dict.ablaze.salve)
  gmcp_add(w, "burning (2)")
  svo.valid.cured_burn_health()
  w.prompt()
  eq(level(svo), 2, "mending with GMCP is GMCP's 2, not 1")
end

do -- DIAGNOSE's level stands with GMCP too, as a diagnose is the game's list
  local w = world.new()
  local svo = w.svo
  gmcp_list(w, { "burning (2)" })
  svo.lifevision.add(svo.dict.diag.physical)
  w.run(read(T .. "General/charredburn.lua"), "diag")
  svo.valid.diagnose_end()
  w.prompt()
  eq(level(svo), 4, "DIAGNOSE's charred line sets 4 with GMCP on")
end

do -- GMCP with no level is level 1
  local w = world.new()
  local svo = w.svo
  w.env.gmcp.Char.Afflictions.Add = { name = "burning", cure = "", desc = "" }
  svo.signals.gmcpcharafflictionsadd:emit()
  eq(level(svo), 1, "GMCP's burning with no level is ablaze at 1")
end

do -- catching fire, and again
  local w = world.new()
  local svo = w.svo
  svo.valid.proper_ablaze()
  w.prompt()
  eq(level(svo), 1, "catching fire is level 1")
  svo.valid.proper_ablaze()
  w.prompt()
  eq(level(svo), 2, "catching fire again is a level up")
end

do -- the four escalation lines, a level up each
  local w = world.new()
  local svo = w.svo
  burning(w, 1)
  local n = 1
  for _, file in ipairs({ "Severe_burn", "Extreme_burn", "Charred_burn", "Melting_burn" }) do
    w.run(read(T .. "Poisons + Generic lines/" .. file .. ".lua"), file)
    w.prompt()
    n = n + 1
    eq(level(svo), n, file .. "'s line takes burning to " .. n)
  end
end

do -- level 5 warns of a golem's destroy, as meltingburn did
  local w = world.new()
  local svo = w.svo
  local warned = 0
  local warn = svo.sk.warn
  svo.sk.warn = function(what) if what == 'golemdestroyable' then warned = warned + 1 end return warn(what) end
  burning(w, 4)
  svo.valid.simpleablaze()
  w.prompt()
  eq(level(svo), 5, "a level up from 4 is 5")
  eq(warned, 1, "which warns of a golem's destroy")
end

-- DIAGNOSE: a rung line's level, or "ablaze." as at least 1
for _, case in ipairs({
  { "ablaze", nil, 1 }, { "severeburn", nil, 2 }, { "extremeburn", nil, 3 }, { "charredburn", nil, 4 },
  { "meltingburn", nil, 5 }, { "extremeburn", 1, 3 }, { "ablaze", 4, 4 },
}) do
  local file, before, want = case[1], case[2], case[3]
  local w = world.new()
  local svo = w.svo
  if before then burning(w, before) end
  w.run(read(T .. "General/" .. file .. ".lua"), file)
  svo.valid.diagnose_end()
  w.prompt()
  eq(level(svo), want, string.format("DIAGNOSE's %s line, at %s, is level %d", file, tostring(before), want))
end

do -- mending: a level down, and the line that ends it
  local w = world.new()
  local svo = w.svo
  burning(w, 3)
  eq(not not svo.dict.ablaze.salve.isadvisable(), true, "mending is advisable while burning")
  w.sent = {}
  svo.dict.ablaze.salve.onstart()
  eq(w.sent[1], "apply mending to body", "and applies mending to the body")
  svo.doaction(svo.dict.ablaze.salve)
  svo.valid.cured_burn_health()
  w.prompt()
  eq(level(svo), 2, "\"diminish somewhat\" after mending takes a level off")
  svo.reset.bals()
  svo.doaction(svo.dict.ablaze.salve)
  svo.valid.salve_cured_ablaze()
  svo.valid.cured_burns_health()
  w.prompt()
  eq(level(svo), nil, "\"goes out\" after mending ends it")
  eq(svo.dict.ablaze.count, 0, "and its count")
end

do -- mending at level 1
  local w = world.new()
  local svo = w.svo
  burning(w, 1)
  svo.doaction(svo.dict.ablaze.salve)
  svo.valid.cured_burn_health()
  w.prompt()
  eq(level(svo), nil, "a level off level 1 ends it")
end

do -- passive curing
  local w = world.new()
  local svo = w.svo
  burning(w, 4)
  svo.valid.generic_burn()
  w.prompt()
  eq(level(svo), 3, "\"diminish somewhat\" on its own takes a level off")
  svo.valid.generic_burn(2)
  w.prompt()
  eq(level(svo), 1, "and two, when told two")
end

do -- a tree touch: a level down, and "goes out" ends it
  local w = world.new()
  local svo = w.svo
  burning(w, 3)
  svo.doaction(svo.dict.touchtree.misc)
  svo.valid.tree_cured('burn')
  w.prompt()
  eq(level(svo), 2, "a tree touch takes a level off")
  svo.reset.bals()
  svo.doaction(svo.dict.touchtree.misc)
  svo.valid.tree_cured('all burns')
  w.prompt()
  eq(level(svo), nil, "and \"goes out\" on a touch ends it")
end

-- pyre: ablaze can't be cured below pyre's level, so mending at or under it
-- is wasted. Pyre caps at 3 in game
for p = 1, 3 do
  for b = 1, 5 do
    local w = world.new()
    local svo = w.svo
    svo.addaffdict(svo.dict.pyre)
    svo.dict.pyre.count = p
    burning(w, b)
    local held = p >= b
    eq(svo.codepaste.pyre_holds(), held, string.format("pyre %d holds burning %d: %s", p, b, tostring(held)))
    eq(svo.dict.ablaze.salve.isadvisable(), not held, "and mending is advisable only when it isn't held")
  end
end

do -- pyre's traps: no pyre, no count, and the count on .p
  local w = world.new()
  local svo = w.svo
  burning(w, 1)
  eq(svo.codepaste.pyre_holds(), false, "no pyre holds nothing")
  svo.addaffdict(svo.dict.pyre)
  svo.dict.pyre.count = 0
  eq(svo.codepaste.pyre_holds(), true, "pyre with no level yet is level 1, and holds burning 1")
  svo.dict.ablaze.count = 2
  eq(svo.codepaste.pyre_holds(), false, "and frees burning 2")
  svo.rmaff('ablaze')
  eq(svo.codepaste.pyre_holds(), false, "with no burning, nothing to hold")
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
