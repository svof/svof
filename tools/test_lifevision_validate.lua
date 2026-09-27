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

It proves nothing about Mudlet integration or real combat.

Run: lua tools/test_lifevision_validate.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local SRC = "src/scripts/svo (curing skeleton, controllers, action system)/Curing_skeleton.lua"

local START_ANCHOR = "local function run_through_actions()"
local END_ANCHOR = "  sys.lineguard = false\nend"

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
    error("start anchor not found in " .. SRC .. " - run_through_actions moved or was reworded; update this test's anchors")
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
  local calls = {cleared = {}, finished = {}, lostbal = {}, debugf = {}, echof = {}, asked = {}, trust = {}}

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
  -- paragraph while this claim ran
  function svo.actionfinished(act)
    calls.finished[#calls.finished + 1] = act.name
    calls.trust[act.name] = sk.gmcp_stands_aside or false
  end

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

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
