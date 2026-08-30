--[[
Logic-level regression test for codepaste.pyre_holds() in
`src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua`.

Same approach as tools/test_gmcp_reconciler.lua and
tools/test_lifevision_validate.lua: the code under test is extracted from the
real source file by anchor text and executed in a stub environment, so it is a
substring of what ships rather than a reimplementation, and the test fails
loudly if the anchors move instead of silently testing stale logic.

What it covers: the pyre/burn ladder that gates the five burn salves. Pyre
builds pyre and ablaze, and a burn cannot tick down below the pyre level, so
salving a burn at or under that level is wasted - it comes straight back.
Applying takes the burn down exactly one rung, so the burn's own index in
sk.burns is the threshold.

Three things it pins:

  * the off-by-one. The thresholds used to be the burn's index plus one, which
    salved a burn pyre would immediately restore at every rung.
  * the field. svo.affs entries are { p = <dict entry>, sw = <stopwatch> } and
    svo.affs carries no __index, so reading affs.pyre.count gave nil and
    `nil >= 2` raised - aborting the whole prompt, not returning a wrong
    answer.
  * the floor. Having pyre at all is level 1 or more, but only the GMCP path
    ever raises svo.dict.pyre.count, so without GMCP the stored level sits at
    0 while the affliction is genuinely there.

It proves nothing about Mudlet integration or real combat.

Run: lua tools/test_pyre_ladder.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local SRC = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"

local START_ANCHOR = "codepaste.pyre_holds = function(burn)"
local END_ANCHOR = "table.index_of(sk.burns, burn)\nend"

-- pyre's in-game maximum. Above this the higher two rungs cannot be held, and
-- the test asserts that rather than leaving it implied.
local PYRE_CAP = 3

local BURNS = {'ablaze', 'severeburn', 'extremeburn', 'charredburn', 'meltingburn'}

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
    error("start anchor not found in " .. SRC ..
      " - codepaste.pyre_holds moved or was reworded; update this test's anchors")
  end
  local e = source:find(END_ANCHOR, s, true)
  if not e then
    error("end anchor not found in " .. SRC ..
      " - codepaste.pyre_holds's body changed shape; update this test's anchors")
  end
  return source:sub(s, e + #END_ANCHOR - 1)
end

local block = extract_block(read_file(SRC))
print(string.format("extracted %d bytes of the real pyre_holds from %s", #block, SRC))

-- Mudlet ships table.index_of; plain Lua does not.
local stub_table = setmetatable({
  index_of = function(t, value)
    for i, v in ipairs(t) do if v == value then return i end end
  end
}, {__index = table})

local affs = {}
local sk = {burns = BURNS}
local codepaste = {}

local env = {
  affs = affs, sk = sk, codepaste = codepaste,
  math = math, table = stub_table, ipairs = ipairs, pairs = pairs,
}

-- Mudlet runs Lua 5.1, where load() takes a reader function and only
-- loadstring() takes a source string, with the environment applied separately
-- via setfenv. 5.2+ folded both into load(). Branch on setfenv rather than on
-- a version string so this runs under either.
local chunk, err
if setfenv then
  chunk, err = loadstring(block, "pyre_holds_under_test")
  if chunk then setfenv(chunk, env) end
else
  chunk, err = load(block, "pyre_holds_under_test", "t", env)
end
if not chunk then error("could not load the extracted block: " .. tostring(err)) end
chunk()

if type(codepaste.pyre_holds) ~= 'function' then
  error("the extracted block did not define codepaste.pyre_holds")
end

local checks, failures = 0, 0
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures = failures + 1
    print(string.format("FAIL %s: got %s, want %s", desc, tostring(got), tostring(want)))
  end
end

-- No pyre at all: nothing is held, and the function must not index a nil.
affs.pyre = nil
for _, burn in ipairs(BURNS) do
  check("no pyre, " .. burn, codepaste.pyre_holds(burn), false)
end

-- Pyre tracked at its real levels. The burn's index in sk.burns is the
-- threshold: held when the pyre level has reached it.
for level = 1, PYRE_CAP do
  affs.pyre = {p = {count = level}}
  for index, burn in ipairs(BURNS) do
    check(string.format("pyre %d vs %s (rung %d)", level, burn, index),
      codepaste.pyre_holds(burn), level >= index)
  end
end

-- The old thresholds were the rung plus one. Spelled out so a regression to
-- them fails here by name rather than as an anonymous arithmetic slip.
affs.pyre = {p = {count = 1}}
check("pyre 1 holds ablaze (the off-by-one rung)", codepaste.pyre_holds('ablaze'), true)
affs.pyre = {p = {count = 2}}
check("pyre 2 holds severeburn (the off-by-one rung)", codepaste.pyre_holds('severeburn'), true)
affs.pyre = {p = {count = 3}}
check("pyre 3 holds extremeburn (the off-by-one rung)", codepaste.pyre_holds('extremeburn'), true)

-- At pyre's cap the top two rungs are still free. They are written the same
-- way as the rest rather than dropped, so the rule survives a cap change.
affs.pyre = {p = {count = PYRE_CAP}}
check("pyre at cap frees charredburn", codepaste.pyre_holds('charredburn'), false)
check("pyre at cap frees meltingburn", codepaste.pyre_holds('meltingburn'), false)

-- Pyre present but its level never tracked - the non-GMCP case, where
-- svo.dict.pyre.count stays 0. Presence floors the level at 1, so ablaze is
-- held and the rest are not.
affs.pyre = {p = {count = 0}}
check("untracked pyre holds ablaze", codepaste.pyre_holds('ablaze'), true)
check("untracked pyre frees severeburn", codepaste.pyre_holds('severeburn'), false)

-- Same, with the count field absent entirely rather than zero.
affs.pyre = {p = {}}
check("pyre with no count field holds ablaze", codepaste.pyre_holds('ablaze'), true)
check("pyre with no count field frees severeburn", codepaste.pyre_holds('severeburn'), false)

-- The field the old code read. It must not be what the answer depends on: a
-- bare .count set high while .p says otherwise has to be ignored.
affs.pyre = {count = 5, p = {count = 1}}
check("a bare .count is not read for severeburn", codepaste.pyre_holds('severeburn'), false)
check("a bare .count is not read for ablaze", codepaste.pyre_holds('ablaze'), true)

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then print("FAILED") os.exit(1) end
print("ALL PASS")
