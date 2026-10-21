--[[
Logic-level regression test for the balances a pear takes, in pressure's
dictionary entry in
`src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua`
and empty.eat_pear in
`src/scripts/svo (setup, misc, empty, funnies, dor)/Empty_cure_handling.lua`.

Same approach as tools/test_latched.lua: the code under test is extracted
from the real source files by anchor text and run in a stub environment, so it
is what ships rather than a reimplementation, and the test fails loudly if the
anchors move instead of silently testing stale logic.

What it pins, checked in game: pressure is cured by eating a pear, which takes
no balance at all unless it cures pressure, and then takes smoke balance only.
So the two cure lines (one level gone, or the last) take smoke balance, and
the no-effect line and an empty pear take none. A wrong smoke balance held off
elm, valerian and pear until the balance reset; a wrong herb balance held off
every herb. pear stays out of the herb loop's lists, since a pear that cures
nothing there would take herb balance.

GMCP is not stubbed here. The no-effect line can't arrive while GMCP still
lists pressure: GMCP reaches the client before the game's lines, and the game
lists no pressure the pear would have cured.

It proves nothing about Mudlet integration, the game, or real combat.

Run: lua tools/test_pear_balance.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local EMPTY = "src/scripts/svo (setup, misc, empty, funnies, dor)/Empty_cure_handling.lua"

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return (data:gsub("\r\n", "\n"))
end

local function extract(source, path, start_anchor, end_anchor, keep_end)
  local s = source:find(start_anchor, 1, true)
  if not s then error("start anchor not found in " .. path .. ": " .. start_anchor) end
  local e = source:find(end_anchor, s + #start_anchor, true)
  if not e then error("end anchor not found in " .. path .. ": " .. end_anchor) end
  return source:sub(s, keep_end and (e + #end_anchor - 1) or (e - 1))
end

local empty_source = read_file(EMPTY)
-- The entry runs from its own key to the next entry's.
local entry_src = extract(read_file(DICT), DICT, "    pressure = {", "    cholerichumour = {")
local eat_pear_src = extract(empty_source, EMPTY, "empty.eat_pear = function()", "\nend\n", true)
-- the herbs the herb loop makes handlers for, empty.herb_affs
local herb_loop_src = extract(empty_source, EMPTY, "empty.herb_affs = {", "for herbname, herbaffs in pairs(empty.herb_affs) do")
print(string.format("extracted %d bytes of the real pressure entry and %d of empty.eat_pear",
  #entry_src, #eat_pear_src))

-- Mudlet runs Lua 5.1, where only loadstring() takes a source string and the
-- environment is applied separately via setfenv. Branch on setfenv rather than
-- on a version string so this runs under either.
local function run(code, name, env)
  local chunk, err
  if setfenv then
    chunk, err = loadstring(code, name)
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(code, name, "t", env)
  end
  if not chunk then error("could not load " .. name .. ": " .. tostring(err)) end
  return chunk()
end

-- One fresh stub world per scenario, recording what the code under test does.
local function world()
  local w = { smoke = 0, herb = 0, removed = {}, presumed = {}, eaten = {} }
  local svo = { dict = {} }
  function svo.lostbal_smoke() w.smoke = w.smoke + 1 end
  function svo.lostbal_herb() w.herb = w.herb + 1 end
  function svo.rmaff(name) w.removed[#w.removed + 1] = name end
  function svo.updateaffcount() end
  function svo.addaffdict() end
  function svo.eat(action) w.eaten[#w.eaten + 1] = action end
  local empty = {}
  local env = {
    svo = svo, empty = empty, affs = { pressure = true }, bals = { smoke = true },
    presume_cured = function(what) w.presumed[#w.presumed + 1] = what end,
  }
  svo.dict.pressure = run("return {\n" .. entry_src .. "\n}", "pressure entry", env).pressure
  run(eat_pear_src, "empty.eat_pear", env)
  w.entry, w.empty = svo.dict.pressure, empty
  return w
end

local checks, failures = 0, 0
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures = failures + 1
    print(string.format("FAIL %s: got %s, want %s", desc, tostring(got), tostring(want)))
  end
end

-- A pear is eaten from the smoke slot, so it checks smoke balance, not herb.
do
  local w = world()
  check("pressure's cure sits on the smoke slot", type(w.entry.smoke), "table")
  check("pressure has no herb cure", w.entry.herb, nil)
  check("the cure eats pear first", w.entry.smoke.eatcure[1], "pear")
  w.entry.smoke.onstart()
  check("onstart eats from the smoke slot", w.eaten[1], w.entry.smoke)
end

-- A pear that cures pressure takes smoke balance, and nothing else.
do
  local w = world()
  w.entry.smoke.oncompleted()
  check("a level cured takes smoke balance", w.smoke, 1)
  check("a level cured takes no herb balance", w.herb, 0)
end

do
  local w = world()
  w.entry.smoke.cured()
  check("the last level cured takes smoke balance", w.smoke, 1)
  check("the last level cured takes no herb balance", w.herb, 0)
  check("the last level cured removes pressure", w.removed[1], "pressure")
end

-- A pear that cures nothing takes no balance.
do
  local w = world()
  w.entry.smoke.noeffect()
  check("the no-effect line takes no smoke balance", w.smoke, 0)
  check("the no-effect line takes no herb balance", w.herb, 0)
  check("the no-effect line removes pressure", w.removed[1], "pressure")
end

do
  local w = world()
  w.entry.smoke.empty()
  check("an empty pear takes no smoke balance", w.smoke, 0)
  check("an empty pear takes no herb balance", w.herb, 0)
  check("an empty pear presumes pressure cured", w.presumed[1], "pressure")
end

do
  local w = world()
  w.empty.eat_pear()
  check("empty.eat_pear takes no smoke balance", w.smoke, 0)
  check("empty.eat_pear takes no herb balance", w.herb, 0)
end

-- The herb loop's handlers take herb balance, so pear must stay out of it.
check("pear is not in the herb loop", herb_loop_src:find("pear", 1, true), nil)

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
print("ALL PASS")
