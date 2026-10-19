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
  16  generated handlers survived a class change and went stale (fixed)
  17  a GMCP gain ran the raising action's oncompleted, written for a
      command svof sent: balances, puffs and waits; six were dropped
      instead (fixed: defences.confirm)
  18  a defence DEF lists that svof did not know about did the same
      (fixed: defences.confirm)
  19  a GMCP loss went through lifevision, so an illusion verdict discarded
      it (fixed: defences.unconfirm)
  20  dict_setup stamps a name and a stopwatch onto sstosvod
  21  susurrating's gain line ends in a space (tools/check_defences.py)
  22  bedevil and evasion have records, no entry and no recognise-only flag
  23  a serverside command several actions share is adopted by whichever
      one pairs() visits last
  24  the server's NIGHTSIGHT is not a command svof adopts
  25  frost's gone lost temperance and temperance's lost frost, and neither
      lost itself (fixed, and checked below)
  26  dict_setup added a defence's gone while pairs() walked the entry, so
      on Lua 5.4 and later a balance could be left without a name (fixed)
  27  vconfig havemindnet on registered lifevision, not mindnet (fixed)
  28  what a player hid in a class's skillsets was forgotten on changing
      class and back, and vshow hidelist listed a defence under a group
      another class had it in (fixed)
  29  a class change lost the saved priorities of the last class's own
      defences and actions (fixed: src/resources/prio_catalog.lua)
  30  a definition could take the name of svof's own action in another
      class that isn't a defence, and share its saved priority place
      (fixed: defences.class_action)

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

-- a row of vcustomdef's screen: its label, then its value, echoed apart so
-- each takes its own colour
local function row_echoed(w, label, value)
  for i = 1, #w.echoes - 1 do
    if w.echoes[i]:find(label, 1, true) and w.echoes[i + 1]:find(value, 1, true) == 1 then return true end
  end
  return false
end

-- an "(e!)" link svof shows when something it ran raised
local function error_shown(w, text)
  for _, l in ipairs(w.links) do
    if l:find("(e!)", 1, true) and (not text or l:find(text, 1, true)) then return true end
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
eq(count(gamenames), 62, "62 dictionary defences carry a gamename (the serverside name)")

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
  -- 174 names plus the stamped name and the shroud line
  eq(strings, 176, "sstosvod: 174 game names map to svof names, plus the stamped name and shroud")
  eq(falses, 37, "sstosvod: 37 game names svof leaves alone")
  eq(svo.dict.sstosvod.shroud, "shroud", "shroud is shroud outside Subterfuge")
  eq(worlds.Serpent.svo.dict.sstosvod.shroud, "cloaking", "and Subterfuge's cloaking")
end

-- dict_setup names every action, which doaction keys actions by. It used to
-- add a defence's gone while pairs() walked the entry, and on Lua 5.4 and
-- later that walk could skip a balance (deathsight's herb, in about half the
-- runs), leaving it nameless until the prio import ran dict_setup again.
-- Lua 5.1 happened not to skip any.
for _, class in ipairs(CLASSES) do
  local unnamed = {}
  for action, entry in pairs(worlds[class].svo.dict) do
    if type(entry) == "table" then
      for bal, act in pairs(entry) do
        if type(act) == "table" and (act.oncompleted or act.isadvisable or act.onstart) and act.name == nil then
          unnamed[#unnamed + 1] = action .. "." .. bal
        end
      end
    end
  end
  table.sort(unnamed)
  eq(table.concat(unnamed, ", "), "", class .. ": every action in the dictionary has a name")
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

-- ===== 4. A GMCP gain is the game's word, not svof's command =====

-- Char.Defences.Add hands the defence to defences.confirm. It used to call
-- got_<name>(true), whose generated version force-added the raising action
-- and finished it, running oncompleted, written for "svof sent the command
-- and the game took it": a defence svof did not raise spent balances and
-- puffs and started waits (defect 17, fixed). Now only a command svof really
-- sent is booked.

do -- rebounding: a smoke svof never sent
  local w = world.new()
  local svo = w.svo
  svo.pipes.skullcap.id, svo.pipes.skullcap.puffs, svo.pipes.skullcap.lit = 12345, 10, true
  w.gmcp_defence_add("rebounding")
  eq(svo.defc.rebounding, true, "GMCP rebounding sets it")
  eq(w.inflight(), "", "and starts no wait")
  eq(svo.pipes.skullcap.puffs, 10, "uses no puff")
  eq(echoed(w, "skullcap left"), false, "and says nothing about one")
  eq(svo.bals.smoke, true, "and spends no smoke balance")
  w.advance(20)
  eq(svo.sys.lagcount, 0, "and nothing times out as lag")
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
  eq(svo.pipes.skullcap.puffs, 9, "the GMCP gain at the aura uses no second puff")
  eq(smokes.n, 0, "and no second smoke balance")
  eq(svo.defc.rebounding, true, "it finishes the wait: rebounding is up")
  svo.valid.got_rebounding() -- "You feel an aura of rebounding surround you."
  w.prompt()
  eq(svo.defc.rebounding, true, "the aura's line after it changes nothing")
  eq(echoed(w, "(e!)") or error_shown(w), false, "and finds nothing to finish, without an error")
  w.advance(20)
  eq(svo.sys.lagcount, 0, "and the wait's timer went with the wait")
end

do -- sileris (GMCP fangbarrier) at login: an application svof never sent
  local w = world.new()
  local svo = w.svo
  w.gmcp_defence_add("fangbarrier")
  eq(svo.defc.sileris, true, "GMCP sileris sets it")
  eq(w.inflight(), "", "and starts no wait")
  w.advance(15)
  eq(svo.sys.lagcount, 0, "so nothing times out as lag")

  w = world.new()
  svo = w.svo
  svo.conf.keepup, svo.defkeepup.basic.sileris = true, true
  w.gmcp_defence_add("fangbarrier")
  w.advance(15)
  eq(svo.defc.sileris, true, "on keepup too, sileris is up and stays up")
  eq(echoed(w, "we might've been tricked"), false, "with no warning of a trick")
end

for gmcpname, def in pairs({ insulation = "caloric", density = "mass" }) do
  local w = world.new()
  local salves = counter(w, "lostbal_salve")
  w.gmcp_defence_add(gmcpname)
  eq(w.svo.defc[def], true, "GMCP " .. gmcpname .. " sets " .. def)
  eq(salves.n, 0, "GMCP " .. gmcpname .. " spends no salve balance")
  eq(w.svo.bals.salve, true, def .. " leaves svof on salve balance")
end

do -- the five Zeal blessings
  for gmcpname, def in pairs({ frostshield = "frostblessing", thermalshield = "thermalblessing",
      earthshield = "earthblessing", enduranceblessing = "enduranceblessing",
      willpowerblessing = "willpowerblessing" }) do
    local w = world.new({ class = "Priest" })
    local prayers = counter(w, "lostbal_prayer")
    w.gmcp_defence_add(gmcpname)
    eq(w.svo.defc[def], true, "GMCP " .. gmcpname .. " sets " .. def)
    eq(prayers.n, 0, "GMCP " .. gmcpname .. " spends no prayer balance")
  end
  -- benediction grants all five by one recitation; the game says so for each
  local w = world.new({ class = "Priest" })
  w.svo.conf.benediction = true
  w.gmcp_defence_add("frostshield")
  eq(w.svo.defc.earthblessing, nil, "with benediction, GMCP frostshield sets only frostblessing")
end

for _, def in ipairs({ "lay", "tune", "aria" }) do -- Voicecraft
  local w = world.new({ class = "Bard" })
  local voices = counter(w, "lostbal_voice")
  w.gmcp_defence_add(def)
  eq(w.svo.defc[def], true, "GMCP " .. def .. " sets it")
  eq(voices.n, 0, "GMCP " .. def .. " spends no voice balance")
end

do -- lyre (GMCP prismatic): svof pauses in lyre mode for its own strum
  local w = world.new({ paused = false })
  w.svo.conf.lyre = true
  w.gmcp_defence_add("prismatic")
  eq(w.svo.defc.lyre, true, "GMCP prismatic sets lyre")
  eq(w.svo.conf.paused, false, "and does not pause svof, which did not strum")
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

do -- shield turns its own keepup off with oldts, after svof's touch
  local w = world.new()
  w.svo.conf.oldts, w.svo.defkeepup.basic.shield = true, true
  w.gmcp_defence_add("shield")
  eq(w.svo.defc.shield, true, "GMCP shield sets it")
  eq(w.svo.defkeepup.basic.shield, true, "and leaves shield keepup alone: svof touched nothing")
end

do -- a defence this class has no record for is left alone
  local w = world.new()
  w.gmcp_defence_add("kaitrance") -- a Monk's
  eq(w.svo.defc.trance, nil, "an Infernal ignores GMCP's kaitrance")
  w.gmcp_defence_add("tempest")
  eq(w.svo.defc.tempest, nil, "and an air elemental's tempest")
end

do -- Duress' tempest and susurration, whose GMCP names the owner's login log showed
  local w = world.new({ class = "Air Elemental Lord" })
  w.gmcp_defence_add("tempest")
  w.gmcp_defence_add("susurrating")
  eq(w.svo.defc.tempest, true, "GMCP tempest sets tempest")
  eq(w.svo.defc.susurrating, true, "GMCP susurrating sets susurrating")
end

do -- a List confirms what it names and unconfirms what it does not
  local w = world.new()
  local svo = w.svo
  svo.pipes.skullcap.puffs = 10
  svo.defences.got("alertness")
  svo.defences.got("cloak")
  local smokes = counter(w, "lostbal_smoke")
  w.gmcp_defence_list({ "rebounding", "cloak" })
  eq(svo.defc.rebounding, true, "a List naming rebounding sets it")
  eq(smokes.n, 0, "with no smoke balance spent")
  eq(svo.pipes.skullcap.puffs, 10, "and no puff")
  eq(svo.defc.cloak, true, "keeps cloak, which it names")
  eq(svo.defc.alertness, false, "and loses alertness, which it does not")
end

do -- an ordinary basicdef defence: GMCP sets it and nothing else
  local w = world.new()
  w.gmcp_defence_add("alertness")
  eq(w.svo.defc.alertness, true, "GMCP alertness sets it")
  eq(w.inflight(), "", "and leaves nothing in flight")
  w.gmcp_defence_add("softfocusing")
  eq(w.svo.defc.softfocus, true, "GMCP softfocusing sets softfocus, through sstosvod")
end

-- Six GMCP-mapped defences have hand-written got_ handlers that ignored the
-- force flag, so with anti-illusion on (svof's default) their GMCP gains
-- were dropped, and blind's always. Now each goes through confirm, whatever
-- anti-illusion says: four are set, and blindness and deafness, which may be
-- the affliction rather than the defence, wait for the prompt flags.
for _, aillusion in ipairs({ true, false }) do
  local setting = "anti-illusion " .. (aillusion and "on" or "off") .. ": "
  for gmcpname, def in pairs({ speed = "speed", blocking = "block", dragonbreath = "dragonbreath" }) do
    local w = world.new()
    w.svo.conf.aillusion = aillusion
    w.gmcp_defence_add(gmcpname)
    w.prompt()
    eq(w.svo.defc[def], true, setting .. "GMCP " .. gmcpname .. " sets " .. def)
  end
  local w = world.new({ class = "Sylvan" })
  w.svo.conf.aillusion = aillusion
  w.gmcp_defence_add("viridian")
  w.prompt()
  eq(w.svo.defc.viridian, true, setting .. "GMCP viridian sets it")
  for gmcpname, def in pairs({ blindness = "blind", deafness = "deaf" }) do
    w = world.new()
    w.svo.conf.aillusion = aillusion
    w.gmcp_defence_add(gmcpname)
    w.prompt()
    eq(w.svo.defc[def], nil, setting .. "GMCP " .. gmcpname .. " leaves " .. def .. " to the prompt flags")
  end
end
do -- the game does not say which way you block: svof assumes its own way
  local w = world.new()
  w.svo.conf.blockingdir = "n"
  w.gmcp_defence_add("blocking")
  eq(w.svo.dict.block.physical.blockingdir, "n", "GMCP blocking takes svof's own direction")
end

-- ===== 5. A GMCP loss is the game's word too =====

-- Char.Defences.Remove hands the defence to defences.unconfirm, which runs
-- its gone at once, outside lifevision. It used to file the gone claim like
-- a text line, so an illusion verdict on the paragraph discarded a loss the
-- game reported (defect 19, fixed).
do
  local w = world.new()
  w.svo.defences.got("alertness")
  w.gmcp_defence_remove("alertness")
  eq(w.svo.defc.alertness, false, "a GMCP loss clears the defence at once")

  w = world.new()
  w.svo.defences.got("alertness")
  w.gmcp_defence_remove("alertness")
  w.svo.sys.flawedillusion = true
  w.prompt()
  eq(w.svo.defc.alertness, false, "and an illusion verdict on the paragraph cannot bring it back")
end

-- ===== 6. DEF =====

-- svo.process_defs reconciles what DEF listed. A defence it lists that svof
-- did not know about used to run oncompleted(true) on a balance pairs()
-- picked (defect 18, fixed); now it goes to defences.confirm.
do
  local w = world.new()
  local svo = w.svo
  svo.pipes.skullcap.puffs = 10
  svo.defences.def_def_list.rebounding = true
  svo.process_defs()
  eq(svo.defc.rebounding, true, "DEF listing rebounding sets it")
  eq(w.inflight(), "", "and starts no wait")
  eq(svo.pipes.skullcap.puffs, 10, "uses no puff")
  eq(svo.bals.smoke, true, "and spends no smoke balance")

  w = world.new()
  svo = w.svo
  svo.defences.def_def_list.blind = true
  svo.process_defs()
  eq(svo.bals.herb, true, "DEF listing blind spends no herb balance")

  -- the whole way: svof's DEF, its lines, the prompt
  w = world.new()
  svo = w.svo
  svo.pipes.skullcap.puffs = 10
  svo.defences.got("alertness")
  svo.doaction(svo.dict.defcheck.physical)
  svo.defs.defstart()
  eq(w.line("You are protected from hand-held weapons with an aura of rebounding."), 1, "DEF's rebounding line is heard")
  svo.defs.defline()
  w.prompt()
  eq(svo.defc.rebounding, true, "after DEF, rebounding is set")
  eq(svo.pipes.skullcap.puffs, 10, "with no puff")
  eq(svo.defc.alertness, false, "and alertness, which DEF did not list, is lost")
  eq(echoed(w, "(e!)") or error_shown(w), false, "with no error")

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

  -- Whichever it adopts, the GMCP gain before it books nothing, and the
  -- caloric line finishes the adopted action, recording the salve once.
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
    eq(salves.n, 1, "adopting " .. adopted .. ", one server application spends salve balance once")
    eq(svo.defc.caloric, true, "adopting " .. adopted .. ": caloric is set")
    eq(w.inflight(), "", "adopting " .. adopted .. ": nothing is left in flight")
  end

  -- NIGHTSIGHT is how the server words it; svof's action is "nightsight on"
  w = world.new()
  eq(w.svo.sys.input_to_actions["nightsight"], nil, "today (defect 24): the server's NIGHTSIGHT is not a command svof adopts")
  eq(w.svo.sys.input_to_actions["nightsight on"] ~= nil, true, "svof adopts its own wording")
end

-- svof sets the server's defence priorities by the server's names, which
-- are GMCP's (the owner, 2026-10-09: the serverside name for caloric is
-- insulation). An entry's gamename gives it, as mass's density does. Of
-- the 13 defences svof names differently from GMCP, only caloric and frost
-- are ever sent; the other 11 are undeffable, which serverside skips.
do
  local w = world.new()
  local svo = w.svo
  local sent = {}
  svo.sendcuringprio = function(prio, kind) sent[#sent + 1] = kind .. " " .. prio end
  svo.sk.sendpriorityswitch("caloric", "salve", {}, { caloric = 5 }, {}, false)
  svo.sk.sendpriorityswitch("frost", "purgative", {}, { frost = 7 }, {}, false)
  svo.sk.sendpriorityswitch("mass", "salve", {}, { mass = 3 }, {}, false)
  svo.sk.sendpriorityignore("caloric", "salve", {}, {}, {}, false)
  eq(table.concat(sent, ", "),
    "defence insulation 5, defence temperance 7, defence density 3, defence insulation reset",
    "serverside priorities name caloric insulation and frost temperance")
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

do -- 16: a class change replaces the generated handlers with the new class's
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  eq(type(svo.defs.lost_boosting), "function", "a Monk has lost_boosting")
  local first_new = #w.triggers + 1
  svo.classchange("Infernal")
  local dangling = {}
  for i = first_new, #w.triggers do
    local h = type(w.triggers[i].code) == "string" and w.triggers[i].code:match("^svo%.defs%.([%w_]+)%(%)$")
    if h and type(svo.defs[h]) ~= "function" then dangling[#dangling + 1] = h end
  end
  eq(#w.triggers >= first_new, true, "the class change made the Infernal's triggers")
  eq(table.concat(dangling, ", "), "", "each of which calls a handler that exists")
  eq(svo.me.class, "Infernal", "the class change went through")
  eq(svo.dict.boosting, nil, "Infernal has no boosting entry")
  eq(svo.defs.lost_boosting, nil, "and no lost_boosting left over from the Monk")
  eq(svo.defs.got_boosting, nil, "or got_boosting")
  eq(type(svo.defs.lost_rebounding), "function", "while its own handlers are there")
  eq(type(svo.defs.got_block), "function", "and the hand-written ones too")
  eq(#w.writes > 0, true, "the class change tried to save the config, and was refused")
  svo.classchange("Monk")
  eq(type(svo.defs.lost_boosting), "function", "changing back makes lost_boosting again")
  svo.defences.got("boosting")
  local ok = pcall(svo.defs.lost_boosting)
  eq(ok, true, "and it works")
end

-- ===== 9. confirm and unconfirm: the game's word, apart from svof's command =====

do -- nothing of svof's in flight: the defence is set, and nothing is booked
  local w = world.new()
  local svo = w.svo
  svo.pipes.skullcap.id, svo.pipes.skullcap.puffs, svo.pipes.skullcap.lit = 12345, 10, true
  local smokes, salves = counter(w, "lostbal_smoke"), counter(w, "lostbal_salve")
  for _, def in ipairs({ "rebounding", "sileris", "caloric", "mass", "speed", "alertness" }) do
    svo.defences.confirm(def)
    eq(svo.defc[def], true, "confirm " .. def .. " with nothing in flight sets it")
  end
  eq(w.inflight(), "", "and starts nothing")
  eq(svo.pipes.skullcap.puffs, 10, "uses no puff")
  eq(smokes.n + salves.n, 0, "and spends no balance")
  w.advance(20)
  eq(svo.sys.lagcount, 0, "and leaves no timer to count as lag")
end

do -- svof's smoke in flight: it went through, so its puff and balance count once
  local w = world.new()
  local svo = w.svo
  svo.pipes.skullcap.id, svo.pipes.skullcap.puffs, svo.pipes.skullcap.lit = 12345, 10, true
  svo.doaction(svo.dict.rebounding.smoke)
  local smokes = counter(w, "lostbal_smoke")
  svo.defences.confirm("rebounding")
  eq(svo.defc.rebounding, true, "confirm rebounding during svof's smoke sets it")
  eq(svo.pipes.skullcap.puffs, 9, "uses the smoke's one puff")
  eq(smokes.n, 1, "spends smoke balance once")
  eq(w.inflight(), "", "and leaves neither the smoke nor its wait in flight")
  w.advance(20)
  eq(svo.sys.lagcount, 0, "and no timer counts as lag")
end

do -- svof's wait in flight: the defence came up
  local w = world.new()
  local svo = w.svo
  svo.doaction(svo.dict.waitingforsileris.waitingfor)
  svo.defences.confirm("sileris")
  eq(svo.defc.sileris, true, "confirm sileris during its wait sets it")
  eq(w.inflight(), "", "and finishes the wait")
  w.advance(20)
  eq(svo.sys.lagcount, 0, "whose timer is gone")
  svo.defs.sileris_finished() -- the hardening line, after GMCP
  w.prompt()
  eq(echoed(w, "(e!)") or error_shown(w), false, "the line after it finds nothing to finish, and no error")
end

do -- a claim a line already filed is finished by confirm, not again at the prompt
  local w = world.new()
  local svo = w.svo
  svo.doaction(svo.dict.caloric.salve)
  svo.defs.salve_got_caloric() -- the caloric line came first, this time
  local salves = counter(w, "lostbal_salve")
  svo.defences.confirm("caloric")
  w.prompt()
  eq(svo.defc.caloric, true, "caloric is set")
  eq(salves.n, 1, "salve balance is spent once")
  eq(echoed(w, "(e!)") or error_shown(w), false, "and the prompt finds no claim left to finish")
end

do -- blind and deaf: the prompt flags decide between defence and affliction
  local w = world.new()
  local svo = w.svo
  svo.defences.confirm("blind")
  eq(svo.defc.blind, nil, "confirm blind with nothing in flight leaves it to the prompt")
  svo.doaction(svo.dict.blind.herb)
  local herbs = counter(w, "lostbal_herb")
  svo.defences.confirm("blind")
  eq(svo.defc.blind, true, "with svof's bayberry in flight, it went through")
  eq(herbs.n, 1, "and herb balance is spent once")
end

do -- unconfirm: the loss is the game's, so no illusion verdict can discard it
  local w = world.new()
  local svo = w.svo
  svo.defences.got("alertness")
  svo.defences.unconfirm("alertness")
  eq(svo.defc.alertness, false, "unconfirm alertness loses it at once")
  svo.defences.got("sileris")
  svo.sys.flawedillusion = true
  svo.defences.unconfirm("sileris")
  w.prompt()
  eq(svo.defc.sileris, false, "unconfirm sileris loses it through its gone, outside lifevision")
end

do -- ongot and onlost: consequences, on the record, run once per change
  local w = world.new()
  local svo = w.svo
  local ran = {}
  svo.defs_data.alertness.ongot = function() ran[#ran + 1] = "got" end
  svo.defs_data.alertness.onlost = function() ran[#ran + 1] = "lost" end
  svo.defences.got("alertness")
  svo.defences.got("alertness")
  svo.defences.lost("alertness")
  svo.defences.lost("alertness")
  eq(table.concat(ran, " "), "got lost", "ongot and onlost run when the defence changes, not when it is said again")
  svo.defs_data.alertness.ongot = function() error("broken") end
  local ok = pcall(svo.defences.got, "alertness")
  eq(ok, true, "a broken ongot does not stop whatever set the defence")
  eq(svo.defc.alertness, true, "which is set")
  eq(error_shown(w, "broken"), true, "and it is reported")
end

-- ===== 10. GMCP has the final word on the defences it reports =====

-- Once Char.Defences has sent its List, a line saying a defence is gone is
-- dropped while GMCP still reports it. A real loss reaches GMCP first, as a
-- Remove, which defences.unconfirm takes at once.
local SHIELD_LOSS = "Your movement causes your magical shield to dissipate."

do -- before the List, the line decides, as it always has
  local w = world.new()
  w.svo.defences.got("shield")
  eq(w.line(SHIELD_LOSS), 1, "shield's loss line is heard")
  w.prompt()
  eq(w.svo.defc.shield, false, "before GMCP's List, the line loses shield")
end

do -- after it, a line GMCP contradicts is dropped
  local w = world.new()
  local svo = w.svo
  svo.conf.gmcpdefechoes = true
  w.gmcp_defence_list({ "shield" })
  eq(svo.defc.shield, true, "the List sets shield")
  w.line(SHIELD_LOSS)
  w.prompt()
  eq(svo.defc.shield, true, "a line saying shield is gone, while GMCP reports it, is dropped")
  eq(echoed(w, "Ignored a line saying shield is gone: GMCP still reports it."), true, "and says so with gmcpdefechoes")

  w.gmcp_defence_remove("shield")
  eq(svo.defc.shield, false, "GMCP's own Remove loses it")
  svo.defences.got("shield")
  w.gmcp_defence_add("shield")
  w.line(SHIELD_LOSS)
  w.prompt()
  eq(svo.defc.shield, true, "an Add puts it back under GMCP's word")
end

do -- a defence GMCP cannot report is left to the lines
  local w = world.new()
  local svo = w.svo
  w.gmcp_defence_list({ "shield" })
  eq(svo.dict.svotossd.riding, nil, "GMCP has no name for riding")
  svo.defences.got("riding")
  svo.defs.lost_riding() -- a dismount line
  w.prompt()
  eq(svo.defc.riding, false, "and its loss line still loses it")
end

do -- after a blackout, GMCP's old word stops counting until it is repeated
  local w = world.new()
  local svo = w.svo
  w.gmcp_defence_list({ "shield" })
  svo.affs.blackout = {}
  svo.signals.svogotaff:emit("blackout")
  eq(svo.gmcp_defs_live(), false, "in blackout GMCP's defences are not live")
  svo.affs.blackout = nil
  eq(svo.gmcp_defs_live(), true, "and are again after it")
  w.line(SHIELD_LOSS)
  w.prompt()
  eq(svo.defc.shield, false, "but shield, from before the blackout, no longer holds against a loss line")
end

do -- DEF's paragraph is the game's own list, so it stands
  local w = world.new()
  local svo = w.svo
  w.gmcp_defence_list({ "alertness" })
  eq(svo.defc.alertness, true, "the List sets alertness")
  svo.doaction(svo.dict.defcheck.physical)
  svo.defs.defstart()
  svo.defs.defline() -- a DEF that does not list alertness
  w.prompt()
  eq(svo.defc.alertness, false, "DEF not listing alertness loses it, whatever GMCP said")
end

-- ===== 10c. And on the gains =====

-- A real gain reaches GMCP first, as an Add, and defences.confirm finishes
-- svof's command for it there, so a gain claim still standing at the prompt
-- for a defence GMCP does not list is a line GMCP does not back. It is
-- dropped (svo.gmcp_refuted_defence), and svof's command waits for the game.
local ALERT = "You prick up your ears."

-- GMCP live, having sent the defence's name and not listing it now
local function live_without(gmcpname)
  local w = world.new()
  w.svo.conf.gmcpdefechoes = true
  w.gmcp_defence_list({ gmcpname })
  w.gmcp_defence_remove(gmcpname)
  return w
end

do -- svof's own command: the line is dropped and the command waits
  local w = live_without("alertness")
  local svo = w.svo
  svo.doaction(svo.dict.alertness.physical)
  w.line(ALERT)
  w.prompt()
  eq(svo.defc.alertness, false, "gain gate: a line saying you have alertness, GMCP silent, is dropped")
  eq(echoed(w, "Ignored a line saying you have alertness: GMCP doesn't report it."), true,
    "gain gate: and says so with gmcpdefechoes")
  eq(w.inflight(), "alertness_physical", "gain gate: svof's command stays in flight for the game's answer")
  w.gmcp_defence_add("alertness")
  eq(svo.defc.alertness, true, "gain gate: GMCP's Add sets it")
  eq(w.inflight(), "", "gain gate: and finishes the command")
end

do -- what the attempt spent is booked once, when the game answers
  local w = live_without("insulation")
  local svo = w.svo
  local salves = counter(w, "lostbal_salve")
  svo.doaction(svo.dict.caloric.salve)
  svo.defs.salve_got_caloric()
  w.prompt()
  eq(svo.defc.caloric, false, "gain gate: a caloric line GMCP does not back is dropped")
  eq(salves.n, 0, "gain gate: and books no salve balance yet")
  w.gmcp_defence_add("insulation")
  eq(svo.defc.caloric, true, "gain gate: GMCP's insulation sets caloric")
  eq(salves.n, 1, "gain gate: and the application's salve balance is booked once")
end

do -- the server's own command counts: its [Curing]: line cannot be illusioned
  local w = live_without("alertness")
  local svo = w.svo
  svo.conf.serverside = true
  svo.curingcommand("ALERTNESS ON")
  eq(w.inflight(), "alertness_physical", "gain gate: the server's ALERTNESS ON is adopted")
  w.line(ALERT)
  w.prompt()
  eq(svo.defc.alertness, true, "gain gate: its line counts, GMCP silent")
end

do -- a GMCP name the game has not sent this session is never refused
  local w = world.new()
  local svo = w.svo
  w.gmcp_defence_list({ "shield" })
  eq(svo.sk.gmcp_defs_seen.alertness, nil, "gain gate: GMCP has not sent alertness")
  svo.doaction(svo.dict.alertness.physical)
  w.line(ALERT)
  w.prompt()
  eq(svo.defc.alertness, true, "gain gate: so its line sets it, as before")
end

do -- before the List the line decides, and a gain GMCP lists counts
  local w = world.new()
  local svo = w.svo
  svo.doaction(svo.dict.alertness.physical)
  w.line(ALERT)
  w.prompt()
  eq(svo.defc.alertness, true, "gain gate: before GMCP's List, the line sets it")
  w.gmcp_defence_list({ "alertness" })
  svo.defc.alertness = false -- svof lost track of it
  svo.doaction(svo.dict.alertness.physical)
  w.line("Alertness is already on!")
  w.prompt()
  eq(svo.defc.alertness, true, "gain gate: a line GMCP agrees with sets it")
end

do -- a delayed defence's raise starts its wait; the wait's own claim is gated
  local w = live_without("rebounding")
  local svo = w.svo
  svo.pipes.skullcap.id, svo.pipes.skullcap.puffs, svo.pipes.skullcap.lit = 12345, 10, true
  svo.doaction(svo.dict.rebounding.smoke)
  svo.lifevision.add(svo.actions.rebounding_smoke.p) -- the smoke line
  w.prompt()
  eq(w.inflight(), "waitingonrebounding_waitingfor", "gain gate: rebounding's smoke starts its wait, GMCP silent")
  eq(svo.pipes.skullcap.puffs, 9, "gain gate: and uses its puff")
  local wait = svo.actions.waitingonrebounding_waitingfor
  if wait then svo.lifevision.add(wait.p) end -- an aura line, GMCP silent
  w.prompt()
  eq(svo.defc.rebounding, false, "gain gate: an aura line GMCP does not back is dropped")
  eq(w.inflight(), "waitingonrebounding_waitingfor", "gain gate: and the wait goes on")
  w.gmcp_defence_add("rebounding")
  eq(svo.defc.rebounding, true, "gain gate: GMCP's Add sets rebounding")
  eq(w.inflight(), "", "gain gate: and ends the wait")
end

do -- a line with nothing of svof's behind it leaves nothing behind
  local w = live_without("alertness")
  local svo = w.svo
  svo.conf.aillusion = false -- so the line makes up its own claim
  w.line(ALERT)
  w.prompt()
  eq(svo.defc.alertness, false, "gain gate: a made-up claim GMCP does not back is dropped")
  eq(w.inflight(), "", "gain gate: and cleared")
end

do -- a second refusal, of a separate command on a later prompt, is believed
  local w = live_without("alertness")
  local svo = w.svo
  svo.doaction(svo.dict.alertness.physical)
  w.line(ALERT)
  w.prompt()
  eq(svo.defc.alertness, false, "gain gate, twice: the first line is dropped")
  w.advance(5) -- svof's command times out
  eq(w.inflight(), "", "gain gate, twice: svof's command timed out")
  svo.promptcount = svo.promptcount + 1
  svo.doaction(svo.dict.alertness.physical)
  w.line(ALERT)
  w.prompt()
  eq(svo.defc.alertness, true, "gain gate, twice: the game showing it again is believed, so svof stops raising it")
  eq(echoed(w, "Believed you have alertness: the game showed it again, though GMCP doesn't report it."), true,
    "gain gate, twice: and says so")
end

-- ===== 10b. A gain line claims whichever of svof's commands for it is in flight =====

-- deathsight is raised by eating skullcap or by the skill, and its gain
-- lines go to the generated got_deathsight, which used to claim one balance
-- pairs() picked, so one of the two was missed.
for _, bal in ipairs({ "herb", "physical" }) do
  local w = world.new()
  local svo = w.svo
  svo.doaction(svo.dict.deathsight[bal])
  w.line("Your mind is already attuned to the realm of Death.")
  eq(svo.lifevision.l["deathsight_" .. bal] ~= nil, true, "deathsight by " .. bal .. ": its gain line claims the " .. bal .. " action")
  w.prompt()
  eq(svo.defc.deathsight, true, "deathsight by " .. bal .. ": and sets it at the prompt")
end
do -- with nothing in flight, the balance a line would make up is the same every time
  local w = world.new()
  eq(w.svo.defences.raising_balance("deathsight"), "herb", "deathsight's default balance is herb, the first by name")
  eq(w.svo.defences.raising_balance("insomnia"), "herb", "and insomnia's is herb, never its aff block")
  eq(w.svo.defences.raising_balance("deathsight", true), nil, "with nothing in flight, nothing is in flight")
end

-- ===== 11. Defences registered after systemstart =====

-- An item's defence (the phylactery's mindnet, a lifevision mask, a
-- Shadowcloak's shroud) is registered once the inventory shows the item,
-- through defences.register, which wires it as systemstart wires the rest.
do
  local w = world.new()
  local svo = w.svo
  -- a choice saved last session, restored at systemstart before the item
  svo.defdefup.basic.mindnet, svo.defkeepup.basic.mindnet = true, true
  local tracked = #svo.defencetemptriggers
  local made = #w.triggers
  svo.defences.enablemindnet()
  eq(#w.triggers - made, 4, "mindnet makes a trigger for each of its four lines")
  eq(#svo.defencetemptriggers - tracked, 4, "and every one is tracked, for a class change to kill")
  eq(svo.defdefup.basic.mindnet, true, "the saved defup choice for mindnet is kept")
  eq(svo.defkeepup.basic.mindnet, true, "and the keepup one")
  svo.defences.got("mindnet")
  eq(w.line("You cease concentration and your mind net vanishes."), 1, "mindnet's loss line is heard")
  w.prompt()
  eq(svo.defc.mindnet, false, "and loses it")
  svo.doaction(svo.dict.mindnet.physical)
  w.line("You already have mindnet active.")
  w.prompt()
  eq(svo.defc.mindnet, true, "a gain line for svof's mindnet sets it")

  svo.defences.enableshroud()
  svo.doaction(svo.dict.shroud.physical)
  eq(w.line("You draw a cloak of the Blood Maiden about you and blend into your surroundings."), 1,
    "shroud's third gain line is heard")
  w.prompt()
  eq(svo.defc.shroud, true, "and sets shroud")

  svo.defences.enablelifevision()
  eq(type(svo.dict.lifevision.physical.aspriority), "number", "lifevision's entry gets its priorities from dict_setup")
  eq(type(svo.defs.got_lifevision), "function", "and its handlers")
end

do -- the item is looked for in your inventory only
  local w = world.new()
  local svo = w.svo
  w.env.gmcp.Char.Items.List = { location = "room", items = { { name = "a  phylactery of sixth sense" } } }
  svo.defences.checkmindnet()
  eq(svo.dict.mindnet, nil, "a phylactery in the room does not register mindnet")
  w.env.gmcp.Char.Items.List = { location = "inv", items = { { name = "a  phylactery of sixth sense" } } }
  svo.defences.checkmindnet()
  eq(type(svo.dict.mindnet), "table", "one in your inventory does")
end

-- The defences a player defines (vcustomdef) are registered on every
-- systemstart for the class they belong to, or for every class.
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  eq(svo.conf.customdefinitions, true, "custom defences: vconfig customdefinitions is on unless switched off")
  svo.defences.custom = {
    shimmer = { class = "Monk", command = "shimmer on", on = { "You begin to shimmer." },
      off = "You stop shimmering.", def = "You are shimmering.", gmcp = "shimmering" },
    warded = { class = "all", command = "ward self", balanceless = true, on = "A ward settles about you.",
      serverside = true },
    rebounding = { class = "all", command = "rebound" },        -- svof's own name
    broken = { class = "Monk", on = "Nothing raises this." },   -- no command
    stoneward = { class = "Infernal", skillset = "malignity", command = "stoneward" },  -- another class's
  }
  svo.defdefup.basic.shimmer = true -- a choice saved last session
  svo.classchange("Infernal")
  eq(svo.defs_data.warded ~= nil and svo.defs_data.stoneward ~= nil, true,
    "custom defences: as an Infernal, the all-class one and the Infernal's are registered")
  eq(svo.defs_data.shimmer, nil, "custom defences: and not the Monk's")
  eq(svo.defs_data.stoneward and svo.defs_data.stoneward.type, "malignity", "custom defences: the Infernal's under its skillset")
  eq(svo.dict.rebounding.smoke ~= nil and svo.defs_data.rebounding.type, "general",
    "custom defences: a name svof uses is refused, and svof's own rebounding stays")
  eq(echoed(w, "Svof has its own rebounding in this class, so the one you defined isn't used."), true,
    "custom defences: and says so")

  svo.classchange("Monk")
  local rec, entry = svo.defs_data.shimmer, svo.dict.shimmer
  eq(rec and rec.type, "custom", "custom defences: as a Monk, shimmer is registered; saved without a skillset, in a group of its own")
  eq(entry and entry.physical.action, "shimmer on", "custom defences: raised with its command")
  eq(entry and entry.physical.balanceful_act, true, "custom defences: taking balance unless balanceless")
  eq(entry and entry.physical.undeffable, nil, "custom defences: with a GMCP name, serverside may raise it")
  local warded = svo.dict.warded and svo.dict.warded.physical or {}
  eq(warded.balanceless_act, true, "custom defences: warded takes no balance")
  eq(warded.undeffable, true, "custom defences: and has no GMCP name, so only svof raises it, whatever the file says")
  eq(svo.dict.sstosvod.shimmering, "shimmer", "custom defences: GMCP's shimmering is shimmer")
  eq(entry and entry.gamename, "shimmering", "custom defences: and so is the serverside name")
  eq(svo.defdefup.basic.shimmer, true, "custom defences: the saved defup choice is kept")
  eq(svo.defs_data.broken, nil, "custom defences: one with no command is not registered")
  eq(echoed(w, "add the defence broken you defined: it has no command to raise it"), true,
    "custom defences: and says why")

  if entry then svo.doaction(entry.physical) end
  eq(w.line("You begin to shimmer."), 1, "custom defences: its gain line is heard")
  w.prompt()
  eq(svo.defc.shimmer, true, "custom defences: and sets it")
  w.line("You stop shimmering.")
  w.prompt()
  eq(svo.defc.shimmer, false, "custom defences: its loss line loses it")
  w.gmcp_defence_add("shimmering")
  eq(svo.defc.shimmer, true, "custom defences: GMCP's gain sets it")

  local ignored = svo.sk.ignored_defences.custom
  if ignored then ignored.t.shimmer = true end -- switched off in vshow defup
  svo.classchange("Infernal")
  svo.classchange("Monk")
  ignored = svo.sk.ignored_defences.custom
  eq(ignored and ignored.t.shimmer, true, "custom defences: switching one off survives a class change")

  svo.conf.customdefinitions = false
  svo.classchange("Infernal")
  eq(svo.defs_data.warded, nil, "custom defences: with customdefinitions off, none is registered")
end

-- vcustomdef: defining one, installing, changing, deleting
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local custom = svo.defences
  local function cmd(rest) custom.customdef_command(rest) end
  local function live(def)
    local n = 0
    for _, t in ipairs(w.triggers) do
      if not t.killed and type(t.code) == "string" and t.code:find("_" .. def .. "()", 1, true) then n = n + 1 end
    end
    return n
  end

  -- the alias hands the rest of the line on. The harness runs no aliases,
  -- so this reads the item: its pattern, and its script run as Mudlet
  -- would, with what the pattern captured
  local dir = "src/aliases/svo (aliases, triggers)/svo/"
  local fh = io.open(dir .. "aliases.json", "r")
  local items = fh and fh:read("*a") or ""
  if fh then fh:close() end
  local at = items:find('"name": "(vcustomdef) Define your own defences"', 1, true)
  local item = at and items:sub(at, (items:find("}", at, true) or #items))
  eq(item and item:find('"isActive": "yes"', 1, true) ~= nil, true, "customdef: the vcustomdef alias is active")
  eq(item and item:match('"regex": "([^"]*)"'), "^vcustomdef(?: (.+))?$",
    "customdef: the vcustomdef alias takes an optional rest of the line")
  fh = io.open(dir .. "(vcustomdef)_Define_your_own_defences.lua", "r")
  local script = fh and fh:read("*a") or ""
  if fh then fh:close() end
  w.env.matches = { "vcustomdef Shimmer command shimmer on", "Shimmer command shimmer on" }
  w.run(script, "vcustomdef")
  local d = custom.custom_drafts.shimmer
  eq(d and d.command, "shimmer on", "customdef: vcustomdef <name> command <text> starts a draft")
  eq(echoed(w, "Asking the game for shimmer's lines."), true,
    "customdef: a new one's screen waits for the game's DEFENCE SHOW")
  w.advance(10) -- which doesn't answer here
  local typed = false
  for _, l in ipairs(w.links) do
    if l:find('printCmdLine("vcustomdef shimmer command ")', 1, true) then typed = true end
  end
  eq(typed, true, "customdef: its change links type a vcustomdef command")
  eq(d and d.class, "monk", "customdef: for the class you are in")
  cmd("shimmer got You begin to shimmer.")
  cmd("shimmer lost You stop shimmering.")
  cmd("shimmer def You are shimmering.")
  svo.defences.gmcp_confirmed.shimmering = true -- as if the game confirmed it; how, further down
  cmd("shimmer gmcp shimmering")
  w.advance(10) -- the screen follows the game's DEFENCE SHOW, which doesn't answer here
  cmd("shimmer test")
  eq(echoed(w, "be installed yet: pick which of its class's skillsets to show it under."), true,
    "customdef: a class's defence needs a skillset")
  -- the skillset row has a link for each of the class's
  local links = {}
  for _, l in ipairs(w.links) do
    local skillset = l:match("^(%a+) svo%.defences%.custom_set%(\"shimmer\", 'skillset', \"%a+\"%)$")
    if skillset and not table.concat(links, ","):find(skillset, 1, true) then links[#links + 1] = skillset end
  end
  eq(table.concat(links, ","), "tekura,kaido,telepathy,shikudo", "customdef: a link for each of the Monk's skillsets")
  w.run([[svo.defences.custom_set("shimmer", 'skillset', "tekura")]])
  eq(d and d.skillset, "tekura", "customdef: clicking one sets it")
  eq(row_echoed(w, string.rep("-", 70), "  Actions:"), true,
    "customdef: the screen's links come under a line, labelled Actions (the user's ask, 2026-10-17)")  cmd("shimmer test")
  eq(echoed(w, "shimmer, for Monk, under Tekura:"), true, "customdef: test says where it's shown")
  eq(echoed(w, "It's ready to install."), true, "customdef: test says it is ready")
  eq(svo.defs_data.shimmer, nil, "customdef: a draft changes nothing in play")

  local writes = #w.writes
  cmd("shimmer install")
  eq(svo.defs_data.shimmer and svo.defs_data.shimmer.type, "tekura", "customdef: install registers it, in its skillset's group")
  local listed = false
  for _, def in ipairs(svo.defences.def_types.tekura or {}) do if def == "shimmer" then listed = true end end
  eq(listed, true, "customdef: so the lists show it under Tekura")
  eq(svo.dict.sstosvod.shimmering, "shimmer", "customdef: with its GMCP name")
  eq(#w.writes > writes, true, "customdef: and saves the definitions")
  eq(custom.custom_drafts.shimmer, nil, "customdef: the draft is done with")
  if svo.dict.shimmer then svo.doaction(svo.dict.shimmer.physical) end
  w.line("You begin to shimmer.")
  w.prompt()
  eq(svo.defc.shimmer, true, "customdef: its gain line works at once")
  svo.ignoreskill("shimmer", true) -- hidden in vshow hidelist

  -- changing it: only install puts the change into play, without piling up triggers
  local triggers = live("shimmer")
  cmd("shimmer command shimmer up")
  eq(svo.dict.shimmer and svo.dict.shimmer.physical.action, "shimmer on", "customdef: a change waits for install")
  custom.custom_unset("shimmer", "on", 1)
  cmd("shimmer got You shimmer brightly.")
  cmd("shimmer install")
  eq(svo.dict.shimmer and svo.dict.shimmer.physical.action, "shimmer up", "customdef: installing again uses the change")
  eq(live("shimmer"), triggers, "customdef: with the old triggers killed")
  eq(svo.sk.ignored_defences.tekura.t.shimmer, true, "customdef: and still hidden, as it was")
  svo.ignoreskill("shimmer", false)
  eq(w.line("You begin to shimmer."), 0, "customdef: the line taken out is no longer heard")
  eq(w.line("You shimmer brightly."), 1, "customdef: and the new one is")

  -- a name svof uses isn't a definition (the user's choice): one of svof's
  -- own defences opens a change to it instead (section 13), and an
  -- incomplete one can't install
  cmd("rebounding")
  eq(echoed(w, "rebounding, Svof's own defence:"), true, "customdef: svof's own defence's name changes svof's own")
  eq(custom.custom_drafts.rebounding, nil, "customdef: and starts no definition")
  cmd("paralysis")
  eq(echoed(w, "define paralysis: Svof already has a defence or action called paralysis."), true,
    "customdef: a name svof uses for something else is refused")
  cmd("hush command hush")
  cmd("hush install")
  eq(echoed(w, "install hush: it needs a line saying you gained it, or its GMCP name"), true,
    "customdef: one svof could never see come up can't be installed")
  eq(svo.defs_data.hush, nil, "customdef: and isn't registered")

  -- picking a line off the screen
  w.env.getLines = function() return { "You see a rat.", "", "You begin to glow." } end
  cmd("glow line got")
  local pick
  for _, l in ipairs(w.links) do
    if l:find("You begin to glow.", 1, true) and l:find("custom_set", 1, true) then pick = l:sub(#"You begin to glow." + 2) end
  end
  eq(pick ~= nil, true, "customdef: line got offers the lines on screen")
  if pick then w.run(pick) end
  eq(custom.custom_drafts.glow and custom.custom_drafts.glow.on[1], "You begin to glow.", "customdef: clicking one adds it")

  -- another class's, whose skillset doesn't carry over
  cmd("ironhide skillset kaido")
  cmd("ironhide class Infernal")
  eq(custom.custom_drafts.ironhide and custom.custom_drafts.ironhide.skillset, nil,
    "customdef: a Monk's skillset is dropped when the class changes to Infernal")
  cmd("ironhide skillset oppression")
  cmd("ironhide command ironhide")
  cmd("ironhide got Your skin turns to iron.")
  cmd("ironhide install")
  eq(echoed(w, "Saved ironhide. It's for Infernal, so Svof adds it when you're one."), true,
    "customdef: one for another class is saved, not added")
  eq(svo.defs_data.ironhide, nil, "customdef: as a Monk it isn't registered")
  svo.classchange("Infernal")
  eq(svo.defs_data.ironhide and svo.defs_data.ironhide.type, "oppression", "customdef: as an Infernal it is, under Oppression")
  eq(svo.defs_data.shimmer, nil, "customdef: and the Monk's isn't")
  svo.classchange("Monk")
  eq(svo.dict.shimmer and svo.dict.shimmer.physical.action, "shimmer up", "customdef: back as a Monk, shimmer is")

  -- a skillset Svof doesn't list for the class gets a group of its own
  cmd("wisp skillset general")
  eq(echoed(w, "Can't show wisp under general: general is Svof's own group, not a skillset."), true,
    "customdef: general isn't a skillset")
  cmd("wisp skillset Wyrd craft")
  cmd("wisp command wisp")
  cmd("wisp got A wisp circles you.")
  cmd("wisp install")
  eq(svo.defs_data.wisp and svo.defs_data.wisp.type, "wyrdcraft", "customdef: a skillset typed in is one word")
  local order = svo.defences.group_order()
  eq(order[#order], "wyrdcraft", "customdef: its group comes after the class's skillsets, by name")
  svo.ignoreskill("wyrdcraft", true)
  svo.classchange("Infernal")
  svo.classchange("Monk")
  eq(svo.sk.ignored_defences.wyrdcraft and svo.sk.ignored_defences.wyrdcraft.status, true,
    "customdef: hiding the group lasts through a class change and back")
  svo.ignoreskill("wyrdcraft", false)
  cmd("wisp delete")
  eq(svo.defences.def_types.wyrdcraft, nil, "customdef: and the group goes with its last defence")

  -- the list, each a link to see and change it: vcustomdef alone, which
  -- captures nothing
  local links = #w.links
  w.env.matches = { "vcustomdef" }
  w.run(script, "vcustomdef")
  eq(echoed(w, "Defences you defined (click one to see or change it):"), true, "customdef: vcustomdef lists them")
  eq(echoed(w, ": Monk (tekura), in use"), true, "customdef: each with its class and skillset")
  local shows, game, new = false, false, false
  for i = links + 1, #w.links do
    if w.links[i]:find('svo.defences.custom_show("shimmer")', 1, true) then shows = true end
    if w.links[i]:find("svo.defences.custom_gamelist()", 1, true) then game = true end
    if w.links[i]:find("printCmdLine('vcustomdef <name>')", 1, true) then new = true end
  end
  eq(shows, true, "customdef: each a link to see and change it")
  eq(game, true, "customdef: and a link to the game's defences Svof doesn't know")
  eq(new, true, "customdef: and one that types vcustomdef <name>, to define a new one")

  -- under it, every form of vcustomdef, each a link that types it (the
  -- user's ask, 2026-10-14)
  eq(echoed(w, "vcustomdef takes (click one to put it on the command line):"), true, "usage: the menu lists the forms")
  local forms = 0
  for i = links + 1, #w.links do
    if w.links[i]:find('^vcustomdef .* printCmdLine%("vcustomdef ') then forms = forms + 1 end
  end
  eq(forms, 14, "usage: each a link that types it")
  for _, typed in ipairs({ "<name>", "shimmer got <line>", "shimmer class|skillset|command|gmcp <value>",
      "export [file]|import <file>", "export [file]", "shimmer fetch [game name]" }) do
    local before = #w.echoes
    cmd(typed)
    local said = false
    for i = before + 1, #w.echoes do
      if w.echoes[i]:find("Replace each <...> with what it stands for", 1, true) then said = true end
    end
    eq(said, true, "usage: sent with its placeholders, " .. typed .. " says what to replace")
  end
  eq(svo.defences.custom_drafts.shimmer, nil, "usage: and changes nothing")
  -- (a library that reads any pattern: world.rex_stub has no (?<name>)
  w.env.rex = { new = function () return { match = function () end } end }
  cmd("shimmer gotpattern ^(?<who>\\w+) shimmers\\.$")
  eq(table.concat(svo.defences.custom_drafts.shimmer.onr or {}, "|"), "^(?<who>\\w+) shimmers\\.$",
    "usage: a pattern's own < > isn't taken for a placeholder")
  w.env.rex = nil
  local before = #w.echoes
  cmd("help")
  eq(#w.echoes > before and echoed(w, "vcustomdef takes"), true, "usage: vcustomdef help shows it alone")
  links = #w.links
  cmd("list")
  eq(#w.links > links, true, "customdef: vcustomdef list does the same")

  -- deleting takes it out of play at once
  cmd("shimmer delete")
  eq(svo.defs_data.shimmer, nil, "customdef: delete takes out its record")
  eq(svo.dict.shimmer, nil, "customdef: its entry")
  eq(svo.defs.got_shimmer, nil, "customdef: its handlers")
  eq(live("shimmer"), 0, "customdef: its triggers")
  eq(svo.dict.sstosvod.shimmering, nil, "customdef: and its GMCP name")
  eq(custom.custom.shimmer, nil, "customdef: and the definition")

  -- import, from a file another player exported
  local old_attributes, old_load = w.env.lfs.attributes, w.env.table.load
  w.env.lfs.attributes = function() return {} end
  w.env.table.load = function(_, t)
    t.veil = { class = "all", command = "veil on", balanceless = true, on = { "A veil falls about you." } }
    t.rebounding = { class = "all", command = "rebound", on = { "x" } }
  end
  cmd("import shared-defences")
  w.env.lfs.attributes, w.env.table.load = old_attributes, old_load
  eq(svo.defs_data.veil and svo.defs_data.veil.type, "general", "customdef: import installs what it can")
  eq(custom.custom.rebounding, nil, "customdef: and refuses svof's own names")
end

-- Serverside knows a defence by its GMCP name, so it raises a defined one
-- with a GMCP name while serverside is on, and svof does otherwise, unless
-- vshow server leaves it to svof (the user, 2026-10-10)
do
  local w = world.new({ class = "Monk", paused = false })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local told = {}
  svo.sendcuringprio = function(prio, kind, slow) told[#told + 1] = kind .. " " .. prio .. (slow and " (slow)" or "") end
  -- as if the game confirmed both GMCP names
  svo.defences.gmcp_confirmed.shimmering, svo.defences.gmcp_confirmed.murky = true, true

  cmd("shimmer skillset tekura")
  cmd("shimmer command shimmer on")
  cmd("shimmer got You begin to shimmer.")
  cmd("shimmer gmcp shimmering")
  cmd("shimmer install")
  eq(svo.serverignore.shimmer, true, "serverside: with a GMCP name, a definition is serverside's to raise")
  local listed = false
  for _, a in ipairs(svo.sk.getallserversideactions()) do if a == "shimmer" then listed = true end end
  eq(listed, true, "serverside: and vshow server lists it")
  svo.sk.sendpriorityswitch("shimmer", "physical", {}, { shimmer = 4 }, {}, false)
  eq(told[#told], "defence shimmering 4", "serverside: its priority goes to the server by its GMCP name")

  -- on keepup: with serverside on svof leaves it, with it off svof raises it
  svo.conf.keepup = true
  svo.defkeepup.basic.shimmer = true
  svo.conf.serverside = true
  w.prompt()
  eq(w.inflight(), "", "serverside: while serverside is on, svof doesn't raise it")
  svo.conf.serverside = false
  w.prompt()
  eq(w.inflight(), "shimmer_physical", "serverside: while it's off, svof does")
  svo.killaction(svo.dict.shimmer.physical)
  svo.defkeepup.basic.shimmer = false

  -- vshow server leaving it to svof lasts through installing again
  svo.unsetserverignore("shimmer")
  cmd("shimmer command shimmer up")
  cmd("shimmer install")
  eq(svo.serverignore.shimmer, nil, "serverside: leaving it to svof in vshow server lasts through a reinstall")
  cmd("shimmer test")
  eq(echoed(w, "Serverside leaves it to Svof."), true, "serverside: and test says so")
  svo.setserverignore("shimmer")

  -- deleting it tells the server, in both curing sets, while svof still
  -- knows the name
  svo.conf.serverside = true
  svo.defkeepup.basic.shimmer = true -- so the priority snapshots have it
  told = {}
  local events = #w.events
  cmd("shimmer delete")
  eq(table.concat(told, ", "), "defence shimmering reset, defence shimmering reset (slow)",
    "serverside: deleting one tells the server to stop raising it")
  eq(svo.serverignore.shimmer, nil, "serverside: and forgets it in vshow server")
  local changed = {}
  for i = events + 1, #w.events do
    local e = w.events[i]
    if e.name == "svo prio changed" and e.args[1] == "shimmer" then changed[#changed + 1] = tostring(e.args[2]) end
  end
  eq(table.concat(changed, ", "), "", "serverside: and raises no priority change for an action that's gone")

  -- taking away its GMCP name does the same, and leaves it to svof
  cmd("murk skillset kaido")
  cmd("murk command murk")
  cmd("murk got A murk gathers about you.")
  cmd("murk gmcp murky")
  cmd("murk install")
  told = {}
  cmd("murk gmcp none")
  cmd("murk install")
  eq(table.concat(told, ", "), "defence murky reset, defence murky reset (slow)",
    "serverside: a definition losing its GMCP name is taken off the server's list")
  eq(svo.serverignore.murk, nil, "serverside: and is svof's to raise")
  eq(svo.dict.murk and svo.dict.murk.physical.undeffable, true, "serverside: which serverside can't now")
  cmd("murk")
  eq(echoed(w, "can't raise it without a GMCP name, so Svof does"), true,
    "serverside: as the definition says")

  cmd("murk serverside yes")
  eq(echoed(w, "Serverside raises a defence by its GMCP name, so give murk one"), true,
    "serverside: there's no serverside switch; the GMCP name decides")
end

-- For a defence the game knows, DEFENCE SHOW gives its lines and GMCP name
-- (the reply's layout is the owner's capture, 2026-10-09)
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function game(text) w.env.line = text svo.defences.custom_fetch_line() w.run_timers() end
  local function listening()
    for _, t in ipairs(w.triggers) do
      if not t.killed and t.code == "svo.defences.custom_fetch_line()" then return true end
    end
    return false
  end

  cmd("shimmering")
  eq(w.sent[#w.sent], "defence show shimmering", "DEFENCE SHOW: a new definition asks the game about it")
  game("You snap your head up as you break your meditation.")
  game("Defence:            Shimmering (shimmering)")
  game("Description:        A soft shimmer that hides you from ")
  game("prying eyes.")
  game("DefMsg:             You are shimmering softly.")
  game("EnactMsg:           You begin to shimmer softly, the light bending about ")
  game("you.")
  game("FadeMsg:            The shimmer about you fades.")
  game("Profession:         No")
  game("Strippable:         Yes")
  local d = svo.defences.custom_drafts.shimmering or { on = {}, off = {} }
  eq(d.gmcp, "shimmering", "DEFENCE SHOW: the GMCP name comes from the game")
  eq(d.on[1], "You begin to shimmer softly, the light bending about you.",
    "DEFENCE SHOW: EnactMsg, joined where it wrapped, is the gain line")
  eq(d.off[1], "The shimmer about you fades.", "DEFENCE SHOW: FadeMsg the loss line")
  eq(d.def, "You are shimmering softly.", "DEFENCE SHOW: DefMsg the DEF line")
  eq(d.class, "all", "DEFENCE SHOW: Profession No makes it every class's")
  eq(echoed(w, "isn't a profession defence, so any class can have it"), true, "DEFENCE SHOW: and says so")
  eq(listening(), false, "DEFENCE SHOW: the trigger reading the reply is killed when it ends")
  eq(svo.defences.custom_problem("shimmering", d), "it has no command to raise it",
    "DEFENCE SHOW: which leaves only the command to set")

  -- a reply that ends at the prompt
  cmd("gleam")
  game("Defence:            Gleam (gleam)")
  game("EnactMsg:           You begin to gleam.")
  w.env.isPrompt = function() return true end
  game("9975h, 6252m cexkdb-")
  w.env.isPrompt = function() return false end
  d = svo.defences.custom_drafts.gleam or { on = {} }
  eq(d.on[1], "You begin to gleam.", "DEFENCE SHOW: a reply cut short by the prompt counts")

  -- a profession defence: the player is asked whose
  cmd("steelstance")
  game("Defence:            Steelstance (steelstance)")
  game("EnactMsg:           You take up your stance.")
  game("Profession:         Yes")
  game("Strippable:         No")
  d = svo.defences.custom_drafts.steelstance or {}
  eq(d.class, "monk", "DEFENCE SHOW: a profession defence stays the class you're in")
  eq(echoed(w, "The game says steelstance is a profession defence. Which class has it?"), true,
    "DEFENCE SHOW: and asks which class has it")
  local pick
  for _, l in ipairs(w.links) do
    if l:find("custom_set(\"steelstance\", 'class', \"serpent\")", 1, true) then pick = l:match("^%S+ (.*)$") end
  end
  eq(pick ~= nil, true, "DEFENCE SHOW: with a link for each class")
  if pick then w.run(pick) end
  eq(d.class, "serpent", "DEFENCE SHOW: clicking one sets it")
  local venom = false
  for _, l in ipairs(w.links) do
    if l:find("custom_set(\"steelstance\", 'skillset', \"venom\")", 1, true) then venom = true end
  end
  eq(venom, true, "DEFENCE SHOW: and then offers that class's skillsets")

  -- a class you chose stays, whatever the game says
  cmd("glimmer class sentinel")
  game("Defence:            Glimmer (glimmer)")
  game("Profession:         No")
  game("Strippable:         Yes")
  d = svo.defences.custom_drafts.glimmer or {}
  eq(d.class, "sentinel", "DEFENCE SHOW: a class the player set is kept")

  -- a defence the game doesn't have
  cmd("hush")
  eq(w.sent[#w.sent], "defence show hush", "DEFENCE SHOW: asks about hush")
  game("You snap your head up as you break your meditation.")
  game("There is no such defence.")
  eq(echoed(w, "The game has no defence called hush, so add its lines yourself."), true,
    "DEFENCE SHOW: says when the game has no such defence")
  eq(listening(), false, "DEFENCE SHOW: and stops reading lines at once")

  -- and one it doesn't answer about
  cmd("murmur")
  w.advance(10)
  eq(echoed(w, "The game didn't answer about a defence called murmur, so add its lines yourself."), true,
    "DEFENCE SHOW: says when the game doesn't answer")
  eq(listening(), true, "DEFENCE SHOW: and reads on only to gag a late answer")
  w.advance(120)
  eq(listening(), false, "DEFENCE SHOW: for two minutes, then stops reading lines")

  -- a GMCP name that is one of svof's own
  cmd("attuned gmcp alertness")
  eq(w.sent[#w.sent], "defence show alertness", "DEFENCE SHOW: setting the GMCP name asks the game")
  game("Defence:            Alertness (alertness)")
  game("DefMsg:             Your senses are attuned to nearby movement.")
  game("EnactMsg:           You prick up your ears.")
  game("FadeMsg:            You cease your watchful alertness.")
  game("Profession:         No")
  game("Strippable:         Yes")
  eq(echoed(w, "The game's alertness is Svof's own alertness, so there's no need to define it."), true,
    "DEFENCE SHOW: one of svof's own is pointed out")
  d = svo.defences.custom_drafts.attuned or { on = {} }
  eq(#d.on, 0, "DEFENCE SHOW: and nothing is filled in")

  -- asking again by hand
  cmd("hush fetch hushing")
  eq(w.sent[#w.sent], "defence show hushing", "DEFENCE SHOW: fetch asks again, by the name given")

  -- the reply is gagged with the prompt after it, and a new definition's
  -- screen shows once, after it, filled in (the user's screenshot,
  -- 2026-10-14: it showed before and after the reply, and the reply too)
  local gagged = {}
  local deleteLineP = svo.deleteLineP
  svo.deleteLineP = function () gagged[#gagged + 1] = w.env.line end
  local function screens(name)
    local n = 0
    for _, e in ipairs(w.echoes) do
      if e:find(name .. ", a defence you are defining", 1, true) then n = n + 1 end
    end
    return n
  end
  cmd("mistral")
  eq(screens("mistral"), 0, "DEFENCE SHOW: a new definition's screen waits for the game")
  eq(echoed(w, "Asking the game for mistral's lines."), true, "DEFENCE SHOW: saying it's asking")
  game("You snap your head up as you break your meditation.")
  w.env.line = "Defence:            Mistral (mistral)"
  svo.defences.custom_fetch_line()
  w.env.line = "Profession:         No"
  svo.defences.custom_fetch_line()
  w.env.line = "Strippable:         Yes"
  svo.defences.custom_fetch_line()
  eq(screens("mistral"), 0, "DEFENCE SHOW: nothing is echoed onto the gagged reply")
  w.run_timers()
  svo.deleteLineP = deleteLineP
  eq(table.concat(gagged, "|"), "Defence:            Mistral (mistral)|Profession:         No|Strippable:         Yes",
    "DEFENCE SHOW: every line of the reply is gagged, and nothing before it")
  eq(screens("mistral"), 1, "DEFENCE SHOW: and the screen shows once it's gone, once")

  -- its links: white, red for taking something out, green for putting it
  -- into play
  local colour, coloured = nil, {}
  local setFgColor, echoLink = w.env.setFgColor, w.env.echoLink
  w.env.setFgColor = function (r, g, b) colour = table.concat({ r, g, b }, ",") end
  w.env.echoLink = function (text, ...) coloured[text] = colour return echoLink(text, ...) end
  cmd("mistral got With a great rushing sound, you become mistral.")
  w.env.setFgColor, w.env.echoLink = setFgColor, echoLink
  eq(coloured.change, "255,255,255", "links: white")
  eq(coloured.x, "255,99,71", "links: x red")
  eq(coloured.delete, "255,99,71", "links: delete red")
  eq(coloured.install, "0,204,0", "links: install green")
end

-- An element's lord and lady are one class: svof gives both the same
-- skillset (the user, 2026-10-14)
do
  local w = world.new({ class = "Fire Elemental Lady" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function game(text) w.env.line = text svo.defences.custom_fetch_line() w.run_timers() end
  cmd("blaze")
  game("Defence:            Blaze (blaze)")
  game("Profession:         Yes")
  game("Strippable:         Yes")
  local d = svo.defences.custom_drafts.blaze or {}
  eq(d.class, "fire elemental", "elementals: a definition is the element's")
  local fire, lady = 0, false
  for _, l in ipairs(w.links) do
    if l:find("custom_set(\"blaze\", 'class', \"fire elemental\")", 1, true) then fire = fire + 1 end
    if l:find("elemental lady", 1, true) or l:find("elemental lord", 1, true) then lady = true end
  end
  eq(fire, 1, "elementals: the class question offers the element once")
  eq(lady, false, "elementals: and no lord or lady apart")
  cmd("blaze class Water Elemental Lord")
  eq(d.class, "water elemental", "elementals: a lord typed is the element")
  cmd("blaze class fire elemental")
  cmd("blaze skillset ignition")
  cmd("blaze command blaze")
  cmd("blaze install")
  eq(svo.defs_data.blaze ~= nil, true, "elementals: installed as a lady")
  svo.classchange("Fire Elemental Lord")
  eq(svo.defs_data.blaze ~= nil, true, "elementals: and in use as a lord")
  svo.classchange("Water Elemental Lady")
  eq(svo.defs_data.blaze, nil, "elementals: but not another element")
end

-- DEFENCE LIST names every defence the game reports, a page at a time, and
-- vcustomdef game shows the ones Svof doesn't track
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function game(text) w.env.line = text svo.defences.custom_gamelist_line() w.run_timers() end
  local function prompt()
    w.env.isPrompt = function() return true end
    game("9975h, 6252m, 21982e, 9637w cexkdb[disl]-")
    w.env.isPrompt = function() return false end
  end
  svo.defences.custom.avoid = { class = "all", command = "avoid", gmcp = "avoid", on = { "x" } }

  cmd("game")
  eq(w.sent[#w.sent], "defence list", "DEFENCE LIST: vcustomdef game asks for it")
  game("You snap your head up as you break your meditation.")
  game("All defences")
  game("------------------------------------------------")
  game("Accursedresolve")
  game("Aiming")
  game("Agithtailegend")
  game("Alertness")
  game("[Type MORE if you wish to continue reading. (8% shown)]")
  eq(w.sent[#w.sent], "more", "DEFENCE LIST: each page asks for the next")
  prompt() -- the page's own prompt
  game("Arcaneshield")
  game("Avoid")
  prompt()
  eq(echoed(w, "Of the 6 defences the game lists, Svof doesn't know these 2. Click one to define it:"), true,
    "DEFENCE LIST: the defences Svof doesn't know are listed, all pages read")
  local unknown = {}
  for _, l in ipairs(w.links) do
    local name = l:match('^(%a+) svo%.defences%.custom_show%("%a+"%)$')
    if name then unknown[#unknown + 1] = name end
  end
  eq(table.concat(unknown, ", "), "agithtailegend, arcaneshield, aiming",
    "DEFENCE LIST: each a link, the one you defined left out, and aiming apart as one Svof leaves alone")
  eq(echoed(w, "Svof knows these, but leaves them alone:"), true, "DEFENCE LIST: which is said")

  -- clicking one starts a definition, which asks the game about it
  w.run('svo.defences.custom_show("agithtailegend")')
  eq(w.sent[#w.sent], "defence show agithtailegend", "DEFENCE LIST: clicking one starts it, asking DEFENCE SHOW")

  -- the last page ends with MORE, and MORE past the end gets the game's
  -- whisper (the user, 2026-10-10), which ends the list at once, whole
  cmd("game")
  game("All defences")
  game("Shimmering")
  game("[Type MORE if you wish to continue reading. (100% shown)]")
  local mores = #w.sent
  prompt()
  game('An unseen presence whispers in your ear, "There is no more, friend."')
  eq(echoed(w, "Of the 1 defences the game lists, Svof doesn't know these 1."), true,
    "DEFENCE LIST: the game saying there's no more ends the list at once")
  eq(svo.defences.game_defences and svo.defences.game_defences.complete, true, "DEFENCE LIST: as the whole list")
  prompt()
  eq(#w.sent, mores, "DEFENCE LIST: and no more MOREs are sent")

  -- no list at all
  cmd("game")
  w.advance(20)
  eq(echoed(w, "The game didn't send its list of defences."), true, "DEFENCE LIST: says when nothing came")
  w.advance(120) -- and it never comes, so svof stops waiting for its page

  -- the whole list is gagged, with the prompts between and after its pages
  -- (svo.deleteLineP), and the "[File continued via MORE]" that starts
  -- every page after the first (the user's screenshot, 2026-10-14)
  local gagged = {}
  local deleteLineP = svo.deleteLineP
  svo.deleteLineP = function () gagged[#gagged + 1] = w.env.line end
  local send, echoes_command = w.env.send, nil
  w.env.send = function (c, e) echoes_command = e return send(c, e) end
  cmd("game")
  w.env.send = send
  game("All defences")
  game("------------------------------------------------")
  game("Accursedresolve")
  game("[Type MORE if you wish to continue reading. (50% shown)]")
  prompt()
  game("[File continued via MORE]")
  game("Arcaneshield")
  local before = #w.echoes
  w.env.isPrompt = function() return true end
  w.env.line = "9975h, 6252m, 21982e, 9637w cexkdb[disl]-"
  svo.defences.custom_gamelist_line()
  w.env.isPrompt = function() return false end
  svo.deleteLineP = deleteLineP
  eq(table.concat(gagged, "|"), "All defences|------------------------------------------------|Accursedresolve|"
    .. "[Type MORE if you wish to continue reading. (50% shown)]|[File continued via MORE]|Arcaneshield",
    "DEFENCE LIST: every line of it is gagged with the prompt after it, MORE's continuation line too")
  eq(#w.echoes, before, "DEFENCE LIST: and nothing is echoed onto the last, gagged prompt")
  w.run_timers()
  eq(echoed(w, "Of the 2 defences the game lists"), true, "DEFENCE LIST: the list follows once it's gone")
  eq(echoes_command, false, "DEFENCE LIST: the command isn't echoed, as svof says it's asking")
end

-- Under lag a reply comes late, and can't fill the wrong definition. The
-- game answers DEFENCE SHOWs in the order asked, and a fetch takes only a
-- reply about what it asked (live, 2026-10-18: the game lagged 60 to 90
-- seconds, and arcaneshield's reply, timed out, filled moontest; the
-- replies here are that session's)
do
  local w = world.new({ class = "Magi" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function game(text) w.env.line = text svo.defences.custom_fetch_line() w.run_timers() end
  local function prompt()
    w.env.isPrompt = function() return true end
    game("4926h, 5909m, 14083e, 17586w exdb-")
    w.env.isPrompt = function() return false end
  end
  local function listening()
    for _, t in ipairs(w.triggers) do
      if not t.killed and t.code == "svo.defences.custom_fetch_line()" then return true end
    end
    return false
  end
  local gagged = {}
  svo.deleteLineP = function () gagged[#gagged + 1] = w.env.line end
  local function was_gagged(text)
    for _, g in ipairs(gagged) do if g == text then return true end end
    return false
  end
  local function fills(name)
    local n = 0
    for _, e in ipairs(w.echoes) do
      if e:find("Filled in " .. name .. " from", 1, true) then n = n + 1 end
    end
    return n
  end

  cmd("arcaneshield")
  w.advance(10)
  eq(echoed(w, "The game didn't answer about a defence called arcaneshield"), true,
    "late replies: the fetch for arcaneshield times out")
  cmd("moontest")
  w.advance(10)
  svo.sk.gmcp_defs_seen.moontattoo = true
  cmd("moontest gmcp moontattoo")
  eq(w.sent[#w.sent], "defence show moontattoo", "late replies: moontest asks about moontattoo")
  local d = svo.defences.custom_drafts.moontest or { on = {}, off = {} }
  -- the game catches up: arcaneshield's reply, moontest's, then moontattoo's
  game("Defence:            Arcaneshield (arcaneshield)")
  game("Description:        This shield will deflect incoming meteors to strike another in your location, if")
  game("possible.")
  game("DefMsg:             You are surrounded by an arcane shield.")
  game("EnactMsg:           With a crackle an arcane shield snaps into being surrounding you.")
  game("FadeMsg:            The arcane shield surrounding you flickers and fades.")
  game("Profession:         No")
  game("Strippable:         No")
  prompt()
  eq(#d.on, 0, "late replies: arcaneshield's reply doesn't fill moontest")
  eq(was_gagged("Defence:            Arcaneshield (arcaneshield)") and was_gagged("possible.")
    and was_gagged("Strippable:         No"), true, "late replies: it's gagged, every line")
  local a = svo.defences.custom_drafts.arcaneshield or {}
  eq(a.on and #a.on, 0, "late replies: and fills nothing, its own draft either")
  game("There is no such defence.")
  prompt()
  eq(was_gagged("There is no such defence."), true, "late replies: moontest's own late answer is gagged")
  eq(echoed(w, "The game has no defence called moontattoo"), false, "late replies: and isn't taken as moontattoo's")
  eq(svo.defences.gmcp_unknown.moontattoo, nil, "late replies: which isn't marked unknown")
  eq(svo.defences.gmcp_unknown.moontest, nil, "late replies: and a late answer marks nothing")
  eq(listening(), true, "late replies: the fetch still waits for its own reply")
  game("Defence:            Moontattoo (moontattoo)")
  game("Description:        This tattoo will passively regenerate your mana.")
  game("DefMsg:             Illuminated by the light of the moon.")
  game("EnactMsg:           The light of the moon illuminates you.")
  game("FadeMsg:            The moonlight fades, leaving an aching absence in her wake.")
  game("Profession:         No")
  game("Strippable:         No")
  prompt()
  eq(d.on[1], "The light of the moon illuminates you.", "late replies: moontest takes moontattoo's reply")
  eq(#d.on == 1 and #d.off == 1 and d.def, "Illuminated by the light of the moon.",
    "late replies: and only its lines")
  eq(fills("moontest"), 1, "late replies: filled once")
  eq(echoed(w, "Filled in moontest from the game's DEFENCE SHOW moontattoo."), true, "late replies: from moontattoo")
  eq(listening(), false, "late replies: every ask answered, svof stops reading lines")

  -- the player's own DEFENCE SHOW, while svof waits on its own
  cmd("veil")
  local before = #gagged
  game("Defence:            Rebounding (rebounding)")
  game("EnactMsg:           You smoke and feel an aura of protection.")
  game("Strippable:         Yes")
  prompt()
  eq(#gagged, before, "late replies: a DEFENCE SHOW svof didn't send is left alone, not gagged")
  local v = svo.defences.custom_drafts.veil or { on = {} }
  eq(#v.on, 0, "late replies: and fills nothing")
  eq(svo.defences.fetch_pending("veil"), true, "late replies: as veil's fetch still waits")

  -- an earlier ask's "There is no such defence." doesn't refuse a GMCP name
  -- asked about since
  cmd("veil gmcp veiled")
  eq(w.sent[#w.sent], "defence show veiled", "late replies: veil asks about veiled")
  game("There is no such defence.") -- veil's own, asked first
  prompt()
  eq(echoed(w, "The game has no defence called veiled over GMCP"), false,
    "late replies: an earlier ask's no such defence doesn't refuse a GMCP name")
  eq(svo.defences.gmcp_unknown.veiled, nil, "late replies: or mark it unknown")
  game("Defence:            Veiled (veiled)")
  game("Strippable:         Yes")
  eq(v.gmcp, "veiled", "late replies: its own answer sets it")

  -- asked again under lag: the first ask's answer is about the same, and
  -- fills it; the second's own is then late
  cmd("mistral")
  w.advance(10)
  cmd("mistral fetch")
  eq(w.sent[#w.sent], "defence show mistral", "late replies: mistral asked again")
  game("Defence:            Mistral (mistral)")
  game("EnactMsg:           With a great rushing sound, you become mistral.")
  game("Strippable:         Yes")
  prompt()
  local m = svo.defences.custom_drafts.mistral or { on = {} }
  eq(m.on[1], "With a great rushing sound, you become mistral.",
    "late replies: asked again, the first ask's answer fills it")
  before = #gagged
  game("Defence:            Mistral (mistral)")
  game("EnactMsg:           With a great rushing sound, you become mistral.")
  game("Strippable:         Yes")
  prompt()
  eq(#gagged - before, 3, "late replies: and the second's own is gagged")
  eq(fills("mistral"), 1, "late replies: filling it once")
  eq(listening(), false, "late replies: then svof stops reading lines")

  -- the game's spelling: a name in words, and the start of a name
  cmd("tremor")
  eq(w.sent[#w.sent], "defence show tremor", "spelling: a new definition asks by its name")
  game("Defence:            Tremor sense (tremorsense)")
  game("EnactMsg:           You attune yourself to the tremors of the earth.")
  game("Strippable:         Yes")
  eq(fills("tremor"), 1, "spelling: a reply for a name starting with the one asked fills it")
  local t = svo.defences.custom_drafts.tremor or {}
  eq(t.gmcp, "tremorsense", "spelling: its GMCP name the game's")
  cmd("tremor fetch tremor sense")
  game("Defence:            Tremor sense (tremorsense)")
  game("Strippable:         Yes")
  eq(fills("tremor"), 2, "spelling: asked by the game's name for it, in words")
  cmd("tremor fetch tremorsense")
  before = #gagged
  game("Defence:            Tremors (tremors)")
  game("Strippable:         Yes")
  eq(#gagged == before and fills("tremor") == 2, true, "spelling: a reply about another defence isn't taken")
  game("Defence:            Tremor sense (tremorsense)")
  game("Strippable:         Yes")
  eq(fills("tremor"), 3, "spelling: the one about it is")
  cmd("tremor fetch tremors")
  game("Defence:            Tremor sense (tremorsense)")
  game("Strippable:         Yes")
  eq(fills("tremor"), 4, "spelling: and asked by the start of its GMCP name, not of its name in words")

  -- an ask whose answer svof didn't know: a reply about a later ask shows
  -- it won't come, so a later "There is no such defence." isn't taken as
  -- its
  cmd("ward")
  w.advance(10)
  cmd("bulwark")
  game("Defence:            Bulwark (bulwark)")
  game("Strippable:         Yes")
  eq(fills("bulwark"), 1, "late replies: a reply about a later ask is taken")
  cmd("rampart")
  game("There is no such defence.")
  eq(echoed(w, "The game has no defence called rampart, so add its lines yourself."), true,
    "late replies: and an earlier ask it passed isn't waited for")

  -- an answer after svof stopped waiting is gagged, and fills nothing; two
  -- minutes on, svof stops reading lines, and leaves one alone
  cmd("aura")
  w.advance(10)
  before = #gagged
  game("Defence:            Aura (aura)")
  game("EnactMsg:           An aura surrounds you.")
  game("Strippable:         Yes")
  eq(#gagged - before, 3, "late replies: an answer once svof stopped waiting is gagged")
  local au = svo.defences.custom_drafts.aura or { on = {} }
  eq(#au.on, 0, "late replies: and fills nothing")
  eq(listening(), false, "late replies: then svof stops reading lines")
  -- a late reply cut short by the prompt ends there
  cmd("glow")
  w.advance(10)
  game("Defence:            Glow (glow)")
  game("EnactMsg:           You begin to glow.")
  prompt()
  before = #gagged
  game("You glow brightly.")
  eq(#gagged, before, "late replies: one cut short ends at the prompt, gagging nothing after")
  cmd("halo")
  w.advance(10)
  eq(listening(), true, "late replies: waiting for halo's late answer")
  w.advance(120)
  eq(listening(), false, "late replies: for two minutes")
  before = #gagged
  game("Defence:            Halo (halo)")
  game("Strippable:         Yes")
  eq(#gagged, before, "late replies: after which svof leaves it alone")
end

-- A DEFENCE LIST that ends waiting too long for a page leaves the game a
-- page to send, which comes late under lag and is gagged then (live,
-- 2026-10-18: the rest of a list showed on screen a minute later)
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function game(text) w.env.line = text svo.defences.custom_gamelist_line() w.run_timers() end
  local function prompt()
    w.env.isPrompt = function() return true end
    game("9975h, 6252m, 21982e, 9637w cexkdb[disl]-")
    w.env.isPrompt = function() return false end
  end
  local function listening()
    for _, t in ipairs(w.triggers) do
      if not t.killed and t.code == "svo.defences.custom_gamelist_line()" then return true end
    end
    return false
  end
  local gagged = {}
  svo.deleteLineP = function () gagged[#gagged + 1] = w.env.line end
  local function names() return svo.defences.game_defences and svo.defences.game_defences.names or {} end

  -- the next page doesn't come in time
  cmd("game")
  game("All defences")
  game("------------------------------------------------")
  game("Accursedresolve")
  game("Arcaneshield")
  game("[Type MORE if you wish to continue reading. (8% shown)]")
  prompt()
  local sent = #w.sent
  w.advance(10)
  eq(echoed(w, "Of the 2 defences the game lists"), true, "late pages: the list ends with what came")
  eq(svo.defences.game_defences.complete, false, "late pages: as part of the list")
  eq(listening(), true, "late pages: and reads on for the page the game owes")
  local before = #gagged
  game("A bird flies past.")
  game("[File continued via MORE]")
  game("Firstaid")
  game("Fleetness")
  game("[Type MORE if you wish to continue reading. (43% shown)]")
  prompt()
  eq(#gagged - before, 4, "late pages: the page comes late and is gagged, and nothing before it")
  eq(#w.sent, sent, "late pages: with no MORE sent for it")
  eq(names().firstaid, nil, "late pages: nor its names kept")
  eq(listening(), false, "late pages: then svof stops reading lines")
  before = #gagged
  game("[File continued via MORE]")
  eq(#gagged, before, "late pages: and gags nothing more")

  -- no page in time, and asked again: the first page owed answers it
  cmd("game")
  sent = #w.sent
  w.advance(10)
  eq(echoed(w, "The game didn't send its list of defences."), true, "late pages: no page came")
  cmd("game")
  eq(#w.sent, sent, "late pages: asked again, svof waits for the first page owed rather than ask twice")
  game("All defences")
  game("Accursedresolve")
  game("Arcaneshield")
  game("Avoid")
  prompt()
  eq(names().avoid and svo.defences.game_defences.complete, true, "late pages: which is the list asked for")

  -- asked again while the first page owed is coming: that page is gagged
  -- to its end, and the new list asks for its own
  cmd("game")
  w.advance(10)
  before = #gagged
  game("All defences")
  cmd("game")
  eq(w.sent[#w.sent], "defence list", "late pages: asked again once the page owed has started, svof asks")
  game("Accursedresolve")
  prompt()
  eq(#gagged - before, 2, "late pages: and the rest of the page owed is gagged")
  game("All defences")
  game("Aiming")
  prompt()
  eq(names().aiming == true and names().accursedresolve == nil, true, "late pages: the new list reads its own")

  -- a first page late, with no list asked since, is gagged too
  cmd("game")
  w.advance(10)
  before = #gagged
  sent = #w.sent
  game("All defences")
  game("------------------------------------------------")
  game("Accursedresolve")
  game("[Type MORE if you wish to continue reading. (8% shown)]")
  prompt()
  eq(#gagged - before, 4, "late pages: a first page that comes late is gagged")
  eq(#w.sent, sent, "late pages: with no MORE sent")

  -- a page owed that turns out not to be the list's, such as another text
  -- continued by MORE: gagging stops at its first line no page has
  cmd("game")
  game("All defences")
  game("Accursedresolve")
  game("[Type MORE if you wish to continue reading. (50% shown)]")
  prompt()
  w.advance(10)
  before = #gagged
  game("[File continued via MORE]")
  game("Curing is the art of keeping yourself alive.")
  prompt()
  eq(#gagged - before, 1, "late pages: gagging stops at a line no page has")
  eq(listening(), false, "late pages: and svof stops reading lines")

  -- a list asked while a page after MORE is owed: the page comes first,
  -- and is gagged, and the new list reads its own
  cmd("game")
  game("All defences")
  game("Accursedresolve")
  game("[Type MORE if you wish to continue reading. (50% shown)]")
  prompt()
  w.advance(10)
  cmd("game")
  eq(w.sent[#w.sent], "defence list", "late pages: a new list asks for it")
  before = #gagged
  game("[File continued via MORE]")
  game("Firstaid")
  game("[Type MORE if you wish to continue reading. (100% shown)]")
  prompt()
  eq(#gagged - before, 3, "late pages: an earlier list's page comes first, and is gagged")
  eq(w.sent[#w.sent], "defence list", "late pages: with no MORE sent for it")
  game("All defences")
  game("Aiming")
  prompt()
  eq(names().aiming == true and names().firstaid == nil and svo.defences.game_defences.complete, true,
    "late pages: and the new list is its own")

  -- the page owed never comes: the new list's first page shows it won't
  cmd("game")
  game("All defences")
  game("Accursedresolve")
  game("[Type MORE if you wish to continue reading. (50% shown)]")
  prompt()
  w.advance(10)
  cmd("game")
  game("All defences")
  game("Aiming")
  game("[Type MORE if you wish to continue reading. (50% shown)]")
  prompt()
  before = #gagged
  game("[File continued via MORE]")
  game("Arcaneshield")
  prompt()
  eq(#gagged - before, 2, "late pages: once a new list's first page comes, an earlier page owed isn't waited for")
  eq(names().arcaneshield == true and names().aiming == true and svo.defences.game_defences.complete, true,
    "late pages: and the new list reads its next page")

  -- svof waits two minutes for a page owed
  cmd("game")
  w.advance(10)
  eq(listening(), true, "late pages: waiting for the first page owed")
  w.advance(120)
  eq(listening(), false, "late pages: for two minutes")
end

do -- vconfig2 links to the list
  local w = world.new()
  w.svo.config_dict.customdefinitions.onshow('a_grey')
  local found = false
  for _, l in ipairs(w.links) do
    if l:find("svo.defences.customdef_menu()", 1, true) then found = true end
  end
  eq(found, true, "customdef: vconfig2's customdefinitions line links to the list")
end

do -- the phylactery is found whether its name has one space after the "a" or two
  local w = world.new()
  w.env.gmcp.Char.Items.List = { location = "inv", items = { { name = "a phylactery of sixth sense" } } }
  w.svo.defences.checkmindnet()
  eq(type(w.svo.dict.mindnet), "table", "a phylactery named with one space registers mindnet")
end

do -- saying you own an artefact registers its defence straight away
  for _, item in ipairs({ "mindnet", "lifevision", "shroud" }) do
    local w = world.new()
    local svo = w.svo
    svo.config.set("have" .. item, true)
    local registered = {}
    for _, def in ipairs({ "mindnet", "lifevision", "shroud" }) do
      if svo.defs_data[def] then registered[#registered + 1] = def end
    end
    eq(table.concat(registered, ", "), item, "vconfig have" .. item .. " on registers " .. item .. " and nothing else")
  end
end

-- Artefacts can be bought by anyone, so each of the three works for every
-- class: as a general defence, or as the class's own where its skills have
-- one (Necromancy's shroud and lifevision, Occultism's shroud, Shindo's and
-- Telepathy's mindnet). conf.have<item> is saved, and a timer after each
-- systemstart registers them again, so they also come back after a class
-- change, with the old class's triggers killed rather than piling up.
do
  local ITEMS = { "mindnet", "lifevision", "shroud" }
  local function live(w, def)
    local n = 0
    for _, t in ipairs(w.triggers) do
      if not t.killed and type(t.code) == "string" and t.code:find("_" .. def .. "()", 1, true) then n = n + 1 end
    end
    return n
  end
  local function summary(w)
    local out = {}
    for _, def in ipairs(ITEMS) do
      local rec = w.svo.defs_data[def]
      out[#out + 1] = string.format("%s %s %s %d", def, rec and rec.type or "no record",
        type(w.svo.dict[def]) == "table" and "entry" or "no entry", live(w, def))
    end
    return table.concat(out, ", ")
  end
  for _, class in ipairs(CLASSES) do
    local w = world.new({ class = class })
    local svo = w.svo
    svo.conf.havemindnet, svo.conf.havelifevision, svo.conf.haveshroud = true, true, true
    w.run_timers()
    local missing, unset = {}, {}
    for _, def in ipairs(ITEMS) do
      if not (svo.defs_data[def] and type(svo.dict[def]) == "table" and type(svo.defs["got_" .. def]) == "function"
        and type(svo.defs["lost_" .. def]) == "function") then
        missing[#missing + 1] = def
      end
      -- today a Serpent's GMCP shroud is its own cloaking (sstosvod.shroud)
      local set = (class == "Serpent" and def == "shroud") and "cloaking" or def
      svo.defc[set] = false
      w.gmcp_defence_add(def)
      if svo.defc[set] ~= true then unset[#unset + 1] = def end
    end
    eq(table.concat(missing, ", "), "", class .. ": owning the three artefacts registers all three defences")
    eq(table.concat(unset, ", "), "", class .. ": and GMCP sets each of them")
    local first = summary(w)
    local other = class == "Monk" and "Infernal" or "Monk"
    svo.classchange(other)
    w.run_timers()
    svo.classchange(class)
    w.run_timers()
    eq(summary(w), first, class .. ": changing class and back keeps them, with no extra triggers")
  end
end

-- ===== 12. The hide list (vshow hidelist) =====

-- What a player hides is kept through a class change and back. systemstart
-- used to take the skillsets a class doesn't have out of the list, which
-- forgot them (defect 28); the list keeps them, and shows only this class's.
do
  local w = world.new({ class = "Occultist" })
  local svo = w.svo
  local shown = {}
  w.env.decho = function(s) shown[#shown + 1] = tostring(s) end
  svo.ignoreskill("astralform", true)
  svo.ignoreskill("tarot", true)
  svo.classchange("Monk")
  w.run_timers()
  shown = {}
  svo.showhidelist()
  local text = table.concat(shown)
  eq(text:find("Tekura defences", 1, true) ~= nil, true, "hide list: as a Monk, it shows the Monk's groups")
  eq(text:find("Occultism defences", 1, true), nil, "hide list: and not the Occultist's")
  eq(text:find("astralform", 1, true), nil, "hide list: nor the Occultist's defences")
  svo.classchange("Occultist")
  w.run_timers()
  eq(svo.sk.ignored_defences.occultism.t.astralform, true,
    "hide list: a hidden defence is still hidden after changing class and back")
  eq(svo.sk.ignored_defences.tarot.status, true, "hide list: and so is a hidden group")
end

do -- a defence two classes have is hidden in the group this class has it in
  local w = world.new({ class = "Apostate" })
  local svo = w.svo
  local showhidelist = svo.showhidelist
  svo.showhidelist = function() end
  svo.classchange("Infernal")
  w.run_timers()
  svo.classchange("Apostate")
  w.run_timers()
  -- more groups from before holding it, so which one a search of the list
  -- reaches first can't decide this
  for i = 1, 20 do svo.sk.ignored_defences["before" .. i] = { status = false, t = { deathaura = false } } end
  svo.ignoreskill("deathaura", true)
  eq(svo.sk.ignored_defences.necromancy.t.deathaura, true, "hide list: an Apostate hides Necromancy's deathaura")
  local others = 0
  for i = 1, 20 do
    if svo.sk.ignored_defences["before" .. i].t.deathaura then others = others + 1 end
    svo.sk.ignored_defences["before" .. i] = nil
  end
  eq(svo.sk.ignored_defences.oppression and svo.sk.ignored_defences.oppression.t.deathaura or others > 0, false,
    "hide list: not the Infernal's, or any other group's still in the list from before")

  -- deathsight is general for an Infernal and Necromancy's for an Apostate,
  -- and the general group keeps the name from before
  local shown = {}
  w.env.decho = function(s) shown[#shown + 1] = tostring(s) end
  -- each defence is a link now, to hide or show it
  w.env.dechoLink = function(s) shown[#shown + 1] = tostring(s) end
  showhidelist()
  local text = table.concat(shown)
  local general = text:match("General defences:(.-) defences:") or ""
  eq(general:find("deathsight", 1, true), nil, "hide list: an Apostate's deathsight isn't listed as general")
  eq((text:match("Necromancy defences:(.-) defences:") or text:match("Necromancy defences:(.*)") or ""):find("deathsight", 1, true) ~= nil,
    true, "hide list: it's listed under Necromancy")
end

-- Hiding a defence takes it off defup and keepup in every mode, as svof
-- doesn't raise what the lists don't show, and vconfig showhiddendefs
-- lists hidden ones anyway (the user's choices, 2026-10-10)
do
  local w = world.new({ class = "Occultist" })
  local svo = w.svo
  svo.showprompt = function() end
  if not svo.defdefup.combat then svo.create_defmode("combat") end
  local function listed(f, def)
    local from = #w.links
    f()
    for i = from + 1, #w.links do
      if w.links[i]:find("] " .. def .. " ", 1, true) or w.links[i]:find("] " .. def .. "$") then return true end
    end
    return false
  end

  svo.defs.defup("astralform", true, "basic")
  svo.defs.keepup("astralform", true, "basic")
  svo.defs.keepup("astralform", true, "combat")
  svo.ignoreskill("astralform", true)
  eq(svo.defdefup.basic.astralform or svo.defkeepup.basic.astralform or svo.defkeepup.combat.astralform, false,
    "hiding: takes a defence off defup and keepup in every mode")
  eq(echoed(w, "Took astralform (basic defup, basic keepup, combat keepup) off, so Svof doesn't raise what it hides."),
    true, "hiding: and says where from")
  local undo
  for _, l in ipairs(w.links) do
    if l:sub(1, 7) == "(undo) " then undo = l:sub(8) end
  end
  eq(undo ~= nil, true, "hiding: with a link to undo it")
  if undo then w.run(undo) end
  eq(svo.sk.ignored_defences.occultism.t.astralform, false, "hiding: undo shows it again")
  eq(svo.defdefup.basic.astralform and svo.defkeepup.basic.astralform and svo.defkeepup.combat.astralform, true,
    "hiding: and puts it back where it was")

  svo.defs.keepup("devil", true, "basic")
  svo.ignoreskill("tarot", true)
  eq(svo.defkeepup.basic.devil, false, "hiding: a group takes its defences off")
  svo.ignoreskill("tarot", false)
  eq(svo.defkeepup.basic.devil, false, "hiding: showing it again doesn't put them back")

  -- the lists
  svo.ignoreskill("astralform", true)
  eq(listed(svo.show_defup, "astralform"), false, "hiding: vshow defup leaves it out")
  svo.defs.defup("astralform", true, nil, true)
  eq(echoed(w, "astralform is hidden in your defence lists, so vshow defup won't show it"), true,
    "hiding: putting a hidden one on defup says it's hidden")
  svo.defs.keepup("astralform", true, nil, true)
  eq(echoed(w, "astralform is hidden in your defence lists, so vshow keepup won't show it"), true,
    "hiding: and on keepup")
  svo.config.set("showhiddendefs", true)
  eq(listed(svo.show_defup, "astralform"), true, "showhiddendefs: lists a hidden defence anyway")
  svo.ignoreskill("tarot", true)
  svo.show_defup()
  eq(echoed(w, "Tarot defences (hidden):"), true, "showhiddendefs: and a hidden group, saying so")
  svo.config.set("showhiddendefs", false)
  svo.ignoreskill("tarot", false)
  svo.ignoreskill("astralform", false)

  -- the general group hides the main list
  eq(listed(svo.show_defup, "rebounding"), true, "hiding: the main list has rebounding")
  svo.ignoreskill("general", true)
  eq(listed(svo.show_defup, "rebounding"), false, "hiding: hiding the general group hides the main list")
  svo.ignoreskill("general", false)

  local from = #w.links
  svo.showhidelist()
  local link = false
  for i = from + 1, #w.links do
    if w.links[i]:find("svo.config.set('showhiddendefs', true, true)", 1, true) then link = true end
  end
  eq(link, true, "hide list: links to vconfig showhiddendefs")
end

-- Each skillset and defence in the hide list is a link to hide it or show
-- it again, the list says the commands that do the same, and with all it
-- has every class's skillsets, to hide another class's (the user's ask,
-- 2026-10-16)
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  svo.showprompt = function() end
  local function link_to(text)
    for i = #w.links, 1, -1 do
      -- (a defence's link text carries its colour)
      local l = w.links[i]:gsub("<%d+,%d+,%d+>", "")
      if l:sub(1, #text + 1) == text .. " " then return l:sub(#text + 2) end
    end
  end

  svo.showhidelist()
  eq(link_to("bear"), 'svo.defences.hide_click("tekura", "bear", true, false)', "hide list: a defence is a link to hide it")
  eq(link_to("hide them"), 'svo.defences.hide_click("dragoncraft", nil, true, false)', "hide list: a skillset has a link to hide it")
  eq(echoed(w, "Or type vshow hide <skillset or defence> to hide one, and vshow unhide <skillset or defence> to show it again."),
    true, "hide list: it says the commands")
  eq(link_to("show every class's skillsets"), "svo.showhidelist(true)", "hide list: and links to every class's")
  eq(echoed(w, "  " .. string.rep("-", 70)), true, "hide list: a line between the list and the rest")
  eq(link_to("acrobatics"), nil, "hide list: only this class's, without all")

  local before = #w.links
  if link_to("bear") then w.run(link_to("bear")) end
  eq(svo.sk.ignored_defences.tekura.t.bear, true, "hide list: clicking a defence hides it")
  eq(#w.links > before and link_to("bear"), 'svo.defences.hide_click("tekura", "bear", false, false)',
    "hide list: and shows the list again, with a link to show it")
  if link_to("bear") then w.run(link_to("bear")) end
  eq(svo.sk.ignored_defences.tekura.t.bear, false, "hide list: which shows it again")

  svo.showhidelist(true)
  eq(echoed(w, "Swashbuckling (Bard) defences:") and echoed(w, "Pranks (Jester) defences:"), true,
    "hide list: all lists every class's skillsets, saying whose")
  eq(link_to("show only Monk's skillsets"), "svo.showhidelist()", "hide list: with a link back to this class's")
  local hide
  for i = #w.links, 1, -1 do
    if w.links[i]:find('hide_click("pranks", "acrobatics", true, true)', 1, true) then hide = w.links[i]:match(" (svo%..*)$") end
  end
  eq(hide ~= nil, true, "hide list: another class's defence is a link to hide it")
  if hide then w.run(hide) end
  eq(svo.sk.ignored_defences.pranks and svo.sk.ignored_defences.pranks.t.acrobatics, true,
    "hide list: which hides it in that class's skillset")
  eq(svo.sk.ignored_defences.swashbuckling == nil or not svo.sk.ignored_defences.swashbuckling.t.acrobatics, true,
    "hide list: and only that one")
  svo.classchange("Jester")
  w.run_timers()
  eq(svo.defences.hidden("acrobatics"), true, "hide list: it's hidden once you're that class")
  svo.classchange("Monk")
  w.run_timers()

  -- the command line, through the alias as Mudlet runs it
  local dir = "src/aliases/svo (aliases, triggers)/svo/"
  local fh = io.open(dir .. "aliases.json", "r")
  local items = fh and fh:read("*a") or ""
  if fh then fh:close() end
  local at = items:find('"name": "Show hidelist"', 1, true)
  local item = at and items:sub(at, (items:find("}", at, true) or #items))
  eq(item and item:match('"regex": "([^"]*)"'), "^vshow ?(h|hidelist|hide|unhide)(?: (.+))?$",
    "hide command: the hidelist alias takes hide and unhide too")
  fh = io.open(dir .. "Show_hidelist.lua", "r")
  local script = fh and fh:read("*a") or ""
  if fh then fh:close() end
  -- (the alias redraws the prompt, which the world has no buffer for)
  w.env.appendBuffer = w.env.appendBuffer or function () end
  local function vshow(verb, rest)
    w.env.matches = { "vshow " .. verb .. (rest and (" " .. rest) or ""), verb, rest }
    w.run(script, "vshow")
  end
  vshow("hide", "Tekura")
  eq(svo.sk.ignored_defences.tekura.status, true, "hide command: vshow hide <skillset> hides it")
  eq(echoed(w, "Hid tekura, the whole skillset, from the defence lists."), true, "hide command: and says so")
  vshow("unhide", "tekura")
  eq(svo.sk.ignored_defences.tekura.status, false, "hide command: vshow unhide shows it again")
  vshow("hide", "kaiboost")
  eq(svo.sk.ignored_defences.kaido.t.kaiboost, true, "hide command: vshow hide <defence> hides it in this class's skillset")
  eq(echoed(w, "Hid kaiboost, in kaido, from the defence lists."), true, "hide command: saying where")
  vshow("unhide", "kaiboost")
  eq(svo.sk.ignored_defences.kaido.t.kaiboost, false, "hide command: and unhide shows it")
  vshow("hide", "acrobatics")
  eq(svo.sk.ignored_defences.pranks.t.acrobatics and svo.sk.ignored_defences.swashbuckling.t.acrobatics, true,
    "hide command: another class's defence is hidden in every skillset it's in")
  vshow("hide", "nosuchthing")
  eq(echoed(w, "Svof doesn't know a skillset or defence called nosuchthing."), true, "hide command: an unknown name says so")
  vshow("hide")
  eq(echoed(w, "vshow hide takes a skillset or a defence"), true, "hide command: no name says what it takes")
  local shown = 0
  local showhidelist = svo.showhidelist
  svo.showhidelist = function (all) shown = shown + (all and 10 or 1) end
  vshow("hidelist", "all")
  vshow("h")
  svo.showhidelist = showhidelist
  eq(shown, 11, "hide command: vshow hidelist all and vshow h still list them")

  -- vcustomdef svof and vshow link to it
  svo.defences.own_list()
  eq(link_to("hide defences"), "svo.showhidelist()", "hide list: vcustomdef svof links to it")
  svo.defences.own_list(true)
  eq(link_to("hide defences"), "svo.showhidelist(true)", "hide list: and vcustomdef svof all to every class's")
  svo.ashow()
  eq(link_to("vshow hidelist"), "svo.showhidelist()", "hide list: vshow links to it")
  eq(echoed(w, "Hidden from the defence lists: 0 skillsets, 2 defences"), true, "hide list: vshow says how many are hidden")
end

do -- the groups come in the class's order: Lua 5.1's pairs() gave a Monk
  -- Kaido, Shikudo, Telepathy, Tekura
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local text = {}
  w.env.decho = function(s) text[#text + 1] = tostring(s) end
  local echof = svo.echof
  svo.echof = function(fmt, ...) text[#text + 1] = string.format(fmt, ...) .. "\n" end
  svo.showprompt = function() end
  local function headings(s, pattern)
    local found = {}
    for name in s:gmatch(pattern) do found[#found + 1] = name end
    return table.concat(found, ", ")
  end
  svo.show_defup()
  eq(headings(table.concat(text), "(%a+) defences:"), "Tekura, Kaido, Telepathy, Shikudo",
    "defence lists: a Monk's skillsets in the order svof lists the class")
  text = {}
  svo.showhidelist()
  eq(headings(table.concat(text), "(%a+) defences:"), "General, Tekura, Kaido, Telepathy, Shikudo, Dragoncraft",
    "hide list: general first, then the class's skillsets, then the rest")
  svo.echof = echof
end

-- ===== 13. Changes to svof's own defences (vcustomdef <svof's name>) =====

-- For a defence the game changed before svof caught up, a player can
-- change svof's own (the user's ask, 2026-10-10): its exact lines and GMCP
-- name, and the command of one basicdef made. A change replaces svof's
-- version, is saved apart from definitions, and is put back by reset.
do
  local w = world.new({ class = "Occultist" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function live(def)
    local n = 0
    for _, t in ipairs(w.triggers) do
      if not t.killed and type(t.code) == "string" and t.code:find("_" .. def .. "()", 1, true) then n = n + 1 end
    end
    return n
  end
  local function link(text)
    for i = #w.links, 1, -1 do
      if w.links[i]:sub(1, #text + 1) == text .. " " then return w.links[i]:sub(#text + 2) end
    end
  end
  local phys = svo.dict.alertness.physical
  local svofs_triggers = live("alertness")

  cmd("alertness")
  eq(echoed(w, "alertness, Svof's own defence:"), true, "changes: vcustomdef with svof's own name shows svof's own")
  eq(echoed(w, "A change replaces Svof's version, and Svof's updates to alertness don't reach you while it's in use."),
    true, "changes: and what a change does")
  eq(row_echoed(w, string.rep("-", 70), "  Actions:"), true, "changes: its links come under a line, labelled Actions")
  local d = svo.defences.edit_drafts.alertness or { on = {} }
  eq(#d.on, 3, "changes: the change starts from svof's own lines")

  cmd("alertness command alertness up")
  cmd("alertness got You perk up your ears.")
  svo.sk.gmcp_defs_seen.alert = true -- as if GMCP had sent the name
  cmd("alertness gmcp alert")
  cmd("alertness install")
  eq(echoed(w, "Changing Svof's own alertness replaces Svof's version of it, and Svof's updates to alertness won't reach you until you reset it."),
    true, "changes: the first install warns what it does")
  eq(phys.action, "alertness on", "changes: and changes nothing until it's confirmed")
  local writes = #w.writes
  if link("(change it)") then w.run(link("(change it)")) end
  eq(phys.action, "alertness up", "changes: confirmed, svof raises it with the new command")
  eq(svo.sys.input_to_actions["alertness up"], phys, "changes: and takes that command for its own when it's typed")
  eq(svo.sys.input_to_actions["alertness on"], nil, "changes: and not the old one")
  eq(svo.dict.sstosvod.alert, "alertness", "changes: GMCP's alert is alertness")
  eq(svo.dict.sstosvod.alertness, nil, "changes: and GMCP's alertness no longer is")
  eq(svo.dict.alertness.gamename, "alert", "changes: serverside knows it by the new GMCP name too")
  eq(#w.writes > writes, true, "changes: the change is saved")
  local saved = svo.defences.edits.all and svo.defences.edits.all.alertness or {}
  eq(saved.command, "alertness up", "changes: saved as every class's, as alertness is general")
  eq(saved.was and saved.was.command, "alertness on", "changes: with svof's own command when it was changed")
  eq(saved.off, nil, "changes: and only what differs from svof's own")

  svo.doaction(phys)
  eq(w.line("You perk up your ears."), 1, "changes: the new gain line is heard")
  w.prompt()
  eq(svo.defc.alertness, true, "changes: and sets it")
  svo.defc.alertness = false
  w.gmcp_defence_add("alert")
  eq(svo.defc.alertness, true, "changes: GMCP's new name sets it")
  eq(live("alertness"), svofs_triggers + 1, "changes: svof's triggers made again, not piled up")

  -- a line taken out goes, and the change replaces svof's lines
  svo.defences.custom_unset("alertness", "on", 1)
  cmd("alertness install")
  eq(w.line("You prick up your ears."), 0, "changes: svof's line taken out of the change is no longer heard")
  eq(w.line("Alertness is already on!"), 1, "changes: the ones kept still are")
  eq(echoed(w, "Changed Svof's own alertness."), true, "changes: installing again doesn't ask again")

  -- svof's own logic stays, and the screen says what
  cmd("rebounding command rebound")
  eq(echoed(w, "Can't change rebounding's command: Svof raises it with smoke, so it has no command to change."), true,
    "changes: a defence svof raises another way keeps its command")
  cmd("rebounding")
  eq(row_echoed(w, "or matches:", svo.defs_data.rebounding.offr[1]), true,
    "changes: the screen shows svof's patterns, which a change can change (section 19)")
  eq(echoed(w, "the wait for it after its command"), true, "changes: and its wait")
  cmd("riding")
  eq(echoed(w, "Svof's action for it is written by hand, so a change can't replace its command"), true,
    "changes: riding's action is written by hand, so its command stays")
  eq(echoed(w, "its own handling of its lines"), true, "changes: and its loss lines have a handler of their own")
  cmd("alertness class all")
  eq(echoed(w, "Svof's own alertness keeps its class and balance."), true, "changes: the class stays svof's")
  cmd("alertness gmcp rebounding")
  eq(echoed(w, "Can't give alertness the GMCP name rebounding: GMCP's rebounding is Svof's rebounding."), true,
    "changes: a GMCP name another of svof's defences has is refused")
  cmd("treewatch")
  cmd("treewatch install")
  eq(echoed(w, "That's the same as Svof's own treewatch, so there's nothing to change."), true,
    "changes: one the same as svof's own changes nothing")

  -- a class's defence is the class's change
  cmd("astralform got You become a being of light.")
  cmd("astralform install")
  if link("(change it)") then w.run(link("(change it)")) end
  eq(svo.defences.edits.occultist and svo.defences.edits.occultist.astralform ~= nil, true,
    "changes: astralform, an Occultism defence, is the Occultist's change")

  -- the list
  cmd("")
  eq(echoed(w, "Svof's own defences you changed:"), true, "changes: vcustomdef lists the changes")
  eq(echoed(w, ": every class, in use"), true, "changes: each with whose it is and that it's in use")
  cmd("skywatch got You look to the skies.")
  cmd("")
  eq(echoed(w, ": every class, not installed"), true, "changes: and one not installed yet")
  if link("discard") then w.run(link("discard")) end
  eq(echoed(w, "Threw away your change to skywatch."), true, "changes: which can be thrown away")
  eq(svo.defences.edit_drafts.skywatch, nil, "changes: and is")

  -- the game's own lines for one of svof's, with DEFENCE SHOW
  cmd("kola fetch")
  eq(w.sent[#w.sent], "defence show kola", "changes: fetch asks the game about svof's own")
  local function game(text) w.env.line = text svo.defences.custom_fetch_line() w.run_timers() end
  game("Defence:            Kola (kola)")
  game("DefMsg:             You are feeling extremely energetic.")
  game("EnactMsg:           You feel energy course through you.")
  game("Profession:         No")
  game("Strippable:         Yes")
  local kola = svo.defences.edit_drafts.kola or { on = {} }
  eq(kola.on[1], "You feel energy course through you.", "changes: and adds the game's gain line to the change")
  eq(echoed(w, "isn't a profession defence"), false, "changes: leaving svof's own class alone")
end

do -- a change is put into play as svof loads, and says when svof's own changed since
  local w = world.new({ class = "Occultist" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function link(text)
    for i = #w.links, 1, -1 do
      if w.links[i]:sub(1, #text + 1) == text .. " " then return w.links[i]:sub(#text + 2) end
    end
  end
  cmd("alertness command alertness up")
  w.run('svo.defences.edit_install("alertness", true)')
  cmd("astralform got You become a being of light.")
  w.run('svo.defences.edit_install("astralform", true)')

  svo.classchange("Monk")
  eq(svo.dict.alertness.physical.action, "alertness up", "changes: every class's change is in use in another class")
  eq(echoed(w, "Svof doesn't have astralform any more"), false, "changes: the Occultist's isn't missed as a Monk")
  svo.classchange("Occultist")
  eq(svo.dict.alertness.physical.action, "alertness up", "changes: back as an Occultist, svof loads with the change")
  eq(svo.sys.input_to_actions["alertness up"], svo.dict.alertness.physical, "changes: its command taken for svof's own")
  eq(w.line("You become a being of light."), 1, "changes: and the Occultist's own change too")

  -- svof updated its own since: as if its command was different when changed
  svo.defences.edits.all.alertness.was.command = "alertness please"
  local echoes = #w.echoes
  svo.classchange("Monk")
  eq(echoed(w, "Svof has updated the command of its own alertness since you changed it. Yours is still in use:"),
    true, "changes: svof says when it changed what a change replaces")
  eq(svo.dict.alertness.physical.action, "alertness up", "changes: and keeps using the change")
  if link("keep yours") then w.run(link("keep yours")) end
  eq(svo.defences.edits.all.alertness.was.command, "alertness on", "changes: keep yours notes svof's own as it is now")
  echoes = #w.echoes
  svo.classchange("Occultist")
  local again = false
  for i = echoes + 1, #w.echoes do
    if w.echoes[i]:find("Svof has updated", 1, true) then again = true end
  end
  eq(again, false, "changes: and stops saying so")

  -- a change to one svof doesn't have any more
  svo.defences.edits.all.oldward = { command = "oldward", was = { command = "ward" } }
  svo.classchange("Monk")
  eq(echoed(w, "Svof doesn't have oldward any more, so your change to it isn't used."), true,
    "changes: a change to a defence svof dropped is said")
  if link("(forget it)") then w.run(link("(forget it)")) end
  eq(svo.defences.edits.all.oldward, nil, "changes: and can be deleted")

  -- reset
  svo.classchange("Occultist")
  local triggers = 0
  cmd("alertness reset")
  local phys = svo.dict.alertness.physical
  eq(phys.action, "alertness on", "changes: reset puts svof's own command back")
  eq(svo.sys.input_to_actions["alertness on"], phys, "changes: and takes it for svof's own again")
  eq(svo.sys.input_to_actions["alertness up"], nil, "changes: and not the change's")
  eq(svo.defences.edits.all, nil, "changes: and deletes the change")
  eq(echoed(w, "Put Svof's own alertness back."), true, "changes: and says so")
  cmd("astralform reset")
  eq(w.line("You become a being of light."), 0, "changes: reset makes svof's own triggers again")
  for _, t in ipairs(w.triggers) do
    if not t.killed and type(t.code) == "string" and t.code:find("_astralform()", 1, true) then triggers = triggers + 1 end
  end
  local fresh = world.new({ class = "Occultist" })
  local svofs = 0
  for _, t in ipairs(fresh.triggers) do
    if not t.killed and type(t.code) == "string" and t.code:find("_astralform()", 1, true) then svofs = svofs + 1 end
  end
  eq(triggers, svofs, "changes: as many as svof's own makes")

  -- with customdefinitions off, the change is kept and not used
  cmd("alertness command alertness up")
  w.run('svo.defences.edit_install("alertness", true)')
  svo.conf.customdefinitions = false
  svo.classchange("Monk")
  eq(svo.dict.alertness.physical.action, "alertness on", "changes: with customdefinitions off, a change isn't used")
  cmd("")
  eq(echoed(w, "not in use, as vconfig customdefinitions is off"), true, "changes: and the list says why")
  svo.conf.customdefinitions = true
end

do -- a change can move a class's defence to another skillset, as a class
  -- update can (the user's ask, 2026-10-17)
  local w = world.new({ class = "Occultist" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function link(text)
    for i = #w.links, 1, -1 do
      if w.links[i]:sub(1, #text + 1) == text .. " " then return w.links[i]:sub(#text + 2) end
    end
  end
  local function listed(group, name)
    for _, def in ipairs(svo.defences.def_types[group] or {}) do
      if def == name then return true end
    end
    return false
  end
  eq(svo.defs_data.astralform.type, "occultism", "skillset change: astralform starts in Occultism")
  svo.ignoreskill("astralform", true)

  cmd("astralform")
  eq(row_echoed(w, "skillset:", "occultism"), true, "skillset change: the screen shows its skillset")
  eq(link("tarot"), [[svo.defences.custom_set("astralform", 'skillset', "tarot")]],
    "skillset change: with a link to each of the class's others")
  eq(link("type one") ~= nil, true, "skillset change: and one to type one")
  cmd("astralform skillset Tarot")
  eq(svo.defences.edit_drafts.astralform.skillset, "tarot", "skillset change: vcustomdef <name> skillset sets it")
  eq(svo.defs_data.astralform.type, "occultism", "skillset change: which waits for install")
  w.run('svo.defences.edit_install("astralform", true)')
  eq(svo.defs_data.astralform.type, "tarot", "skillset change: installed, it's in the new skillset")
  eq(listed("tarot", "astralform") and not listed("occultism", "astralform"), true,
    "skillset change: and the lists show it there, not in the old one")
  eq(svo.sk.ignored_defences_map.astralform, "tarot", "skillset change: hiding it goes by the new one")
  eq(svo.sk.ignored_defences.tarot.t.astralform, true, "skillset change: and it's still hidden, as it was")
  eq(svo.sk.ignored_defences.occultism.t.astralform, nil, "skillset change: and gone from the old one")
  local saved = svo.defences.edits.occultist and svo.defences.edits.occultist.astralform or {}
  eq(saved.skillset, "tarot", "skillset change: saved as the Occultist's change")
  eq(saved.was and saved.was.skillset, "occultism", "skillset change: with svof's own skillset when it was changed")

  svo.classchange("Monk")
  svo.classchange("Occultist")
  eq(svo.defs_data.astralform.type, "tarot", "skillset change: in the new skillset as svof loads")
  eq(listed("tarot", "astralform") and not listed("occultism", "astralform"), true,
    "skillset change: and listed there as svof loads")

  cmd("astralform reset")
  eq(svo.defs_data.astralform.type, "occultism", "skillset change: reset puts it back in svof's own skillset")
  eq(listed("occultism", "astralform") and not listed("tarot", "astralform"), true,
    "skillset change: and in the lists")
  eq(svo.sk.ignored_defences.occultism.t.astralform, true, "skillset change: still hidden")

  cmd("astralform skillset general")
  eq(echoed(w, "Can't list astralform under general: general is Svof's own group, not a skillset."), true,
    "skillset change: general isn't a skillset to move it to")
  cmd("alertness skillset tarot")
  eq(echoed(w, "Svof's own alertness is a general defence, which every class has, so its skillset stays."), true,
    "skillset change: a general defence's skillset stays")
  cmd("alertness")
  eq(row_echoed(w, "skillset:", "general, which every class has, so it stays there"), true,
    "skillset change: and its screen says so")
end

do -- vcustomdef works with customdefinitions off as svof loads, when the
  -- definitions file wasn't read before
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  svo.defences.custom, svo.defences.edits = nil, nil
  svo.conf.customdefinitions = false
  svo.classchange("Occultist")
  local ok = pcall(svo.defences.customdef_command, "")
  eq(ok, true, "customdef: vcustomdef lists definitions with customdefinitions off from the start")
  ok = pcall(svo.defences.customdef_command, "shimmer command shimmer")
  eq(ok, true, "customdef: and starts one")
end

do -- a definition saved in another class, where svof has its own by that
  -- name, becomes a change to svof's own when the player says so. One
  -- can't be made now (section 17), so this is one saved before
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function link(text)
    for i = #w.links, 1, -1 do
      if w.links[i]:sub(1, #text + 1) == text .. " " then return w.links[i]:sub(#text + 2) end
    end
  end
  cmd("astralform command astral form")
  eq(echoed(w, "define astralform: Svof has its own astralform for Occultist. vcustomdef astralform copy copies it in instead."), true,
    "clash: as a Monk, astralform, an Occultist's, can't be defined now")
  svo.defences.custom.astralform = { class = "occultist", skillset = "occultism", command = "astral form",
    on = { "You become a being of light." }, off = {} }
  eq(svo.defences.custom.astralform ~= nil, true, "clash: as a Monk, a definition named astralform for Occultists is saved")
  svo.classchange("Occultist")
  eq(echoed(w, "Svof has its own astralform in this class, so the one you defined isn't used."), true,
    "clash: as an Occultist, svof says its own is used")
  eq(link("(delete it)") ~= nil, true, "clash: with a link to delete the definition")
  if link("(make it a change to Svof's own)") then w.run(link("(make it a change to Svof's own)")) end
  local d = svo.defences.edit_drafts.astralform or { on = {} }
  local joined = false
  for _, l in ipairs(d.on) do if l == "You become a being of light." then joined = true end end
  eq(joined, true, "clash: the definition's gain line joins svof's in a change")
  eq(#d.on > 1, true, "clash: next to svof's own lines")
  eq(echoed(w, "Svof makes astralform's command itself, so the one you defined, astral form, isn't used."), true,
    "clash: a command svof makes itself is said to stay")
  w.run('svo.defences.edit_install("astralform", true)')
  eq(w.line("You become a being of light."), 1, "clash: installed, the line is heard")
  eq(svo.defences.custom.astralform, nil, "clash: and the definition goes")
end

do -- vshow links to vcustomdef
  local w = world.new({ class = "Monk" })
  w.svo.showprompt = function() end
  w.svo.ashow()
  local found = false
  for _, l in ipairs(w.links) do
    if l == "vcustomdef svo.defences.customdef_menu()" then found = true end
  end
  eq(found, true, "vshow: links to the defences you defined and changed")
end

do -- an item's defence registers after systemstart, and its change goes in then
  local w = world.new({ class = "Occultist" })
  local svo = w.svo
  svo.defences.enablemindnet()
  svo.defences.customdef_command("mindnet command mindnet up")
  w.run('svo.defences.edit_install("mindnet", true)')
  eq(svo.dict.mindnet.physical.action, "mindnet up", "changes: mindnet, the phylactery's, can be changed")
  svo.conf.havemindnet = true
  -- an Infernal, as a Monk's mindnet is Telepathy's own
  svo.classchange("Infernal")
  w.run_timers()
  eq(echoed(w, "Svof doesn't have mindnet any more"), false, "changes: an item's isn't missed as svof loads")
  eq(svo.dict.mindnet and svo.dict.mindnet.physical.action, "mindnet up", "changes: and is in use once the item registers")
end

do -- serverside: a new GMCP name is a new name to the server
  local w = world.new({ class = "Occultist", paused = false })
  local svo = w.svo
  local told = {}
  svo.sendcuringprio = function(prio, kind, slow) told[#told + 1] = kind .. " " .. prio .. (slow and " (slow)" or "") end
  svo.conf.serverside = true
  svo.setserverignore("alertness")
  svo.sk.gmcp_defs_seen.alert = true -- as if GMCP had sent the name
  svo.defences.customdef_command("alertness gmcp alert")
  w.run('svo.defences.edit_install("alertness", true)')
  eq(table.concat(told, ", "), "defence alertness reset, defence alertness reset (slow)",
    "changes: a new GMCP name tells the server to stop raising it by the old one")
  told = {}
  svo.sk.sendpriorityswitch("alertness", "physical", {}, { alertness = 4 }, {}, false)
  eq(told[#told], "defence alert 4", "changes: and its priority goes to the server by the new one")
end

do -- import: the changes a file holds, with its definitions
  local w = world.new({ class = "Occultist" })
  local svo = w.svo
  local old_attributes, old_load = w.env.lfs.attributes, w.env.table.load
  w.env.lfs.attributes = function() return {} end
  w.env.table.load = function(_, t)
    t.treewatch = { class = "all", command = "treewatch", on = { "x" } }
    t._changes = { all = { treewatch = { command = "treewatch up", was = { command = "treewatch on" } } } }
  end
  svo.defences.customdef_command("import shared-defences")
  w.env.lfs.attributes, w.env.table.load = old_attributes, old_load
  eq(echoed(w, "Svof has its own treewatch, so the one in shared-defences isn't used."), true,
    "changes: import refuses a definition with svof's own name")
  eq(svo.dict.treewatch.physical.action, "treewatch up", "changes: and puts the file's change to svof's own in")
  eq(echoed(w, "Added the change to Svof's own treewatch from shared-defences."), true, "changes: saying so")
end

-- ===== 14. The marks in the defence and priority lists =====

-- * after a defence the player defined, + after one of svof's own they
-- changed, with a key under the list (the user's choice, 2026-10-10)
do
  -- Lua 5.2 and later have no math.log10, which the priority lists use
  -- through svo.intlen; 5.1, which svof runs on, has it
  math.log10 = math.log10 or function (x) return math.log(x, 10) end
  local w = world.new({ class = "Occultist" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  svo.showprompt = function() end
  cmd("shimmer skillset occultism")
  cmd("shimmer command shimmer on")
  cmd("shimmer got You begin to shimmer.")
  cmd("shimmer install")
  cmd("alertness command alertness up")
  w.run('svo.defences.edit_install("alertness", true)')
  eq(svo.defences.mark("shimmer") .. svo.defences.mark("alertness") .. svo.defences.mark("kola"), "*+",
    "marks: * for a definition, + for a change to svof's own, nothing for svof's own")

  local cells, hints = {}, {}
  w.env.dechoLink = function(text, code, hint)
    cells[#cells + 1] = tostring(text)
    hints[#hints + 1] = tostring(hint)
  end
  local function cell(name)
    for i, c in ipairs(cells) do
      if c:find("] " .. name, 1, true) then return c, hints[i] end
    end
  end
  local function visible(s) return (s:gsub("<%d+,%d+,%d+>", "")) end
  local echoes = #w.echoes
  svo.show_keepup()
  local shimmer, shimmerhint = cell("shimmer")
  local alertness, alertnesshint = cell("alertness")
  eq(shimmer and visible(shimmer):match("%] (%S+)"), "shimmer*", "marks: vshow keepup marks a definition")
  eq(alertness and visible(alertness):match("%] (%S+)"), "alertness+", "marks: and a change to svof's own")
  eq(alertness and alertness:find("alertness<255,170,0>+<153,204,204>", 1, true) ~= nil, true,
    "marks: the mark in a colour of its own")
  eq(alertness and #visible(alertness), #"[ ] " + 23, "marks: and the column as wide as before")
  eq(shimmerhint and shimmerhint:find("(you defined it)", 1, true) ~= nil, true, "marks: the link says what * means")
  eq(alertnesshint and alertnesshint:find("(Svof's own, changed by you)", 1, true) ~= nil, true,
    "marks: and what + means")
  local kola = cell("kola")
  eq(kola and visible(kola):match("%] (%S+)"), "kola", "marks: svof's own is shown as before")
  local key = false
  for i = echoes + 1, #w.echoes do
    if w.echoes[i]:find("you defined it", 1, true) and w.echoes[i]:find("Svof's own, changed by you", 1, true) then key = true end
  end
  eq(key, true, "marks: a key under the list says what they mean")

  -- the priority lists
  echoes = #w.echoes
  svo.printorder("physical")
  local text = table.concat(w.echoes, "", echoes + 1)
  eq(text:find("alertness<255,170,0>+", 1, true) ~= nil and text:find("shimmer<255,170,0>*", 1, true) ~= nil, true,
    "marks: the physical priority list marks them")
  eq(text:find("(vcustomdef)", 1, true) ~= nil, true, "marks: with the key")
  echoes = #w.echoes
  svo.printordersync()
  text = table.concat(w.echoes, "", echoes + 1)
  eq(text:find("shimmer<255,170,0>*<112,112,112> (physical)", 1, true) ~= nil, true,
    "marks: the slow curing list marks one between its name and balance")

  -- vshow server and vshow hidelist
  cells, hints = {}, {}
  svo.showserverside()
  alertness, alertnesshint = cell("alertness")
  eq(alertness and visible(alertness):match("%] (%S+)"), "alertness+", "marks: vshow server marks them")
  eq(alertnesshint and alertnesshint:find("(Svof's own, changed by you)", 1, true) ~= nil, true,
    "marks: and its link says so")
  echoes = #cells
  svo.showhidelist()
  -- each defence is a link, to hide or show it
  text = table.concat(cells, "\n", echoes + 1)
  eq(text:find("shimmer<255,170,0>*", 1, true) ~= nil and text:find("alertness<255,170,0>+", 1, true) ~= nil, true,
    "marks: vshow hidelist marks them")
end

do -- no marks, no key
  local w = world.new({ class = "Occultist" })
  local svo = w.svo
  svo.showprompt = function() end
  svo.show_keepup()
  eq(echoed(w, "(vcustomdef)"), false, "marks: a list with nothing marked has no key")
end

-- ===== 15. DEF lines =====

-- Without a DEF line, each DEF marks a defence gone, so test and install
-- warn, and def none says DEF doesn't list it, as svof's own invisibledef
-- does. A warning, not a refusal, as some defences DEF doesn't show (the
-- user, 2026-10-10)
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  svo.showprompt = function() end
  local cmd = svo.defences.customdef_command
  local function def()
    svo.defences.def_def_list = {}
    svo.process_defs()
    w.prompt()
  end
  cmd("shimmer skillset tekura")
  cmd("shimmer command shimmer on")
  cmd("shimmer got You begin to shimmer.")
  cmd("shimmer test")
  eq(echoed(w, "Without a DEF line, each DEF marks shimmer gone, and keepup raises it again."), true,
    "DEF lines: test warns about a definition without one")
  eq(echoed(w, "It's ready to install."), true, "DEF lines: which can still be installed")
  local echoes = #w.echoes
  cmd("shimmer install")
  local warned = false
  for i = echoes + 1, #w.echoes do
    if w.echoes[i]:find("Without a DEF line", 1, true) then warned = true end
  end
  eq(warned, true, "DEF lines: install warns too")
  svo.defences.got("shimmer")
  def()
  eq(svo.defc.shimmer, false, "DEF lines: and each DEF marks it gone, as it warns")

  cmd("shimmer def none")
  local d = svo.defences.custom_drafts.shimmer or {}
  eq(d.notondef, true, "DEF lines: def none says DEF doesn't list it")
  cmd("shimmer test")
  eq(echoed(w, "DEF doesn't list it, so DEF leaves it alone."), true, "DEF lines: as test says")
  cmd("shimmer install")
  eq(svo.defs_data.shimmer and svo.defs_data.shimmer.invisibledef, true, "DEF lines: its record is invisibledef, like svof's own")
  svo.defences.got("shimmer")
  def()
  eq(svo.defc.shimmer, true, "DEF lines: and DEF leaves it alone")
  cmd("shimmer def You are shimmering.")
  d = svo.defences.custom_drafts.shimmer or {}
  eq(d.def == "You are shimmering." and d.notondef == nil, true, "DEF lines: a DEF line given undoes def none")
end

do -- a change to svof's own can say DEF doesn't list it, and warns taking out its DEF line
  local w = world.new({ class = "Occultist" })
  local svo = w.svo
  svo.showprompt = function() end
  local cmd = svo.defences.customdef_command
  cmd("alertness def none")
  w.run('svo.defences.edit_install("alertness", true)')
  eq(svo.defs_data.alertness.invisibledef, true, "DEF lines: a change says DEF doesn't list svof's own")
  svo.defences.got("alertness")
  svo.defences.def_def_list = {}
  svo.process_defs()
  w.prompt()
  eq(svo.defc.alertness, true, "DEF lines: and DEF leaves it alone")
  cmd("alertness reset")
  eq(svo.defs_data.alertness.invisibledef, nil, "DEF lines: reset puts svof's own back")
  svo.defences.custom_unset("alertness", "def", 1)
  cmd("alertness test")
  eq(echoed(w, "Without a DEF line, each DEF marks alertness gone"), true,
    "DEF lines: taking svof's own DEF line out of a change warns")
end

-- ===== 16. GMCP names the game confirms =====

-- A definition or a change takes only a GMCP name the game confirms (the
-- user, 2026-10-10): by DEFENCE SHOW, DEFENCE LIST or GMCP sending it. With
-- a wrong one, svof would leave the defence to serverside, which couldn't
-- raise it either.
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function game(text) w.env.line = text svo.defences.custom_fetch_line() w.run_timers() end
  cmd("shimmer command shimmer on")
  local d = svo.defences.custom_drafts.shimmer or {}

  cmd("shimmer gmcp shimer")
  eq(w.sent[#w.sent], "defence show shimer", "GMCP names: one the game hasn't confirmed is asked about")
  eq(d.gmcp, nil, "GMCP names: and isn't taken yet")
  -- the game answers the new draft's own DEFENCE SHOW shimmer first
  game("Defence:            Shimmering (shimmering)")
  game("Strippable:         Yes")
  eq(d.gmcp, nil, "GMCP names: the answer to an earlier ask doesn't set it")
  game("There is no such defence.")
  eq(echoed(w, "The game has no defence called shimer over GMCP, so it can't be shimmer's GMCP name. Check the name, or use vcustomdef shimmer gmcp none"),
    true, "GMCP names: one the game doesn't have is refused, saying what to do")
  eq(d.gmcp, nil, "GMCP names: and isn't taken")
  local sent = #w.sent
  cmd("shimmer gmcp shimer")
  eq(#w.sent, sent, "GMCP names: given again, it's refused without asking the game again")

  cmd("shimmer gmcp Shimmering")
  game("Defence:            Shimmering (shimmering)")
  game("EnactMsg:           You begin to shimmer.")
  game("Profession:         No")
  game("Strippable:         Yes")
  eq(d.gmcp, "shimmering", "GMCP names: the game's reply sets it")
  eq(d.on[1], "You begin to shimmer.", "GMCP names: and fills in its lines, as before")
  cmd("shimmer gmcp none")
  cmd("shimmer gmcp shimmering")
  eq(d.gmcp, "shimmering", "GMCP names: the game's confirmation lasts the session, so it's taken at once")

  cmd("shimmer gmcp shimmer")
  game("Defence:            Shimmering (shimmering)")
  game("Strippable:         Yes")
  eq(echoed(w, "The game knows shimmer as shimmering over GMCP."), true, "GMCP names: the game's own spelling is taken")

  cmd("shimmer gmcp wisp")
  w.advance(10)
  eq(echoed(w, "The game didn't answer about wisp, so Svof can't take it as shimmer's GMCP name."), true,
    "GMCP names: without an answer, it isn't taken")
  eq(d.gmcp, "shimmering", "GMCP names: and the one before stays")

  svo.sk.gmcp_defs_seen.glimmering = true
  cmd("shimmer gmcp glimmering")
  eq(d.gmcp, "glimmering", "GMCP names: one GMCP has sent this session is taken at once")
  cmd("shimmer gmcp none")
  eq(d.gmcp, nil, "GMCP names: none takes it away")
end

do -- a change to svof's own
  local w = world.new({ class = "Occultist" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function game(text) w.env.line = text svo.defences.custom_fetch_line() w.run_timers() end
  cmd("alertness gmcp alertnes")
  eq(w.sent[#w.sent], "defence show alertnes", "GMCP names: a change's new GMCP name is asked about too")
  game("There is no such defence.")
  eq(echoed(w, "The game has no defence called alertnes over GMCP, so it can't be alertness's GMCP name."), true,
    "GMCP names: and refused when the game doesn't have it")
  local d = svo.defences.edit_drafts.alertness or {}
  eq(d.gmcp, "alertness", "GMCP names: leaving svof's own")
  cmd("alertness gmcp alert")
  game("Defence:            Alertness (alert)")
  game("EnactMsg:           You prick up your ears sharply.")
  game("Strippable:         Yes")
  eq(d.gmcp, "alert", "GMCP names: the game's reply sets a change's")
  eq(#d.on, 3, "GMCP names: and adds none of its lines to a change")
  local sent = #w.sent
  cmd("alertness gmcp alertness")
  eq(d.gmcp == "alertness" and #w.sent == sent, true, "GMCP names: svof's own name back needs no asking")
end

do -- import checks a file's GMCP names against DEFENCE LIST, which then answers for any name
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function game(text) w.env.line = text svo.defences.custom_gamelist_line() w.run_timers() end
  local old_attributes, old_load = w.env.lfs.attributes, w.env.table.load
  w.env.lfs.attributes = function() return {} end
  w.env.table.load = function(_, t)
    t.veil = { class = "all", command = "veil on", on = { "A veil falls about you." }, gmcp = "Veiled" }
    t.murk = { class = "all", command = "murk", on = { "A murk gathers about you." }, gmcp = "murkiness" }
    t._changes = { all = { treewatch = { gmcp = "treewatching", was = { gmcp = svo.dict.svotossd.treewatch } },
      skywatch = { gmcp = "skywatching", was = { gmcp = svo.dict.svotossd.skywatch } } } }
  end
  cmd("import shared-defences")
  w.env.lfs.attributes, w.env.table.load = old_attributes, old_load
  eq(w.sent[#w.sent], "defence list", "GMCP names: import checks names the game hasn't confirmed against DEFENCE LIST")
  eq(svo.defs_data.veil, nil, "GMCP names: and waits for it")
  game("All defences")
  game("Veiled")
  game("Treewatching")
  w.env.isPrompt = function() return true end
  game("9975h, 6252m cexkdb-")
  w.env.isPrompt = function() return false end
  eq(svo.defs_data.veil and svo.dict.sstosvod.veiled, "veil", "GMCP names: a definition whose name the list has is imported")
  eq(echoed(w, "Didn't import murk from shared-defences: the game has no defence called murkiness over GMCP."), true,
    "GMCP names: one whose name it doesn't have isn't")
  eq(svo.defs_data.murk, nil, "GMCP names: and isn't installed")
  eq(svo.dict.svotossd.treewatch, "treewatching", "GMCP names: a change whose name the list has is imported too")
  eq(echoed(w, "Didn't import the change to Svof's own skywatch from shared-defences: the game has no defence called skywatching over GMCP."),
    true, "GMCP names: and one whose name it doesn't have isn't")
  eq(svo.dict.svotossd.skywatch == "skywatching", false, "GMCP names: so skywatch keeps svof's own")

  cmd("shimmer command shimmer on")
  local sent = #w.sent
  cmd("shimmer gmcp nosuch")
  eq(#w.sent, sent, "GMCP names: after a whole DEFENCE LIST, a name it doesn't have is refused without asking")
  eq(echoed(w, "The game has no defence called nosuch over GMCP"), true, "GMCP names: as svof says")
end

-- ===== 17. Svof's own defences in other classes, and clashes =====

-- svof builds only the class it loads, so src/resources/defence_catalog.lua
-- (tools/defence_catalog.lua) holds every class's version of the defences
-- only some classes have. A definition can't take one of those names, and
-- svof's own can be copied in instead, for a class svof's list is out of
-- date for or an artefact (the user, 2026-10-10). Nothing that clashes with
-- the class's other defences goes into play: not a copy, a definition or a
-- change, when it's installed or as svof loads.

-- the code a link runs, the latest with this text
local function link_of(w, text)
  for i = #w.links, 1, -1 do
    if w.links[i]:sub(1, #text + 1) == text .. " " then return w.links[i]:sub(#text + 2) end
  end
end

-- loads svof again as class, as logging in does: a class change to the
-- class svof already has does nothing
local function reload(svo, class)
  svo.classchange("None")
  svo.classchange(class)
end

do -- the catalog is the defences some classes have and others don't
  local w = world.new({ class = "Monk" })
  local listed = {}
  for name in pairs(w.svo.defences.catalog()) do listed[name] = true end
  local expected = {}
  for name in pairs(union) do if not everywhere[name] then expected[name] = true end end
  eq(sorted_keys(listed), sorted_keys(expected), "copies: the catalog lists every defence only some classes have")
  local v = w.svo.defences.catalog().acrobatics[1]
  eq(v.classes[1] .. " " .. v.command .. " " .. v.gmcp, "bard acrobatics on acrobatics",
    "copies: with each class's version: Bard's acrobatics")
end

do -- vcustomdef svof [all]: svof's own, each a link to change or copy it (the user's ask, 2026-10-16)
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local tekura = {}
  for _, name in ipairs(svo.defences.def_types.tekura) do tekura[#tekura + 1] = name end
  table.sort(tekura)
  cmd("svof")
  eq(echoed(w, "Svof's own defences for Monk (click one to change it):"), true, "own list: vcustomdef svof lists them")
  eq(link_of(w, tekura[1]), string.format('svo.defences.custom_show("%s")', tekura[1]),
    "own list: each a link to its screen")
  eq(link_of(w, "acrobatics"), nil, "own list: only this class's")
  eq(link_of(w, "show every class's defences"), "svo.defences.own_list(true)", "own list: with a link to every class's")
  eq(echoed(w, "  " .. string.rep("-", 70)), true, "own list: a line between the list and its links")
  local general, tekura_at
  for i, e in ipairs(w.echoes) do
    if e:find("General:", 1, true) and not general then general = i end
    if e:find("Tekura:", 1, true) and not tekura_at then tekura_at = i end
  end
  eq(general ~= nil and tekura_at ~= nil and general < tekura_at, true, "own list: by skillset, general first")

  cmd("svof all")
  eq(echoed(w, "Svof's own defences, every class's, by skillset"), true, "own list: vcustomdef svof all lists every class's")
  eq(link_of(w, "acrobatics"), 'svo.defences.custom_show("acrobatics")', "own list: another class's too, a link to copy it")
  eq(echoed(w, "Swashbuckling (Bard):") and echoed(w, "Pranks (Jester):"), true,
    "own list: another class's skillset says whose it is")
  eq(echoed(w, "General (every class):") and echoed(w, "Tekura:"), true, "own list: general for every class, and Monk's as they are")
  eq(link_of(w, "show only Monk's defences"), "svo.defences.own_list()", "own list: with a link back to this class's")

  cmd("svof everything")
  eq(echoed(w, "vcustomdef svof lists Svof's own defences for your class, and vcustomdef svof all every class's."), true,
    "own list: anything else after svof says what it takes")
  eq(svo.defences.custom_problem("svof", {}), "svof is a command here, not a name", "own list: svof can't be a defence's name")

  -- the menu links to it, and to turning vconfig customdefinitions on or off
  cmd("list")
  eq(link_of(w, "change one of Svof's own"), "svo.defences.own_list()", "own list: vcustomdef's menu links to it")
  eq(echoed(w, "Svof uses your definitions and changes (vconfig customdefinitions is on)."), true,
    "customdefinitions: the menu says it's on")
  eq(link_of(w, "turn it off"), 'svo.config.set("customdefinitions", false, true)', "customdefinitions: with a link to turn it off")
  -- (vconfig redraws the prompt, which the world has no buffer for)
  w.env.appendBuffer = w.env.appendBuffer or function () end
  svo.config.set("customdefinitions", false, true)
  eq(svo.conf.customdefinitions, false, "customdefinitions: which turns it off")
  cmd("list")
  eq(echoed(w, "Svof leaves out your definitions and changes (vconfig customdefinitions is off)."), true,
    "customdefinitions: the menu says it's off")
  eq(link_of(w, "turn it on"), 'svo.config.set("customdefinitions", true, true)', "customdefinitions: with a link to turn it on")
end

do -- a name svof has in other classes is refused, and copied instead
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local sent = #w.sent
  cmd("acrobatics")
  eq(echoed(w, "Svof has its own acrobatics for Bard and Jester, so it can't be defined again."), true,
    "copies: vcustomdef with a name svof has in other classes says so")
  eq(#w.sent, sent, "copies: and doesn't ask the game about a new definition")
  eq(link_of(w, "copy it"), 'svo.defences.copy_own("acrobatics", 2)', "copies: with a link to copy each class's version")
  cmd("acrobatics command acrobatics on")
  eq(echoed(w, "define acrobatics: Svof has its own acrobatics for Bard and Jester. vcustomdef acrobatics copy copies it in instead."),
    true, "copies: a definition of it is refused")
  eq(svo.defences.custom_drafts.acrobatics, nil, "copies: and none is started")
  svo.defences.custom_drafts.acrobatics = { class = "monk", skillset = "kaido", command = "acrobatics on", on = { "x" }, off = {} }
  cmd("acrobatics install")
  eq(echoed(w, "install acrobatics: Svof has its own acrobatics for Bard and Jester, so use vcustomdef acrobatics copy"),
    true, "copies: and can't be installed")
  eq(svo.defs_data.acrobatics, nil, "copies: so isn't")
  svo.defences.custom_drafts.acrobatics = nil

  svo.defences.copy_own("acrobatics", 1)
  local d = svo.defences.custom_drafts.acrobatics or { on = {} }
  eq(d.command .. " " .. d.gmcp .. " " .. tostring(d.copy and d.copy.from), "acrobatics on acrobatics bard",
    "copies: a copy takes svof's command and GMCP name, from Bard's")
  eq(#d.on .. " " .. tostring(d.def), "2 You are bouncing around acrobatically.", "copies: and its lines")
  eq(d.skillset, nil, "copies: a Monk has no Swashbuckling, so the skillset is left to pick")
  eq(echoed(w, "acrobatics, a copy of Svof's own from Bard (not installed):"), true, "copies: and shown as a copy")
  cmd("acrobatics skillset kaido")
  cmd("acrobatics install")
  eq(svo.defs_data.acrobatics and svo.defs_data.acrobatics.type, "kaido", "copies: installed under Kaido")
  w.gmcp_defence_add("acrobatics")
  eq(svo.defc.acrobatics, true, "copies: and GMCP's acrobatics is it")
  cmd("list")
  eq(echoed(w, ": Svof's own, copied, for Monk (kaido), in use"), true, "copies: the list says it's a copy")

  -- a definition made before svof had it: the copy keeps its lines
  svo.defences.custom.glide = nil
  svo.defences.custom.acrobatics = { class = "monk", skillset = "kaido", command = "flip", on = { "You flip about." }, off = {} }
  svo.defences.custom_drafts.acrobatics = nil
  cmd("acrobatics")
  eq(link_of(w, "(use Svof's own instead)"), 'svo.defences.copy_offer("acrobatics")',
    "copies: a definition of a name svof has elsewhere links to svof's own")
  svo.defences.copy_own("acrobatics", 2)
  d = svo.defences.custom_drafts.acrobatics or { on = {} }
  eq(table.concat(d.on, "|"), "You begin leaping and bouncing about, making it more difficult to hit you.|You are already bouncing around acrobatically.|You flip about.",
    "copies: the definition's lines join svof's")
  eq(d.command .. " " .. d.skillset .. " " .. d.copy.from, "acrobatics on kaido jester",
    "copies: with svof's command, the definition's skillset, from Jester's")

  -- svof's patterns come with a copy, to see and change: a Serpent's ghost
  local pattern = svo.defences.catalog().ghost[1].offr[1]
  svo.defences.copy_own("ghost", 1)
  eq(row_echoed(w, "or matches:", pattern), true, "copies: the screen shows svof's loss pattern")
  eq(svo.defences.custom_drafts.ghost.offr[1], pattern, "copies: as the copy's own")
  -- and its other lines, kept as they are: a Druid's concealment
  svo.defences.copy_own("concealment", 1)
  eq(echoed(w, "more of Svof's own lines and patterns, kept as they are"), true,
    "copies: the screen says what else comes from svof's own")
  local only = svo.defences.catalog().concealment[1].on_only[1]
  cmd("concealment skillset kaido")
  cmd("concealment install")
  eq(svo.defs_data.concealment and svo.defs_data.concealment.on_only and svo.defs_data.concealment.on_only[1], only,
    "copies: installed, its record has them")
  cmd("ghost skillset kaido")
  cmd("ghost install")
  eq(svo.defs_data.ghost and svo.defs_data.ghost.offr and svo.defs_data.ghost.offr[1], pattern,
    "copies: a copy's record has svof's loss pattern")
  local made = false
  for _, t in ipairs(w.triggers) do
    if t.kind == "regex" and t.pattern == pattern and not t.killed then made = true end
  end
  eq(made, true, "copies: and a trigger for it")
end

do -- so is the name of svof's own action in other classes that isn't a defence (prio_catalog.lua)
  local w = world.new({ class = "Bard" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local why = "Svof has its own %s in other classes, and it isn't a defence, so give yours another name"
  eq(svo.dict.fitness == nil and svo.defences.catalog().fitness == nil, true,
    "actions: a Bard has no fitness, and it isn't a defence elsewhere")
  local sent = #w.sent
  cmd("fitness")
  eq(echoed(w, "define fitness: " .. why:format("fitness") .. "."), true, "actions: vcustomdef with its name says so")
  eq(svo.defences.custom_drafts.fitness, nil, "actions: and starts no definition")
  eq(#w.sent, sent, "actions: nor asks the game about one")
  svo.defences.custom_drafts.fitness = { class = "bard", skillset = "swashbuckling", command = "fitness", on = { "x" },
    off = {} }
  eq(svo.defences.custom_problem("fitness", svo.defences.custom_drafts.fitness), why:format("fitness"),
    "actions: a definition of it has that problem")
  cmd("fitness install")
  eq(echoed(w, "install fitness: " .. why:format("fitness") .. "."), true, "actions: and can't be installed")
  eq(svo.dict.fitness == nil and svo.defences.custom.fitness == nil, true, "actions: so isn't")
  svo.defences.custom_drafts.fitness = nil
  -- one only in the slow curing list is named there with its balance
  eq(svo.dict.age == nil and svo.defences.class_action("age"), true, "actions: a slow curing one by its name alone")
  -- the copy of a defence svof has elsewhere, and a name nothing has, aren't such names
  eq(svo.defences.class_action("acrobatics") or svo.defences.class_action("shimmer"), false,
    "actions: not a defence in the catalog, nor a name svof doesn't have")

  -- import
  local old_attributes, old_load = w.env.lfs.attributes, w.env.table.load
  w.env.lfs.attributes = function() return {} end
  w.env.table.load = function(_, t)
    t.transmute = { class = "all", command = "transmute", on = { "You transmute." } }
    t.veil = { class = "all", command = "veil on", on = { "A veil falls about you." } }
  end
  cmd("import shared-defences")
  w.env.lfs.attributes, w.env.table.load = old_attributes, old_load
  eq(echoed(w, "install transmute: " .. why:format("transmute") .. "."), true, "actions: import refuses one, saying why")
  eq(svo.defences.custom.transmute, nil, "actions: and doesn't install it")
  eq(svo.defs_data.veil ~= nil, true, "actions: but installs the rest")

  -- one saved before Svof refused it is left out as Svof loads
  svo.defences.custom.rage = { class = "bard", skillset = "swashbuckling", command = "rage", on = { "You rage." },
    off = {} }
  reload(svo, "Bard")
  eq(echoed(w, "add the defence rage you defined: " .. why:format("rage")), true,
    "actions: one saved is refused as Svof loads, saying why")
  eq(svo.defences.custom_registered.rage == nil and svo.dict.rage == nil, true, "actions: and isn't added")
  svo.classchange("Infernal")
  eq(svo.dict.rage and svo.dict.rage.misc ~= nil and svo.defences.custom_registered.rage == nil, true,
    "actions: an Infernal has svof's own rage")
  eq(svo.defences.class_action("rage"), false, "actions: which isn't another class's there")
end

do -- (6) svof's own that does more than a copy can carry isn't copied
  local w = world.new({ class = "Infernal" })
  local svo = w.svo
  svo.defences.copy_offer("bear")
  eq(echoed(w, "can't be copied: it can't be up with some of your other defences"), true,
    "copies: bear, which can't be up with other forms, can't be copied")
  svo.defences.copy_own("bear", 1)
  eq(echoed(w, "Can't copy Svof's own bear: it can't be up with some of your other defences"), true,
    "copies: and copy_own refuses it")
  eq(svo.defences.custom_drafts.bear, nil, "copies: starting nothing")
  svo.defences.copy_offer("air")
  eq(echoed(w, "Svof counts it with your other channel defences"), true, "copies: nor a channel, which svof counts")
  svo.defences.copy_offer("listen")
  eq(echoed(w, "Svof keeps losing it when you leave the room"), true, "copies: nor one svof keeps rules for elsewhere")
  svo.defences.copy_offer("mindnet")
  eq(echoed(w, "it comes with an item, and vconfig havemindnet adds Svof's own for that"), true,
    "copies: nor an item's, which its vconfig option adds")
  svo.defences.custom.acrobatics = { class = "infernal", skillset = "oppression", command = "acrobatics on",
    on = { "x" }, off = {}, copy = { from = "nosuchclass", was = {} } }
  eq(svo.defences.custom_problem("acrobatics", svo.defences.custom.acrobatics),
    "Svof doesn't have acrobatics for nosuchclass, which it was copied from", "copies: one from a file is checked again")
end

do -- (1) a class with svof's own has nothing to copy, and a copy gives way to it
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  svo.defences.copy_own("acrobatics", 1)
  cmd("acrobatics class all")
  cmd("acrobatics install")
  eq(svo.defences.custom_registered.acrobatics, true, "copies: a copy for every class is in use as a Monk")
  svo.classchange("Bard")
  eq(svo.defences.custom_registered.acrobatics, nil, "copies: and as a Bard isn't")
  eq(svo.defs_data.acrobatics and svo.defs_data.acrobatics.type, "swashbuckling", "copies: Svof's own is")
  eq(echoed(w, "your copy of it isn't used"), false, "copies: without a word, as it's for every class")
  cmd("acrobatics copy")
  eq(echoed(w, "Svof has its own acrobatics in this class, so there's nothing to copy."), true,
    "copies: and there's nothing to copy as a Bard")
  svo.defences.custom.acrobatics.class = "bard"
  reload(svo, "Bard")
  eq(echoed(w, "Svof has its own acrobatics in this class now, so your copy of it isn't used."), true,
    "copies: a copy for the class, once svof has it there, says so")
  eq(link_of(w, "(delete it)"), 'svo.defences.custom_delete("acrobatics")', "copies: with a link to delete it")
end

do -- (2, 5) a GMCP name another defence has
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  svo.defences.copy_own("acrobatics", 1)
  cmd("acrobatics skillset kaido")
  -- two saved definitions sharing a GMCP name: as svof loads, the first by
  -- name goes in and the other stays out, rather than each refusing the
  -- other
  svo.defences.custom.glint = { class = "monk", skillset = "kaido", command = "glint", gmcp = "tumbling",
    on = { "You glint." }, off = {} }
  svo.defences.custom.tumble = { class = "monk", skillset = "kaido", command = "tumble", gmcp = "tumbling",
    on = { "You tumble." }, off = {} }
  reload(svo, "Monk")
  eq(svo.defences.custom_registered.glint, true, "clashes: of two definitions with one GMCP name, the first is in")
  eq(echoed(w, "add the defence tumble you defined: GMCP's tumbling is already your glint"), true,
    "clashes: and the other stays out, saying why")
  eq(svo.defs_data.tumble, nil, "clashes: unregistered")
  svo.defences.custom_drafts.acrobatics.gmcp = "tumbling"
  cmd("acrobatics install")
  eq(echoed(w, "install acrobatics: GMCP's tumbling is already your glint"), true,
    "clashes: a copy with a registered definition's GMCP name")
  svo.defences.custom_drafts.acrobatics.gmcp = "alertness"
  cmd("acrobatics install")
  eq(echoed(w, "install acrobatics: GMCP's alertness is already Svof's alertness"), true,
    "clashes: one of svof's own GMCP names")
  eq(svo.defs_data.acrobatics, nil, "clashes: and neither is installed")
  eq(svo.defences.clash("acrobatics", { gmcp = "alertness" }), "GMCP's alertness is already Svof's alertness",
    "clashes: defences.clash says so too")
end

do -- (3) a line another defence watches for
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  svo.defences.copy_own("acrobatics", 1)
  cmd("acrobatics skillset kaido")
  cmd("acrobatics got You prick up your ears.")
  cmd("acrobatics install")
  eq(echoed(w, 'install acrobatics: Svof\'s alertness already watches for "You prick up your ears."'), true,
    "clashes: a copy's line svof's alertness watches for")
  eq(svo.defs_data.acrobatics, nil, "clashes: isn't installed")
  cmd("shimmer command shimmer on")
  cmd("shimmer skillset kaido")
  cmd("shimmer got You shimmer.")
  cmd("shimmer def You prick up your ears.")
  eq(svo.defences.custom_problem("shimmer", svo.defences.custom_drafts.shimmer),
    'Svof\'s alertness already watches for "You prick up your ears."', "clashes: nor a definition's DEF line")
  -- svof's own records watch for none of a part-line (offs) today
  svo.defs_data:set("murmur", { offs = "prick up your" })
  eq(svo.defences.clash("acrobatics", { lines = { "You prick up your nose." } }) ~= nil, true,
    "clashes: a line with another's part-line in it")
  eq(svo.defences.clash("acrobatics", { subs = { "prick up" } }) ~= nil, true,
    "clashes: and a part-line in another's line")
  svo.defs_data:set("murmur", nil)

  -- a change's new line, and one svof's own already had isn't new
  cmd("treewatch got You prick up your ears.")
  cmd("treewatch install")
  eq(echoed(w, 'change treewatch: Svof\'s alertness already watches for "You prick up your ears."'), true,
    "clashes: a change's new line another defence watches for")
  svo.defences.edit_drafts.treewatch = nil
  -- a line svof's own treewatch already has isn't the change's to clash
  -- with, even where another defence shares it
  svo.defs_data:set("treeshare", { on = svo.defs_data.treewatch.on[1] })
  cmd("treewatch got You watch the trees.")
  w.run('svo.defences.edit_install("treewatch", true)')
  eq(svo.defences.edits.all and svo.defences.edits.all.treewatch ~= nil, true,
    "clashes: a change keeping svof's lines another defence shares is installed")
  svo.defs_data:set("treeshare", nil)
  w.run('svo.defences.edit_reset("treewatch")')
  cmd("treewatch got You watch the trees.")
  w.run('svo.defences.edit_install("treewatch", true)')
  eq(svo.defences.edits.all and svo.defences.edits.all.treewatch ~= nil, true, "clashes: one that doesn't is installed")

  -- as svof loads, which a class change or an update to svof can bring
  svo.defences.edits.all.treewatch.on = { "You prick up your ears." }
  svo.defences.custom.acrobatics = svo.defences.custom_drafts.acrobatics
  svo.defences.custom_drafts.acrobatics = nil
  reload(svo, "Monk")
  eq(echoed(w, 'use your change to Svof\'s own treewatch: Svof\'s alertness already watches for "You prick up your ears."'),
    true, "clashes: a change that clashes as svof loads stays out")
  eq(table.concat(svo.defs_data.treewatch.on, "|") == "You prick up your ears.", false, "clashes: so treewatch keeps svof's lines")
  eq(echoed(w, 'add the defence acrobatics you defined: Svof\'s alertness already watches for "You prick up your ears."'),
    true, "clashes: a copy that clashes as svof loads stays out")
  eq(svo.defs_data.acrobatics, nil, "clashes: and isn't registered")
end

do -- (4) a command svof already takes for another action
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  svo.defences.copy_own("acrobatics", 1)
  cmd("acrobatics skillset kaido")
  cmd("acrobatics command Alertness on")
  cmd("acrobatics install")
  eq(echoed(w, 'install acrobatics: Svof already takes "Alertness on" as alertness\'s command'), true,
    "clashes: a command svof already takes, whatever its case")
  cmd("acrobatics command eat kola")
  eq(svo.defences.custom_problem("acrobatics", svo.defences.custom_drafts.acrobatics) ~= nil, true,
    "clashes: a cure's command too")
  cmd("acrobatics command acrobatics on")
  cmd("acrobatics install")
  cmd("glint command acrobatics on")
  cmd("glint skillset kaido")
  cmd("glint got You glint.")
  cmd("glint install")
  eq(echoed(w, 'install glint: your acrobatics is raised with "acrobatics on" too'), true,
    "clashes: a command a registered definition sends")
  cmd("treewatch command alertness on")
  cmd("treewatch install")
  eq(echoed(w, 'change treewatch: Svof already takes "alertness on" as alertness\'s command'), true,
    "clashes: and a change's")
end

do -- (7) svof's own updated since it was copied, or gone from that class
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  svo.defences.copy_own("acrobatics", 1)
  cmd("acrobatics skillset kaido")
  cmd("acrobatics install")
  reload(svo, "Monk")
  eq(echoed(w, "since you copied it"), false, "copies: nothing to say while svof's own is as copied")
  svo.defences.custom.acrobatics.copy.was.on = { "You leap about." }
  reload(svo, "Monk")
  eq(echoed(w, "Svof has updated its own acrobatics since you copied it. Your copy is still in use:"), true,
    "copies: svof's own changed since says so")
  eq(svo.defences.custom_registered.acrobatics, true, "copies: and the copy stays in use")
  eq(link_of(w, "copy it again"), 'svo.defences.copy_own("acrobatics", 1)', "copies: with a link to copy it again")
  w.run(link_of(w, "keep yours") or "")
  w.echoes = {}
  reload(svo, "Monk")
  eq(echoed(w, "since you copied it"), false, "copies: keep yours stops saying so")
  svo.defences.custom.acrobatics.copy.from = "nosuchclass"
  reload(svo, "Monk")
  eq(echoed(w, "Svof doesn't have acrobatics for Nosuchclass any more. Your copy of it is still in use."), true,
    "copies: svof's own gone from that class says so")
end

-- ===== 18. Serverside's commands for defences registered after systemstart =====

-- svof takes a command for its own action when the player types it or
-- serverside sends it (sys.input_to_actions, section 7). systemstart maps
-- the dictionary's commands before definitions, copies and items' defences
-- register, so defences.register maps theirs, and unregister takes it out.
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local map = function() return svo.sys.input_to_actions end
  cmd("shimmer command Shimmer On")
  cmd("shimmer skillset kaido")
  cmd("shimmer got You shimmer.")
  cmd("shimmer install")
  eq(map()["shimmer on"], svo.dict.shimmer.physical, "adopting: a definition's command, in lower case as the server's is read")
  svo.conf.serverside = true
  svo.curingcommand("SHIMMER ON")
  eq(w.inflight(), "shimmer_physical", "adopting: the server's SHIMMER ON is the definition's action")
  w.line("You shimmer.")
  w.prompt()
  eq(svo.defc.shimmer, true, "adopting: and its line finishes it")
  svo.conf.serverside = false

  reload(svo, "Monk")
  eq(map()["shimmer on"], svo.dict.shimmer.physical, "adopting: mapped again as svof loads")
  cmd("shimmer command shimmer up")
  cmd("shimmer install")
  eq(map()["shimmer on"], nil, "adopting: installed with a new command, the old one goes")
  eq(map()["shimmer up"], svo.dict.shimmer.physical, "adopting: and the new one is mapped")
  cmd("shimmer delete")
  eq(map()["shimmer up"], nil, "adopting: deleted, its command goes")

  svo.defences.copy_own("acrobatics", 1)
  cmd("acrobatics skillset kaido")
  cmd("acrobatics install")
  eq(map()["acrobatics on"], svo.dict.acrobatics.physical, "adopting: a copy's command")

  local alertness = map()["alertness on"]
  svo.defences.register("nudge", { type = "general", on = "You nudge." }, { physical = {
    def = true, balanceful_act = true, action = "alertness on",
    isadvisable = function() return false end, oncompleted = function() end, onstart = function() end } })
  eq(map()["alertness on"], alertness, "adopting: a command another action has stays that action's")
end

-- ===== 19. Patterns for lines that vary =====

-- A definition takes patterns next to its exact lines (the user,
-- 2026-10-11): vcustomdef <name> gotpattern, lostpattern and defpattern,
-- into the record's onr, offr and defr, as svof's own have. Only a pattern
-- Mudlet's rex library reads is taken, and the clash check runs them
-- against the class's other lines, other defences' patterns against the
-- definition's lines, and each against the definition's own lines of
-- another kind. Here rex is svof_world's stand-in, which reads only simple
-- patterns; none of this proves what PCRE does in Mudlet.
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  cmd("glint command glint")
  cmd("glint skillset kaido")
  cmd("glint gotpattern ^You glint at (\\w+)\\.$")
  eq(echoed(w, "Svof can't read patterns without Mudlet's rex library."), true,
    "patterns: without rex, none is taken")
  eq(svo.defences.custom_drafts.glint.onr, nil, "patterns: so the definition has none")

  w.env.rex = world.rex_stub
  cmd("glint gotpattern ^You glint at (\\w+\\.$")
  eq(echoed(w, "it isn't a pattern Svof can read"), true, "patterns: one rex can't read is refused")
  eq(svo.defences.custom_drafts.glint.onr, nil, "patterns: and isn't taken")
  cmd("glint gotpattern ^You glint at (\\w+)\\.$")
  local d = svo.defences.custom_drafts.glint
  eq(d.onr and d.onr[1], "^You glint at (\\w+)\\.$", "patterns: gotpattern adds a gain pattern")
  eq(row_echoed(w, "or matches:", "^You glint at (\\w+)\\.$"), true, "patterns: shown under the gain lines")
  eq(link_of(w, "add a pattern") ~= nil, true, "patterns: with a link to add one")
  cmd("glint test")
  eq(echoed(w, "It knows it's up from 1 pattern."), true, "patterns: a pattern alone says it's up")
  cmd("glint got You glint.")
  cmd("glint lostpattern ^Your glint at (\\w+) fades\\.$")
  cmd("glint defpattern ^You are glinting at (\\w+)\\.$")
  eq(d.offr[1] .. " | " .. d.defr[1], "^Your glint at (\\w+) fades\\.$ | ^You are glinting at (\\w+)\\.$",
    "patterns: lostpattern and defpattern add loss and DEF patterns")
  w.echoes = {}
  cmd("glint test")
  eq(echoed(w, "It knows it's up from 1 line and 1 pattern."), true, "patterns: next to exact lines")
  eq(echoed(w, "Without a DEF line"), false, "patterns: a DEF pattern is a DEF line")
  cmd("glint install")
  local rec = svo.defs_data.glint or {}
  eq(rec.on and rec.on[1], "You glint.", "patterns: installed, the exact line is the record's")
  eq((rec.onr or {})[1] .. " " .. (rec.offr or {})[1] .. " " .. (rec.defr or {})[1],
    "^You glint at (\\w+)\\.$ ^Your glint at (\\w+) fades\\.$ ^You are glinting at (\\w+)\\.$",
    "patterns: and the patterns its onr, offr and defr")
  local regex = {}
  for _, t in ipairs(w.triggers) do
    if t.kind == "regex" and not t.killed and t.pattern:find("glint", 1, true) then regex[#regex + 1] = t.code end
  end
  table.sort(regex)
  eq(table.concat(regex, ", "), "svo.defs.def_glint(), svo.defs.got_glint(), svo.defs.lost_glint()",
    "patterns: each a regex trigger calling its handler")
  w.run('svo.defences.custom_unset("glint", "offr", 1)')
  eq(#svo.defences.custom_drafts.glint.offr, 0, "patterns: x takes one out")
  cmd("glint def none")
  eq(svo.defences.custom_drafts.glint.defr, nil, "patterns: def none takes the DEF patterns too")

  -- the clash check
  cmd("shimmer command shimmer on")
  cmd("shimmer skillset kaido")
  cmd("shimmer gotpattern ^You prick up your \\w+\\.$")
  cmd("shimmer install")
  eq(echoed(w, "matches Svof's alertness's line \"You prick up your ears.\""), true,
    "patterns: one matching another defence's line is refused")
  eq(svo.defs_data.shimmer, nil, "patterns: and not installed")
  svo.defences.custom_drafts.shimmer.onr = nil
  cmd("shimmer got You glint at Bob.")
  cmd("shimmer install")
  eq(echoed(w, "your glint's pattern \"^You glint at (\\\\w+)\\\\.$\" matches \"You glint at Bob.\""), true,
    "patterns: a line another defence's pattern matches is refused")
  svo.defences.custom_drafts.shimmer.on = {}
  cmd("shimmer gotpattern ^You (\\w+) about\\.$")
  cmd("shimmer lost You stop about.")
  eq(svo.defences.custom_problem("shimmer", svo.defences.custom_drafts.shimmer),
    "its gain pattern \"^You (\\\\w+) about\\\\.$\" matches its own loss line \"You stop about.\"",
    "patterns: one matching the definition's own line of another kind is refused")

  -- a pattern a file brought in, not typed
  svo.defences.custom_drafts.shimmer = { class = "monk", skillset = "kaido", command = "shimmer on", on = {}, off = {},
    onr = { "^You shimmer (" } }
  local why = svo.defences.custom_problem("shimmer", svo.defences.custom_drafts.shimmer) or ""
  eq(why:sub(1, 67), "^You shimmer ( can't be a pattern: it isn't a pattern Svof can read",
    "patterns: one that came from a file is checked on install too")

  -- a change's new line, which svof's own patterns now check too
  cmd("treewatch got You glint at Ann.")
  cmd("treewatch install")
  eq(echoed(w, "change treewatch: your glint's pattern"), true,
    "patterns: a change's new line another defence's pattern matches is refused")
end

do -- a change to svof's own takes patterns too (the user, 2026-10-11)
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  w.env.rex = world.rex_stub
  local onr = svo.defs_data.shield.onr
  local own = type(onr) == "table" and onr[1] or onr
  local new ="^(\\w+)'s guardian surrounds you with a protective shield\\.$"
  cmd("shield")
  eq(row_echoed(w, "or matches:", own), true, "change patterns: the screen shows svof's gain pattern")
  w.run('svo.defences.custom_unset("shield", "onr", 1)')
  cmd("shield gotpattern ^(\\w+'s guardian")
  eq(echoed(w, "it isn't a pattern Svof can read"), true, "change patterns: one rex can't read is refused")
  cmd("shield gotpattern " .. new)
  eq(echoed(w, "Svof's: " .. own), true, "change patterns: and svof's next to a changed one")
  w.echoes = {}
  cmd("shield test")
  eq(echoed(w, "Your change replaces its gain patterns."), true, "change patterns: test says what the change replaces")
  w.run('svo.defences.edit_install("shield", true)')
  local rec = svo.defs_data.shield
  eq(table.concat(rec.onr, "|"), new, "change patterns: installed, the record's gain pattern is the change's")
  local live, old = false, false
  for _, t in ipairs(w.triggers) do
    if t.kind == "regex" and not t.killed and t.pattern == new then live = true end
    if t.kind == "regex" and not t.killed and t.pattern == own then old = true end
  end
  eq(live and not old, true, "change patterns: its trigger is made, and svof's is gone")
  local edit
  for _, names in pairs(svo.defences.edits) do edit = edit or names.shield end
  eq(edit and edit.onr and edit.onr[1] == new and edit.on == nil and edit.was.onr[1] == own, true,
    "change patterns: saved, with svof's as it was, and nothing else")

  reload(svo, "Monk")
  eq(svo.defs_data.shield.onr[1], new, "change patterns: in play as svof loads")
  edit.was.onr = { "^(\\w+)'s angel shields you\\.$" }
  reload(svo, "Monk")
  eq(echoed(w, "Svof has updated the gain patterns of its own shield since you changed it."), true,
    "change patterns: svof updating its own pattern says so")
  w.run('svo.defences.edit_reset("shield")')
  onr = svo.defs_data.shield.onr
  eq(type(onr) == "table" and onr[1] or onr, own, "change patterns: reset puts svof's pattern back")

  -- the clash check
  cmd("shield gotpattern ^You prick up your \\w+\\.$")
  w.run('svo.defences.edit_install("shield", true)')
  eq(echoed(w, "matches Svof's alertness's line \"You prick up your ears.\""), true,
    "change patterns: one matching another defence's line is refused")
  cmd("treewatch lostpattern ^You begin to keep .+\\.$")
  w.run('svo.defences.edit_install("treewatch", true)')
  eq(echoed(w, "its loss pattern \"^You begin to keep .+\\\\.$\" matches its own gain line"), true,
    "change patterns: one matching its own line of another kind is refused")

  -- import: one that can't be read is left out
  local old_attributes, old_load = w.env.lfs.attributes, w.env.table.load
  w.env.lfs.attributes = function() return {} end
  w.env.table.load = function(_, t)
    t._changes = { all = { skywatch = { onr = { "^You watch the (" }, was = { onr = {} } } } }
  end
  cmd("import shared-defences")
  w.env.lfs.attributes, w.env.table.load = old_attributes, old_load
  eq(echoed(w, "Didn't import the change to Svof's own skywatch from shared-defences: ^You watch the ( can't be a pattern"),
    true, "change patterns: import leaves out a change whose pattern can't be read")
end

do -- an item's defence registers after systemstart too
  local w = world.new({ class = "Infernal" })
  local svo = w.svo
  eq(svo.sys.input_to_actions["mindnet on"], nil, "adopting: an Infernal has no mindnet")
  svo.defences.enablemindnet()
  eq(svo.sys.input_to_actions["mindnet on"], svo.dict.mindnet.physical, "adopting: the phylactery's mindnet")
end

-- ===== 20. What a definition shares with svof's own by name =====

-- vshow server's choice (svo.serverignore) and GMCP's names (sstosvod,
-- svotossd) are by name in every class, so a copy of svof's own shares
-- them with svof's own. A change to svof's own goes on svof's own only.
do -- vshow server's choice stays svof's own's
  local w = world.new({ class = "Bard" })
  local svo = w.svo
  svo.setserverignore("acrobatics")
  -- a copy for every class saved as a Monk, which gives way here
  svo.defences.custom.acrobatics = { class = "all", command = "acrobatics on", gmcp = "acrobatics",
    on = { "You begin leaping and bouncing about, making it more difficult to hit you." }, off = {},
    copy = { from = "bard", was = {}, lines = {} } }
  svo.defences.custom_delete("acrobatics")
  eq(svo.serverignore.acrobatics, true, "sharing: deleting a copy leaves serverside raising svof's own")
end
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  eq(svo.serverignore.acrobatics, nil, "sharing: acrobatics left to Svof")
  svo.defences.copy_own("acrobatics", 1)
  svo.defences.customdef_command("acrobatics class all")
  svo.defences.customdef_command("acrobatics install")
  eq(svo.defences.custom.acrobatics ~= nil, true, "sharing: a copy for every class installed")
  eq(svo.serverignore.acrobatics, nil, "sharing: and it's left to Svof still")
end

do -- GMCP's name for svof's own comes back when a copy goes
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local ss, svod = svo.dict.sstosvod.acrobatics, svo.dict.svotossd.acrobatics
  eq(ss, "acrobatics", "sharing: GMCP's acrobatics is svof's in every class")
  svo.defences.copy_own("acrobatics", 1)
  cmd("acrobatics skillset kaido")
  cmd("acrobatics install")
  cmd("acrobatics delete")
  eq(svo.dict.sstosvod.acrobatics, ss, "sharing: deleting a copy leaves GMCP's acrobatics svof's")
  eq(svo.dict.svotossd.acrobatics, svod, "sharing: and svof's name for it")
  -- one GMCP name nothing had before goes with the definition
  cmd("shimmer command shimmer on")
  cmd("shimmer skillset kaido")
  cmd("shimmer got You shimmer.")
  svo.defences.gmcp_confirmed.shimmering = true -- as if the game confirmed it (section 16)
  cmd("shimmer gmcp shimmering")
  cmd("shimmer install")
  eq(svo.dict.sstosvod.shimmering, "shimmer", "sharing: a definition's own GMCP name")
  cmd("shimmer delete")
  eq(svo.dict.sstosvod.shimmering, nil, "sharing: goes when it does")
end

do -- a change saved for svof's own goes on svof's own only
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  eq(svo.defs_data.glimmer == nil and svo.defences.catalog().glimmer == nil, true, "sharing: no glimmer of svof's")
  svo.defences.edits = { monk = { glimmer = { on = { "Your old glimmer line." }, was = { on = { "x" } } } } }
  cmd("glimmer command glimmer")
  cmd("glimmer skillset kaido")
  cmd("glimmer got You begin to glimmer.")
  cmd("glimmer install")
  eq(table.concat(svo.defs_data.glimmer.on, "|"), "You begin to glimmer.", "sharing: a definition keeps its own lines")
  eq(w.line("Your old glimmer line."), 0, "sharing: and an old change's line isn't heard")
  reload(svo, "Monk")
  eq(table.concat(svo.defs_data.glimmer.on, "|"), "You begin to glimmer.", "sharing: as svof loads too")
end

do -- the commands svof takes for its own, in either case
  local w = world.new({ class = "Monk", paused = false })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function server(text)
    svo.conf.serverside = true
    svo.curingcommand(text)
    svo.conf.serverside = false
    local got = w.inflight()
    svo.killaction(svo.dict.sturdiness.physical)
    if svo.dict.shimmer then svo.killaction(svo.dict.shimmer.physical) end
    return got
  end
  local function typed(text)
    svo.cnrl.processusercommand(text)
    w.run_timers()
    local got = w.inflight()
    svo.killaction(svo.dict.sturdiness.physical)
    if svo.dict.shimmer then svo.killaction(svo.dict.shimmer.physical) end
    return got
  end
  cmd("sturdiness command Stand Firm")
  w.run('svo.defences.edit_install("sturdiness", true)')
  eq(server("STAND FIRM"), "sturdiness_physical", "case: a change's command, as serverside sends it")
  eq(typed("Stand Firm"), "sturdiness_physical", "case: and as the player typed it")
  w.run('svo.defences.edit_reset("sturdiness")')
  eq(svo.sys.input_to_actions["stand firm"], svo.dict.sturdiness.physical, "case: reset puts svof's back")
  eq(svo.sys.input_to_actions["Stand Firm"], nil, "case: and the change's goes")
  cmd("shimmer command Shimmer On")
  cmd("shimmer skillset kaido")
  cmd("shimmer got You shimmer.")
  cmd("shimmer install")
  eq(server("SHIMMER ON"), "shimmer_physical", "case: a definition's command, as serverside sends it")
  eq(typed("Shimmer On"), "shimmer_physical", "case: as the player typed it")
  eq(typed("shimmer on"), "shimmer_physical", "case: and in lower case")
end

do -- each pattern compiled once, not each time clash matches it
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local news, strings = 0, 0
  w.env.rex = {
    new = function(p) news = news + 1 return world.rex_stub.new(p) end,
    match = function(s, p) strings = strings + 1 return world.rex_stub.match(s, p) end,
  }
  for _, n in ipairs({ "glinta", "glintb" }) do
    cmd(n .. " command " .. n)
    cmd(n .. " skillset kaido")
    cmd(n .. " got You " .. n .. ".")
    cmd(n .. " gotpattern ^You " .. n .. " at (\\w+)\\.$")
    cmd(n .. " install")
  end
  news, strings = 0, 0
  local parts = { lines = { "You glintc." }, patterns = { { 'onr', "^You glintc at (\\w+)\\.$" } } }
  svo.defences.clash("glintc", parts)
  local first = news
  svo.defences.clash("glintc", parts)
  eq(strings, 0, "patterns: clash matches with compiled patterns")
  eq(first > 0 and news == first, true, "patterns: and compiles none again")
end

-- ===== 21. The saved priorities of defences svof leaves out =====

-- svof saves its priorities as it quits, from its dictionary, and loads
-- them as it starts. A definition vconfig customdefinitions off leaves
-- out, or one for another class, keeps its saved place for when it's
-- back, and so does a change to svof's own defence for another class
-- (live test, 2026-10-18: probealpha was 176 before a session with
-- definitions off, and 4 after), and every action svof has in another
-- class (defect 29). vcleargaps and vset there leave those places next to
-- the same actions.

-- the saved priorities, in a file the harness keeps instead of the disk
local function prio_file(w)
  local file, out = {}, nil
  local function serialize(t)
    local parts = {}
    for k, v in pairs(t) do parts[#parts + 1] = string.format("[%s] = %q", tostring(k), v) end
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  w.env.io.output = function(path) out = path return true end
  w.env.io.write = function(s) if out and out:find("/svo/prios/current$") then file.text = s end return true end
  w.env.io.input = function(path) file.reading = path end
  w.env.io.read = function()
    if file.reading:find("/svo/prios/current$") then return file.text end
    return world.read_file("src/resources/" .. file.reading:match("^%./svof/(.+)$"))
  end
  w.env.lfs.attributes = function(path)
    if path:find("/svo/prios/current$") then return file.text and {} or nil end
    if path == "./svof/default_prios" then return {} end
  end
  -- import runs the file with loadstring and setfenv, which Lua 5.2 and
  -- later don't have
  w.env.loadstring = w.env.loadstring or function(s, n) return load(s, n) end
  w.env.setfenv = w.env.setfenv or function(f, e) debug.setupvalue(f, 1, e) return f end
  -- export writes with pl.pretty, which the harness stubs, and Setup takes
  -- it again each time svof loads
  local pretty, req = { write = serialize }, w.env.require
  w.env.require = function(name) if name == "pl.pretty" then return pretty end return req(name) end
  w.svo.pl.pretty = pretty
  return file
end

-- starts svof again in the same class without the save as it quits: the
-- load alone
local function start(w)
  w.svo.dict = {}
  w.svo.systemloaded = false
  w.env.svo_init_system()
end

-- quits and starts svof again in the same class, as logging out and in
-- does: the save as it quits, then the load
local function relaunch(w)
  w.svo.signals.saveconfig:emit()
  start(w)
end

-- a balance of the saved list, number -> name
local function saved_list(file, balance)
  local t = {}
  local list = file.text and file.text:match("\n" .. balance .. " = (%b{})") or ""
  for num, name in list:gmatch('%[(%d+)%] = "([^"]+)"') do t[tonumber(num)] = name end
  return t
end

local function saved_at(file, balance, name)
  for num, n in pairs(saved_list(file, balance)) do
    if n == name then return num end
  end
end

-- the names of a number -> name list that wanted has, lowest first
local function in_order(list, wanted)
  local nums = {}
  for num, name in pairs(list) do if wanted[name] then nums[#nums + 1] = num end end
  table.sort(nums)
  for i, num in ipairs(nums) do nums[i] = list[num] end
  return table.concat(nums, " ")
end

-- an entry's place in slow curing, between the ones next to it
local function slow_place(svo, entry)
  local t = svo.make_sync_prio_table("%s_%s")
  local at, lo, hi
  for n, e in pairs(t) do if e == entry then at = n end end
  if not at then return "none" end
  for n in pairs(t) do
    if n < at and (not lo or n > lo) then lo = n end
    if n > at and (not hi or n < hi) then hi = n end
  end
  return tostring(t[lo]) .. " < " .. entry .. " < " .. tostring(t[hi])
end

do -- a session with definitions off
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local file = prio_file(w)
  local function at(n) return tostring(svo.prio.getaction(n, "physical")) end
  svo.defences.custom.shimmer = { class = "Monk", skillset = "tekura", command = "shimmer on",
    on = { "You begin to shimmer." } }
  relaunch(w)
  -- the places the player gave it, in the middle of each list. prio.insert
  -- can't put one in a slow curing gap, so it takes a number that's used
  svo.prio.insert("shimmer", "physical", 40)
  local sync, slow = svo.make_sync_prio_table("%s_%s"), 100
  while not sync[slow] do slow = slow + 1 end
  svo.prio.insert("shimmer_physical", "slowcuring", slow)
  local below, above, x, xbelow, xabove = at(39), at(41), at(60), at(59), at(61)
  local slowplace = slow_place(svo, "shimmer_physical")

  svo.conf.customdefinitions = false
  relaunch(w)
  eq(svo.dict.shimmer, nil, "priorities: with customdefinitions off, svof starts without shimmer")
  eq(at(40), "nil", "priorities: and its place is empty")
  relaunch(w)
  eq(saved_at(file, "physical", "shimmer"), 40, "priorities: the save as that session quits keeps shimmer's place")
  eq(saved_at(file, "slowcuring", "shimmer_physical") ~= nil, true, "priorities: and its slow curing one")

  svo.conf.customdefinitions = true
  relaunch(w)
  eq(svo.dict.shimmer and svo.dict.shimmer.physical.aspriority, 40,
    "priorities: with definitions on again, shimmer has its place back")
  eq(at(39) .. " " .. at(41), below .. " " .. above, "priorities: between the same two")
  -- each load moves every slow curing number up (dict_setup gives
  -- svo.dict.lovers.map one), and the kept place moves with them
  eq(slow_place(svo, "shimmer_physical"), slowplace, "priorities: and in slow curing")

  -- one the player put in its empty place moves up one, with the ones
  -- above it up to the gap that one left
  svo.conf.customdefinitions = false
  relaunch(w)
  svo.prio.insert(x, "physical", 40)
  relaunch(w)
  svo.conf.customdefinitions = true
  relaunch(w)
  eq(svo.dict.shimmer and svo.dict.shimmer.physical.aspriority, 40,
    "priorities: shimmer keeps its place when the player put another there")
  eq(at(41) .. " " .. at(42), x .. " " .. above, "priorities: which moves up one, and the next one too")
  eq(at(60) .. " " .. at(61), xbelow .. " " .. xabove, "priorities: up to the gap it left")

  -- svof's default priorities forget it, as they do every place
  svo.conf.customdefinitions = false
  relaunch(w)
  svo.prio.usedefault()
  relaunch(w)
  eq(saved_at(file, "physical", "shimmer"), nil, "priorities: going back to the default priorities forgets shimmer's place")

  -- and so does deleting it
  svo.conf.customdefinitions = true
  relaunch(w)
  svo.prio.insert("shimmer", "physical", 40)
  svo.conf.customdefinitions = false
  relaunch(w)
  svo.defences.custom_delete("shimmer")
  relaunch(w)
  eq(saved_at(file, "physical", "shimmer"), nil, "priorities: deleting a definition svof left out forgets its place")
end

do -- another class's definition and change
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local file = prio_file(w)
  svo.defences.custom.shimmer = { class = "Monk", skillset = "tekura", command = "shimmer on",
    on = { "You begin to shimmer." } }
  svo.defences.edits = { monk = { mindcloak = { notondef = true, was = {} } } }
  relaunch(w)
  local monk = svo.make_prio_table("physical")
  svo.classchange("Infernal")
  relaunch(w) -- the save as an Infernal quits
  local infernal = saved_list(file, "physical")
  -- the two, and the actions both classes have
  local wanted, inmonk = { shimmer = true, mindcloak = true }, {}
  for _, name in pairs(monk) do inmonk[name] = true end
  for _, name in pairs(infernal) do if inmonk[name] then wanted[name] = true end end
  eq(in_order(infernal, wanted), in_order(monk, wanted),
    "priorities: an Infernal's save keeps the Monk's definition and changed mindcloak in their places")
  eq(saved_at(file, "physical", "kaiboost") ~= nil, true,
    "priorities: and a Monk defence of svof's own the player didn't change (defect 29, fixed)")
  svo.classchange("Monk")
  eq(in_order(svo.make_prio_table("physical"), wanted), in_order(monk, wanted),
    "priorities: back as a Monk, both have their places")
end

do -- a class change and back keeps the last class's own (defect 29, fixed)
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local file = prio_file(w)
  relaunch(w)
  local balances = { "physical", "misc", "slowcuring" }
  local function lists()
    return { physical = svo.make_prio_table("physical"), misc = svo.make_prio_table("misc"),
      slowcuring = svo.make_sync_prio_table("%s_%s") }
  end
  local monk = lists()
  svo.classchange("Infernal")

  -- what the Monk has that an Infernal doesn't, by balance. Every class
  -- has a blind entry, and an Infernal's has no misc
  local monkonly = {}
  for _, b in ipairs(balances) do
    monkonly[b] = {}
    for _, name in pairs(monk[b]) do
      local a, bal = name, b
      if b == "slowcuring" then a, bal = name:match("(%w+)_(%w+)") end
      if not (svo.dict[a] and svo.dict[a][bal]) then monkonly[b][name] = true end
    end
  end
  eq(tostring(monkonly.physical.kaiboost) .. " " .. tostring(monkonly.physical.toughness) .. " "
    .. tostring(monkonly.physical.transmute) .. " " .. tostring(monkonly.misc.blind) .. " "
    .. tostring(monkonly.slowcuring.kaiboost_physical) .. " " .. tostring(monkonly.slowcuring.blind_misc),
    "true true true true true true",
    "class change: an Infernal has no kaiboost, toughness, transmute, blind misc or their slow curing")
  eq(svo.dict.blind ~= nil, true, "class change: but has a blind entry")

  -- the Monk's whole list, in the Monk's order, among the Infernal's
  relaunch(w) -- the save as an Infernal quits
  local all = {}
  for _, b in ipairs(balances) do
    all[b] = {}
    for _, name in pairs(monk[b]) do all[b][name] = true end
    eq(in_order(saved_list(file, b), all[b]), in_order(monk[b], all[b]),
      "class change: an Infernal's save keeps every " .. b .. " place the Monk had, in the Monk's order")
  end

  -- a name no class has is dropped, and so is one in a balance no class
  -- has it in. Each goes in above the highest number in its list, as one
  -- at a number the list has would be overwritten as the file loads
  local put = {}
  local function add(b, name)
    local top = 0
    for num in pairs(saved_list(file, b)) do top = math.max(top, num) end
    file.text = file.text:gsub("\n" .. b .. " = {", string.format('\n%s = {[%d] = "%s", ', b, top + 1, name), 1)
    put[#put + 1] = { b, top + 1, name }
  end
  add("physical", "nosuchaction")
  add("misc", "kaiboost")
  add("slowcuring", "nosuchaction_physical")
  add("slowcuring", "kaiboost_misc")
  local there = {}
  for i, p in ipairs(put) do there[i] = tostring(saved_list(file, p[1])[p[2]]) end
  eq(table.concat(there, " "), "nosuchaction kaiboost nosuchaction_physical kaiboost_misc",
    "class change: the saved file has the names put in it")
  start(w)
  relaunch(w)
  local function where(b, name) return tostring((saved_at(file, b, name))) end
  eq(where("physical", "nosuchaction") .. " " .. where("slowcuring", "nosuchaction_physical"), "nil nil",
    "class change: a name no class has is dropped")
  eq(where("misc", "kaiboost") .. " " .. where("slowcuring", "kaiboost_misc"), "nil nil",
    "class change: and so is one in a balance no class has it in")
  eq(saved_at(file, "physical", "kaiboost") ~= nil, true, "class change: while the Monk's kaiboost stays")

  -- back as a Monk, every list is the Monk's again, in the Monk's order
  svo.classchange("Monk")
  local back = lists()
  for _, b in ipairs(balances) do
    eq(in_order(back[b], all[b]) .. " | " .. count(back[b]), in_order(monk[b], all[b]) .. " | " .. count(monk[b]),
      "class change: back as a Monk, " .. b .. " is as the Monk left it")
  end
end

do -- what the player does in another class leaves the last class's places
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local file = prio_file(w)
  relaunch(w)
  -- two empty numbers below kaiboost, which vcleargaps closes as well
  local kat = svo.dict.kaiboost.physical.aspriority
  for _, entry in pairs(svo.dict) do
    local p = type(entry) == "table" and entry.physical
    if type(p) == "table" and p.aspriority and p.aspriority >= kat then p.aspriority = p.aspriority + 2 end
  end
  local monk = svo.make_prio_table("physical")
  eq(tostring(monk[kat]) .. " " .. tostring(monk[kat + 1]) .. " " .. tostring(monk[kat + 2]), "nil nil kaiboost",
    "another class: two empty numbers below kaiboost")
  local all = {}
  for _, name in pairs(monk) do all[name] = true end

  svo.classchange("Infernal")
  svo.showprompt = function() end -- vcleargaps shows the prompt
  svo.prio.cleargaps("physical")
  relaunch(w)
  svo.classchange("Monk")
  local back = svo.make_prio_table("physical")
  eq(in_order(back, all), in_order(monk, all), "another class: vcleargaps there keeps the Monk's order")

  -- the player moves the nearest action below kaiboost an Infernal has to
  -- the bottom of an Infernal's list, and kaiboost doesn't go with it
  kat = svo.dict.kaiboost.physical.aspriority
  svo.classchange("Infernal")
  local below, at
  for n, a in pairs(back) do
    if n < kat and svo.dict[a] and svo.dict[a].physical and (not at or n > at) then below, at = a, n end
  end
  svo.prio.insert(below, "physical", 1)
  local lowest
  for n in pairs(svo.make_prio_table("physical")) do lowest = math.min(lowest or n, n) end
  eq(svo.prio.getaction(lowest, "physical"), below,
    "another class: the action below kaiboost is at the bottom of an Infernal's list")
  relaunch(w)
  svo.classchange("Monk")
  local others = {}
  for name in pairs(all) do others[name] = name ~= below or nil end
  eq(in_order(svo.make_prio_table("physical"), others), in_order(back, others),
    "another class: moving it there leaves the Monk's own where they were")
end

do -- the last class's own at the bottom of the list, vcleargaps in another
  -- (live test, 2026-10-19: a Magi's own, Monk and back, came back turned
  -- over)
  local w = world.new({ class = "Magi" })
  local svo = w.svo
  prio_file(w)
  relaunch(w)
  -- every action only some classes have to the bottom, in its order, so
  -- nothing svof keeps in a Monk's list is below them
  local list, own = svo.make_prio_table("physical"), {}
  local nums = {}
  for n, name in pairs(list) do
    if svo.prio.catalog().physical[name] then nums[#nums + 1] = n end
  end
  table.sort(nums, function(a, b) return a > b end)
  for _, n in ipairs(nums) do svo.prio.insert(list[n], "physical", 1) end
  -- and a wide gap above them, as the profile's own list had, which
  -- vcleargaps closes: the nearest place above moves far down
  for _, entry in pairs(svo.dict) do
    local p = type(entry) == "table" and entry.physical
    if type(p) == "table" and p.aspriority and p.aspriority > #nums then p.aspriority = p.aspriority + 100 end
  end
  local magi = svo.make_prio_table("physical")
  for _, name in pairs(magi) do own[name] = true end
  eq(#nums > 10 and svo.prio.catalog().physical[svo.prio.getaction(1, "physical")] == true, true,
    "bottom: the Magi's own at the bottom of the list")
  relaunch(w)
  svo.classchange("Monk")
  svo.showprompt = function() end -- vcleargaps shows the prompt
  svo.prio.cleargaps("physical")
  svo.classchange("Magi")
  local back, lowest = svo.make_prio_table("physical"), nil
  for n in pairs(back) do lowest = math.min(lowest or n, n) end
  eq(in_order(back, own), in_order(magi, own),
    "bottom: vcleargaps in a Monk leaves the Magi's own in their order")
  eq(lowest, 1, "bottom: and the lowest of them at 1")
end

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
