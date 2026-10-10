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
    stoneward = { class = "Infernal", command = "stoneward" },  -- another class's
  }
  svo.defdefup.basic.shimmer = true -- a choice saved last session
  svo.classchange("Infernal")
  eq(svo.defs_data.warded ~= nil and svo.defs_data.stoneward ~= nil, true,
    "custom defences: as an Infernal, the all-class one and the Infernal's are registered")
  eq(svo.defs_data.shimmer, nil, "custom defences: and not the Monk's")
  eq(svo.dict.rebounding.smoke ~= nil and svo.defs_data.rebounding.type, "general",
    "custom defences: a name svof uses is refused, and svof's own rebounding stays")
  eq(echoed(w, "Svof has its own rebounding now, so the one you defined isn't used."), true,
    "custom defences: and says so")

  svo.classchange("Monk")
  local rec, entry = svo.defs_data.shimmer, svo.dict.shimmer
  eq(rec and rec.type, "custom", "custom defences: as a Monk, shimmer is registered, as a custom defence")
  eq(entry and entry.physical.action, "shimmer on", "custom defences: raised with its command")
  eq(entry and entry.physical.balanceful_act, true, "custom defences: taking balance unless balanceless")
  eq(entry and entry.physical.undeffable, true, "custom defences: and raised by svof, not serverside, unless it says so")
  local warded = svo.dict.warded and svo.dict.warded.physical or {}
  eq(warded.balanceless_act, true, "custom defences: warded takes no balance")
  eq(warded.undeffable, nil, "custom defences: and serverside may raise it")
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
  local typed = false
  for _, l in ipairs(w.links) do
    if l:find('printCmdLine("vcustomdef shimmer command ")', 1, true) then typed = true end
  end
  eq(typed, true, "customdef: its change links type a vcustomdef command")
  eq(d and d.class, "monk", "customdef: for the class you are in")
  cmd("shimmer got You begin to shimmer.")
  cmd("shimmer lost You stop shimmering.")
  cmd("shimmer def You are shimmering.")
  cmd("shimmer gmcp shimmering")
  cmd("shimmer test")
  eq(echoed(w, "It's ready to install."), true, "customdef: test says it is ready")
  eq(svo.defs_data.shimmer, nil, "customdef: a draft changes nothing in play")

  local writes = #w.writes
  cmd("shimmer install")
  eq(svo.defs_data.shimmer and svo.defs_data.shimmer.type, "custom", "customdef: install registers it")
  eq(svo.dict.sstosvod.shimmering, "shimmer", "customdef: with its GMCP name")
  eq(#w.writes > writes, true, "customdef: and saves the definitions")
  eq(custom.custom_drafts.shimmer, nil, "customdef: the draft is done with")
  if svo.dict.shimmer then svo.doaction(svo.dict.shimmer.physical) end
  w.line("You begin to shimmer.")
  w.prompt()
  eq(svo.defc.shimmer, true, "customdef: its gain line works at once")

  -- changing it: only install puts the change into play, without piling up triggers
  local triggers = live("shimmer")
  cmd("shimmer command shimmer up")
  eq(svo.dict.shimmer and svo.dict.shimmer.physical.action, "shimmer on", "customdef: a change waits for install")
  custom.custom_unset("shimmer", "on", 1)
  cmd("shimmer got You shimmer brightly.")
  cmd("shimmer install")
  eq(svo.dict.shimmer and svo.dict.shimmer.physical.action, "shimmer up", "customdef: installing again uses the change")
  eq(live("shimmer"), triggers, "customdef: with the old triggers killed")
  eq(w.line("You begin to shimmer."), 0, "customdef: the line taken out is no longer heard")
  eq(w.line("You shimmer brightly."), 1, "customdef: and the new one is")

  -- svof's own names are refused (the user's choice), and an incomplete one can't install
  cmd("rebounding")
  eq(echoed(w, "define rebounding: Svof already has a defence or action called rebounding."), true,
    "customdef: svof's own name is refused")
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

  -- another class's
  cmd("stoneskin class Infernal")
  cmd("stoneskin command stoneskin")
  cmd("stoneskin got Your skin turns to stone.")
  cmd("stoneskin install")
  eq(echoed(w, "Saved stoneskin. It's for infernal, so Svof adds it when you're one."), true,
    "customdef: one for another class is saved, not added")
  eq(svo.defs_data.stoneskin, nil, "customdef: as a Monk it isn't registered")
  svo.classchange("Infernal")
  eq(svo.defs_data.stoneskin and svo.defs_data.stoneskin.type, "custom", "customdef: as an Infernal it is")
  eq(svo.defs_data.shimmer, nil, "customdef: and the Monk's isn't")
  svo.classchange("Monk")
  eq(svo.dict.shimmer and svo.dict.shimmer.physical.action, "shimmer up", "customdef: back as a Monk, shimmer is")

  -- the list, each a link to see and change it: vcustomdef alone, which
  -- captures nothing
  local links = #w.links
  w.env.matches = { "vcustomdef" }
  w.run(script, "vcustomdef")
  eq(echoed(w, "Defences you defined (click one to see or change it):"), true, "customdef: vcustomdef lists them")
  local shows, game, new = false, false, false
  for i = links + 1, #w.links do
    if w.links[i]:find('svo.defences.custom_show("shimmer")', 1, true) then shows = true end
    if w.links[i]:find("svo.defences.custom_gamelist()", 1, true) then game = true end
    if w.links[i]:find("printCmdLine('vcustomdef ')", 1, true) then new = true end
  end
  eq(shows, true, "customdef: each a link to see and change it")
  eq(game, true, "customdef: and a link to the game's defences Svof doesn't know")
  eq(new, true, "customdef: and one that types vcustomdef, to define a new one")
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

-- For a defence the game knows, DEFENCE SHOW gives its lines and GMCP name
-- (the reply's layout is the owner's capture, 2026-10-09)
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function game(text) w.env.line = text svo.defences.custom_fetch_line() end
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
  eq(listening(), false, "DEFENCE SHOW: and stops reading lines")

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
end

-- DEFENCE LIST names every defence the game reports, a page at a time, and
-- vcustomdef game shows the ones Svof doesn't track
do
  local w = world.new({ class = "Monk" })
  local svo = w.svo
  local cmd = svo.defences.customdef_command
  local function game(text) w.env.line = text svo.defences.custom_gamelist_line() end
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

  -- no list at all
  cmd("game")
  w.advance(20)
  eq(echoed(w, "The game didn't send its list of defences."), true, "DEFENCE LIST: says when nothing came")
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
  showhidelist()
  local text = table.concat(shown)
  local general = text:match("General defences:(.-) defences:") or ""
  eq(general:find("deathsight", 1, true), nil, "hide list: an Apostate's deathsight isn't listed as general")
  eq((text:match("Necromancy defences:(.-) defences:") or text:match("Necromancy defences:(.*)") or ""):find("deathsight", 1, true) ~= nil,
    true, "hide list: it's listed under Necromancy")
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

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
