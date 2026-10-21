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

-- ===== 5. svof's own cure lines =====

-- A cure takes one affliction of the ones it can, and the game picks which:
-- a line naming one claims the action svof sent for another. The loops in
-- Main trigger functions make these handlers; this pins what they do.
local function claimed(w)
  local t = {}
  -- the map's entries, not its own _keys, which Lua 5.1's pairs shows too
  for name in pairs(w.svo.lifevision.l) do
    if type(name) == 'string' and name ~= '_keys' then t[#t + 1] = name end
  end
  table.sort(t)
  return table.concat(t, ", ")
end

do
  for _, case in ipairs({
    { "herb", "weakness", "clumsiness", "herb_cured_clumsiness" },
    { "smoke", "disloyalty", "slickness", "smoke_cured_slickness" },
    { "salve", "itching", "anorexia", "salve_cured_anorexia" },
  }) do
    local balance, sent, named, handler = case[1], case[2], case[3], case[4]
    local w = world.new()
    local svo = w.svo
    svo.addaffdict(svo.dict[sent])
    svo.addaffdict(svo.dict[named])
    svo.doaction(svo.dict[sent][balance])
    svo.valid[handler]()
    eq(w.inflight(), named .. "_" .. balance, handler .. " with " .. sent .. "'s " .. balance .. " in flight claims it for " .. named)
    eq(claimed(w), named .. "_" .. balance, "and lifevision has " .. named .. "'s")
  end
end

-- ===== 6. Registering =====

local function gmcp_aff_add(w, name)
  w.env.gmcp.Char.Afflictions.Add = { name = name, cure = "", desc = "" }
  w.svo.signals.gmcpcharafflictionsadd:emit()
end

local KELPY = {
  cures = "Eat Kelp / Eat Aurum", gmcp = "kelpyaff",
  gain = { "You feel terribly kelpy." }, cured = { "The kelpiness leaves you." },
  diag = { "terribly kelpy." },
}

do -- a gain line, and GMCP
  local w = world.new()
  local svo = w.svo
  local ok, why = svo.afflictions.register("testkelpy", KELPY)
  eq(ok, true, "registers (" .. tostring(why) .. ")")
  eq(svo.dict.testkelpy.herb.name, "testkelpy_herb", "with dict_setup's names")
  eq(w.line("You feel terribly kelpy."), 1, "its gain line has a trigger")
  w.prompt()
  eq(not not svo.affs.testkelpy, true, "which afflicts you with it")
  svo.rmaff("testkelpy")
  eq(svo.dict.sstosvoa.kelpyaff, "testkelpy", "GMCP's name is mapped to it")
  eq(svo.dict.svotossa.testkelpy, "kelpyaff", "and back")
  gmcp_aff_add(w, "kelpyaff")
  eq(not not svo.affs.testkelpy, true, "so GMCP's Add tracks it")
end

do -- its cure line, against its own herb and svof's
  local w = world.new()
  local svo = w.svo
  -- a cure faster than half the ping looks like an illusion to svof, and
  -- the harness's stopwatches read 0; a second is an ordinary eat
  w.env.getStopWatchTime = function() return 1 end
  svo.afflictions.register("testkelpy", KELPY)
  local herbs = counter(w, "lostbal_herb")
  svo.addaffdict(svo.dict.testkelpy)
  svo.doaction(svo.dict.testkelpy.herb)
  w.line("The kelpiness leaves you.")
  w.prompt()
  eq(svo.affs.testkelpy, nil, "its cure line cures it, with its own herb in flight")
  eq(herbs.n, 1, "and takes herb balance")

  -- svof ate kelp for clumsiness, and the game cured this instead
  svo.addaffdict(svo.dict.testkelpy)
  svo.addaffdict(svo.dict.clumsiness)
  svo.doaction(svo.dict.clumsiness.herb)
  w.line("The kelpiness leaves you.")
  eq(w.inflight(), "testkelpy_herb", "with clumsiness's kelp in flight, its cure line claims it")
  w.prompt()
  eq(svo.affs.testkelpy, nil, "and it's cured")
  eq(not not svo.affs.clumsiness, true, "while clumsiness stays")

  -- and the other way: svof ate kelp for this, and the game cured clumsiness
  svo.addaffdict(svo.dict.testkelpy)
  svo.doaction(svo.dict.testkelpy.herb)
  svo.valid.herb_cured_clumsiness()
  eq(w.inflight(), "clumsiness_herb", "with its kelp in flight, clumsiness's cure line claims it")
  w.prompt()
  eq(svo.affs.clumsiness, nil, "and clumsiness is cured")
  eq(not not svo.affs.testkelpy, true, "while it stays")
end

do -- an empty kelp, from svof's own handler
  local w = world.new()
  local svo = w.svo
  svo.afflictions.register("testkelpy", KELPY)
  svo.addaffdict(svo.dict.testkelpy)
  svo.empty.eat_kelp()
  eq(svo.affs.testkelpy, nil, "svof's empty kelp rules it out too")
  local plain = world.new()
  eq(plain.svo.empty.defined.eat_kelp, nil, "and with nothing defined, the handler has nothing more to do")
end

do -- random cures, DIAGNOSE and the commands you type
  local w = world.new()
  local svo = w.svo
  local before = svo.sys.input_to_actions["eat kelp"]
  svo.afflictions.register("testkelpy", KELPY)
  eq(svo.sys.input_to_actions["eat kelp"], before, "a command svof's own has stays svof's")
  local found
  for _, n in ipairs(svo.empty.treecurables) do if n == "testkelpy" then found = true end end
  eq(found, true, "a random cure takes it")
  w.line("terribly kelpy.")
  eq(svo.sk.diag_list.testkelpy, nil, "its DIAGNOSE line counts for nothing outside a diagnose")
  svo.doaction(svo.dict.diag.physical)
  w.line("terribly kelpy.")
  eq(svo.sk.diag_list.testkelpy, true, "and is read during one")

  local spec = {}
  for k, v in pairs(KELPY) do spec[k] = v end
  spec.gmcp, spec.norandomcure = nil, true
  svo.afflictions.register("testfixed", spec)
  found = nil
  for _, n in ipairs(svo.empty.treecurables) do if n == "testfixed" then found = true end end
  eq(found, nil, "one no random cure takes isn't a tree cure")
end

do -- unregistering leaves nothing
  local w = world.new()
  local svo = w.svo
  local before = #svo.empty.treecurables
  svo.afflictions.register("testkelpy", KELPY)
  svo.addaffdict(svo.dict.testkelpy)
  svo.afflictions.unregister("testkelpy")
  eq(svo.dict.testkelpy, nil, "its entry is gone")
  eq(svo.affs.testkelpy, nil, "and the affliction")
  eq(w.line("You feel terribly kelpy."), 0, "and its triggers")
  eq(svo.valid.simpletestkelpy, nil, "and its handlers")
  eq(svo.valid.herb_cured_testkelpy, nil, "both")
  eq(svo.dict.sstosvoa.kelpyaff, nil, "and its GMCP name")
  eq(svo.dict.svotossa.testkelpy, nil, "both ways")
  eq(#svo.empty.treecurables, before, "and its tree place")
  eq(svo.empty.defined.eat_kelp, nil, "and its empty kelp")
  eq(svo.afflictions.cures_with("herb", "kelp"), nil, "and its kelp cure")
end

do -- refusals, in both of svof's vocabularies
  local w = world.new()
  local svo = w.svo
  local sstosvoa = svo.dict.sstosvoa
  -- a GMCP name svof knows under another of its own names
  local gamename, svofname
  for g, s in pairs(sstosvoa) do
    if type(s) == 'string' and s ~= g and not svo.dict[g] then gamename, svofname = g, s break end
  end
  local ok, why = svo.afflictions.register(gamename, { cures = "Eat Kelp" })
  eq(ok, false, "the game's name for one of svof's own is refused")
  eq(why, string.format("Svof knows the game's %s as its own %s", gamename, svofname), "and says so")
  ok, why = svo.afflictions.register("testaff", { cures = "Eat Kelp", gmcp = gamename })
  eq(why, string.format("GMCP's %s is already Svof's %s", gamename, svofname), "and so is its GMCP name")
  ok, why = svo.afflictions.register("testaff", { cures = "Eat Kelp", gmcp = "blindness" })
  eq(why, "Svof leaves GMCP's blindness out on purpose", "and one svof leaves out on purpose")
  eq(svo.dict.testaff, nil, "with no entry made")
end

do -- a madness affliction
  local w = world.new()
  local svo = w.svo
  svo.afflictions.register("testmad", { cures = "Eat Ginseng", madness = true })
  local found
  for _, n in ipairs(svo.empty.madness_affs) do if n == "testmad" then found = true end end
  eq(found, true, "joins svof's madness afflictions")
  svo.addaffdict(svo.dict.testmad)
  svo.addaffdict(svo.dict.madness)
  svo.empty.eat_ginseng()
  eq(not not svo.affs.testmad, true, "so svof's empty ginseng doesn't rule it out with madness")
  svo.rmaff("madness")
  svo.empty.eat_ginseng()
  eq(svo.affs.testmad, nil, "and does without")
end

do -- a timed one's expire line
  local w = world.new()
  local svo = w.svo
  svo.afflictions.register("testgale", { cures = "Time", time = 15, expire = { "The gale dies down." } })
  svo.addaffdict(svo.dict.testgale)
  w.advance(5)
  w.line("The gale dies down.")
  w.prompt()
  eq(svo.affs.testgale, nil, "its expire line ends it")
  eq(w.inflight(), "", "and its time")
end

-- ===== 7. Through a class change =====

local function reload(w, class)
  local svo = w.svo
  svo.me.class = class or svo.me.class
  svo.dict = {}
  svo.systemloaded = false
  w.env.svo_init_system()
end

do
  local w = world.new()
  local svo = w.svo
  local ok, why = svo.afflictions.define("testkelpy", KELPY)
  eq(ok, true, "defines (" .. tostring(why) .. ")")
  reload(w, "Monk")
  svo = w.svo
  eq(svo.dict.testkelpy and svo.dict.testkelpy.herb.name, "testkelpy_herb", "a class change registers it again")
  eq(w.line("You feel terribly kelpy."), 1, "with one trigger for its line, the last class's gone")
  eq(svo.dict.sstosvoa.kelpyaff, "testkelpy", "and its GMCP name")

  svo.conf.customdefinitions = false
  reload(w)
  svo = w.svo
  eq(svo.dict.testkelpy, nil, "customdefinitions off starts svof without it")
  eq(w.line("You feel terribly kelpy."), 0, "or its triggers")
  eq(svo.valid.simpletestkelpy, nil, "or its handlers")
  svo.conf.customdefinitions = true
  reload(w)
  eq(w.svo.dict.testkelpy ~= nil, true, "and back on, it's there")

  w.svo.afflictions.undefine("testkelpy")
  reload(w)
  eq(w.svo.dict.testkelpy, nil, "undefined, it stays out")
end

if #failures > 0 then
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(string.format("%d checks, %d failures", checks, #failures))
  os.exit(1)
end
print(string.format("%d checks, 0 failures", checks))
print("ALL PASS")
