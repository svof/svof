--[[
Afflictions a player defines (vcustomaff): svo.affcures, which reads the
Cure(s) text of the game's AFFLICTION SHOW, and svo.basicaff, which builds
a dictionary entry from it.

It runs svof's real loaders through tools/svof_world.lua, and checks each
built entry against svof's own hand-written entry for the same cure:
clumsiness for kelp, itching for epidermal on the body, disloyalty for
valerian, voyria for immunity and scalded for a timed one. Both are given
the same state, and must say and send the same.

  lua tools/test_afflictions.lua
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local function counter(w, name)
  local c = { n = 0 }
  local real = w.svo[name]
  w.svo[name] = function(...) c.n = c.n + 1 return real(...) end
  return c
end

local function describe(cures)
  if not cures then return "nil" end
  local t = {}
  for _, c in ipairs(cures) do
    t[#t + 1] = c.kind .. (c[1] and (" " .. c[1] .. "/" .. tostring(c[2])) or "") .. (c.place and (" to " .. c.place) or "")
  end
  return table.concat(t, ", ")
end

-- what an action's onstart sends
local function sends(w, act)
  w.sent = {}
  act.onstart()
  return table.concat(w.sent, "; ")
end

-- ===== 1. Reading Cure(s) =====

do
  local w = world.new()
  local affcures = w.svo.affcures
  for text, expected in pairs({
    ["Eat Ginseng / Eat Ferrum"] = "herb ginseng/ferrum",
    ["Eat Ferrum"] = "herb ginseng/ferrum",
    ["eat   kelp "] = "herb kelp/aurum",
    ["Time"] = "time",
    ["Apply Epidermal to Head"] = "salve epidermal/sensory to head",
    ["Apply Sensory to Body / Apply Epidermal to Body"] = "salve epidermal/sensory to body",
    ["Apply Caloric"] = "salve caloric/exothermic",
    ["Smoke Valerian"] = "smoke valerian/realgar",
    ["Smoke Realgar"] = "smoke valerian/realgar",
    ["Sip Immunity"] = "purgative immunity/antigen",
    ["Eat Bloodroot / Smoke Valerian"] = "herb bloodroot/magnesium, smoke valerian/realgar",
  }) do
    eq(describe((affcures(text))), expected, "Cure(s) " .. text)
  end
  for text, why in pairs({
    [""] = "it has no cure",
    ["Stand"] = 'Svof can\'t cure with "stand"',
    ["Eat Pear"] = 'Svof can\'t cure with "eat pear"',
    ["Smoke Kelp"] = 'Svof can\'t cure with "smoke kelp"',
    ["Apply Mending to Wings"] = 'Svof can\'t cure with "apply mending to wings"',
    ["Sip Health"] = 'Svof can\'t cure with "sip health"',
    ["Eat Kelp / Eat Ginseng"] = 'Svof can cure it with only one herb, and it says "eat ginseng" too',
    ["Apply Epidermal to Head / Apply Epidermal to Body"] = 'Svof can cure it with only one salve, and it says "apply epidermal to body" too',
  }) do
    local cures, said = affcures(text)
    eq(cures, nil, "Cure(s) " .. text .. " is refused")
    eq(said, why, "and says why")
  end
end

-- ===== 2. Refusals =====

do
  local w = world.new()
  local svo = w.svo
  for _, case in ipairs({
    { "clumsiness", { cures = "Eat Kelp" }, "Svof already has clumsiness" },
    { "Bad Name", { cures = "Eat Kelp" }, "a name is lowercase letters and digits" },
    { "testaff", { cures = "Stand" }, 'Svof can\'t cure with "stand"' },
    { "testaff", { cures = "Time" }, "a timed affliction needs its time" },
    { "testaff", { cures = "Time", time = 0 }, "a timed affliction needs its time" },
  }) do
    local ok, why = svo.basicaff(case[1], case[2])
    eq(ok, false, "basicaff " .. case[1] .. " " .. case[2].cures .. " is refused")
    eq(why, case[3], "and says why")
  end
  eq(svo.dict.testaff, nil, "and makes no entry")
end

-- ===== 3. Each cure, against svof's own entry for it =====

-- builds name from cures in w, and runs dict_setup, as registering will
local function build(w, name, spec)
  local ok, why = w.svo.basicaff(name, spec)
  eq(ok, true, "basicaff " .. name .. " builds (" .. tostring(why) .. ")")
  w.svo.dict_setup()
  return w.svo.dict[name]
end

local function same_list(a, b)
  return table.concat(a or {}, ",") == table.concat(b or {}, ",")
end

-- isadvisable, given name's affliction alone, against own's given its own
local function advisable_alike(w, kind, name, own)
  local svo, affs = w.svo, w.svo.affs
  local mine, theirs = svo.dict[name][kind], svo.dict[own][kind]
  eq(not not mine.isadvisable(), not not theirs.isadvisable(), name .. " " .. kind .. ": not advisable without it, like " .. own)
  svo.addaffdict(svo.dict[name])
  svo.addaffdict(svo.dict[own])
  eq(not not mine.isadvisable(), not not theirs.isadvisable(), name .. " " .. kind .. ": advisable with it, like " .. own)
  svo.rmaff(name)
  svo.rmaff(own)
  eq(affs[name], nil, "and it's removed after")
end

do -- herb: kelp, like clumsiness
  local w = world.new()
  local svo = w.svo
  local e = build(w, "testkelp", { cures = "Eat Kelp / Eat Aurum" })
  local own = svo.dict.clumsiness.herb
  eq(same_list(e.herb.eatcure, own.eatcure), true, "kelp: eatcure like clumsiness's")
  eq(e.herb.name, "testkelp_herb", "dict_setup names the action")
  eq(e.herb.aspriority > 0, true, "and gives it a priority place")
  eq(type(e.herb.noeffect), "function", "and a noeffect")
  advisable_alike(w, "herb", "testkelp", "clumsiness")
  eq(sends(w, e.herb), sends(w, own), "sends what clumsiness's sends")

  -- an empty kelp: svof's kelp handler takes herb balance, once
  local herbs = counter(w, "lostbal_herb")
  svo.addaffdict(e)
  e.herb.empty()
  eq(herbs.n, 1, "an empty kelp takes herb balance once")
  eq(svo.affs.testkelp, nil, "and rules it out")

  -- oncompleted: cured, and herb balance gone
  herbs.n = 0
  svo.addaffdict(e)
  e.herb.oncompleted()
  eq(svo.affs.testkelp, nil, "cured")
  eq(herbs.n, 1, "and takes herb balance")
end

do -- herb: ginger, whose empty handler leaves herb balance to the entry
  local w = world.new()
  local svo = w.svo
  local e = build(w, "testginger", { cures = "Eat Ginger" })
  local herbs = counter(w, "lostbal_herb")
  svo.addaffdict(e)
  e.herb.empty()
  eq(herbs.n, 1, "an empty ginger takes herb balance once, as the humours' entries do")
  eq(svo.affs.testginger, nil, "and rules it out")
end

do -- salve: epidermal on the body, like itching
  local w = world.new()
  local svo = w.svo
  local e = build(w, "testskin", { cures = "Apply Epidermal to Body" })
  local own = svo.dict.itching.salve
  eq(same_list(e.salve.applycure, own.applycure), true, "epidermal: applycure like itching's")
  eq(same_list(e.salve.actions, own.actions), true, "and the commands it answers to")
  advisable_alike(w, "salve", "testskin", "itching")
  eq(sends(w, e.salve), sends(w, own), "sends what itching's sends")

  local salves = counter(w, "lostbal_salve")
  svo.addaffdict(e)
  e.salve.empty()
  eq(salves.n, 1, "an empty apply takes salve balance once")
  eq(svo.affs.testskin, nil, "and rules it out")
end

do -- salve with no place
  local w = world.new()
  local e = build(w, "testcold", { cures = "Apply Caloric" })
  eq(same_list(e.salve.actions, { "apply caloric", "apply exothermic" }), true, "caloric with no place answers to apply caloric")
  eq(sends(w, e.salve), "apply caloric", "and sends it")
end

do -- smoke: valerian, like disloyalty
  local w = world.new()
  local svo = w.svo
  svo.pipes.valerian.id, svo.pipes.valerian.puffs, svo.pipes.valerian.lit = 12345, 10, true
  local e = build(w, "testpipe", { cures = "Smoke Valerian" })
  local own = svo.dict.disloyalty.smoke
  eq(same_list(e.smoke.smokecure, own.smokecure), true, "valerian: smokecure like disloyalty's")
  advisable_alike(w, "smoke", "testpipe", "disloyalty")
  eq(sends(w, e.smoke), sends(w, own), "sends what disloyalty's sends")

  local smokes = counter(w, "lostbal_smoke")
  svo.addaffdict(e)
  e.smoke.oncompleted()
  eq(svo.affs.testpipe, nil, "cured")
  eq(smokes.n, 1, "and takes smoke balance")
  eq(svo.pipes.valerian.puffs, 9, "and a puff")
end

do -- purgative: immunity, like voyria
  local w = world.new()
  local svo = w.svo
  local e = build(w, "testsip", { cures = "Sip Immunity" })
  local own = svo.dict.voyria.purgative
  eq(same_list(e.purgative.sipcure, own.sipcure), true, "immunity: sipcure like voyria's")
  advisable_alike(w, "purgative", "testsip", "voyria")
  eq(sends(w, e.purgative), sends(w, own), "sends what voyria's sends")
  svo.addaffdict(svo.dict.latency)
  svo.addaffdict(e)
  eq(not not e.purgative.isadvisable(), false, "not with latency, like voyria")
end

do -- a madness affliction waits while you have madness
  local w = world.new()
  local svo = w.svo
  local e = build(w, "testmad", { cures = "Eat Ginseng", madness = true })
  local plain = build(w, "testsane", { cures = "Eat Ginseng" })
  svo.addaffdict(e)
  svo.addaffdict(plain)
  eq(not not e.herb.isadvisable(), true, "a madness affliction is cured without madness")
  svo.addaffdict(svo.dict.madness)
  eq(not not e.herb.isadvisable(), false, "and not with it")
  eq(not not plain.herb.isadvisable(), true, "while one that isn't still is")
  e.herb.empty()
  eq(not not svo.affs.testmad, true, "an empty ginseng with madness doesn't rule it out")
  svo.rmaff("madness")
  e.herb.empty()
  eq(svo.affs.testmad, nil, "and does without")
end

do -- the GMCP name
  local w = world.new()
  local e = build(w, "testnamed", { cures = "Eat Kelp", gmcp = "namedingame" })
  eq(e.gamename, "namedingame", "a GMCP name that differs is the entry's gamename")
  e = build(w, "testsame", { cures = "Eat Kelp", gmcp = "testsame" })
  eq(e.gamename, nil, "and one that doesn't isn't")
end

-- ===== 4. A timed affliction, like scalded =====

do
  local w = world.new()
  local svo = w.svo
  local e = build(w, "testgale", { cures = "Time", time = 15 })
  eq(e.waitingfor.customwait, 15, "its time is its wait")
  eq(e.herb or e.salve or e.smoke or e.purgative, nil, "and nothing cures it")
  svo.addaffdict(e)
  eq(w.inflight(), "testgale_waitingfor", "gaining it starts its time")
  w.advance(10)
  eq(not not svo.affs.testgale, true, "it's still there after 10s")
  -- a fresh one through its aff action starts the time again
  e.aff.oncompleted()
  w.advance(10)
  eq(not not svo.affs.testgale, true, "a fresh one 10s in starts its time again")
  w.advance(6)
  eq(svo.affs.testgale, nil, "and it's gone when the time is up")
  eq(w.inflight(), "", "leaving nothing in flight")
end

if #failures > 0 then
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(string.format("%d checks, %d failures", checks, #failures))
  os.exit(1)
end
print(string.format("%d checks, 0 failures", checks))
print("ALL PASS")
