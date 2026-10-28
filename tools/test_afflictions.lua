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
    -- the game's to cure, and svof only tracks it (the user, 2026-10-22)
    [""] = "",
    ["Writhe"] = "game writhe/nil",
    ["Stand"] = "game stand/nil",
    ["Eat Pear"] = "game eat pear/nil",
    ["Smoke Kelp"] = "game smoke kelp/nil",
    ["Apply Mending to Wings"] = "game apply mending to wings/nil",
    ["Sip Health"] = "game sip health/nil",
    ["Apply Health To Torso"] = "game apply health to torso/nil",
    ["Eat Kelp / Writhe / Concentrate"] = "herb kelp/aurum, game writhe/nil, game concentrate/nil",
    ["Eat Kelp / "] = "herb kelp/aurum",
  }) do
    eq(describe((affcures(text))), expected, "Cure(s) " .. text)
  end
  for text, why in pairs({
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
  }) do
    local ok, why = svo.basicaff(case[1], case[2])
    eq(ok, false, "basicaff " .. case[1] .. " " .. case[2].cures .. " is refused")
    eq(why, case[3], "and says why")
  end
  eq(svo.dict.testaff, nil, "and makes no entry")

  -- 21 of the game's timed ones have no Default time (the capture,
  -- 2026-10-21), and have no timer (the user, 2026-10-22)
  for _, time in ipairs({ "none", 0 }) do
    local ok = svo.basicaff("testlong", { cures = "Time", time = time ~= "none" and time or nil })
    eq(ok, true, "basicaff takes Time with " .. tostring(time) .. " for its time")
    eq(svo.dict.testlong and svo.dict.testlong.waitingfor, nil, "and gives it no timer")
    svo.dict.testlong = nil
  end
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

do -- whispering madness keeps no cure from curing (AB OCCULTISM WHISPERINGMADNESS)
  local w = world.new()
  local svo = w.svo
  -- one marked a WhisperingMadness affliction is tracked as one, not held back
  local e = build(w, "testmad", { cures = "Eat Ginseng", madness = true })
  svo.addaffdict(e)
  svo.addaffdict(svo.dict.madness)
  eq(not not e.herb.isadvisable(), true, "madness: a defined affliction is cured while you have madness")
  e.herb.empty()
  eq(svo.affs.testmad, nil, "madness: and an empty ginseng rules it out")
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

do -- madness holds nothing back for one registered either
  local w = world.new()
  local svo = w.svo
  svo.afflictions.register("testmad", { cures = "Eat Ginseng", madness = true })
  eq(svo.empty.madness_affs, nil, "madness: svof keeps no list of madness afflictions for definitions")
  svo.addaffdict(svo.dict.testmad)
  svo.addaffdict(svo.dict.madness)
  svo.empty.eat_ginseng()
  eq(svo.affs.testmad, nil, "madness: svof's empty ginseng rules it out while you have madness")
end

do -- one svof can't cure is only tracked (the user, 2026-10-22)
  local w = world.new()
  local svo = w.svo
  -- icebound's record: Writhe, which svof can't send as a cure
  local ok, why = svo.afflictions.register("testice", { cures = "Writhe", norandomcure = true,
    gain = { "Frost tests your limbs." }, cured = { "Your limbs thaw from the test." } })
  eq(ok, true, "registers (" .. tostring(why) .. ")")
  local balances = {}
  for _, b in ipairs({ "herb", "salve", "smoke", "purgative", "focus", "waitingfor" }) do
    if svo.dict.testice[b] then balances[#balances + 1] = b end
  end
  eq(table.concat(balances, " "), "", "with no action to cure it")
  w.line("Frost tests your limbs.")
  w.prompt()
  eq(not not svo.affs.testice, true, "its gain line afflicts you")
  w.line("Your limbs thaw from the test.")
  w.prompt()
  eq(svo.affs.testice, nil, "and its cure line, the game's cure, ends it")

  -- bloodfire's: no Cure(s) at all
  ok, why = svo.afflictions.register("testblood", { gain = { "Your blood tests you." }, cured = { "Your blood calms." } })
  eq(ok, true, "one the game gives no cure for registers too (" .. tostring(why) .. ")")
  w.line("Your blood tests you.")
  w.prompt()
  w.line("Your blood calms.")
  w.prompt()
  eq(svo.affs.testblood, nil, "and its cure line ends it")

  -- a cure of svof's beside one it can't give: svof's cure line handler, as before
  svo.afflictions.register("testboth", { cures = "Eat Kelp / Writhe", gain = { "A test of both takes you." },
    cured = { "The test of both lets go." } })
  eq(svo.dict.testboth.herb ~= nil, true, "a cure svof can give beside it still has its action")
  eq(svo.valid.testboth_cured, nil, "and no gone handler of its own on the cure line")
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

  -- accentato's layout: only time cures it, and the game gives a Cured msg
  -- and no Expire msg (the capture, 2026-10-20)
  svo.afflictions.register("testhold", { cures = "Time", time = 20, cured = { "The test hold lets go of you." },
    norandomcure = true })
  svo.addaffdict(svo.dict.testhold)
  w.advance(5)
  w.line("The test hold lets go of you.")
  w.prompt()
  eq(svo.affs.testhold, nil, "its cure line ends one only time cures")
  eq(w.inflight(), "", "and its time")

  -- asphyxiating's layout: Time, and no Default time (the capture,
  -- 2026-10-21), so no timer, and its line or GMCP ends it (the user,
  -- 2026-10-22)
  local ok, why = svo.afflictions.register("testbreath", { cures = "Time", norandomcure = true, gmcp = "testbreathaff",
    gain = { "Your test breath fails you." }, cured = { "Your test breath comes easier." } })
  eq(ok, true, "one with no time registers (" .. tostring(why) .. ")")
  eq(svo.dict.testbreath.waitingfor, nil, "with no timer")
  gmcp_aff_add(w, "testbreathaff")
  w.prompt()
  eq(not not svo.affs.testbreath, true, "GMCP's Add tracks it")
  eq(w.inflight(), "", "with nothing waiting on a time")
  w.advance(600)
  eq(not not svo.affs.testbreath, true, "and it stays, however long")
  -- while GMCP lists it, it has the final word (svo.gmcp_refuse_remove), so
  -- the line counts once GMCP doesn't, as in a blackout
  svo.gaffl.testbreathaff = nil
  w.line("Your test breath comes easier.")
  w.prompt()
  eq(svo.affs.testbreath, nil, "until its cure line ends it")
  gmcp_aff_add(w, "testbreathaff")
  w.env.gmcp.Char.Afflictions.Remove = { "testbreathaff" }
  svo.signals.gmcpcharafflictionsremove:emit()
  eq(svo.affs.testbreath, nil, "or GMCP's Remove")

  -- an expire line, with no timer to end
  svo.afflictions.register("testchill", { cures = "Time", norandomcure = true, gain = { "A test chill takes you." },
    expire = { "The test chill lifts." } })
  w.line("A test chill takes you.")
  w.prompt()
  w.line("The test chill lifts.")
  w.prompt()
  eq(svo.affs.testchill, nil, "an expire line ends one with no timer")

  -- nothing to end it
  local unending = "nothing would end it: with no cure of Svof's and no time, it needs a line it ends on or its GMCP name"
  eq(select(2, svo.afflictions.register("testforever", { cures = "Time", gain = { "A test without end takes you." } })),
    unending, "one with no time, no line it ends on and no GMCP name is refused")
  eq(svo.dict.testforever, nil, "and isn't registered")
  eq(svo.afflictions.register("testgmcpend", { cures = "Time", gmcp = "testgmcpendaff" }), true,
    "while its GMCP name alone, whose Remove ends it, is enough")
  eq(svo.afflictions.problem("testforever", { cures = "Writhe", gain = { "A test without end takes you." } }), unending,
    "as is one only tracked with nothing to end it")
  eq(svo.afflictions.problem("testforever", { cures = "Time", time = 10, gain = { "A test without end takes you." } }), nil,
    "while a timer ends one")
  eq(svo.afflictions.problem("testforever", { cures = "Eat Kelp", gain = { "A test without end takes you." } }), nil,
    "and so does a cure of svof's")
end

do -- a line that clashes stays out however it's registered, and either way round with a defence
  local w = world.new()
  local svo = w.svo
  local taken = { cures = "Eat Kelp", gain = { "You prick up your ears." } }
  local why = "Svof's defence alertness watches for \"You prick up your ears.\""
  eq(svo.afflictions.problem("testears", taken), why, "install refuses a line svof's defence watches for")
  local ok, err = svo.afflictions.register("testears", taken)
  eq(ok, false, "and so does registering, as systemstart does for a saved one")
  eq(err, why, "saying why")
  eq(w.line("You prick up your ears."), 1, "so the line is the defence's alone")

  local shimmer = { cures = "Eat Kelp", gain = { "A strange shimmer surrounds you." } }
  eq(svo.afflictions.define("testshimmer", shimmer), true, "an affliction with its own line defines")
  eq(svo.defences.custom_problem("testshimmerdef", { class = 'all', command = "shimmer on",
    on = { "A strange shimmer surrounds you." }, off = {}, def = "You shimmer." }),
    "your affliction testshimmer watches for \"A strange shimmer surrounds you.\"",
    "and a defence defined after it can't take that line")
  eq(svo.defences.custom_problem("testshimmerdef", { class = 'all', command = "shimmer on",
    on = { "You begin to shimmer." }, off = {}, def = "You shimmer." }), nil, "while one with its own lines can")
  svo.afflictions.undefine("testshimmer")
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

-- ===== 8. vcustomaff =====

local function echoed(w, text)
  for _, e in ipairs(w.echoes) do
    if e:find(text, 1, true) then return true end
  end
  return false
end

-- the game's lines, as a trigger reading them gets them, and its prompt
local function reader(w, code)
  local function listening()
    for _, t in ipairs(w.triggers) do
      if not t.killed and t.code == code then return true end
    end
    return false
  end
  local function game(text)
    w.env.line = text
    if listening() then w.run(code) end
    w.run_timers()
  end
  local function prompt()
    w.env.isPrompt = function() return true end
    game("9975h, 6252m cexkdb-")
    w.env.isPrompt = function() return false end
  end
  return game, prompt, listening
end

-- AFFLICTION SHOW's layout is the user's capture (2026-10-20); the
-- afflictions and their lines are made up for the test
do
  local w = world.new()
  local svo = w.svo
  local cmd = svo.afflictions.command
  local game, prompt, listening = reader(w, "svo.afflictions.show_line()")
  local gagged = {}
  local delete = svo.deleteLineP
  svo.deleteLineP = function () gagged[#gagged + 1] = w.env.line delete() end

  cmd("testfire")
  eq(w.sent[#w.sent], "affliction show testfire", "a new definition asks the game about it")
  eq(listening(), true, "and reads the reply")
  game("You glance about.")
  game("Affliction:         Testfire")
  game("Diagnose:           burning with testfire.")
  game("Afflicted msg:      Testfire burns within you.")
  game("Cured msg:          The testfire within you dies.")
  game("Cure(s):            Eat Kelp / Eat Aurum")
  game("Description:        Testfire makes everything you eat taste of ")
  game("ashes.")
  game("NoRandomCure:       No")
  game("WhisperingMadness:  Yes")
  game("Enlighten:          No")
  game("Tzantza:            No")
  game("Accentato:          No")
  game("CadmusCurse:        No")
  prompt()
  local d = svo.afflictions.drafts.testfire or {}
  eq(d.gmcp, "testfire", "the name the game shows it under is its GMCP name")
  eq((d.gain or {})[1], "Testfire burns within you.", "Afflicted msg is its gain line")
  eq((d.cured or {})[1], "The testfire within you dies.", "Cured msg its cure line")
  eq((d.diag or {})[1], "burning with testfire.", "Diagnose its DIAGNOSE line")
  eq(d.cures, "Eat Kelp / Eat Aurum", "Cure(s) its cures")
  eq(d.desc, "Testfire makes everything you eat taste of ashes.", "a wrapped value is joined")
  eq(d.norandomcure, nil, "NoRandomCure No leaves random cures taking it")
  eq(d.madness, true, "WhisperingMadness Yes marks it a WhisperingMadness affliction, tracked only")
  eq(gagged[1], "Affliction:         Testfire", "the reply is gagged from its first line")
  -- svo.deleteLineP takes the prompt after the line with it
  eq(gagged[#gagged], "CadmusCurse:        No", "to its last line, and the prompt with it")
  eq(listening(), false, "and the trigger reading it is killed")
  eq(echoed(w, "Filled in testfire from the game's AFFLICTION SHOW testfire."), true, "and says so")
  eq(svo.afflictions.problem("testfire", d), nil, "it's ready to install")

  -- a timed one, the airfisted capture's layout
  cmd("testgust")
  game("Affliction:         Testgust")
  game("Diagnose:           being blown about by a testgust.")
  game("Afflicted msg:      none")
  game("Cured msg:          none")
  game("Expire msg:         The testgust about you dies ")
  game("down.")
  game("Cure(s):            Time")
  game("NoRandomCure:       Yes")
  game("Default time:       15 seconds")
  prompt()
  d = svo.afflictions.drafts.testgust or {}
  eq(#(d.gain or {}), 0, "none is no gain line")
  eq((d.expire or {})[1], "The testgust about you dies down.", "Expire msg, joined, is its expire line")
  eq(d.cures, "Time", "Cure(s) Time")
  eq(d.time, 15, "and Default time its time")
  eq(d.norandomcure, true, "NoRandomCure Yes keeps random cures off it")
  eq(d.gmcp, "testgust", "its GMCP name, as the game shows it")
  eq(svo.afflictions.problem("testgust", d), nil, "is what tells svof you have it, with no gain line")
  d.gmcp = nil
  eq(svo.afflictions.problem("testgust", d), "it needs a line saying you have it, or its GMCP name, or Svof can't tell when you do",
    "and without either, it can't be installed")

  -- one of svof's own, under the game's name for it
  cmd("testair")
  w.sent = {}
  svo.afflictions.fetch("testair", "airfisted")
  game("Affliction:         Airfisted")
  game("Cure(s):            Time")
  prompt()
  eq(echoed(w, "The game's airfisted is Svof's own galed, so there's no need to define it."), true,
    "the game's name for one of svof's own points at svof's")
  eq((svo.afflictions.drafts.testair or {}).cures, nil, "and fills nothing")

  -- a SHOW the player sends is left alone
  gagged = {}
  game("Affliction:         Testfire")
  eq(#gagged, 0, "a reply svof didn't ask for isn't gagged")
end

-- the whole record, captured on muddlertest 2026-10-20: 43 of the 203
-- titles don't start with the name, and a second cure route is an entry of
-- its own, indented to the values
do
  local w = world.new()
  local svo = w.svo
  local game, prompt, listening = reader(w, "svo.afflictions.show_line()")
  local gagged = {}
  local delete = svo.deleteLineP
  svo.deleteLineP = function () gagged[#gagged + 1] = w.env.line delete() end
  -- what Mudlet raises for each command sent, svof's own among them
  local send = w.env.send
  w.env.send = function (command, ...)
    for _, h in ipairs(w.handlers) do
      if h.name == "sysDataSendRequest" and not h.killed then h.f("sysDataSendRequest", command) end
    end
    return send(command, ...)
  end
  local function player(command) w.env.send(command) end

  svo.afflictions.command("testwound")
  game("Affliction:         Grievously tested")
  game("Cured msg:          The testwound closes.")
  game("Cure(s):            Eat Kelp / Eat Aurum")
  game("                    Focus Mind")
  prompt()
  local d = svo.afflictions.drafts.testwound or {}
  eq(d.title, "Grievously tested", "a reply whose title doesn't name what was asked is the ask's whose turn it is")
  eq(d.cures, "Eat Kelp / Eat Aurum / Focus Mind", "and a second route joins the first")
  eq(gagged[1], "Affliction:         Grievously tested", "and is gagged")
  eq(d.gmcp, nil, "but its GMCP name isn't taken from a title that doesn't name it")
  eq(listening(), false, "and the reading stops")

  -- the player's own, after svof's
  gagged = {}
  svo.afflictions.command("testbind")
  player("affliction show aeon")
  game("Affliction:         Restricted by tests")
  game("Cure(s):            Eat Kelp")
  prompt()
  game("Affliction:         The aeon curse")
  game("Cure(s):            Smoke Elm / Smoke Cinnabar")
  prompt()
  eq((svo.afflictions.drafts.testbind or {}).title, "Restricted by tests", "svof's ask takes the first reply")
  eq(#gagged, 2, "and only it, with its prompt, is gagged")
  eq(listening(), false, "and the reading stops once both are answered")

  -- and before
  gagged = {}
  player("affliction show dazzled")
  svo.afflictions.command("testlast")
  game("Affliction:         Dazzled")
  game("Cure(s):            Apply Mending To Head")
  game("                    Time")
  prompt()
  eq(#gagged, 0, "the player's reply, first, is left alone")
  game("Affliction:         A test at the last")
  game("Cure(s):            Eat Kelp")
  prompt()
  eq((svo.afflictions.drafts.testlast or {}).title, "A test at the last", "and svof's comes next")
  eq((svo.afflictions.drafts.testlast or {}).cures, "Eat Kelp", "with only its own lines")

  -- the player's ask for a name the game doesn't have
  gagged = {}
  player("affliction show nothing")
  game("There is no such affliction.")
  eq(#gagged, 0, "the game's no to the player's own is left alone")
  eq(listening(), false, "and answers it")
end

do -- svof's lines as Mudlet runs its triggers (tools/trigger_catalog.py)
  local w = world.new()
  local svo = w.svo
  w.env.rex = world.rex_stub
  local function problem(field, line)
    return svo.afflictions.problem("testone", { cures = "Eat Kelp", gmcp = nil, [field] = { line },
      gain = field ~= 'gain' and { "A test affliction takes you." } or { line } })
  end
  -- Apostasy's Def strip is an AND trigger: start "Your " and a regex
  eq(problem('cured', "Your skin ceases its painful tingling."), nil,
    "a line starting as one of an AND trigger's patterns does isn't refused")
  eq(problem('cured', "Your rebounding defence has been stripped by Testa's Baalzadeen.") ~= nil, true,
    "a line all its patterns match is")
  -- Chaosrays hit / red is "red" on the line "You are hit by a ... ray." starts
  eq(problem('cured', "You are rendered entirely unable to communicate."), nil,
    "a child's pattern alone, without its parent's line, isn't refused")
  eq(problem('cured', "You are hit by a red ray.") ~= nil, true, "but with it is")
  -- Channels' children read the 5 lines after "You have harnessed the power
  -- of:", and nothing else
  eq(problem('gain', "Bound by tendrils of water."), nil, "a line a longer chain's child reads isn't refused")
  -- svo diag's children are DIAGNOSE's lines
  eq(problem('diag', "paralysed.") ~= nil, true, "a DIAGNOSE line svof's diagnose reads is refused there")
  eq(problem('cured', "paralysed."), nil, "but not as a cure line")
  -- Ate is an AND trigger with a spacer: it fires on the line after "You
  -- eat", so its children are cure lines there, which only it watches for
  eq(problem('cured', "Your dissonant nature becomes harmonious.") ~= nil, true,
    "a cure line a spacer trigger's child watches for is refused")
end

do -- a late reply goes to nothing but the gag
  local w = world.new()
  local svo = w.svo
  local game, prompt = reader(w, "svo.afflictions.show_line()")
  svo.afflictions.command("testslow")
  w.advance(6)
  eq(echoed(w, "The game didn't answer about an affliction called testslow, so add its parts yourself."), true,
    "no answer in time is said")
  svo.afflictions.command("testnext")
  game("Affliction:         Testslow")
  game("Afflicted msg:      The slow one hits you.")
  prompt()
  eq(#((svo.afflictions.drafts.testnext or {}).gain or {}), 0, "the late reply about testslow fills nothing in testnext")
end

do -- a name the game doesn't have (the user, 2026-10-20)
  local w = world.new()
  local svo = w.svo
  local game, prompt, listening = reader(w, "svo.afflictions.show_line()")
  local gagged = {}
  local delete = svo.deleteLineP
  svo.deleteLineP = function () gagged[#gagged + 1] = w.env.line delete() end
  svo.afflictions.command("testnone")
  game("There is no such affliction.")
  eq(gagged[1], "There is no such affliction.", "the game's no is gagged")
  eq(listening(), false, "and ends the wait")
  eq(echoed(w, "The game has no affliction called testnone, so add its parts yourself."), true, "and is said")
  eq(svo.afflictions.gmcp_known("testnone"), false, "so it isn't a GMCP name")
  svo.afflictions.set("testnone", "gmcp", "testnone")
  eq(echoed(w, "The game has no affliction called testnone over GMCP, so it can't be testnone's GMCP name."), true,
    "and can't be set as one")

  -- asked to set a GMCP name, the game's no refuses it
  svo.afflictions.set("testnone", "gmcp", "testother")
  eq(w.sent[#w.sent], "affliction show testother", "a GMCP name the game hasn't confirmed is asked about")
  game("There is no such affliction.")
  eq(echoed(w, "The game has no affliction called testother, so it can't be testnone's GMCP name."), true,
    "and refused on the game's no")
  eq((svo.afflictions.drafts.testnone or {}).gmcp, nil, "leaving it unset")
end

do -- installing, and the clash checks
  local w = world.new()
  local svo = w.svo
  w.env.rex = world.rex_stub
  local function spec(over)
    local t = { cures = "Eat Kelp", gain = { "A test affliction takes you." }, cured = { "The test affliction leaves you." } }
    for k, v in pairs(over or {}) do t[k] = v end
    return t
  end
  local problem = svo.afflictions.problem
  eq(problem("testone", spec()), nil, "a definition with its own lines is fine")
  -- the first of the three triggers on clumsiness's cure line, in the catalog's order
  eq(problem("testone", spec({ gain = { "Thank Maya, the Great Mother! Your clumsiness has been cured." } })),
    "Svof's trigger svo (aliases, triggers) / svo / General / General cures / svo cure clumsiness generic already watches for \"Thank Maya, the Great Mother! Your clumsiness has been cured.\"",
    "a line one of svof's triggers watches for is refused, naming it")
  -- a line only a defence record has, which no trigger item does
  eq(problem("testone", spec({ gain = { "You bring your eyes back into focus." } })),
    "Svof's defence softfocus watches for \"You bring your eyes back into focus.\"",
    "and one of svof's defence lines")
  eq(problem("testone", spec({ cured = { "A test affliction takes you." } })),
    "its gain line \"A test affliction takes you.\" is its cure line too", "and its gain line as its cure line")
  eq(problem("testone", spec({ gainpattern = { "^A test affliction takes (\\w+)%.$" } })), nil,
    "a pattern matching nothing else is fine")
  eq(problem("testone", spec({ curedpattern = { "^A test affliction takes .+$" } })),
    "its cure pattern \"^A test affliction takes .+$\" matches its own gain line \"A test affliction takes you.\"",
    "a pattern matching its own line of another kind is refused")
  eq(problem("testone", spec({ gmcp = "testone" })), "Svof couldn't check its GMCP name testone with the game",
    "a GMCP name the game hasn't confirmed is refused")
  eq(problem("clumsiness", spec()), "Svof already has clumsiness", "and a name svof has")
  eq(problem("testone", spec({ cures = "Stand" })), nil, "while a cure svof can't give is only tracked")

  w.writes = {}
  eq(svo.afflictions.install("testone"), false, "install needs a draft")
  svo.afflictions.drafts.testone = spec()
  eq(svo.afflictions.install("testone"), true, "installs")
  eq(svo.afflictions.registered.testone ~= nil, true, "into play")
  eq(svo.afflictions.custom.testone ~= nil, true, "and saved")
  local saved = false
  for _, wr in ipairs(w.writes) do if wr:find("svo/custom/affs", 1, true) then saved = true end end
  eq(saved, true, "to svo/custom/affs")
  eq(w.line("A test affliction takes you."), 1, "its gain line has a trigger")

  svo.afflictions.drafts.testtwo = spec({ gain = { "A second one takes you." }, cured = { "The test affliction leaves you." } })
  eq(svo.afflictions.install("testtwo"), false, "a line another definition watches for is refused")
  eq(echoed(w, "your testone watches for \"The test affliction leaves you.\" too"), true, "naming it")

  svo.afflictions.delete("testone")
  eq(svo.afflictions.registered.testone, nil, "delete takes it out of play")
  eq(svo.afflictions.custom.testone, nil, "and out of the saved ones")
  eq(w.line("A test affliction takes you."), 0, "with its trigger")
end

do -- MORE past AFFLICTION LIST's end gets DEFENCE LIST's line (the user, 2026-10-20)
  local w = world.new()
  local svo = w.svo
  local game, _, listening = reader(w, "svo.afflictions.list_line()")
  svo.afflictions.gamelist()
  game("All afflictions")
  game("Accentato")
  game("[Type MORE if you wish to continue reading. (50% shown)]")
  game('An unseen presence whispers in your ear, "There is no more, friend."')
  eq(listening(), false, "the game's line past its end ends the list")
  eq(svo.afflictions.game_list and svo.afflictions.game_list.complete, true, "as complete")
end

do -- AFFLICTION LIST: what svof doesn't know, what it knows by another name, what it leaves out
  local w = world.new()
  local svo = w.svo
  local game, prompt, listening = reader(w, "svo.afflictions.list_line()")
  svo.afflictions.command("game")
  eq(w.sent[#w.sent], "affliction list", "vcustomaff game sends AFFLICTION LIST")
  game("All afflictions")
  game("------------------------------------------------")
  for _, n in ipairs({ "Accentato", "Addiction", "Airfisted", "Blindness" }) do game(n) end
  game("[Type MORE if you wish to continue reading. (10% shown)]")
  eq(w.sent[#w.sent], "more", "and MORE after a page")
  game("[File continued via MORE]")
  game("Testfire")
  prompt()
  eq(listening(), false, "the list ends at a prompt with no MORE before it")
  eq(echoed(w, "Of the 5 afflictions the game lists, Svof doesn't know these 2. Click one to define it:"), true,
    "it lists the ones svof doesn't know")
  local links = table.concat(w.links, "|")
  eq(links:find('svo.afflictions.show("accentato")', 1, true) ~= nil, true, "as links")
  eq(echoed(w, "airfisted (galed)"), true, "the ones svof knows by its own name, the game's first")
  eq(echoed(w, "blindness"), true, "and the ones it reads another way")
  eq(svo.afflictions.gmcp_known("accentato"), true, "the list confirms its names as GMCP names")
  eq(svo.afflictions.gmcp_known("nosuchthing"), false, "and that a name it lacks isn't one")
end

do -- the forms
  local w = world.new()
  local svo = w.svo
  local cmd = svo.afflictions.command
  svo.afflictions.drafts.testform = { gain = {}, cured = {}, expire = {}, diag = {}, gainpattern = {}, curedpattern = {} }
  cmd("testform cures Smoke Valerian")
  eq(svo.afflictions.drafts.testform.cures, "Smoke Valerian", "cures sets its cures")
  cmd("testform madness yes")
  eq(svo.afflictions.drafts.testform.madness, true, "madness yes")
  cmd("testform randomcure no")
  eq(svo.afflictions.drafts.testform.norandomcure, true, "randomcure no")
  cmd("testform gain You feel tested.")
  eq(svo.afflictions.drafts.testform.gain[1], "You feel tested.", "gain adds a line")
  cmd("testform time 20")
  eq(svo.afflictions.drafts.testform.time, 20, "time sets it")
  w.echoes = {}
  cmd("testform madness|randomcure yes|no")
  eq(echoed(w, "Replace each <...> with what it stands for"), true, "a form with its placeholders is explained")
  cmd("testform colour red")
  eq(echoed(w, "colour isn't one"), true, "and a field it doesn't have")
end

-- ===== 9. Review fixes, 2026-10-24 =====

do
  local w = world.new({ class = "Monk" })
  local svo, A = w.svo, w.svo.afflictions
  svo.conf.customdefinitions = true

  -- skullcap is smoked as malachite and eaten as azurite
  eq(describe(svo.affcures("Smoke Skullcap / Smoke Malachite")), "smoke skullcap/malachite",
    "smoke: skullcap's mineral to smoke is malachite")
  eq(describe(svo.affcures("Smoke Elm / Smoke Cinnabar")), "smoke elm/cinnabar", "smoke: elm's is cinnabar")

  -- installing it again while you have it keeps it, with or without a
  -- GMCP name to put it back
  A.drafts.itchy = { cures = "Eat Kelp / Eat Aurum", gain = { "You feel itchy all over." } }
  eq(A.install("itchy"), true, "reinstall: the first install")
  svo.addaffdict(svo.dict.itchy)
  A.set("itchy", "diag", "covered in itches.")
  eq(A.install("itchy"), true, "reinstall: installing it with a DIAGNOSE line added")
  eq(svo.affs.itchy ~= nil, true, "reinstall: you still have it")
  eq(svo.affs.itchy and svo.affs.itchy.p == svo.dict.itchy, true, "reinstall: as its new entry")
  A.set("itchy", "diag", "covered in itches all over.")
  svo.rmaff("itchy")
  eq(A.install("itchy"), true, "reinstall: installing it again without it")
  eq(svo.affs.itchy, nil, "reinstall: one you don't have isn't added")

  -- an empty kelp rules it out once, by kelp's own handler
  svo.addaffdict(svo.dict.itchy)
  local ruled = 0
  local rmaff = svo.rmaff
  svo.rmaff = function(which)
    -- (a list is removed a name at a time, through svo.rmaff again)
    if which == "itchy" then ruled = ruled + 1 end
    return rmaff(which)
  end
  svo.dict.itchy.herb.empty()
  svo.rmaff = rmaff
  eq(ruled, 1, "empty: an empty kelp rules it out once")
  eq(svo.affs.itchy, nil, "empty: and it's gone")
end

-- ===== 10. Review fixes, 2026-10-28 =====

do -- a name svof's own svo.valid handlers have can't be an affliction's
  local w = world.new()
  local svo, A = w.svo, w.svo.afflictions
  svo.conf.customdefinitions = true
  local tree_cured, generic_cured = svo.valid.tree_cured, svo.valid.generic_cured
  local spec = { cures = "Eat Kelp", gain = { "A test affliction takes you." } }
  for _, case in ipairs({ { "tree", "tree_cured" }, { "generic", "generic_cured" } }) do
    local name, key = case[1], case[2]
    local why = string.format("Svof has its own svo.valid.%s, which %s's would replace", key, name)
    eq(A.problem(name, spec), why, "handlers: install refuses " .. name)
    local ok, err = A.register(name, spec)
    eq(ok, false, "handlers: and so does registering " .. name .. ", as systemstart does for a saved one")
    eq(err, why, "handlers: saying why for " .. name)
    eq(svo.dict[name], nil, "handlers: and " .. name .. " isn't registered")
    w.echoes = {}
    A.show(name)
    eq(echoed(w, why), true, "handlers: nor can " .. name .. " be started")
    eq(A.drafts[name], nil, "handlers: so there's no draft of " .. name)
  end
  eq(svo.valid.tree_cured, tree_cured, "handlers: svof's tree_cured is still its own")
  eq(svo.valid.generic_cured, generic_cured, "handlers: and so is its generic_cured")

  -- a definition's own handlers aren't svof's: it installs again
  A.drafts.testhandlers = { cures = "Eat Kelp", gain = { "A test affliction takes you." } }
  eq(A.install("testhandlers"), true, "handlers: a name of its own installs")
  eq(svo.valid.simpletesthandlers ~= nil, true, "handlers: with its handlers")
  eq(A.problem("testhandlers", A.custom.testhandlers), nil, "handlers: which don't stop it installing again")
  A.set("testhandlers", "diag", "covered in test handlers.")
  eq(A.install("testhandlers"), true, "handlers: and it does")
  A.delete("testhandlers")
end

if #failures > 0 then
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(string.format("%d checks, %d failures", checks, #failures))
  os.exit(1)
end
print(string.format("%d checks, 0 failures", checks))
print("ALL PASS")
