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
it forget an affliction still held and stop curing it. The game is asked
first, but no longer here: presume_cured hands its whole list to svo.rmaff,
whose backstop keeps anything GMCP still reports (svo.gmcp_refuse_remove in
Setup.lua). The GMCP cases this file used to cover - an affliction the game
still reports is kept, levelled names match, names GMCP cannot report are
removed, nothing is kept before the first List - are tested against the real
backstop in tools/test_gmcp_reconciler.lua (scenarios 14 and 17), along with
the two it used to get wrong: sleep and seriousconcussion under their other
game name, and the stale entry after a blackout that kept an affliction cured
during it and re-cured it forever.

Three things it pins here:

  * Blackout presumes nothing. Char.Afflictions stops entirely during
    blackout and the cure lines themselves can go unseen, so nothing is
    removed at all.
  * Outside blackout every name goes to svo.rmaff, including ones GMCP still
    reports: keeping those is rmaff's decision, made in one place, and a
    second copy of it here is what went stale.
  * A string argument behaves like a one-element list, because two call sites
    pass one.

It proves nothing about Mudlet integration or real combat.

Run: lua tools/test_empty_cure_gate.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local SRC = "src/scripts/svo (setup, misc, empty, funnies, dor)/Empty_cure_handling.lua"

local START_ANCHOR = "local function presume_cured(which)"
local END_ANCHOR = "  svo.rmaff(which)\nend"

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

local checks, failures = 0, {}
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures[#failures + 1] = string.format("%s: got %s, want %s", desc,
      tostring(got), tostring(want))
  end
end

-- Builds a fresh environment and returns presume_cured plus what it handed to
-- svo.rmaff. gafflkeys fills svo.gaffl, so a scenario can show presume_cured
-- no longer reads it.
local function harness(gafflkeys, blackout)
  local removed = {}
  local affs = {blackout = blackout or nil}
  local svo = {
    affs = affs,
    gaffl = {},
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

-- ===== blackout presumes nothing =====
do
  local presume_cured, removed = harness({}, true)
  presume_cured({'asthma', 'slickness', 'unknownany'})
  check("blackout removes nothing at all", #removed, 0)
end

do
  -- and without blackout the same call hands everything on, so the check
  -- above is testing the guard rather than an empty list
  local presume_cured, removed = harness({})
  presume_cured({'asthma', 'slickness', 'unknownany'})
  check("outside blackout, the whole list goes to rmaff", #removed, 3)
end

-- ===== rmaff decides, not a second copy of its check =====
do
  -- asthma is in gaffl, and presume_cured still hands it on: whether to keep
  -- it is the backstop's call inside rmaff, which knows about blackouts and
  -- about sleep's two game names.
  local presume_cured, removed = harness({'asthma', 'torntendons (2)'})
  presume_cured({'asthma', 'torntendons', 'slickness'})
  check("an affliction gaffl lists still goes to rmaff", has(removed, 'asthma'), true)
  check("a levelled one too", has(removed, 'torntendons'), true)
  check("and one gaffl does not list", has(removed, 'slickness'), true)
end

-- ===== a string argument =====
do
  local presume_cured, removed = harness({})
  presume_cured('voyria')
  check("a string goes to rmaff", has(removed, 'voyria'), true)
  check("as exactly one name", #removed, 1)
end

do
  local presume_cured, removed = harness({}, true)
  presume_cured('voyria')
  check("a string in blackout removes nothing", #removed, 0)
end

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
