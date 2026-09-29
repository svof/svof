--[[
Logic-level regression test for the six GMCP affliction/defence handlers in
`src/scripts/svo (setup, misc, empty, funnies, dor)/Setup.lua`.

This does NOT run svof or Mudlet. It extracts the exact handler block from
the real source file by anchor text and executes it inside a stub
environment that provides only the globals that block touches (svo, sk,
conf, gmcp, signals, luanotify). Because the code under test is a substring
of the real file rather than a reimplementation, this cannot drift from what
actually ships - if the anchors move, the test fails loudly instead of
silently testing stale logic.

It proves the reconciler's *logic* is correct in isolation: name parsing,
the pairs-vs-ipairs key space, the svotossa/svotossd removal gate, the
unknownany guard, and call counts (once per event, not once per item). It
proves nothing about Mudlet integration, GMCP wire format, or actual play -
that still needs the in-game testing in the safety-patch spec.

Run: lua tools/test_gmcp_reconciler.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local SRC = "src/scripts/svo (setup, misc, empty, funnies, dor)/Setup.lua"

local START_ANCHOR = "signals.gmcpcharafflictionslist = signals.gmcpcharafflictionslist or luanotify.signal.new()"
local END_ANCHOR = "end, 'update list of defs from gmcp')"

-- The removal gates read svo.dict.svotossa / svo.dict.svotossd, which the
-- dictionary builds from sstosvoa / sstosvod as it loads. Extract those two
-- loops from the real dictionary too, rather than reimplementing them here:
-- a fixture that built the reverse index its own way could agree with a
-- reconciler that the shipped dictionary disagrees with.
local DICT_SRC = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local DICT_START_ANCHOR = "for ssa, svoa in pairs(svo.dict.sstosvoa) do"
local DICT_END_ANCHOR = "if type(svod) == 'string' then svo.dict.svotossd[svod] = ssd end"

-- sk.gmcp_cured schedules its own clear on the prompt queue, so whether the
-- record really is short-lived depends on two things this file does not own:
-- how the queue runs its callbacks, and who else empties it. Both are pulled
-- in from their real sources for the scenario that tests it - a stub queue
-- can only ever confirm the test's own idea of what a prompt does.
local PROMPT_SRC = "src/scripts/svo (curing skeleton, controllers, action system)/Curing_skeleton.lua"
local PROMPT_START_ANCHOR = "function sk.onprompt_beforeaction_add(name, what)"
local PROMPT_END_ANCHOR = "signals.after_lifevision_processing:connect(sk.onprompt_beforeaction_do"

local RESET_SRC = "src/scripts/svo (alias and defence functions)/Alias_functions.lua"
local RESET_START_ANCHOR = "function svo.reset.general()"
local RESET_END_ANCHOR = "  svo.check_generics()"

-- The two connections that take the final word away from GMCP (a new login,
-- a blackout). They sit further down Setup.lua than the handler block,
-- because svogotaff is only created there.
local TRUST_START_ANCHOR = "signals.connected:connect(function() sk.gmcp_affs_listed"
local TRUST_END_ANCHOR = "end, 'gmcp affs stale after blackout')"

-- svo.addaffdict and svo.rmaff themselves, for the backstop call in each, and
-- the public svo.addaff, svo.removeaff and svo.removeafflevel after them,
-- which set GMCP aside: the scenarios above test what the backstops decide,
-- these prove the functions that store afflictions actually ask them, and
-- that the public ones do not have to.
local STORE_START_ANCHOR = "local old_internal_addaff = function (new_aff)"
local STORE_END_ANCHOR = "-- externally available as svo.prompttrigger"

-- vreset, vaff and vrmaff, which set GMCP aside too.
local ALIAS_SRC = "src/scripts/svo (alias and defence functions)/Alias_functions.lua"
local RESETAFFS_START_ANCHOR = "function svo.reset.affs(echoback)"
local RESETAFFS_END_ANCHOR = "function svo.reset.general()"
local VAFF_START_ANCHOR = "function svo.vaff(aff)"
local VAFF_END_ANCHOR = "if svo.haveskillset('kaido') then"

-- The dictionary's unknownany and unknownmental entries, whose recklessness
-- guess is about an affliction the game hid, and the codepaste they count
-- unknowns with.
local HIDDEN_START_ANCHOR = "    unknownany = {"
local HIDDEN_END_ANCHOR = "    unknowncrippledlimb = {"
local ADDUNKNOWN_START_ANCHOR = "codepaste.addunknownany = function(amount)"
local ADDUNKNOWN_END_ANCHOR = "sk.burns = {"

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
    error("start anchor not found in " .. SRC .. " - the GMCP handlers moved or were reworded; update this test's anchors")
  end
  local e = source:find(END_ANCHOR, s, true)
  if not e then
    error("end anchor not found in " .. SRC .. " after the start anchor - update this test's anchors")
  end
  e = e + #END_ANCHOR
  return source:sub(s, e)
end

-- Generic: everything from a start anchor up to (but not including) a
-- terminator, or through a final line plus its closing `end`.
local function extract_between(source, path, start_anchor, end_anchor, through)
  local s = source:find(start_anchor, 1, true)
  if not s then
    error("start anchor not found in " .. path .. " - it moved or was reworded; update this test's anchors")
  end
  local e = source:find(end_anchor, s, true)
  if not e then
    error("end anchor not found in " .. path .. " after the start anchor - update this test's anchors")
  end
  if not through then return source:sub(s, e - 1) end
  e = source:find("\nend", e + #end_anchor, true)
  if not e then
    error("no closing end after the end anchor in " .. path .. " - update this test's anchors")
  end
  return source:sub(s, e + 4)
end

-- Both loops, plus the `end` closing the second one.
local function extract_dict_block(source)
  local s = source:find(DICT_START_ANCHOR, 1, true)
  if not s then
    error("start anchor not found in " .. DICT_SRC .. " - the reverse-index loops moved; update this test's anchors")
  end
  local e = source:find(DICT_END_ANCHOR, s, true)
  if not e then
    error("end anchor not found in " .. DICT_SRC .. " after the start anchor - update this test's anchors")
  end
  e = source:find("\nend", e + #DICT_END_ANCHOR, true)
  if not e then
    error("no closing end after the svotossd loop in " .. DICT_SRC .. " - update this test's anchors")
  end
  return source:sub(s, e + 4)
end

-- ===== assertion plumbing =====

local failures = {}
local checks = 0

local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format(
      "%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local function truthy(value, label)
  checks = checks + 1
  if not value then
    failures[#failures + 1] = string.format("%s: expected truthy, got %s", label, tostring(value))
  end
end

local function contains(list, value, label)
  checks = checks + 1
  for _, v in ipairs(list) do
    if v == value then return end
  end
  failures[#failures + 1] = string.format("%s: %s not found in [%s]", label, tostring(value), table.concat(list, ", "))
end

local function not_contains(list, value, label)
  checks = checks + 1
  for _, v in ipairs(list) do
    if v == value then
      failures[#failures + 1] = string.format("%s: %s unexpectedly found in [%s]", label, tostring(value), table.concat(list, ", "))
      return
    end
  end
end

-- ===== stub environment =====

-- Builds one fresh environment per scenario so tests can't leak state into
-- each other. Returns (env, handlers, calls) where handlers exposes the six
-- connected functions by name and calls records every side-effecting call
-- the block under test made.
local function new_environment()
  local calls = {
    addaff = {}, rmaff = {}, addaffdict = {}, updateaffcount = {},
    remove_unknownany = {}, debugf = {}, got = {}, lost = {},
    onprompt = {}, checkaeony = 0, changecuring = 0, echof = {}, events = {},
  }

  local handlers = {}

  local function new_signal(store_as)
    local fns = {}
    local sig
    sig = {
      connect = function(self, fn, name)
        fns[#fns + 1] = fn
        if store_as then handlers[store_as] = fn end
      end,
      emit = function(self, ...)
        for _, fn in ipairs(fns) do fn(...) end
      end,
      add_pre_emit = function() end,
      add_post_emit = function() end,
    }
    return sig
  end

  local luanotify = { signal = { new = function() return new_signal(nil) end } }

  local svo = {}
  svo.dict = {
    unknownany = { count = 0 },
    sstosvoa = {}, sstosvod = {},
    -- declared empty by the dictionary at load; populated by the extracted
    -- reverse-index loops, via build_reverse_indexes below.
    svotossa = {}, svotossd = {},
  }
  svo.affl = {}
  svo.affs = {}
  svo.gaffl = {}
  svo.gdefc = {}
  svo.defc = {}
  svo.defs = {}
  svo.me = {}
  svo.conf = { gmcpaffechoes = false, gmcpdefechoes = false }
  svo.sk = {}
  svo.sk.gmcp_cured = {}
  svo.sk.onpromptfuncs = {}
  svo.valid = {}
  svo.reset = {}
  -- what the real svo.reset.general walks; empty is enough, the flags it
  -- clears are the point here, not the action teardown.
  svo.actions = { iter = function() return function() return nil end end }
  svo.bals_in_use = {}
  function svo.killaction() end
  function svo.check_generics() end
  -- for the public add/remove API and the aliases
  svo.affsp = {}
  svo.codepaste = { badaeon = function() end }
  svo.lifevision = { l = {} }
  function svo.lifevision.l:set(k, v) self[k] = v end
  function svo.make_gnomes_work() end
  function svo.assert(condition, msg) if not condition then error(msg) end end

  function svo.deepcopy(t)
    if type(t) ~= 'table' then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = svo.deepcopy(v) end
    return r
  end

  function svo.addaff(name) calls.addaff[#calls.addaff + 1] = name end
  function svo.rmaff(name) calls.rmaff[#calls.rmaff + 1] = name end
  function svo.addaffdict(entry) calls.addaffdict[#calls.addaffdict + 1] = entry and entry.name end
  function svo.updateaffcount(entry) calls.updateaffcount[#calls.updateaffcount + 1] = entry and entry.name end
  function svo.echof(fmt, ...) calls.echof[#calls.echof + 1] = string.format(fmt, ...) end
  function svo.debugf(fmt, ...) calls.debugf[#calls.debugf + 1] = string.format(fmt, ...) end
  function svo.valid.remove_unknownany(name) calls.remove_unknownany[#calls.remove_unknownany + 1] = name end
  function svo.sk.checkaeony() calls.checkaeony = calls.checkaeony + 1 end
  -- Records the prompt callback the way sk.onprompt_beforeaction_do would
  -- later run it, so the test can fire it and check the reset.
  function svo.sk.onprompt_beforeaction_add(name, fn) calls.onprompt[name] = fn end

  -- svo.defs['got_x'] / ['lost_x'] are looked up dynamically; record any call.
  setmetatable(svo.defs, {
    __index = function(t, key)
      local prefix, name = key:match("^(got_)(.*)$")
      if not prefix then prefix, name = key:match("^(lost_)(.*)$") end
      if not prefix then return nil end
      return function(...)
        local bucket = (prefix == "got_") and calls.got or calls.lost
        bucket[#bucket + 1] = name
      end
    end,
  })

  local signals = {}
  signals.changecuring = new_signal(nil)
  signals.changecuring.emit = function(self, ...) calls.changecuring = calls.changecuring + 1 end
  signals.canoutr = new_signal(nil)
  signals.gmcpcharafflictionslist = new_signal("afflist")
  signals.gmcpcharafflictionsremove = new_signal("affremove")
  signals.gmcpcharafflictionsadd = new_signal("affadd")
  signals.gmcpchardefenceslist = new_signal("deflist")
  signals.gmcpchardefencesremove = new_signal("defremove")
  signals.gmcpchardefencesadd = new_signal("defadd")
  signals.connected = new_signal("connected")
  signals.svogotaff = new_signal("gotaff")
  signals.svolostaff = new_signal(nil)
  signals.after_lifevision_processing = { block = function() end, unblock = function() end }

  local gmcp = { Char = { Afflictions = {}, Defences = {} } }

  local env = {
    svo = svo, signals = signals, luanotify = luanotify, gmcp = gmcp,
    -- upvalues the real file aliases at the top of Setup.lua before this block
    sk = svo.sk, conf = svo.conf, defc = svo.defc, gaffl = svo.gaffl, me = svo.me,
    affs = svo.affs,
    -- and the ones Curing_skeleton.lua and Alias_functions.lua alias
    cnrl = {}, lifevision = svo.lifevision,
    -- stdlib the block needs
    string = string, table = table, tonumber = tonumber, pairs = pairs, ipairs = ipairs,
    type = type, tostring = tostring, error = error, setmetatable = setmetatable,
    pcall = pcall, next = next,
    -- Mudlet's; only reached when a queued prompt callback raises.
    echoLink = function() end,
    -- Mudlet's, for the real addaffdict and rmaff
    createStopWatch = function() return 1 end,
    startStopWatch = function() end,
    stopStopWatch = function() return 0 end,
    raiseEvent = function(name, arg) calls.events[#calls.events + 1] = name .. " " .. tostring(arg) end,
    debug = debug,
  }
  env._G = env

  return env, handlers, calls, svo, gmcp
end

-- Mudlet runs Lua 5.1, where load() takes a reader function and only
-- loadstring() takes a source string, with the environment applied separately
-- via setfenv. 5.2+ folded both into load(). Testing under whichever lua
-- happens to be on PATH is how this got written 5.2-only and still passed
-- locally, so branch on setfenv rather than assume.
local function load_block(block, env)
  local chunk, err
  if setfenv then
    chunk, err = loadstring(block, "gmcp_handlers_under_test")
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(block, "gmcp_handlers_under_test", "t", env)
  end
  if not chunk then error("failed to load extracted block: " .. tostring(err)) end
  local ok, runerr = pcall(chunk)
  if not ok then error("failed to execute extracted block: " .. tostring(runerr)) end
end

local source = read_file(SRC)
local block = extract_block(source)
print("extracted " .. #block .. " bytes of Setup.lua between the GMCP handler anchors")

local dict_block = extract_dict_block(read_file(DICT_SRC))
print("extracted " .. #dict_block .. " bytes of the dictionary's reverse-index loops")

local prompt_block = extract_between(read_file(PROMPT_SRC), PROMPT_SRC,
  PROMPT_START_ANCHOR, PROMPT_END_ANCHOR, false)
local reset_block = extract_between(read_file(RESET_SRC), RESET_SRC,
  RESET_START_ANCHOR, RESET_END_ANCHOR, true)
print("extracted " .. #prompt_block .. " bytes of the real prompt queue and "
  .. #reset_block .. " bytes of the real svo.reset.general")

local trust_block
do
  local src = read_file(SRC)
  local s = src:find(TRUST_START_ANCHOR, 1, true)
  if not s then
    error("start anchor not found in " .. SRC .. " - the GMCP trust connections moved; update this test's anchors")
  end
  local e = src:find(TRUST_END_ANCHOR, s, true)
  if not e then
    error("end anchor not found in " .. SRC .. " after the start anchor - update this test's anchors")
  end
  trust_block = src:sub(s, e + #TRUST_END_ANCHOR - 1)
end
print("extracted " .. #trust_block .. " bytes of the GMCP trust connections")

local store_block = extract_between(read_file(PROMPT_SRC), PROMPT_SRC,
  STORE_START_ANCHOR, STORE_END_ANCHOR, false)
print("extracted " .. #store_block .. " bytes of the real svo.addaffdict, svo.rmaff and the public add/remove API")

local resetaffs_block = extract_between(read_file(ALIAS_SRC), ALIAS_SRC,
  RESETAFFS_START_ANCHOR, RESETAFFS_END_ANCHOR, false)
local vaff_block = extract_between(read_file(ALIAS_SRC), ALIAS_SRC,
  VAFF_START_ANCHOR, VAFF_END_ANCHOR, false)
print("extracted " .. #resetaffs_block .. " bytes of the real svo.reset.affs and "
  .. #vaff_block .. " of svo.vaff and svo.vrmaff")

local hidden_block = extract_between(read_file(DICT_SRC), DICT_SRC,
  HIDDEN_START_ANCHOR, HIDDEN_END_ANCHOR, false)
local addunknown_block = extract_between(read_file(DICT_SRC), DICT_SRC,
  ADDUNKNOWN_START_ANCHOR, ADDUNKNOWN_END_ANCHOR, false)
print("extracted " .. #hidden_block .. " bytes of the dictionary's unknownany and unknownmental and "
  .. #addunknown_block .. " of codepaste.addunknownany")

-- Run the dictionary's own reverse-index build over whatever sstosvoa /
-- sstosvod a scenario has just set, exactly as it runs at dict-load time.
local function build_reverse_indexes(env)
  load_block(dict_block, env)
end

-- ===== scenario 1: parseaffname, via the Add handler's observable effects =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity', clumsiness = 'clumsiness' }
  svo.dict.sensitivity = { name = 'sensitivity', count = 0 }
  svo.dict.clumsiness = { name = 'clumsiness' }
  env.gmcp.Char.Afflictions.Add = { name = 'sensitivity (10)' }

  h.affadd()

  eq(svo.dict.sensitivity.count, 10, "parseaffname: level 10 (two digits) reaches svoaff.count")

  -- level 10 used to parse as count 1 with a trailing '(' left on the name
  -- under the old sub(1,-5) logic; assert the fixed count directly instead
  -- of re-deriving the old bug's number.
  eq(#calls.debugf, 0, "parseaffname: no debug noise from a normal add")
end

-- ===== scenario 2: G3/G4 - unknown GMCP name never indexes nil =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = {} -- nothing resolves
  env.gmcp.Char.Afflictions.Add = { name = 'brandnewaff (2)' }

  local ok, err = pcall(h.affadd)
  truthy(ok, "G3/G4: unresolvable GMCP name does not raise (" .. tostring(err) .. ")")
  eq(#calls.addaffdict, 0, "G3/G4: unresolvable name never reaches addaffdict")
end

-- ===== scenario 3: G5 - count propagates only when svo.affl already tracks it =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity' }
  svo.dict.sensitivity = { name = 'sensitivity', count = 0 }
  svo.affl.sensitivity = { count = 0 } -- already tracked, as it would be post-addaffdict in real svof
  env.gmcp.Char.Afflictions.Add = { name = 'sensitivity (3)' }

  h.affadd()

  contains(calls.updateaffcount, 'sensitivity', "G5: updateaffcount runs when svo.affl has the entry")
end

do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity' }
  svo.dict.sensitivity = { name = 'sensitivity', count = 0 }
  -- svo.affl.sensitivity intentionally absent
  env.gmcp.Char.Afflictions.Add = { name = 'sensitivity (3)' }

  h.affadd()

  eq(#calls.updateaffcount, 0, "G5: updateaffcount does not run when svo.affl lacks the entry (no raise, no call)")
end

do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  -- 130 of the 145 mapped GMCP names have no count field in their dict
  -- entry. updateaffcount assigns svo.affl[name].count unconditionally and
  -- raises the documented "svo updated aff" event with that amount, so
  -- calling it here stored nil and announced a count of nothing.
  svo.dict.sstosvoa = { nausea = 'illness' }
  svo.dict.illness = { name = 'illness' } -- no count field
  svo.affl.illness = {}
  env.gmcp.Char.Afflictions.Add = { name = 'nausea (3)' }

  h.affadd()

  eq(#calls.updateaffcount, 0, "G5: a level reported for an aff whose dict entry has no count never reaches updateaffcount")
  eq(svo.dict.illness.count, nil, "G5: and no count is invented on the dict entry either")
end

-- ===== scenario 4: G6 - unknownany only decrements for a real, previously-untracked affliction =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity' }
  svo.dict.unknownany.count = 1
  -- svo.affl.sensitivity absent: this cure was NOT already tracked -> counts toward unknownany
  env.gmcp.Char.Afflictions.Remove = { [1] = 'sensitivity' }

  h.affremove()

  contains(calls.remove_unknownany, 'sensitivity', "G6: a real, untracked cure decrements unknownany")
end

do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = {} -- this GMCP name resolves to nothing svof knows
  svo.dict.unknownany.count = 1
  env.gmcp.Char.Afflictions.Remove = { [1] = 'someuntranslatablename' }

  h.affremove()

  eq(#calls.remove_unknownany, 0, "G6: an unresolvable GMCP removal must not eat unknownany (the old bug: affname was \"\", always nil, always fired)")
end

do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity' }
  svo.dict.unknownany.count = 1
  svo.affl.sensitivity = { count = 1 } -- svof WAS already tracking this one
  env.gmcp.Char.Afflictions.Remove = { [1] = 'sensitivity' }

  h.affremove()

  eq(#calls.remove_unknownany, 0, "G6: a cure svof was already tracking must not eat unknownany")
end

-- ===== scenario 5: G7 - rmaff receives a name string, not a table =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity' }
  svo.dict.sensitivity = { name = 'sensitivity' }
  env.gmcp.Char.Afflictions.Remove = { [1] = 'sensitivity' }

  h.affremove()

  eq(#calls.rmaff, 1, "G7: rmaff called exactly once")
  eq(type(calls.rmaff[1]), 'string', "G7: rmaff receives a string")
  eq(calls.rmaff[1], 'sensitivity', "G7: rmaff receives the resolved svof name")
end

-- ===== scenario 5b: GMCP-cured record for the trigger-side illusion checks =====
-- GMCP is processed before the game text it accompanies, so by the time a
-- cure's own line reaches a trigger, rmaff has already cleared affs[aff].
-- Without this record the trigger reads "we never had it" and calls a real
-- cure an illusion.
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)
  -- the real queue, not the recording stub: what clears the record is the
  -- point of this scenario, so the mechanism that clears it has to be real.
  load_block(prompt_block, env)
  load_block(reset_block, env)

  -- The real mapping is nausea -> illness. Keying the fixture illness ->
  -- illness made rawaff, affname and svoaffkey the same string, so
  -- "recorded under its svof name" could not fail: recording under either
  -- of the other two left the suite green.
  svo.dict.sstosvoa = { nausea = 'illness' }
  svo.dict.illness = { name = 'illness' }
  env.gmcp.Char.Afflictions.Remove = { [1] = 'nausea' }

  h.affremove()

  eq(svo.sk.gmcp_cured.illness, true, "gmcp_cured: a resolved GMCP cure is recorded under its svof name")
  eq(svo.sk.gmcp_cured.nausea, nil, "gmcp_cured: and not under the GMCP name the cure arrived as")
  eq(type(svo.sk.onpromptfuncs['gmcpcharafflictionsremove']), 'function', "gmcp_cured: a prompt reset was queued")

  svo.sk.onprompt_beforeaction_do()
  eq(svo.sk.gmcp_cured.illness, nil, "gmcp_cured: the record does not survive the prompt")
end

-- Nine herb-cured afflictions reach GMCP under a different name, and the
-- four tempered humours are levelled as well, so a real cure can need the
-- level strip and the name translation at once.
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { temperedcholeric = 'cholerichumour' }
  svo.dict.cholerichumour = { name = 'cholerichumour', count = 2 }
  env.gmcp.Char.Afflictions.Remove = { [1] = 'temperedcholeric (2)' }

  h.affremove()

  eq(svo.sk.gmcp_cured.cholerichumour, true, "gmcp_cured: a levelled cure under a differing GMCP name is recorded under the bare svof name")
end

-- svo.reset.general empties the prompt queue without running it, so the
-- clear this record queued for itself is thrown away and the record - read
-- by the two illusion checks as "GMCP just cured this" - survives every
-- later prompt. Every direct caller runs svo.reset.affs first, so nothing
-- else can arrive to flush it: you are unafflicted and it stays true.
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)
  load_block(prompt_block, env)
  load_block(reset_block, env)

  svo.dict.sstosvoa = { nausea = 'illness' }
  svo.dict.illness = { name = 'illness' }
  env.gmcp.Char.Afflictions.Remove = { [1] = 'nausea' }
  h.affremove()
  svo.sk.removed_something = true

  svo.reset.general()

  eq(svo.sk.gmcp_cured.illness, nil, "reset.general: the GMCP-cured record does not survive a general reset")
  eq(svo.sk.removed_something, nil, "reset.general: nor does sk.removed_something, which leaks through the same discarded queue")

  -- and it is really gone, not merely pending: the next prompt has nothing
  -- queued to clear it with.
  svo.sk.onprompt_beforeaction_do()
  eq(next(svo.sk.gmcp_cured), nil, "reset.general: still clear after the next prompt")
end

do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = {} -- nothing resolves
  env.gmcp.Char.Afflictions.Remove = { [1] = 'somethingunknown' }

  h.affremove()

  eq(next(svo.sk.gmcp_cured), nil, "gmcp_cured: an unresolvable GMCP name records nothing")
  eq(calls.onprompt['gmcpcharafflictionsremove'], nil, "gmcp_cured: no prompt reset registered when nothing was recorded")
end

-- ===== scenario 6: G1/G2 - the List reconciler =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  -- Three real mappings, none of them an identity, and deliberately the
  -- nastiest shape in the dictionary: GMCP 'mangledleftarm' is svof
  -- 'mutilatedleftarm', while 'mangledleftarm' is *also* a svof name in its
  -- own right (GMCP 'damagedleftarm') - one severity step milder. Confusing
  -- the two key spaces here does not resolve to nothing, it resolves to a
  -- real neighbouring affliction. An identity fixture makes the two spaces
  -- indistinguishable, so every assertion below would hold even if the gate
  -- and the loop keyed on the wrong one. Many string-valued sstosvoa
  -- entries differ across the two spaces - no figure here on purpose, it
  -- moves every time one of them is renamed and has gone stale once
  -- already. All four mangled limbs collide this way.
  -- 'unreachable' is one of the names GMCP can never confirm or deny (no
  -- sstosvoa entry). Two items in the reported list so the checkaeony/
  -- changecuring frequency assertions below actually distinguish "once per
  -- list" from "once per item" (a list of one can't tell the two apart).
  svo.dict.sstosvoa = {
    mangledleftarm = 'mutilatedleftarm',
    damagedleftarm = 'mangledleftarm',
    nausea = 'illness',
  }
  build_reverse_indexes(env)

  svo.affl = {
    mutilatedleftarm = { count = 1 }, mangledleftarm = { count = 1 },
    illness = { count = 1 }, unreachable = { count = 1 },
  }
  env.gmcp.Char.Afflictions.List = { { name = 'mangledleftarm' }, { name = 'damagedleftarm' } }

  h.afflist()

  eq(calls.checkaeony, 1, "G1/G7-followup: checkaeony fires exactly once per List event, not once per item (list had 2 items)")
  eq(calls.changecuring, 1, "G1/G7-followup: changecuring fires exactly once per List event, not once per item (list had 2 items)")

  eq(#calls.addaff, 0, "G1: an affliction already tracked and still in the list is not re-added")
  contains(calls.rmaff, 'illness', "G1/G2: a GMCP-reachable affliction absent from the list IS removed, under its svof name")
  not_contains(calls.rmaff, 'unreachable', "G2: an affliction GMCP cannot report is NEVER removed, even when absent from the list")
  not_contains(calls.rmaff, 'mutilatedleftarm', "G1: an affliction the list confirms under a different GMCP name is not removed")
  not_contains(calls.rmaff, 'mangledleftarm', "G1: the svof name that collides with another affliction's GMCP name is not removed either")

  -- The removal loop is the destructive half of the reconciler; debugf is
  -- its only record. Deleting that line left the suite green before this.
  contains(calls.debugf, "gmcp list: removing illness, not in the game's list",
    "G1: a removal is recorded through debugf")
end

do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { nausea = 'illness' }
  build_reverse_indexes(env)

  svo.affl = {} -- nothing tracked yet
  env.gmcp.Char.Afflictions.List = { { name = 'nausea' } }

  h.afflist()

  contains(calls.addaff, 'illness', "G1: an affliction reported by GMCP but not yet tracked is added, under its svof name")
  eq(#calls.rmaff, 0, "G1: nothing to remove when svo.affl started empty")
end

-- ===== scenario 6b: a levelled affliction in the List =====
-- The original handler stripped the level suffix only when it was exactly
-- " (1)", so "torntendons (2)" resolved to nothing in sstosvoa, its preaffl
-- entry was never cleared, and the removal loop dropped an affliction the
-- game had just reported as present. Inert while the loop was dead code;
-- a false removal once G1 made it live.
--
-- Found by replaying a real fight (torntendons escalating 1->6) rather than
-- by this file, because every List case here used a bare name.
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  -- The real fight that found this had torntendons, whose GMCP name happens
  -- to match svof's. The fixture uses one of the four tempered humours
  -- instead - GMCP 'temperedcholeric' is svof 'cholerichumour', and it is
  -- levelled - so the level strip and the name translation both have to be
  -- right for this to pass, not just the strip.
  svo.dict.sstosvoa = { temperedcholeric = 'cholerichumour', slickness = 'slickness' }
  svo.dict.cholerichumour = { name = 'cholerichumour', count = 1 }
  svo.dict.slickness = { name = 'slickness' }
  build_reverse_indexes(env)

  svo.affl = { cholerichumour = { count = 1 }, slickness = { count = 1 } }
  env.gmcp.Char.Afflictions.List = {
    { name = 'temperedcholeric (2)' },
    { name = 'slickness' },
  }

  h.afflist()

  not_contains(calls.rmaff, 'cholerichumour',
    "List: an affliction reported at a level above 1 is NOT removed")
  eq(#calls.addaff, 0,
    "List: a levelled affliction already tracked is not re-added either")
  eq(svo.dict.cholerichumour.count, 2,
    "List: the level from a List reaches svo.dict, like it does from an Add")
  contains(calls.updateaffcount, 'cholerichumour',
    "List: svo.affl's count is updated when the entry exists")
end

do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  -- and the removal half still works for a levelled name that really is gone
  svo.dict.sstosvoa = { temperedcholeric = 'cholerichumour', slickness = 'slickness' }
  svo.dict.slickness = { name = 'slickness' }
  build_reverse_indexes(env)

  svo.affl = { cholerichumour = { count = 3 }, slickness = { count = 1 } }
  env.gmcp.Char.Afflictions.List = { { name = 'slickness' } }

  h.afflist()

  contains(calls.rmaff, 'cholerichumour',
    "List: a levelled affliction genuinely absent from the list is still removed")
end

-- ===== scenario 6b: Char.Afflictions.List resets svo.gaffl in place =====
-- Setup.lua aliases the table once at load (`local gaffl = svo.gaffl`), which
-- the harness reproduces by passing gaffl into the environment. The List
-- handler used to do `svo.gaffl = {}`, which rebound the public name to a fresh
-- table while the loop below it went on writing to the aliased one. Two silent
-- effects, both pinned here: svo.gaffl read empty from the first List onwards,
-- and the resync never actually cleared anything, so an Add whose Remove was
-- missed stayed for the rest of the session.
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { asthma = 'asthma', slickness = 'slickness' }
  svo.dict.asthma = { name = 'asthma' }
  svo.dict.slickness = { name = 'slickness' }
  build_reverse_indexes(env)

  local before = svo.gaffl
  env.gaffl.leftover = true -- an Add whose Remove never arrived

  env.gmcp.Char.Afflictions.List = { { name = 'asthma' } }
  h.afflist()

  eq(svo.gaffl, before,
    "List: svo.gaffl is cleared in place, not rebound to a fresh table")
  eq(svo.gaffl, env.gaffl,
    "List: the public svo.gaffl and the aliased local stay the same table")
  eq(env.gaffl.leftover, nil,
    "List: a stale name the game no longer reports is cleared by the resync")
  eq(env.gaffl.asthma, true,
    "List: what the game does report is present after the resync")
end

-- ===== scenario 7: G8 - defence List reconciler uses the svof key space =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  -- sstosvod is serverside-keyed. 'armour' and 'rebounding' happen to share
  -- their name between the two spaces (the common case); 'ds' (svof) is
  -- reported by GMCP under a different serverside name 'discern shield'
  -- (the case G8 fixes - 51 real defences share this shape). 'untouchable'
  -- has no sstosvod entry at all - GMCP can never confirm or deny it.
  svo.dict.sstosvod = {
    armour = 'armour', rebounding = 'rebounding', ['discern shield'] = 'ds',
  }
  build_reverse_indexes(env)

  -- mutate in place: the extracted block captured `defc` as a local alias
  -- of svo.defc at load time (`local defc = svo.defc`, outside this
  -- extracted range), so reassigning svo.defc here would leave that alias
  -- pointing at the old, empty table.
  svo.defc.armour = true
  svo.defc.rebounding = true
  svo.defc.ds = true
  svo.defc.untouchable = true
  -- GMCP confirms only 'rebounding' is currently up; armour and ds are
  -- absent from the report, untouchable is unreachable regardless.
  env.gmcp.Char.Defences.List = { { name = 'rebounding' } }

  h.deflist()

  contains(calls.lost, 'armour', "G8: a same-named defence absent from the GMCP list is removed")
  contains(calls.lost, 'ds', "G8: a differently-keyed defence (the G8 bug) is now removed via svodtoss, not sstosvod")
  not_contains(calls.lost, 'rebounding', "G8: a defence GMCP confirms is present is not removed")
  not_contains(calls.lost, 'untouchable', "G8/whitelist: a defence GMCP cannot report is never removed")
end

-- ===== scenario 8: GMCP first - does GMCP report an affliction? =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = {
    deepsleep = 'sleep', sleeping = 'sleep',
    temperedcholeric = 'cholerichumour',
    deafness = false,
  }
  build_reverse_indexes(env)

  -- svotossa keeps one of sleep's two game names, and which one depends on
  -- pairs order. Report through the other one: that is the case svotossa
  -- gets wrong and the forward walk has to get right.
  local kept = svo.dict.svotossa.sleep
  truthy(kept == 'deepsleep' or kept == 'sleeping', "reports: svotossa keeps one of sleep's game names")
  local other = (kept == 'deepsleep') and 'sleeping' or 'deepsleep'
  env.gaffl[other] = true
  eq(svo.gmcp_reports('sleep'), true, "reports: sleep is found under the game name svotossa did not keep")

  env.gaffl[other] = nil
  env.gaffl['temperedcholeric (2)'] = true
  eq(svo.gmcp_reports('cholerichumour'), true, "reports: a levelled entry under a differing game name is found")

  env.gaffl.deafness = true
  eq(svo.gmcp_reports('deafness'), false, "reports: a game name svof maps to nothing reports nothing")
  eq(svo.gmcp_reports('sensitivity'), false, "reports: an affliction absent from gaffl is not reported")
end

-- ===== scenario 9: GMCP first - when GMCP has the final word =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)
  load_block(trust_block, env)

  svo.dict.sstosvoa = { prone = 'prone' }
  build_reverse_indexes(env)

  eq(svo.gmcp_live(), false, "live: not before the game has sent a List")

  env.gmcp.Char.Afflictions.List = {}
  h.afflist()
  eq(svo.gmcp_live(), true, "live: a List makes GMCP live")

  svo.affs.blackout = {}
  eq(svo.gmcp_live(), false, "live: not in blackout")
  svo.affs.blackout = nil

  h.gotaff('prone')
  eq(svo.gmcp_live(), true, "live: gaining any other affliction changes nothing")

  h.gotaff('blackout')
  eq(svo.gmcp_live(), false, "live: not after a blackout, even once it has ended")

  h.afflist()
  eq(svo.gmcp_live(), true, "live: a List resyncs after a blackout")

  h.connected()
  eq(svo.gmcp_live(), false, "live: not after a new connection, until its List")
end

-- ===== scenario 10: GMCP first - does GMCP contradict an affliction? =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity', prone = 'prone', blackout = 'blackout' }
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'prone' } }
  h.afflist()

  eq(svo.gmcp_refutes('sensitivity'), true, "refutes: an affliction GMCP could report and does not")
  eq(svo.gmcp_refutes('prone'), false, "refutes: not one GMCP reports")
  eq(svo.gmcp_refutes('stun'), false, "refutes: never one GMCP cannot report")
  eq(svo.gmcp_refutes('blackout'), false, "refutes: never blackout, which is what switches GMCP off")

  svo.sk.gmcp_stands_aside = true
  eq(svo.gmcp_refutes('sensitivity'), false, "refutes: nothing in a paragraph the game vouches for")
  svo.sk.gmcp_stands_aside = nil

  svo.affs.blackout = {}
  eq(svo.gmcp_refutes('sensitivity'), false, "refutes: nothing while GMCP is not live")
end

-- ===== scenario 11: GMCP first - which affliction a claim is about =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = {
    sensitivity = 'sensitivity', asthma = 'asthma', aeon = 'aeon',
    impaled = 'impale', webbed = 'webbed',
  }
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = {}
  h.afflist()

  local function claim(action_name, balance, other_action, arg)
    return {
      p = { action_name = action_name, balance = balance, name = action_name .. '_' .. balance },
      other_action = other_action, arg = arg,
    }
  end

  eq(svo.gmcp_refuted_claim(claim('sensitivity', 'aff')), 'sensitivity', "claim: an affliction's own claim")
  eq(svo.gmcp_refuted_claim(claim('sensitivity', 'herb')), nil, "claim: a cure is never refused")
  eq(svo.gmcp_refuted_claim(claim('stun', 'aff')), nil, "claim: an affliction GMCP cannot report is never refused")
  eq(svo.gmcp_refuted_claim(claim('checkasthma', 'aff')), 'asthma', "claim: a probe is about the affliction it tests")
  eq(svo.gmcp_refuted_claim(claim('checkstun', 'aff')), nil, "claim: checkstun tests stun, which GMCP cannot report")
  eq(svo.gmcp_refuted_claim(claim('checkslows', 'aff', 'truename')), 'aeon', "claim: checkslows' truename outcome is about aeon")
  eq(svo.gmcp_refuted_claim(claim('checkslows', 'aff', nil, 'aeon')), 'aeon', "claim: checkslows names aeon in its argument")
  eq(svo.gmcp_refuted_claim(claim('checkslows', 'aff', nil, 'retardation')), nil, "claim: and retardation, which GMCP cannot report")
  eq(svo.gmcp_refuted_claim(claim('checkwrithes', 'aff', 'impale', 150)), 'impale', "claim: checkwrithes' impale outcome")
  eq(svo.gmcp_refuted_claim(claim('checkwrithes', 'aff', nil, 'webbed')), 'webbed', "claim: checkwrithes names the writhe in its argument")

  env.gaffl.asthma = true
  eq(svo.gmcp_refuted_claim(claim('checkasthma', 'aff')), nil, "claim: a probe for an affliction GMCP reports is not refused")
end

-- ===== scenario 12: GMCP first - the live log that started this =====
-- A shield strike to the ribs while deaf: the game stripped deafness instead
-- of giving sensitivity. GMCP sent "Remove deafness" and "Add prone" and
-- nothing about sensitivity, while the trigger's deafness check missed the
-- "Your hearing is suddenly restored." line and claimed sensitivity anyway.
-- Driven through the real handlers, so gaffl holds what they made of it.
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  -- the real mappings: GMCP's deafness is not a svof affliction
  svo.dict.sstosvoa = { deafness = false, prone = 'prone', sensitivity = 'sensitivity' }
  svo.dict.prone = { name = 'prone' }
  build_reverse_indexes(env)

  env.gmcp.Char.Afflictions.List = { { name = 'deafness' } }
  h.afflist()
  env.gmcp.Char.Afflictions.Remove = { [1] = 'deafness' }
  h.affremove()
  env.gmcp.Char.Afflictions.Add = { name = 'prone' }
  h.affadd()

  local function aff_claim(name)
    return { p = { action_name = name, balance = 'aff', name = name .. '_aff' } }
  end
  eq(svo.gmcp_refuted_claim(aff_claim('sensitivity')), 'sensitivity', "live log: the sensitivity claim is refused")
  eq(svo.gmcp_refuted_claim(aff_claim('prone')), nil, "live log: the prone claim GMCP confirmed is not")
end

-- ===== scenario 13: GMCP first - after a blackout, the next List resyncs =====
-- Blackout stops Char.Afflictions and no List comes when it ends, so gaffl
-- still holds what was cured during it. The game sends a List after every
-- diagnose that goes through (every one of the 41 Lists in the two captured
-- fights followed a diagnose), and that List hands GMCP the final word back.
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)
  load_block(trust_block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity', prone = 'prone', asthma = 'asthma' }
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'sensitivity' }, { name = 'prone' } }
  h.afflist()
  h.gotaff('blackout')
  -- blackout has ended; sensitivity was cured during it, which GMCP never said

  local function aff_claim(name)
    return { p = { action_name = name, balance = 'aff', name = name .. '_aff' } }
  end
  eq(svo.gmcp_refuted_claim(aff_claim('asthma')), nil, "after blackout: nothing is refused while gaffl is stale")

  -- the List a diagnose brings
  env.gmcp.Char.Afflictions.List = { { name = 'prone' } }
  h.afflist()

  eq(env.gaffl.sensitivity, nil, "after blackout: the List drops what was cured during it")
  eq(env.gaffl.prone, true, "after blackout: and keeps what the game still reports")
  eq(svo.gmcp_live(), true, "after blackout: GMCP has the final word again")
  eq(svo.gmcp_refuted_claim(aff_claim('asthma')), 'asthma', "after blackout: claims are checked against GMCP again")
end

-- ===== scenario 14: GMCP first - does GMCP contradict a loss? =====
-- Includes the cases the empty-cure gate used to check with its own copy of
-- this logic, now that presume_cured hands its whole list to svo.rmaff.
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = {
    asthma = 'asthma', torntendons = 'torntendons', slickness = 'slickness',
    deepsleep = 'sleep', sleeping = 'sleep',
  }
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'asthma' }, { name = 'torntendons (2)' } }
  h.afflist()

  eq(svo.gmcp_holds('asthma'), true, "holds: an affliction GMCP still reports")
  eq(svo.gmcp_holds('torntendons'), true, "holds: one GMCP reports at level 2")
  eq(svo.gmcp_holds('slickness'), false, "holds: not one GMCP does not report")
  eq(svo.gmcp_holds('unknownany'), false, "holds: never one GMCP cannot report")

  local kept = svo.dict.svotossa.sleep
  local other = (kept == 'deepsleep') and 'sleeping' or 'deepsleep'
  env.gaffl[other] = true
  eq(svo.gmcp_holds('sleep'), true, "holds: sleep under the game name svotossa did not keep")

  svo.sk.gmcp_stands_aside = true
  eq(svo.gmcp_holds('asthma'), false, "holds: nothing in a paragraph the game vouches for")
  svo.sk.gmcp_stands_aside = nil

  svo.affs.blackout = {}
  eq(svo.gmcp_holds('asthma'), false, "holds: nothing while GMCP is not live")
end

do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  -- no List yet: GMCP disabled, or svof loaded mid-session. Nothing is kept,
  -- which is how svof behaved before GMCP had any say.
  svo.dict.sstosvoa = { asthma = 'asthma' }
  build_reverse_indexes(env)
  env.gaffl.asthma = true
  eq(svo.gmcp_holds('asthma'), false, "holds: nothing before the game has sent a List")
end

-- ===== scenario 15: GMCP first - which affliction a "gone" claim is about =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { asthma = 'asthma', slickness = 'slickness' }
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'asthma' } }
  h.afflist()

  local function claim(action_name, balance)
    return { p = { action_name = action_name, balance = balance, name = action_name .. '_' .. balance } }
  end

  eq(svo.gmcp_kept_claim(claim('asthma', 'gone')), 'asthma', "gone claim: kept when GMCP still reports it")
  eq(svo.gmcp_kept_claim(claim('slickness', 'gone')), nil, "gone claim: not when GMCP does not")
  eq(svo.gmcp_kept_claim(claim('rebounding', 'gone')), nil, "gone claim: a defence's is never kept")
  eq(svo.gmcp_kept_claim(claim('asthma', 'herb')), nil, "gone claim: a cure is not one, its own rmaff decides")
  eq(svo.gmcp_kept_claim(claim('asthma', 'aff')), nil, "gone claim: a gain is not one")
end

-- ===== scenario 16: GMCP first - the add backstop =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity', prone = 'prone' }
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'prone' } }
  h.afflist()
  svo.conf.gmcpaffechoes = true

  eq(svo.gmcp_refuse_add('sensitivity'), true, "add backstop: refuses one GMCP does not report")
  eq(calls.echof[1], "Didn't add sensitivity: GMCP doesn't report it.", "add backstop: and echoes it")
  eq(svo.gmcp_refuse_add('prone'), false, "add backstop: lets through one GMCP reports")
  eq(svo.gmcp_refuse_add('stun'), false, "add backstop: lets through one GMCP cannot report")
  eq(#calls.echof, 1, "add backstop: only a refusal is echoed")
end

-- ===== scenario 17: GMCP first - the remove backstop =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { torntendons = 'torntendons', asthma = 'asthma', slickness = 'slickness' }
  svo.dict.torntendons = { name = 'torntendons', count = 0 }
  svo.dict.asthma = { name = 'asthma' }
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'torntendons (3)' }, { name = 'asthma' } }
  h.afflist()
  svo.affs.torntendons = {}
  svo.affl.torntendons = { count = 3 }
  svo.conf.gmcpaffechoes = true

  eq(svo.gmcp_refuse_remove('asthma'), true, "remove backstop: keeps one GMCP still reports")
  eq(calls.echof[#calls.echof], "Kept asthma: GMCP still reports it.", "remove backstop: and echoes it")
  eq(calls.onprompt['gmcp count asthma'], nil, "remove backstop: no count to put back for an uncounted affliction")
  eq(svo.gmcp_refuse_remove('slickness'), false, "remove backstop: lets go of one GMCP does not report")

  -- 70 callers reset the count themselves right after rmaff returns
  eq(svo.gmcp_refuse_remove('torntendons'), true, "remove backstop: keeps a counted one GMCP still reports")
  svo.dict.torntendons.count = 0
  local fix = calls.onprompt['gmcp count torntendons']
  eq(type(fix), 'function', "remove backstop: queues the count fix for the prompt")
  fix = fix or function() end -- so a missing fix fails the checks below instead of crashing
  fix()
  eq(svo.dict.torntendons.count, 3, "remove backstop: the prompt puts GMCP's level back")
  contains(calls.updateaffcount, 'torntendons', "remove backstop: and announces the count")

  -- and by then GMCP may have removed it after all
  svo.affs.torntendons = nil
  svo.dict.torntendons.count = 0
  fix()
  eq(svo.dict.torntendons.count, 0, "remove backstop: a count fix leaves a since-removed affliction alone")
end

do
  local env, h, calls, svo = new_environment()
  load_block(block, env)
  load_block(trust_block, env)

  -- The loop the empty-cure gate used to fall into: asthma was cured during a
  -- blackout, no Remove came, and the stale entry kept it and re-cured it
  -- forever. Until the next List, GMCP keeps nothing.
  svo.dict.sstosvoa = { asthma = 'asthma' }
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'asthma' } }
  h.afflist()
  h.gotaff('blackout')

  eq(svo.gmcp_refuse_remove('asthma'), false, "remove backstop: a stale entry after blackout keeps nothing")
end

-- ===== scenario 18: GMCP first - the real addaffdict and rmaff ask =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity', prone = 'prone' }
  svo.dict.sensitivity = { name = 'sensitivity' }
  svo.dict.prone = { name = 'prone' }
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'prone' } }
  h.afflist()

  -- after the List: its handler calls svo.addaff, which this replaces with the
  -- real one, and the real one needs far more of svof than this harness has
  load_block(store_block, env)

  svo.addaffdict(svo.dict.sensitivity)
  eq(svo.affs.sensitivity, nil, "store: an add GMCP contradicts never reaches svo.affs")
  eq(svo.affl.sensitivity, nil, "store: nor svo.affl")
  not_contains(calls.events, "svo got aff sensitivity", "store: and raises no event")

  svo.addaffdict(svo.dict.prone)
  truthy(svo.affs.prone, "store: an add GMCP confirms goes through")
  contains(calls.events, "svo got aff prone", "store: and raises its event")

  svo.rmaff('prone')
  truthy(svo.affs.prone, "store: a removal GMCP contradicts is refused")
  not_contains(calls.events, "svo lost aff prone", "store: and raises no event")

  env.gaffl.prone = nil -- what the Remove handler does before it calls rmaff
  svo.rmaff('prone')
  eq(svo.affs.prone, nil, "store: once GMCP drops it, the removal goes through")
  contains(calls.events, "svo lost aff prone", "store: and raises its event")

  svo.affs.blackout = {}
  svo.addaffdict(svo.dict.sensitivity)
  truthy(svo.affs.sensitivity, "store: in blackout the text decides, as before")
end

-- ===== scenario 19: GMCP first - setting GMCP aside for an instruction =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity', prone = 'prone' }
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'prone' } }
  h.afflist()

  local seen = svo.gmcp_set_aside(function(a, b)
    return { refutes = svo.gmcp_refutes('sensitivity'), holds = svo.gmcp_holds('prone'), args = a .. b }
  end, 'x', 'y')
  eq(seen.refutes, false, "set aside: nothing is refused inside")
  eq(seen.holds, false, "set aside: nothing is kept inside")
  eq(seen.args, 'xy', "set aside: the arguments reach the function and its result comes back")
  eq(svo.gmcp_refutes('sensitivity'), true, "set aside: GMCP has the final word again afterwards")

  local ok, err = pcall(svo.gmcp_set_aside, function() error("boom", 0) end)
  eq(ok, false, "set aside: an error inside still raises")
  eq(err, "boom", "set aside: with its own message")
  eq(svo.sk.gmcp_stands_aside, nil, "set aside: and does not leave GMCP standing aside")

  svo.gmcp_set_aside(function()
    svo.gmcp_set_aside(function() end)
    eq(svo.sk.gmcp_stands_aside, true, "set aside: a nested call leaves the outer one in place")
  end)
end

-- ===== scenario 20: GMCP first - the public API works as documented =====
-- svo.addaff and svo.removeaff are documented to act "right away", and
-- people's own scripts depend on that.
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity', prone = 'prone', skullfractures = 'skullfractures' }
  for _, name in ipairs({'sensitivity', 'prone', 'skullfractures'}) do
    local entry = { name = name }
    entry.aff = { oncompleted = function() svo.addaffdict(entry) end }
    entry.gone = {
      oncompleted = function() svo.rmaff(name) end,
      general_cure = function() svo.rmaff(name) end,
    }
    svo.dict[name] = entry
  end
  svo.dict.skullfractures.count = 2
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'prone' }, { name = 'skullfractures (2)' } }
  h.afflist()
  load_block(store_block, env)
  svo.addaffdict(svo.dict.prone)
  svo.addaffdict(svo.dict.skullfractures)

  svo.addaff('sensitivity')
  truthy(svo.affs.sensitivity, "public API: svo.addaff adds what GMCP does not report")

  eq(svo.removeaff('prone'), true, "public API: svo.removeaff reports the removal")
  eq(svo.affs.prone, nil, "public API: and removes what GMCP still reports")

  svo.removeafflevel('skullfractures')
  eq(svo.affs.skullfractures, nil, "public API: svo.removeafflevel acts even where GMCP disagrees")

  svo.gmcp_set_aside(svo.rmaff, 'sensitivity')
  svo.addaff(svo.dict.sensitivity)
  truthy(svo.affs.sensitivity, "public API: so does svo.addaff given a dictionary entry")

  -- and none of it leaves GMCP standing aside for svof's own adds
  svo.gmcp_set_aside(svo.rmaff, 'sensitivity')
  svo.addaffdict(svo.dict.sensitivity)
  eq(svo.affs.sensitivity, nil, "public API: afterwards svof's own adds are checked again")
end

-- ===== scenario 21: GMCP first - vaff, vrmaff and vreset work as before =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { sensitivity = 'sensitivity', prone = 'prone' }
  for _, name in ipairs({'sensitivity', 'prone'}) do
    local entry = { name = name }
    entry.aff = { oncompleted = function() svo.addaffdict(entry) end }
    entry.gone = { oncompleted = function() svo.rmaff(name) end }
    svo.dict[name] = entry
  end
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'prone' } }
  h.afflist()
  load_block(store_block, env)
  load_block(resetaffs_block, env)
  load_block(vaff_block, env)
  svo.addaffdict(svo.dict.prone)

  svo.vrmaff('prone')
  eq(svo.affs.prone, nil, "vrmaff: removes what GMCP still reports")

  svo.vaff('sensitivity')
  truthy(svo.affs.sensitivity, "vaff typed: adds what GMCP does not report")

  svo.addaffdict(svo.dict.prone)
  svo.reset.affs()
  eq(next(svo.affs), nil, "vreset: clears everything, including what GMCP still reports")
end

-- ===== scenario 22: GMCP first - the recklessness guess about a hidden affliction =====
-- "You are confused as to the effects of the venom." is the game hiding an
-- affliction, and the game does not send a hidden affliction over GMCP. When
-- the prompt reads full straight after one, svof takes the hidden one for
-- recklessness. The add backstop refused that guess because GMCP did not
-- report recklessness, which it never would: in a live fight svof then took
-- 26% health for full and spent the elixir on a limb instead of healing.
-- Runs the dictionary's own entries through the real addaffdict.
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  svo.dict.sstosvoa = { recklessness = 'recklessness', prone = 'prone', sensitivity = 'sensitivity' }
  svo.dict.recklessness = { name = 'recklessness' }
  svo.dict.sensitivity = { name = 'sensitivity' }
  build_reverse_indexes(env)
  env.gmcp.Char.Afflictions.List = { { name = 'prone' } }
  h.afflist()
  load_block(store_block, env)
  svo.conf.gmcpaffechoes = true

  env.stats = { currenthealth = 7188, maxhealth = 7188, currentmana = 6252, maxmana = 6252 }
  env.codepaste = {}
  load_block(addunknown_block, env)
  load_block("svo.hidden_under_test = {\n" .. hidden_block .. "\n}", env)
  local hidden = svo.hidden_under_test
  hidden.unknownany.name, hidden.unknownmental.name = 'unknownany', 'unknownmental'
  svo.dict.unknownany, svo.dict.unknownmental = hidden.unknownany, hidden.unknownmental

  local function reset()
    for name in pairs(svo.affs) do svo.affs[name] = nil end
    for name in pairs(svo.affl) do svo.affl[name] = nil end
    hidden.unknownany.count, hidden.unknownmental.count = 0, 0
  end

  -- health was down before the venom line, and the prompt after it reads full
  hidden.unknownany.reckhp = true
  hidden.unknownany.aff.oncompleted(1)
  truthy(svo.affs.recklessness, "hidden: one hidden affliction and full stats are taken as recklessness")
  eq(svo.affs.unknownany, nil, "hidden: and that affliction is not counted as an unknown too")
  not_contains(calls.echof, "Didn't add recklessness: GMCP doesn't report it.", "hidden: GMCP does not refuse the guess")
  eq(hidden.unknownany.reckhp, false, "hidden: the flag is spent")

  reset()
  hidden.unknownany.reckmana = true
  hidden.unknownany.aff.oncompleted(2)
  truthy(svo.affs.recklessness, "hidden: of two hidden afflictions, one is taken as recklessness")
  eq(hidden.unknownany.count, 1, "hidden: and the other stays an unknown")

  reset()
  svo.paragraph_length = 1
  hidden.unknownany.reckhp = true
  hidden.unknownany.aff.wrack()
  truthy(svo.affs.recklessness, "hidden: a hidden wrack before full stats is taken as recklessness")

  reset()
  hidden.unknownmental.reckhp = true
  hidden.unknownmental.aff.oncompleted(1)
  truthy(svo.affs.recklessness, "hidden: a hidden mental affliction before full stats is taken as recklessness")
  eq(svo.affs.unknownmental, nil, "hidden: and is not counted as an unknown mental one too")

  -- no full stats, no guess: the hidden affliction stays an unknown
  reset()
  env.stats.currenthealth = 5780
  hidden.unknownany.reckhp = true
  hidden.unknownany.aff.oncompleted(1)
  eq(svo.affs.recklessness, nil, "hidden: without full stats there is no guess")
  eq(hidden.unknownany.count, 1, "hidden: the affliction is counted as an unknown instead")

  -- and GMCP still has the final word on everything else
  eq(svo.sk.gmcp_stands_aside, nil, "hidden: the guess does not leave GMCP standing aside")
  svo.addaffdict(svo.dict.sensitivity)
  eq(svo.affs.sensitivity, nil, "hidden: svof's other adds are still checked afterwards")
end

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do
    print("FAIL: " .. msg)
  end
  os.exit(1)
end
print("ALL PASS")
