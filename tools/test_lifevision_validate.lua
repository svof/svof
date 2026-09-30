--[[
Logic-level regression test for svo.lifevision.validate() in
`src/scripts/svo (curing skeleton, controllers, action system)/Curing_skeleton.lua`.

Same approach as tools/test_gmcp_reconciler.lua: the code under test is
extracted from the real source file by anchor text and executed in a stub
environment, so it is a substring of what ships rather than a
reimplementation, and the test fails loudly if the anchors move instead of
silently testing stale logic.

What it covers: that discarding a paragraph as an illusion still records the
balance a consumable cure spent. svof sent the command and the item left the
rift; an illusion can lie about what the cure did, but it cannot un-eat the
herb. Dropping that bookkeeping left bals.<balance> true while actionclear()
freed bals_in_use, so svof re-sent the cure on the next prompt, outran GMCP
item tracking, failed the same illusion check, and looped without recovering.

And the GMCP gate in run_through_actions: a claim GMCP contradicts, gained or
gone, is cleared instead of run, every other claim runs as before, and
diagnose and blackout-onset paragraphs are left alone and marked trusted for
the add and remove backstops while their claims run. Whether GMCP contradicts
a claim is decided by svo.gmcp_refuted_claim and svo.gmcp_kept_claim in
Setup.lua, which are stubbed here and tested in tools/test_gmcp_reconciler.lua
against the real code.

And what lifevision tells svo.gmcp_overlooked (Setup.lua, also stubbed here and
tested against the real code in the reconciler suite): lifevision.add marks a
claim as the game's answer to a command svof sent, or as confirmed by svof's
own symptom counters, a refused claim GMCP overlooks runs with GMCP set aside,
and the add backstop is told which claim is running.

It proves nothing about Mudlet integration or real combat.

Run: lua tools/test_lifevision_validate.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local SRC = "src/scripts/svo (curing skeleton, controllers, action system)/Curing_skeleton.lua"

local START_ANCHOR = "local function answer_to(act)"
local END_ANCHOR = "  sys.lineguard = false\nend"

-- svof's own symptom counters, whose confirmations are believed where GMCP is
-- silent (scenario 21)
local COUNTERS_START_ANCHOR = "-- The symptom counters below are svof's own check against illusions"
local COUNTERS_END_ANCHOR = "sk.unparryable_count = 0"

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return data
end

local function extract_block(source)
  local s = source:find(START_ANCHOR, 1, true)
  if not s then
    error("start anchor not found in " .. SRC .. " - answer_to, above lifevision.add, moved or was reworded; update this test's anchors")
  end
  local e = source:find(END_ANCHOR, s, true)
  if not e then
    error("end anchor not found in " .. SRC .. " after the start anchor - validate() changed shape; update this test's anchors")
  end
  return source:sub(s, e + #END_ANCHOR)
end

-- ===== assertion plumbing =====

local failures, checks = {}, 0

local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local function contains(list, value, label)
  checks = checks + 1
  for _, v in ipairs(list) do if v == value then return end end
  failures[#failures + 1] = string.format("%s: %s not found in [%s]", label, tostring(value), table.concat(list, ", "))
end

local function not_contains(list, value, label)
  checks = checks + 1
  for _, v in ipairs(list) do
    if v == value then
      failures[#failures + 1] = string.format("%s: %s unexpectedly present in [%s]", label, tostring(value), table.concat(list, ", "))
      return
    end
  end
end

-- ===== stub environment =====

-- Minimal stand-in for the Penlight OrderedMap that svo.lifevision.l is.
-- iter() yields key, value in insertion order, and a queued claim can be read
-- by its key (svo.lifevision.l.diag_physical), because Penlight stores each
-- value as a plain field of the map.
local function ordered_map()
  local m = {keys = {}, vals = {}}
  function m:set(k, v)
    if self.vals[k] == nil then self.keys[#self.keys + 1] = k end
    self.vals[k] = v
  end
  function m:iter()
    local i = 0
    return function()
      i = i + 1
      local k = self.keys[i]
      if k == nil then return nil end
      return k, self.vals[k]
    end
  end
  return setmetatable(m, {__index = function(t, k) return rawget(t, 'vals')[k] end})
end

local function new_environment()
  local calls = {cleared = {}, finished = {}, lostbal = {}, debugf = {}, echof = {}, asked = {}, trust = {},
    overlooked = {}, claim = {}}

  local sys = {flawedillusion = false, not_illusion = false, lineguard = false}
  local conf = {batch = false, gmcpaffechoes = false}
  local sk = {stopprocessing = nil, sawcuring = function() return false end}
  local me = {haveillusion = false}

  local svo = {}
  svo.lifevision = {}
  svo.pl = {OrderedMap = ordered_map}
  svo.paragraph_length = 1

  function svo.debugf(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    calls.debugf[#calls.debugf + 1] = ok and msg or fmt
  end
  function svo.echof(fmt, ...) calls.echof[#calls.echof + 1] = string.format(fmt, ...) end

  function svo.actionclear(act) calls.cleared[#calls.cleared + 1] = act.name end
  -- also records whether the add and remove backstops were told to trust the
  -- paragraph while this claim ran, and which claim they were told is running
  function svo.actionfinished(act)
    calls.finished[#calls.finished + 1] = act.name
    calls.trust[act.name] = sk.gmcp_stands_aside or false
    calls.claim[act.name] = sk.gmcp_claim or false
  end

  -- the commands svof sent, by action name, as svo.actions holds them
  svo.actions = {}

  -- The GMCP side, stubbed: GMCP is not live unless a scenario says so, which
  -- leaves every scenario above the gate ones exactly as it was. A scenario
  -- lists, by claim name, the gains GMCP contradicts in svo.gmcp_refuted and
  -- the losses it contradicts in svo.gmcp_kept.
  svo.gmcp_is_live = false
  svo.gmcp_refuted = {}
  svo.gmcp_kept = {}
  function svo.gmcp_live() return svo.gmcp_is_live end
  function svo.gmcp_refuted_claim(claim)
    calls.asked[#calls.asked + 1] = claim.p.name
    return svo.gmcp_refuted[claim.p.name]
  end
  function svo.gmcp_kept_claim(claim)
    calls.asked[#calls.asked + 1] = claim.p.name
    return svo.gmcp_kept[claim.p.name]
  end
  -- which refused afflictions GMCP overlooks, by affliction
  svo.gmcp_believed = {}
  function svo.gmcp_overlooked(aff, claim)
    calls.overlooked[#calls.overlooked + 1] = aff
    return svo.gmcp_believed[aff] or false
  end
  function svo.gmcp_set_aside(f, ...)
    local was = sk.gmcp_stands_aside
    sk.gmcp_stands_aside = true
    f(...)
    sk.gmcp_stands_aside = was
  end

  -- Record every lostbal_* the code under test reaches for.
  for _, balance in ipairs({'herb', 'salve', 'sip', 'smoke', 'moss', 'purgative',
                            'focus', 'tree', 'shrugging', 'fitness', 'rage'}) do
    svo['lostbal_' .. balance] = function()
      calls.lostbal[#calls.lostbal + 1] = balance
    end
  end

  local env = {
    svo = svo, sys = sys, conf = conf, sk = sk, me = me,
    -- Mudlet screen functions the block calls; inert here.
    moveCursor = function() end,
    moveCursorEnd = function() end,
    getLineNumber = function() return 10 end,
    getCurrentLine = function() return "" end,
    insertLink = function() end,
    -- a command's stopwatch reads how long ago it was sent
    getStopWatchTime = function(watch) return watch end,
    -- stdlib
    string = string, table = table, pairs = pairs, ipairs = ipairs,
    type = type, tostring = tostring, tonumber = tonumber, error = error,
    pcall = pcall, next = next, unpack = unpack,
  }
  env._G = env

  return env, calls, svo, sys, sk, conf
end

-- Mudlet runs Lua 5.1, where load() takes a reader function and only
-- loadstring() takes a source string, with the environment applied separately
-- via setfenv. 5.2+ folded both into load(). Branch on setfenv rather than
-- assume whichever lua is on PATH is the one this has to work under.
local function load_block(block, env)
  local chunk, err
  if setfenv then
    chunk, err = loadstring(block, "validate_under_test")
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(block, "validate_under_test", "t", env)
  end
  if not chunk then error("failed to load extracted block: " .. tostring(err)) end
  local ok, runerr = pcall(chunk)
  if not ok then error("failed to execute extracted block: " .. tostring(runerr)) end
end

-- Queue one action into svo.lifevision.l the way lifevision.add does.
local function queue(svo, name, balance)
  svo.lifevision.l:set(name, {p = {name = name, balance = balance}})
end

local source = read_file(SRC)
local block = extract_block(source)
print("extracted " .. #block .. " bytes of Curing_skeleton.lua between the validate() anchors")

-- ===== scenario 1: illusion with a herb cure queued =====
do
  local env, calls, svo, sys = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'relapsing_herb', 'herb')
  sys.flawedillusion = true

  svo.lifevision.validate()

  contains(calls.cleared, 'relapsing_herb', "illusion: the action is still cleared")
  eq(#calls.finished, 0, "illusion: the action is not completed")
  contains(calls.lostbal, 'herb', "illusion: herb balance is still recorded as spent (the loop fix)")
  eq(#calls.lostbal, 1, "illusion: exactly one balance recorded")
end

-- ===== scenario 2: two herb actions in one paragraph record the balance once =====
do
  local env, calls, svo, sys = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'relapsing_herb', 'herb')
  queue(svo, 'illness_herb', 'herb')
  sys.flawedillusion = true

  svo.lifevision.validate()

  eq(#calls.cleared, 2, "illusion: both actions cleared")
  eq(#calls.lostbal, 1, "illusion: herb balance recorded once, not once per action")
  contains(calls.lostbal, 'herb', "illusion: the balance recorded is herb")
end

-- ===== scenario 3: non-consumable actions record nothing =====
do
  local env, calls, svo, sys = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'illness_aff', 'aff')
  queue(svo, 'deaf_gone', 'gone')
  queue(svo, 'waitingondeaf_waitingfor', 'waitingfor')
  sys.flawedillusion = true

  svo.lifevision.validate()

  eq(#calls.cleared, 3, "illusion: all three cleared")
  eq(#calls.lostbal, 0, "illusion: an aff/gone/waitingfor action spends no consumable balance")
end

-- ===== scenario 4: mixed paragraph records each consumable balance once =====
-- All six consumable_balances entries, not three: salve, smoke and purgative
-- had no scenario at all, so any of them could be dropped from the literal
-- in Curing_skeleton.lua with the suite still green - and the dictionary
-- defines far more of them (45 salve, 13 smoke, 5 purgative sub-entries)
-- than of the ones that were covered.
do
  local env, calls, svo, sys = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'illness_aff', 'aff')
  queue(svo, 'relapsing_herb', 'herb')
  queue(svo, 'torntendons_sip', 'sip')
  queue(svo, 'healhealth_moss', 'moss')
  queue(svo, 'crippledleftarm_salve', 'salve')
  queue(svo, 'asthma_smoke', 'smoke')
  queue(svo, 'vomiting_purgative', 'purgative')
  sys.flawedillusion = true

  svo.lifevision.validate()

  eq(#calls.cleared, 7, "illusion: every action cleared")
  contains(calls.lostbal, 'herb', "illusion: herb recorded")
  contains(calls.lostbal, 'sip', "illusion: sip recorded")
  contains(calls.lostbal, 'moss', "illusion: moss recorded")
  contains(calls.lostbal, 'salve', "illusion: salve recorded")
  contains(calls.lostbal, 'smoke', "illusion: smoke recorded")
  contains(calls.lostbal, 'purgative', "illusion: purgative recorded")
  not_contains(calls.lostbal, 'aff', "illusion: 'aff' is not a balance to spend")
  eq(#calls.lostbal, 6, "illusion: exactly the six consumable balances")
end

-- ===== scenario 5: the normal path is untouched =====
do
  local env, calls, svo, sys = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'relapsing_herb', 'herb')
  sys.flawedillusion = false
  sys.lineguard = false

  svo.lifevision.validate()

  contains(calls.finished, 'relapsing_herb', "no illusion: the action completes normally")
  eq(#calls.cleared, 0, "no illusion: nothing is cleared")
  eq(#calls.lostbal, 0, "no illusion: validate() records no balance itself - the action's completed handler does that")
end

-- ===== scenario 6: a cancelled illusion also takes the normal path =====
do
  local env, calls, svo, sys = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'relapsing_herb', 'herb')
  sys.flawedillusion = true
  sys.not_illusion = "script override"

  svo.lifevision.validate()

  contains(calls.finished, 'relapsing_herb', "cancelled illusion: the action completes normally")
  eq(#calls.cleared, 0, "cancelled illusion: nothing is cleared")
  eq(#calls.lostbal, 0, "cancelled illusion: validate() records no balance itself")
end

-- ===== scenario 7: a lineguard discard records the balance too =====
do
  local env, calls, svo, sys = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'relapsing_herb', 'herb')
  -- not a flawed illusion - the paragraph was simply longer than allowed
  sys.flawedillusion = false
  sys.lineguard = 1
  svo.paragraph_length = 5

  svo.lifevision.validate()

  contains(calls.cleared, 'relapsing_herb', "lineguard: the action is cleared")
  contains(calls.lostbal, 'herb', "lineguard: herb balance is still recorded as spent")
end

-- ===== scenario 8: state is reset for the next paragraph =====
do
  local env, calls, svo, sys, sk = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'relapsing_herb', 'herb')
  sys.flawedillusion = true
  sk.stopprocessing = true

  svo.lifevision.validate()

  eq(sys.flawedillusion, false, "after validate: flawedillusion cleared")
  eq(sys.lineguard, false, "after validate: lineguard cleared")
  eq(sk.stopprocessing, nil, "after validate: stopprocessing cleared")
end

-- ===== scenario 9: GMCP gate - a contradicted claim is dropped, the rest run =====
-- The live case that motivated the gate: a shield strike to the ribs claimed
-- sensitivity while GMCP reported only "Remove deafness", and the claim that
-- should have been cancelled ran anyway.
do
  local env, calls, svo, sys, sk, conf = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'sensitivity_aff', 'aff')
  queue(svo, 'prone_aff', 'aff')
  queue(svo, 'relapsing_herb', 'herb')
  svo.gmcp_is_live = true
  svo.gmcp_refuted = {sensitivity_aff = 'sensitivity'}
  conf.gmcpaffechoes = true

  svo.lifevision.validate()

  contains(calls.cleared, 'sensitivity_aff', "gate: a claim GMCP contradicts is cleared")
  not_contains(calls.finished, 'sensitivity_aff', "gate: and never runs")
  contains(calls.finished, 'prone_aff', "gate: a claim GMCP agrees with runs as before")
  contains(calls.finished, 'relapsing_herb', "gate: a cure in the same paragraph runs as before")
  eq(#calls.cleared, 1, "gate: nothing else is cleared")
  eq(calls.echof[1], "Ignored a line claiming sensitivity: GMCP doesn't report it.", "gate: the refusal is echoed with gmcpaffechoes on")
  eq(#calls.lostbal, 0, "gate: dropping a claim spends no balance")
end

-- ===== scenario 10: the echo follows gmcpaffechoes =====
do
  local env, calls, svo = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'sensitivity_aff', 'aff')
  svo.gmcp_is_live = true
  svo.gmcp_refuted = {sensitivity_aff = 'sensitivity'}

  svo.lifevision.validate()

  contains(calls.cleared, 'sensitivity_aff', "gate, echoes off: the claim is still dropped")
  eq(#calls.echof, 0, "gate, echoes off: nothing is echoed")
end

-- ===== scenario 11: GMCP not live - nothing is asked, everything runs =====
-- Before the login List, in blackout, and after a blackout until a diagnose
-- resyncs, the triggers decide as they always did.
do
  local env, calls, svo = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'sensitivity_aff', 'aff')
  svo.gmcp_is_live = false
  svo.gmcp_refuted = {sensitivity_aff = 'sensitivity'}

  svo.lifevision.validate()

  contains(calls.finished, 'sensitivity_aff', "not live: the claim runs")
  eq(#calls.asked, 0, "not live: GMCP is not consulted at all")
end

-- ===== scenario 12: a diagnose paragraph is left alone =====
-- A diagnose is the game's own list and can name a hidden affliction GMCP
-- never sent, so its claims must run even where GMCP disagrees.
do
  local env, calls, svo = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'diag_physical', 'physical')
  queue(svo, 'paralysis_aff', 'aff')
  svo.gmcp_is_live = true
  svo.gmcp_refuted = {paralysis_aff = 'paralysis'}

  svo.lifevision.validate()

  contains(calls.finished, 'paralysis_aff', "diagnose: a claim GMCP has not confirmed still runs")
  contains(calls.finished, 'diag_physical', "diagnose: the diagnose itself completes")
  eq(#calls.asked, 0, "diagnose: GMCP is not consulted")
end

-- ===== scenario 13: the paragraph blackout starts in is left alone =====
-- GMCP has already gone quiet by the time the blackout prompt arrives.
do
  local env, calls, svo = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'blackout_aff', 'aff')
  queue(svo, 'asthma_aff', 'aff')
  svo.gmcp_is_live = true
  svo.gmcp_refuted = {asthma_aff = 'asthma'}

  svo.lifevision.validate()

  contains(calls.finished, 'blackout_aff', "blackout onset: blackout is gained")
  contains(calls.finished, 'asthma_aff', "blackout onset: a claim GMCP never confirmed still runs")
  eq(#calls.asked, 0, "blackout onset: GMCP is not consulted")
end

-- ===== scenario 14: stopprocessing still wins over the gate =====
-- A claim that sets sk.stopprocessing (checkstun freezing a paragraph) clears
-- everything after it; the gate must not bring a cleared claim back or ask
-- GMCP about it.
do
  local env, calls, svo, sys, sk = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'prone_aff', 'aff')
  queue(svo, 'asthma_aff', 'aff')
  svo.gmcp_is_live = true
  sk.stopprocessing = true

  svo.lifevision.validate()

  eq(#calls.finished, 0, "stopprocessing: nothing runs")
  eq(#calls.cleared, 2, "stopprocessing: both claims are cleared")
  eq(#calls.asked, 0, "stopprocessing: GMCP is not consulted about cleared claims")
end

-- ===== scenario 15: GMCP gate - a "gone" claim GMCP contradicts is dropped =====
-- A wore-off line or a passive cure for an affliction GMCP still reports.
do
  local env, calls, svo, sys, sk, conf = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'asthma_gone', 'gone')
  queue(svo, 'prone_gone', 'gone')
  svo.gmcp_is_live = true
  svo.gmcp_kept = {asthma_gone = 'asthma'}
  conf.gmcpaffechoes = true

  svo.lifevision.validate()

  contains(calls.cleared, 'asthma_gone', "gone gate: a claim GMCP contradicts is cleared")
  not_contains(calls.finished, 'asthma_gone', "gone gate: and never runs")
  contains(calls.finished, 'prone_gone', "gone gate: a claim GMCP agrees with runs as before")
  eq(calls.echof[1], "Ignored a line saying asthma is gone: GMCP still reports it.", "gone gate: the refusal is echoed")
end

-- ===== scenario 16: the backstops are told which paragraphs to trust =====
-- svo.addaffdict and svo.rmaff read sk.gmcp_stands_aside, so it has to be set
-- while a diagnose's or a blackout onset's claims run, and nowhere else.
do
  local env, calls, svo, sys, sk = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'diag_physical', 'physical')
  queue(svo, 'paralysis_aff', 'aff')
  svo.gmcp_is_live = true

  svo.lifevision.validate()

  eq(calls.trust.paralysis_aff, true, "trust: set while a diagnose paragraph's claims run")
  eq(sk.gmcp_stands_aside, nil, "trust: cleared once the paragraph is done")
end

do
  local env, calls, svo, sys, sk = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'blackout_aff', 'aff')
  svo.gmcp_is_live = true

  svo.lifevision.validate()

  eq(calls.trust.blackout_aff, true, "trust: set while a blackout onset's claims run")
end

do
  local env, calls, svo, sys, sk = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'paralysis_aff', 'aff')
  svo.gmcp_is_live = true

  svo.lifevision.validate()

  eq(calls.trust.paralysis_aff, false, "trust: not set for an ordinary paragraph")
end

-- ===== scenario 17: a refused claim GMCP overlooks runs with GMCP set aside =====
-- A hidden affliction's symptom: the game hid it, so GMCP's silence proves
-- nothing (svo.gmcp_overlooked, tested against the real code in the
-- reconciler suite, decides; here it is stubbed).
do
  local env, calls, svo, sys, sk, conf = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'slickness_aff', 'aff')
  queue(svo, 'sensitivity_aff', 'aff')
  svo.gmcp_is_live = true
  svo.gmcp_refuted = {slickness_aff = 'slickness', sensitivity_aff = 'sensitivity'}
  svo.gmcp_believed = {slickness = true}
  conf.gmcpaffechoes = true

  svo.lifevision.validate()

  contains(calls.overlooked, 'slickness', "overlooked: GMCP's check is asked about a refused claim")
  contains(calls.finished, 'slickness_aff', "overlooked: a claim it overlooks runs")
  eq(calls.trust.slickness_aff, true, "overlooked: with GMCP set aside, so the backstop lets its add through")
  not_contains(calls.cleared, 'slickness_aff', "overlooked: and is not cleared")
  not_contains(calls.echof, "Ignored a line claiming slickness: GMCP doesn't report it.", "overlooked: nor echoed as ignored")
  contains(calls.cleared, 'sensitivity_aff', "overlooked: a refused claim it does not overlook is still cleared")
  contains(calls.echof, "Ignored a line claiming sensitivity: GMCP doesn't report it.", "overlooked: and echoed as before")
  eq(sk.gmcp_stands_aside, nil, "overlooked: GMCP is not left standing aside")
end

-- only refused claims are asked about
do
  local env, calls, svo = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'prone_aff', 'aff')
  queue(svo, 'asthma_gone', 'gone')
  svo.gmcp_is_live = true
  svo.gmcp_kept = {asthma_gone = 'asthma'}
  svo.gmcp_believed = {prone = true, asthma = true}

  svo.lifevision.validate()

  eq(#calls.overlooked, 0, "overlooked: not asked about a claim GMCP agrees with, nor about a kept loss")
  contains(calls.cleared, 'asthma_gone', "overlooked: a loss GMCP contradicts is still cleared")
end

-- ===== scenario 18: the add backstop is told which claim is running =====
-- sileris' "slick" outcome adds slickness from inside the claim, so
-- svo.gmcp_refuse_add has to know that claim to see it is the game's answer.
do
  local env, calls, svo, sys, sk = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  queue(svo, 'sileris_misc', 'misc')
  queue(svo, 'prone_aff', 'aff')
  svo.gmcp_is_live = true

  svo.lifevision.validate()

  eq(type(calls.claim.sileris_misc), 'table', "claim: set while a claim runs")
  eq(calls.claim.sileris_misc.p.name, 'sileris_misc', "claim: to the claim that is running")
  eq(calls.claim.prone_aff.p.name, 'prone_aff', "claim: and to the next one for the next")
  eq(sk.gmcp_claim, nil, "claim: cleared once the claims have run")
end

-- ===== scenario 19: lifevision.add marks the game's answers to svof's commands =====
do
  local env, calls, svo, sys, sk = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  -- svof sent sileris 0.4 seconds ago (the action's stopwatch reads 0.4)
  local sileris = {name = 'sileris_misc', balance = 'misc', actionwatch = 0.4}
  svo.actions.sileris_misc = {timerid = 7, p = sileris}

  svo.lifevision.add(sileris, 'slick', nil, 1)
  local answer = svo.lifevision.l.sileris_misc.answer
  eq(type(answer), 'table', "answer: an unusual outcome of a command svof sent is its answer")
  answer = answer or {}
  eq(answer.act, sileris, "answer: to that command")
  eq(answer.timerid, 7, "answer: with the timer that command runs on")
  eq(answer.elapsed, 0.4, "answer: and how long ago it left")

  svo.lifevision.add(sileris)
  eq(svo.lifevision.l.sileris_misc.answer, nil, "answer: its usual outcome is not a refusal")

  -- an action checkaction filed for a line, not one svof sent
  local slickness = {name = 'slickness_aff', balance = 'aff'}
  svo.actions.slickness_aff = {p = slickness}
  svo.lifevision.add(slickness, 'something')
  eq(svo.lifevision.l.slickness_aff.answer, nil, "answer: nothing svof did not send is answered")
  eq(svo.lifevision.l.slickness_aff.confirmed, nil, "answer: nor confirmed")
end

-- the triggers that work out which command a refusal answers say so
do
  local env, calls, svo, sys, sk = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  local salve = {name = 'crippledleftarm_salve', balance = 'salve', actionwatch = 0.3}
  svo.actions.crippledleftarm_salve = {timerid = 9, p = salve}
  local slickness = {name = 'slickness_aff', balance = 'aff'}

  svo.lifevision.answering(salve, function() svo.lifevision.add(slickness) end)
  local answer = svo.lifevision.l.slickness_aff.answer or {}
  eq(answer.act, salve, "answering: the claim is the answer to the command given")
  eq(answer.timerid, 9, "answering: with its timer")
  eq(answer.elapsed, 0.3, "answering: and its age")
  eq(sk.filing_answer, nil, "answering: nothing is marked afterwards")

  -- the command was already killed (symp_paralysis kills the fill first)
  svo.actions.crippledleftarm_salve = nil
  svo.lifevision.answering(salve, function() svo.lifevision.add(slickness) end)
  answer = svo.lifevision.l.slickness_aff.answer or {}
  eq(answer.act, salve, "answering: a killed command's answer is still one")
  eq(answer.timerid, nil, "answering: with no timer left to read")

  -- no command in flight: nothing to answer
  svo.lifevision.answering(nil, function() svo.lifevision.add(slickness) end)
  eq(svo.lifevision.l.slickness_aff.answer, nil, "answering: without a command the claim is not marked")

  local ok, err = pcall(svo.lifevision.answering, salve, function() error("boom", 0) end)
  eq(ok, false, "answering: an error inside still raises")
  eq(err, "boom", "answering: with its own message")
  eq(sk.filing_answer, nil, "answering: and leaves nothing marked")

  svo.lifevision.confirming(function() svo.lifevision.add(slickness) end)
  eq(svo.lifevision.l.slickness_aff.confirmed, true, "confirming: svof's symptom counters mark their claim confirmed")
  eq(sk.filing_confirmed, nil, "confirming: nothing is marked afterwards")
  ok, err = pcall(svo.lifevision.confirming, function() error("bang", 0) end)
  eq(err, "bang", "confirming: an error inside still raises")
  eq(sk.filing_confirmed, nil, "confirming: and leaves nothing marked")
end

-- ===== scenario 20: a paragraph's vouches do not outlive it =====
do
  local env, calls, svo, sys, sk = new_environment()
  load_block(block, env)
  svo.lifevision.l = ordered_map()

  sk.gmcp_vouched = {clumsiness = true}
  svo.lifevision.validate()
  eq(next(sk.gmcp_vouched), nil, "vouched: cleared once the paragraph is settled")

  sk.gmcp_vouched = {clumsiness = true}
  sys.flawedillusion = true
  queue(svo, 'clumsiness_aff', 'aff')
  svo.lifevision.validate()
  eq(next(sk.gmcp_vouched), nil, "vouched: and after a paragraph discarded as an illusion")
end

-- ===== scenario 21: what svof's symptom counters confirm is marked confirmed =====
-- Each counter adds its affliction only after seeing the symptom two to four
-- times, svof's own check against illusions; the claim it files then is
-- believed where GMCP is silent, which needs it marked.
do
  local s = source:find(COUNTERS_START_ANCHOR, 1, true)
  local e = s and source:find(COUNTERS_END_ANCHOR, s, true)
  if not (s and e) then
    error("symptom counter anchors not found in " .. SRC .. " - update this test's anchors")
  end
  local counters_block = source:sub(s, e - 1)

  local cases = {
    {'retardation_symptom', 'retardation', 4},
    {'stupidity_symptom', 'stupidity', 3},
    {'illness_constitution_symptom', 'hypochondria', 2},
    {'transfixed_symptom', 'transfixed', 2},
    {'impale_symptom', 'impale', 2},
    {'aeon_symptom', 'aeon', 2},
    {'paralysis_symptom', 'paralysis', 2},
    {'haemophilia_symptom', 'haemophilia', 2},
    {'webbed_symptom', 'webbed', 2},
    {'roped_symptom', 'roped', 2},
    {'impaled_symptom', 'impale', 2},
    {'hypochondria_symptom', 'hypochondria', 3},
  }

  for _, case in ipairs(cases) do
    local counter, aff, times = case[1], case[2], case[3]
    local env, calls, svo, sys, sk, conf = new_environment()
    load_block(block, env)

    -- what the counters reach for, inert here
    env.affs, env.defc, env.defs = {}, {constitution = true}, {lost_speed = function() end}
    env.tempTimer, env.echo, env.line = function() end, function() end, "a symptom"
    sys.wait = 0.7
    conf.aillusion, conf.serverside = false, false
    svo.affsp = {}
    svo.sk = sk
    function svo.syncdelay() return 0 end
    function svo.find_until_last_paragraph() return false end

    local filed = {}
    svo.valid = setmetatable({}, {__index = function(_, name)
      return function() filed[#filed + 1] = {name = name, confirmed = sk.filing_confirmed} end
    end})
    load_block(counters_block, env)

    for _ = 1, times do sk[counter]() end
    eq(#filed, 1, counter .. ": files one claim on the " .. times .. "th sighting")
    local claim = filed[1] or {}
    eq(claim.name, 'simple' .. aff, counter .. ": for " .. aff)
    eq(claim.confirmed, true, counter .. ": marked as confirmed")
    eq(sk.filing_confirmed, nil, counter .. ": and nothing is marked afterwards")
  end
end

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
