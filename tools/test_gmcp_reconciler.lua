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
    checkaeony = 0, changecuring = 0,
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
  svo.gaffl = {}
  svo.gdefc = {}
  svo.defc = {}
  svo.defs = {}
  svo.me = {}
  svo.conf = { gmcpaffechoes = false, gmcpdefechoes = false }
  svo.sk = {}
  svo.valid = {}

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
  function svo.echof(...) end
  function svo.debugf(fmt, ...) calls.debugf[#calls.debugf + 1] = string.format(fmt, ...) end
  function svo.valid.remove_unknownany(name) calls.remove_unknownany[#calls.remove_unknownany + 1] = name end
  function svo.sk.checkaeony() calls.checkaeony = calls.checkaeony + 1 end

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
  signals.gmcpcharafflictionslist = new_signal("afflist")
  signals.gmcpcharafflictionsremove = new_signal("affremove")
  signals.gmcpcharafflictionsadd = new_signal("affadd")
  signals.gmcpchardefenceslist = new_signal("deflist")
  signals.gmcpchardefencesremove = new_signal("defremove")
  signals.gmcpchardefencesadd = new_signal("defadd")

  local gmcp = { Char = { Afflictions = {}, Defences = {} } }

  local env = {
    svo = svo, signals = signals, luanotify = luanotify, gmcp = gmcp,
    -- upvalues the real file aliases at the top of Setup.lua before this block
    sk = svo.sk, conf = svo.conf, defc = svo.defc, gaffl = svo.gaffl, me = svo.me,
    -- stdlib the block needs
    string = string, table = table, tonumber = tonumber, pairs = pairs, ipairs = ipairs,
    type = type, tostring = tostring, error = error, setmetatable = setmetatable,
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

-- ===== scenario 6: G1/G2 - the List reconciler =====
do
  local env, h, calls, svo = new_environment()
  load_block(block, env)

  -- Three real mappings, none of them an identity, and deliberately the
  -- nastiest shape in the dictionary: GMCP 'burning' is svof 'ablaze', while
  -- 'burning' is *also* a svof name in its own right (GMCP 'flamefisted').
  -- An identity fixture makes the two key spaces indistinguishable, so every
  -- assertion below would hold even if the gate and the loop keyed on the
  -- wrong one. 46 of the 145 string-valued sstosvoa entries differ like this.
  -- 'unreachable' is one of the names GMCP can never confirm or deny (no
  -- sstosvoa entry). Two items in the reported list so the checkaeony/
  -- changecuring frequency assertions below actually distinguish "once per
  -- list" from "once per item" (a list of one can't tell the two apart).
  svo.dict.sstosvoa = { burning = 'ablaze', flamefisted = 'burning', nausea = 'illness' }
  build_reverse_indexes(env)

  svo.affl = { ablaze = { count = 1 }, burning = { count = 1 }, illness = { count = 1 }, unreachable = { count = 1 } }
  env.gmcp.Char.Afflictions.List = { { name = 'burning' }, { name = 'flamefisted' } }

  h.afflist()

  eq(calls.checkaeony, 1, "G1/G7-followup: checkaeony fires exactly once per List event, not once per item (list had 2 items)")
  eq(calls.changecuring, 1, "G1/G7-followup: changecuring fires exactly once per List event, not once per item (list had 2 items)")

  eq(#calls.addaff, 0, "G1: an affliction already tracked and still in the list is not re-added")
  contains(calls.rmaff, 'illness', "G1/G2: a GMCP-reachable affliction absent from the list IS removed, under its svof name")
  not_contains(calls.rmaff, 'unreachable', "G2: an affliction GMCP cannot report is NEVER removed, even when absent from the list")
  not_contains(calls.rmaff, 'ablaze', "G1: an affliction the list confirms under a different GMCP name is not removed")
  not_contains(calls.rmaff, 'burning', "G1: the svof name that collides with another affliction's GMCP name is not removed either")

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

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do
    print("FAIL: " .. msg)
  end
  os.exit(1)
end
print("ALL PASS")
