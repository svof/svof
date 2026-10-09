--[[
Logic-level test for svof's defences: what the records and dictionary
entries hold in every class, the handlers svof generates from them, and
what happens when the game reports a defence over GMCP or on DEF.

It runs svof's real loaders through tools/svof_world.lua, so the code under
test is the shipped source: the defence records in Defences.lua, the
dictionary, the systemstart generator, the GMCP handlers in Setup.lua,
svo.process_defs, the action system and lifevision.

Many checks pin behaviour that is wrong today, so that the commit fixing it
has to change the expectation in the same diff. Their labels start with
"today", name the defect, and say what is wrong. A label without "today" is
behaviour meant to stay. All of these are in the 2018 module xmls:

   1  rest's second loss line is a positional value, outside off
   2  enabling boosting adds heartsfury instead of regeneration
   3  six Shikudo forms put a regex in off, an exact-match key
   4  spinning puts a regex in off
   5  croonmirror's loss regex starts with a stray quote
   6  fortifying air tests defc.fortifiedwaterand, so never grants fortifyall
   7  bonding's gone is nested inside physical
   8  the "demon armour" strip line maps to demonarmour; the record is armour
   9  aria applies svo.dict.aria.salve, which does not exist
  10  drunkensailor and heartsfury skip their checks during defup (and/or)
  11  lipread's specialskip reads an undefined global mindseye
  12  mindseye's oncompleted marks you deaf, and blind on keepup (and/or)
  13  svo.defs.curedblind and cureddeaf are called and never defined
  14  the Spirit channel's handlers are called and never defined
  15  the relogin handler collects the defc table, not the names in it
  16  generated handlers survive a class change and go stale
  17  a GMCP gain runs the raising action's oncompleted, written for a
      command svof sent: balances, puffs and waits; six are dropped instead
  18  a defence DEF lists that svof did not know about does the same
  19  a GMCP loss goes through lifevision, so an illusion verdict discards it
  20  dict_setup stamps a name and a stopwatch onto sstosvod
  21  susurrating's gain line ends in a space (tools/check_defences.py)
  22  bedevil and evasion have records, no entry and no recognise-only flag
  23  a serverside command several actions share is adopted by whichever
      one pairs() visits last
  24  the server's NIGHTSIGHT is not a command svof adopts
  25  frost's gone lost temperance and temperance's lost frost, and neither
      lost itself (fixed, and checked below)

Nothing here proves anything about Mudlet, the static trigger items in
src/triggers, the game's real wording or timing, or play.

Run: lua tools/test_defences.lua
]]

local world = dofile("tools/svof_world.lua")

-- ===== assertions =====

local failures, checks = {}, 0
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local function sorted_keys(t)
  local r = {}
  for k in pairs(t) do r[#r + 1] = k end
  table.sort(r)
  return table.concat(r, ", ")
end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- counts the calls to svo[name] from here on
local function counter(w, name)
  local c = { n = 0 }
  local real = w.svo[name]
  w.svo[name] = function(...) c.n = c.n + 1 return real(...) end
  return c
end

local function echoed(w, text)
  for _, e in ipairs(w.echoes) do
    if e:find(text, 1, true) then return true end
  end
  return false
end

-- Every class svof knows, by the name the game gives it
local CLASSES = {"Alchemist", "Apostate", "Bard", "Blademaster", "Depthswalker", "Druid", "Infernal", "Jester",
  "Magi", "Monk", "None", "Occultist", "Paladin", "Pariah", "Priest", "Runewarden", "Sentinel", "Serpent",
  "Shaman", "Sylvan", "Psion", "Unnamable", "Earth Elemental Lord", "Fire Elemental Lord", "Air Elemental Lord",
  "Water Elemental Lord"}

-- ===== 1. Every class loads =====

-- The globals svof reads that Mudlet does not provide either: Logger is an
-- optional Mudlet package, force_init and ndb are read before they are set.
local EXPECTED_UNKNOWN = "Logger, force_init, ndb"

local worlds = {}
for _, class in ipairs(CLASSES) do
  local w = world.new({ class = class })
  worlds[class] = w
  eq(sorted_keys(w.unknown_globals), EXPECTED_UNKNOWN, class .. ": the globals svof reads that nothing provides")
  eq(#w.writes, 0, class .. ": loading writes no file")
end

-- ===== 2. Records and entries, across every class =====

-- svo.defs_data holds what the game prints (a record per defence);
-- svo.dict[name] holds how svof raises it (an entry). They are gated on
-- skillsets separately and joined by name.
local union, everywhere, entries, gamenames = {}, nil, {}, {}
local unflagged, without_record = {}, {}
for _, class in ipairs(CLASSES) do
  local svo = worlds[class].svo
  local here = {}
  for name, rec in svo.defs_data:iter() do
    here[name] = true
    union[name] = true
    if not svo.dict[name] and not (rec.nodef or rec.invisibledef or rec.custom_def_type) then
      unflagged[name] = true
    end
  end
  if not everywhere then
    everywhere = here
  else
    for name in pairs(everywhere) do if not here[name] then everywhere[name] = nil end end
  end
  for name, entry in pairs(svo.dict) do
    local isdef = false
    if type(entry) == "table" then
      for _, b in pairs(entry) do if type(b) == "table" and b.def then isdef = true end end
    end
    if isdef then
      entries[name] = true
      if entry.gamename then gamenames[name] = true end
      if not svo.defs_data[name] then without_record[name] = true end
    end
  end
end
eq(count(union), 317, "317 defence records across every class")
eq(count(everywhere), 78, "78 of them exist whatever the class")
eq(count(entries), 287, "287 defences have a dictionary entry")
eq(sorted_keys(without_record), "", "no dictionary defence lacks a record, in any class")
eq(sorted_keys(unflagged), "bedevil, evasion",
  "today (defect 22): two records have no entry and no recognise-only flag")
eq(count(gamenames), 60, "60 dictionary defences carry a gamename (the serverside name)")

-- GMCP's name for a defence: sstosvod maps game names to svof names, and
-- false for the ones svof leaves alone. It is not class gated, except the
-- shroud line after it.
do
  local svo = worlds.Infernal.svo
  local strings, falses = 0, 0
  for _, v in pairs(svo.dict.sstosvod) do
    if type(v) == "string" then strings = strings + 1 elseif v == false then falses = falses + 1 end
  end
  -- dict_setup walks svo.dict and stamps a name and a stopwatch on every
  -- table in it, these two included (plan defect 20)
  eq(svo.dict.sstosvod.name, "sstosvod", "today (defect 20): dict_setup stamped a name onto sstosvod")
  eq(type(svo.dict.sstosvod.sw), "number", "today (defect 20): and a stopwatch")
  -- 172 names plus the stamped name and the shroud line
  eq(strings, 174, "sstosvod: 172 game names map to svof names, plus the stamped name and shroud")
  eq(falses, 37, "sstosvod: 37 game names svof leaves alone")
  eq(svo.dict.sstosvod.shroud, "shroud", "shroud is shroud outside Subterfuge")
  eq(worlds.Serpent.svo.dict.sstosvod.shroud, "cloaking", "and Subterfuge's cloaking")
end

-- ===== 3. The handlers svof generates =====

-- systemstart makes a got_, lost_ and def_ handler for every record, and a
-- gotonly_ for every record with an on_only line, unless one is already
-- written by hand. got_ and lost_ are keyed by the record's name as it is,
-- def_ with its spaces made underscores, and every trigger calls the
-- underscored name. Only the eleven DEF-only records have a space in their
-- name, and they have no gain or loss lines, so nothing calls the two that
-- differ.
for _, class in ipairs(CLASSES) do
  local w = worlds[class]
  local svo = w.svo
  local missing = {}
  for name, rec in svo.defs_data:iter() do
    for _, h in ipairs({"got_" .. name, "lost_" .. name, "def_" .. name:gsub(" ", "_")}) do
      if type(svo.defs[h]) ~= "function" then missing[#missing + 1] = h end
    end
    if rec.on_only and type(svo.defs["gotonly_" .. name]) ~= "function" then missing[#missing + 1] = "gotonly_" .. name end
  end
  eq(table.concat(missing, ", "), "", class .. ": every record has its generated handlers")

  -- and every temp trigger svof made calls a handler that exists
  local dangling = {}
  for _, t in ipairs(w.triggers) do
    local h = type(t.code) == "string" and t.code:match("^svo%.defs%.([%w_]+)%(%)$")
    if h and type(svo.defs[h]) ~= "function" then dangling[#dangling + 1] = h end
  end
  eq(table.concat(dangling, ", "), "", class .. ": every defence trigger calls a handler that exists")
end

-- ===== 4. A GMCP gain runs svof's own command bookkeeping =====

-- Char.Defences.Add calls got_<name>(true). The generated got_ force-adds the
-- defence's raising action and finishes it at once, running oncompleted,
-- which is written for "svof sent the command and the game took it". So a
-- defence the game reports, that svof did not raise, spends balances and
-- puffs and starts waits. Plan defect 17; D3 replaces this path.

do -- rebounding: a smoke svof never sent
  local w = world.new()
  local svo = w.svo
  svo.pipes.skullcap.id, svo.pipes.skullcap.puffs, svo.pipes.skullcap.lit = 12345, 10, true
  w.gmcp_defence_add("rebounding")
  eq(w.inflight(), "waitingonrebounding_waitingfor", "today (defect 17): GMCP rebounding starts svof's rebounding wait")
  eq(svo.pipes.skullcap.puffs, 9, "today (defect 17): and uses a skullcap puff")
  eq(echoed(w, "(9 skullcap left)"), true, "today (defect 17): and says so")
  eq(svo.bals.smoke, false, "today (defect 17): and spends smoke balance")
  eq(svo.defc.rebounding, nil, "today (defect 17): and does not set the defence; only the wait's end would")
  -- without the aura's text line to finish it, the wait runs out
  w.advance(20)
  eq(svo.defc.rebounding, nil, "today (defect 17): GMCP alone never sets rebounding")
  eq(svo.sys.lagcount, 1, "today (defect 17): and the wait's timeout counts as lag")
end

do -- rebounding svof raised: the gain comes with the aura, after the smoke
  local w = world.new()
  local svo = w.svo
  svo.pipes.skullcap.id, svo.pipes.skullcap.puffs, svo.pipes.skullcap.lit = 12345, 10, true
  svo.doaction(svo.dict.rebounding.smoke)
  svo.lifevision.add(svo.actions.rebounding_smoke.p) -- the smoke line
  w.prompt()
  eq(svo.pipes.skullcap.puffs, 9, "svof's own smoke uses one puff")
  eq(w.inflight(), "waitingonrebounding_waitingfor", "and starts the wait")
  local smokes = counter(w, "lostbal_smoke")
  w.advance(8)
  w.gmcp_defence_add("rebounding")
  eq(svo.pipes.skullcap.puffs, 8, "today (defect 17): the GMCP gain at the aura uses a second puff")
  eq(smokes.n, 1, "today (defect 17): and spends smoke balance a second time")
  svo.valid.got_rebounding() -- "You feel an aura of rebounding surround you."
  w.prompt()
  eq(svo.defc.rebounding, true, "the aura's line then finishes the (new) wait")
  w.advance(20)
  eq(svo.sys.lagcount, 1, "today (defect 17): the first wait's timer was never killed and counts as lag")
end

do -- sileris (GMCP fangbarrier) at login: an application svof never sent
  local w = world.new()
  local svo = w.svo
  w.gmcp_defence_add("fangbarrier")
  eq(w.inflight(), "waitingforsileris_waitingfor", "today (defect 17): GMCP sileris starts the 10s sileris wait")
  eq(svo.defc.sileris, nil, "today (defect 17): and does not set the defence")
  w.advance(15)
  eq(svo.defc.sileris, nil, "today (defect 17): with no hardening line the wait just runs out")
  eq(svo.sys.lagcount, 1, "today (defect 17): and counts as lag")

  w = world.new()
  svo = w.svo
  svo.conf.keepup, svo.defkeepup.basic.sileris = true, true
  w.gmcp_defence_add("fangbarrier")
  w.advance(15)
  eq(svo.defc.sileris, "unsure", "today (defect 17): on keepup, the timeout marks sileris unsure")
  eq(echoed(w, "we might've been tricked"), true, "today (defect 17): and warns of a trick")
end

for gmcpname, def in pairs({ insulation = "caloric", density = "mass" }) do
  local w = world.new()
  local salves = counter(w, "lostbal_salve")
  w.gmcp_defence_add(gmcpname)
  eq(w.svo.defc[def], true, "GMCP " .. gmcpname .. " sets " .. def)
  eq(salves.n, 1, "today (defect 17): GMCP " .. gmcpname .. " spends salve balance")
  eq(w.svo.bals.salve, false, "today (defect 17): " .. def .. " leaves svof off salve balance")
end

do -- the five Zeal blessings spend prayer balance
  for gmcpname, def in pairs({ frostshield = "frostblessing", thermalshield = "thermalblessing",
      earthshield = "earthblessing", enduranceblessing = "enduranceblessing",
      willpowerblessing = "willpowerblessing" }) do
    local w = world.new({ class = "Priest" })
    local prayers = counter(w, "lostbal_prayer")
    w.gmcp_defence_add(gmcpname)
    eq(w.svo.defc[def], true, "GMCP " .. gmcpname .. " sets " .. def)
    eq(prayers.n, 1, "today (defect 17): GMCP " .. gmcpname .. " spends prayer balance")
  end
  -- with benediction on, any one of them grants all five
  local w = world.new({ class = "Priest" })
  w.svo.conf.benediction = true
  w.gmcp_defence_add("frostshield")
  eq(w.svo.defc.earthblessing, true, "today (defect 17): with benediction, GMCP frostshield also sets earthblessing")
end

for _, def in ipairs({ "lay", "tune", "aria" }) do -- Voicecraft
  local w = world.new({ class = "Bard" })
  local voices = counter(w, "lostbal_voice")
  w.gmcp_defence_add(def)
  eq(w.svo.defc[def], true, "GMCP " .. def .. " sets it")
  eq(voices.n, 1, "today (defect 17): GMCP " .. def .. " spends voice balance")
end

do -- lyre (GMCP prismatic) pauses svof in lyre mode
  local w = world.new({ paused = false })
  w.svo.conf.lyre = true
  w.gmcp_defence_add("prismatic")
  eq(w.svo.defc.lyre, true, "GMCP prismatic sets lyre")
  eq(w.svo.conf.paused, true, "today (defect 17): and pauses svof, as for a strum svof sent")
end

do -- mindseye reclassifies the blindness and deafness you already have
  local w = world.new()
  w.gmcp_defence_add("mindseye")
  eq(w.svo.defc.mindseye, true, "GMCP mindseye sets it")
  eq(w.svo.defc.deaf, nil, "mindseye does not make you deaf")
  eq(w.svo.defc.blind, nil, "or blind")
  w = world.new()
  w.svo.conf.keepup, w.svo.defkeepup.basic.blind = true, true
  w.gmcp_defence_add("mindseye")
  eq(w.svo.defc.blind, nil, "blind on keepup does not make you blind either")

  -- deafness you have counts as the defence once you have mindseye
  w = world.new()
  w.svo.addaffdict(w.svo.dict.deafaff)
  w.gmcp_defence_add("mindseye")
  eq(w.svo.defc.deaf, true, "with mindseye, the deafness you have is the deaf defence")
  eq(w.svo.affs.deafaff, nil, "and not the affliction")
  -- blindness you have counts as the defence when you want it up
  w = world.new()
  w.svo.conf.keepup, w.svo.defkeepup.basic.blind = true, true
  w.svo.addaffdict(w.svo.dict.blindaff)
  w.gmcp_defence_add("mindseye")
  eq(w.svo.defc.blind, true, "with blind on keepup, the blindness you have is the blind defence")
  eq(w.svo.affs.blindaff, nil, "and not the affliction")
  -- and as the affliction when you do not
  w = world.new()
  w.svo.defences.got("blind")
  w.gmcp_defence_add("mindseye")
  eq(w.svo.defc.blind, false, "with blind on neither list, blindness is not the defence")
  eq(w.svo.affs.blindaff ~= nil, true, "but the affliction")
end

do -- shield turns its own keepup off with oldts
  local w = world.new()
  w.svo.conf.oldts, w.svo.defkeepup.basic.shield = true, true
  w.gmcp_defence_add("shield")
  eq(w.svo.defc.shield, true, "GMCP shield sets it")
  eq(w.svo.defkeepup.basic.shield, false, "today (defect 17): and turns shield keepup off, as after svof's own touch")
end

do -- an ordinary basicdef defence: GMCP sets it and nothing else
  local w = world.new()
  w.gmcp_defence_add("alertness")
  eq(w.svo.defc.alertness, true, "GMCP alertness sets it")
  eq(w.inflight(), "", "and leaves nothing in flight")
  w.gmcp_defence_add("softfocusing")
  eq(w.svo.defc.softfocus, true, "GMCP softfocusing sets softfocus, through sstosvod")
end

-- Six GMCP-mapped defences have hand-written got_ handlers that ignore the
-- force argument. With anti-illusion on (svof's default) they claim only an
-- action already in flight, so a GMCP gain is dropped unless svof was
-- raising the defence.
do
  local GAINS = { blindness = "blind", deafness = "deaf", speed = "speed", blocking = "block",
    dragonbreath = "dragonbreath" }
  for gmcpname, def in pairs(GAINS) do
    local w = world.new()
    eq(w.svo.conf.aillusion, true, "anti-illusion is on by default")
    w.gmcp_defence_add(gmcpname)
    w.prompt()
    eq(w.svo.defc[def], nil, "today (defect 17): with anti-illusion on, GMCP " .. gmcpname .. " is dropped")
  end
  local w = world.new({ class = "Sylvan" })
  w.gmcp_defence_add("viridian")
  w.prompt()
  eq(w.svo.defc.viridian, nil, "today (defect 17): GMCP viridian is dropped")

  -- with it off, checkaction makes the action up and lifevision claims it,
  -- except blind's handler, which never makes one up
  for gmcpname, def in pairs({ deafness = "deaf", speed = "speed", blocking = "block" }) do
    w = world.new()
    w.svo.conf.aillusion = false
    w.gmcp_defence_add(gmcpname)
    w.prompt()
    eq(w.svo.defc[def], true, "with anti-illusion off, GMCP " .. gmcpname .. " sets " .. def .. " at the prompt")
  end
  w = world.new()
  w.svo.conf.aillusion = false
  w.gmcp_defence_add("blindness")
  w.prompt()
  eq(w.svo.defc.blind, nil, "today (defect 17): GMCP blindness is dropped even with anti-illusion off")
  w = world.new()
  w.svo.conf.aillusion = false
  w.gmcp_defence_add("blocking")
  w.prompt()
  eq(w.svo.dict.block.physical.blockingdir, nil,
    "today (defect 17): got_block(true) takes the force flag for a direction and loses it")
end

-- ===== 5. A GMCP loss goes through lifevision =====

-- Char.Defences.Remove calls lost_<name>(), which files the gone claim with
-- lifevision like a text line. An illusion verdict on the paragraph then
-- discards a loss the game reported (plan defect 19).
do
  local w = world.new()
  w.svo.defences.got("alertness")
  w.gmcp_defence_remove("alertness")
  eq(w.svo.defc.alertness, true, "a GMCP loss waits for the prompt")
  w.prompt()
  eq(w.svo.defc.alertness, false, "and clears the defence there")

  w = world.new()
  w.svo.defences.got("alertness")
  w.gmcp_defence_remove("alertness")
  w.svo.sys.flawedillusion = true
  w.prompt()
  eq(w.svo.defc.alertness, true, "today (defect 19): an illusion verdict discards a real GMCP loss")
end

-- ===== 6. DEF =====

-- svo.process_defs reconciles what DEF listed. A defence it lists that svof
-- did not know about runs oncompleted(true) on a balance pairs() picks.
do
  local w = world.new()
  local svo = w.svo
  svo.pipes.skullcap.puffs = 10
  svo.defences.def_def_list.rebounding = true
  svo.process_defs()
  eq(w.inflight(), "waitingonrebounding_waitingfor", "today (defect 18): DEF listing rebounding starts the wait")
  eq(svo.pipes.skullcap.puffs, 9, "today (defect 18): and uses a puff")
  eq(svo.bals.smoke, false, "today (defect 18): and spends smoke balance")

  w = world.new()
  svo = w.svo
  svo.defences.def_def_list.alertness = true
  svo.process_defs()
  eq(svo.defc.alertness, true, "DEF listing alertness sets it")

  w = world.new()
  svo = w.svo
  svo.defences.got("alertness")
  svo.process_defs()
  w.prompt()
  eq(svo.defc.alertness, false, "a defence DEF did not list is lost at the prompt")
end

-- ===== 7. Serverside raising a defence =====

-- With serverside on, the game prints "[Curing]: <COMMAND>" for every command
-- it sends, and svof adopts it as its own action (svo.curingcommand). The
-- owner's login log shows the GMCP Add arrives before that line.
do
  -- Three actions list "apply caloric" as their command, and the map from
  -- command to action keeps whichever one pairs() visits last, so which of
  -- them svof adopts changes from run to run.
  local w = world.new()
  local claimants = {}
  for name, entry in pairs(w.svo.dict) do
    if type(entry) == "table" then
      for bal, b in pairs(entry) do
        if type(b) == "table" and type(b.actions) == "table" then
          for _, cmd in ipairs(b.actions) do
            if cmd == "apply caloric" then claimants[name .. "_" .. bal] = true end
          end
        end
      end
    end
  end
  eq(sorted_keys(claimants), "caloric_salve, frozen_salve, shivering_salve",
    "today (defect 23): three actions share the command apply caloric")
  eq(claimants[w.svo.sys.input_to_actions["apply caloric"].name], true, "and the server's APPLY CALORIC adopts one of them")

  -- Whichever it adopts, the caloric line finishes it and caloric's
  -- bookkeeping runs again, after the GMCP gain already ran it.
  for adopted in pairs(claimants) do
    w = world.new()
    local svo = w.svo
    svo.conf.serverside = true
    local aff = adopted:match("^(%w+)_salve$")
    svo.sys.input_to_actions["apply caloric"] = svo.dict[aff].salve
    local salves = counter(w, "lostbal_salve")
    w.gmcp_defence_add("insulation")           -- Char.Defences.Add
    svo.curingcommand("APPLY CALORIC")          -- [Curing]: APPLY CALORIC
    eq(w.inflight(), adopted, "adopting " .. adopted .. ": it is in flight")
    svo.defs.salve_got_caloric()               -- the game's caloric line
    w.prompt()
    eq(salves.n, 2, "today (defect 17): adopting " .. adopted .. ", one server application spends salve balance twice")
    eq(svo.defc.caloric, true, "adopting " .. adopted .. ": caloric is set")
    eq(w.inflight(), "", "adopting " .. adopted .. ": nothing is left in flight")
  end

  -- NIGHTSIGHT is how the server words it; svof's action is "nightsight on"
  w = world.new()
  eq(w.svo.sys.input_to_actions["nightsight"], nil, "today (defect 24): the server's NIGHTSIGHT is not a command svof adopts")
  eq(w.svo.sys.input_to_actions["nightsight on"] ~= nil, true, "svof adopts its own wording")
end

-- ===== 8. Pre-existing defects, pinned =====

do -- 1: both of rest's loss lines are in off
  local w = world.new({ class = "Druid" })
  eq(w.svo.defs_data.rest[1], nil, "rest: no line sits outside its keys")
  w.svo.defences.got("rest")
  eq(w.line("You rise from your rest, refreshed and full of energy."), 1, "rest: the line after a full rest is heard")
  w.prompt()
  eq(w.svo.defc.rest, false, "rest: and ends rest")
end

do -- 2: enabling boosting adds the regeneration it needs
  local w = world.new({ class = "Monk" })
  w.svo.defs.defup("boosting", true, "basic")
  eq(w.svo.defdefup.basic.regeneration, true, "enabling boosting in defup adds regeneration")
  eq(w.svo.defdefup.basic.heartsfury, nil, "and no heartsfury, which Monks do not have")
  w.svo.defs.keepup("boosting", true, "basic")
  eq(w.svo.defkeepup.basic.regeneration, true, "and in keepup")
end

do -- 3 and 4: a regex in off, an exact-match key, can never match
  local w = worlds.Monk
  local exact_regex = 0
  for _, t in ipairs(w.triggers) do
    if t.kind == "exact" and t.pattern:find("^%^You clumsily transition") then exact_regex = exact_regex + 1 end
  end
  eq(exact_regex, 6, "today (defect 3): six Shikudo forms make an exact-match trigger of a regex")
  w = worlds.Sentinel
  local spinning
  for _, t in ipairs(w.triggers) do
    if t.pattern == [[^You cease spinning .+\.$]] then spinning = t.kind .. " " .. t.code end
  end
  eq(spinning, "regex svo.defs.lost_spinning()", "spinning's loss line is a regex trigger")
end

do -- 5: croonmirror's loss regex is anchored, with no stray quote before it
  local found
  for _, class in ipairs(CLASSES) do
    local rec = worlds[class].svo.defs_data.croonmirror
    if rec then found = rec.offr end
  end
  eq(found and found:sub(1, 1), "^", "croonmirror's offr starts at its anchor")
end

do -- 6: fortifying any of the four last grants fortifyall
  for _, last in ipairs({ "fortifiedair", "fortifiedearth", "fortifiedwater", "fortifiedfire" }) do
    local w = world.new({ class = "Magi" })
    local svo = w.svo
    for _, d in ipairs({ "fortifiedair", "fortifiedearth", "fortifiedwater", "fortifiedfire" }) do
      if d ~= last then svo.defences.got(d) end
    end
    svo.dict[last].physical.oncompleted()
    eq(svo.defc[last], true, last .. " last: it is set")
    eq(svo.defc.fortifyall, true, last .. " last: with the other three up it grants fortifyall")
  end
end

do -- 7: bonding's gone is the entry's own, beside physical
  local w = world.new({ class = "Druid" })
  local svo = w.svo
  eq(svo.dict.bonding.physical.gone, nil, "bonding: nothing nested in physical")
  svo.defences.got("bonding")
  svo.dict.bonding.gone.oncompleted()
  eq(svo.defc.bonding, false, "bonding: its gone loses it")
end

do -- 8: the demon armour strip line loses armour, the record's name
  local w = world.new({ class = "Apostate" })
  w.svo.defences.got("armour")
  w.svo.valid.defstrip("demon armour")
  w.prompt()
  eq(w.svo.defc.armour, false, "a demon armour strip loses armour")
end

do -- 9: aria applies a salve route that does not exist
  local w = world.new({ class = "Bard" })
  w.svo.defences.got("deaf")
  local ok = pcall(w.svo.dict.aria.physical.onstart)
  eq(ok, false, "today (defect 9): while deaf, aria's onstart raises")
end

do -- 10: drunkensailor and heartsfury skip their checks during defup
  local w = world.new({ class = "Bard" })
  local svo = w.svo
  svo.sys.deffing, svo.defdefup.basic.drunkensailor, svo.defdefup.basic.heartsfury = true, true, true
  svo.affs.paralysis = {}
  eq(svo.dict.drunkensailor.physical.isadvisable(), true, "today (defect 10): drunkensailor is advisable while paralysed in defup")
  eq(svo.dict.heartsfury.physical.isadvisable(), true, "today (defect 10): heartsfury too")
end

do -- 11: lipread's specialskip reads a global that does not exist
  local w = world.new({ class = "Serpent" })
  w.svo.defences.got("mindseye")
  eq(w.svo.defs_data.lipread.specialskip(), true, "today (defect 11): lipread is skipped in defup even with mindseye")
  eq(w.unknown_globals.mindseye ~= nil, true, "today (defect 11): because it reads a global mindseye")
end

do -- 12: mindseye's oncompleted, run by svof's own touch
  local w = world.new()
  w.svo.dict.mindseye.physical.oncompleted()
  eq(w.svo.defc.deaf, nil, "touching mindseye does not make you deaf")
end

do -- 13 and 14: trigger handlers that were never defined, in any class
  for _, class in ipairs(CLASSES) do
    local svo = worlds[class].svo
    for _, h in ipairs({ "curedblind", "cureddeaf" }) do
      eq(svo.defs[h], nil, "today (defect 13): " .. class .. ": svo.defs." .. h .. " is not defined")
    end
    for _, h in ipairs({ "got_spirit", "got_boundspirit", "got_fortifiedspirit" }) do
      eq(svo.defs[h], nil, "today (defect 14): " .. class .. ": svo.defs." .. h .. " is not defined")
    end
  end
end

do -- 15: the relogin handler collects the table, not the names
  local w = world.new()
  w.svo.defences.got("alertness")
  w.svo.signals.relogin:emit()
  eq(w.svo.defc.alertness, true, "today (defect 15): a relogin leaves defences set")
end

do -- 25: frost's and temperance's gone each lose themselves, not only the other
  for _, class in ipairs({ "Infernal", "Druid" }) do
    local metamorph = class == "Druid"
    local w = world.new({ class = class })
    local svo = w.svo
    svo.defences.got("frost")
    if metamorph then svo.defences.got("temperance") end
    eq(w.line("Forks of flame lick against your skin, melting away your protection against fire."), 1,
      class .. ": frost's loss line is heard")
    w.prompt()
    eq(svo.defc.frost, false, class .. ": and loses frost")
    if metamorph then eq(svo.defc.temperance, false, class .. ": and temperance with it") end

    w = world.new({ class = class })
    svo = w.svo
    svo.defences.got("frost")
    w.gmcp_defence_remove("temperance") -- GMCP's name for frost
    w.prompt()
    eq(svo.defc.frost, false, class .. ": GMCP losing temperance loses frost")
  end
  local w = world.new({ class = "Druid" })
  w.svo.defences.got("frost")
  w.svo.defences.got("temperance")
  w.svo.dict.temperance.gone.oncompleted()
  eq(w.svo.defc.temperance, false, "Druid: temperance's gone loses temperance")
  eq(w.svo.defc.frost, false, "Druid: and frost with it")
end

do -- 16: generated handlers survive a class change
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local old_lost_boosting = svo.defs.lost_boosting
  svo.classchange("Infernal")
  eq(svo.me.class, "Infernal", "the class change went through")
  eq(svo.dict.boosting, nil, "Infernal has no boosting entry")
  eq(svo.defs.lost_boosting, old_lost_boosting, "today (defect 16): Monk's lost_boosting survives the change")
  local ok = pcall(svo.defs.lost_boosting)
  eq(ok, false, "today (defect 16): and raises, indexing an entry that is gone")
  eq(#w.writes > 0, true, "the class change tried to save the config, and was refused")
end

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
