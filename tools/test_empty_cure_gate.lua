--[[
Logic-level test for presume_cured() in
`src/scripts/svo (setup, misc, empty, funnies, dor)/Empty_cure_handling.lua`.

Same approach as tools/test_gmcp_reconciler.lua, tools/test_lifevision_validate.lua
and tools/test_pyre_ladder.lua: the code under test is extracted from the real
source by anchor text and run in a stub environment, so it is a substring of what
ships rather than a reimplementation, and the test fails loudly if the anchors
move instead of quietly testing stale logic.

What it covers. Every handler in that file acts on one inference: a cure that
cured nothing means we did not have the afflictions it would have cured. svof
used to act on that unconditionally, so a wrong name in one of those lists made
it forget an affliction still held and stop curing it. presume_cured checks the
game first.

Five things it pins:

  * GMCP overrules the inference. A name Char.Afflictions still reports is kept.
  * The gate only applies where GMCP can speak. A name absent from
    svo.dict.svotossa - the four unknowns, and earworm - is removed the way it
    always was, because there the inference is the only information there is,
    and resolving an unknown this way is the whole point of tracking one.
  * Levelled names match. GMCP keys an affliction at level 2 and up as
    "name (2)" and bare at level 1, so a comparison on the raw key would keep
    a level-1 affliction and drop a level-2 one.
  * Blackout presumes nothing. Char.Afflictions stops entirely during blackout,
    so svo.gaffl goes stale rather than empty and every name would read as
    still held; removing on that would be acting on a frozen snapshot.
  * A string argument behaves like a one-element list, because two call sites
    pass one.

It proves nothing about Mudlet integration or real combat.

Run: lua tools/test_empty_cure_gate.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local SRC = "src/scripts/svo (setup, misc, empty, funnies, dor)/Empty_cure_handling.lua"

local START_ANCHOR = "local function presume_cured(which)"
local END_ANCHOR = "  svo.rmaff(gone)\nend"

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return (data:gsub("\r\n", "\n"))
end

local function extract_block(source)
  local s = source:find(START_ANCHOR, 1, true)
  if not s then
    error("start anchor not found in " .. SRC ..
      " - presume_cured moved or was renamed; update this test's anchors")
  end
  local e = source:find(END_ANCHOR, s, true)
  if not e then
    error("end anchor not found in " .. SRC ..
      " - presume_cured's body changed shape; update this test's anchors")
  end
  return source:sub(s, e + #END_ANCHOR - 1)
end

local block = extract_block(read_file(SRC))
print(string.format("extracted %d bytes of the real presume_cured from %s", #block, SRC))

-- The svof names this test uses, and the GMCP name each maps to. Mirrors the
-- shape of svo.dict.svotossa, which the dictionary builds by reversing
-- sstosvoa and which omits anything mapped to false there.
local SVOTOSSA = {
  asthma      = 'asthma',
  slickness   = 'slickness',
  torntendons = 'torntendons',
  latched     = 'latched',
  -- deliberately absent: unknownany, unknownmental, earworm. GMCP cannot
  -- report these, so the gate must leave them to the old behaviour.
}

local checks, failures = 0, {}
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures[#failures + 1] = string.format("%s: got %s, want %s", desc,
      tostring(got), tostring(want))
  end
end

-- Builds a fresh environment and returns presume_cured plus what it removed.
local function harness(gafflkeys, blackout)
  local removed = {}
  local affs = {blackout = blackout or nil}
  local svo = {
    affs = affs,
    gaffl = {},
    dict = {svotossa = SVOTOSSA},
    debugf = function() end,
    rmaff = function(list)
      if type(list) == 'string' then list = {list} end
      for _, name in ipairs(list) do removed[#removed + 1] = name end
    end,
  }
  for _, key in ipairs(gafflkeys) do svo.gaffl[key] = true end

  local env = {
    svo = svo, affs = affs,
    type = type, pairs = pairs, ipairs = ipairs, tostring = tostring,
    string = string, table = table,
  }

  -- Mudlet runs Lua 5.1, where load() takes a reader function and only
  -- loadstring() takes a source string, with the environment applied via
  -- setfenv. 5.2+ folded both into load(). Branch on setfenv rather than on a
  -- version string, so this runs under either.
  local chunk, err
  if setfenv then
    chunk, err = loadstring(block .. "\nreturn presume_cured", "presume_cured_under_test")
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(block .. "\nreturn presume_cured", "presume_cured_under_test", "t", env)
  end
  if not chunk then error("could not load the extracted block: " .. tostring(err)) end

  local fn = chunk()
  if type(fn) ~= 'function' then
    error("the extracted block did not define presume_cured")
  end
  return fn, removed
end

local function has(list, name)
  for _, v in ipairs(list) do if v == name then return true end end
  return false
end

-- ===== GMCP overrules the inference =====
do
  local presume_cured, removed = harness({'asthma'})
  presume_cured({'asthma', 'slickness'})
  check("an affliction the game still reports is kept", has(removed, 'asthma'), false)
  check("one the game does not report is removed", has(removed, 'slickness'), true)
end

-- ===== the gate only applies where GMCP can speak =====
do
  local presume_cured, removed = harness({'asthma'})
  presume_cured({'unknownany', 'unknownmental', 'earworm'})
  check("unknownany, which GMCP cannot report, is still removed",
    has(removed, 'unknownany'), true)
  check("unknownmental, same, is still removed", has(removed, 'unknownmental'), true)
  check("earworm, the one real affliction GMCP cannot report, is still removed",
    has(removed, 'earworm'), true)
end

-- ===== levelled GMCP names =====
do
  -- level 2 and up is keyed "name (2)"; a raw comparison would miss this and
  -- drop an affliction the game had just reported.
  local presume_cured, removed = harness({'torntendons (2)'})
  presume_cured({'torntendons', 'slickness'})
  check("an affliction reported at level 2 is kept", has(removed, 'torntendons'), false)
  check("the other name in the same call is still removed",
    has(removed, 'slickness'), true)
end

do
  -- level 1 is keyed bare, the way an unlevelled affliction is
  local presume_cured, removed = harness({'torntendons'})
  presume_cured({'torntendons'})
  check("an affliction reported at level 1 is kept", has(removed, 'torntendons'), false)
end

-- ===== blackout presumes nothing =====
do
  local presume_cured, removed = harness({}, true)
  presume_cured({'asthma', 'slickness', 'unknownany'})
  check("blackout removes nothing at all", #removed, 0)
end

do
  -- and without blackout the same call clears everything, so the check above
  -- is testing the guard rather than an empty list
  local presume_cured, removed = harness({})
  presume_cured({'asthma', 'slickness', 'unknownany'})
  check("outside blackout, an unreported list is cleared", #removed, 3)
end

-- ===== a string argument =====
do
  local presume_cured, removed = harness({'latched'})
  presume_cured('latched')
  check("a string the game still reports is kept", #removed, 0)
end

do
  local presume_cured, removed = harness({})
  presume_cured('voyria')
  check("a string the game does not report is removed", has(removed, 'voyria'), true)
end

-- ===== today's behaviour is preserved when GMCP has said nothing =====
do
  -- An empty svo.gaffl is what a profile looks like before the first
  -- Char.Afflictions message. Everything falls through to the old behaviour,
  -- which is the fail-safe direction: no cure is silently skipped.
  local presume_cured, removed = harness({})
  presume_cured({'asthma', 'slickness', 'torntendons', 'latched'})
  check("with no GMCP data at all, every name is removed as before", #removed, 4)
end

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
