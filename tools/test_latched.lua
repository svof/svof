--[[
Logic-level regression test for latched's dictionary entry in
`src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua`
and its gain-line handler, svo.valid.simplelatched, in
`src/scripts/svo (trigger functions)/Simple_aff_trigger_functions.lua`.

Same approach as tools/test_pyre_ladder.lua: the code under test is extracted
from the real source files by anchor text and run in a stub environment, so it
is what ships rather than a reimplementation, and the test fails loudly if the
anchors move instead of silently testing stale logic.

What it pins: gaining latched knocks you off sip balance, and only the gain
line may record that. It is printed as the balance goes, so the game's "You
may drink another" line gives the balance back on time. Every other way
latched is added is not the moment it was gained:

  * a GMCP List, after a reload or a login, adds it through svo.addaff, which
    runs aff.oncompleted with nothing;
  * DIAGNOSE adds it through the aff action with nothing (it passes a count
    only to counted afflictions, and latched has none);
  * a GMCP Add calls addaffdict directly, which runs onadded. An Add can be the
    game unmasking, after blackout, a latched gained during it. Taking the
    balance then, with no regain line to follow, stops health and mana sipping
    until the fallback timer runs out.

So the entry must have no onadded at all, and aff.oncompleted must take the
balance only when the gain line says 'gained'.

It proves nothing about Mudlet integration, the game, or real combat.

Run: lua tools/test_latched.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local SIMPLE = "src/scripts/svo (trigger functions)/Simple_aff_trigger_functions.lua"

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

-- The entry runs from its own key to the next entry's.
local entry_src = extract(read_file(DICT), DICT, "    latched = {", "    voided = {")
local handler_src = extract(read_file(SIMPLE), SIMPLE, "svo.valid.simplelatched = function ()", "\nend\n", true)
print(string.format("extracted %d bytes of the real latched entry and %d of svo.valid.simplelatched",
  #entry_src, #handler_src))

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
  local w = { strips = 0, removed = {}, added = {}, lifevision = {} }
  local svo = { dict = {}, valid = {} }
  function svo.lostbal_sip() w.strips = w.strips + 1 end
  function svo.addaffdict(entry) w.added[#w.added + 1] = entry end
  function svo.rmaff(name) w.removed[#w.removed + 1] = name end
  function svo.doingaction() return false end
  function svo.sip() end
  function svo.checkaction() end
  local env = {
    svo = svo, affs = {}, codepaste = { badaeon = function() end },
    actions = { latched_aff = { p = 'latched_aff action' } },
    lifevision = { add = function(...) w.lifevision[#w.lifevision + 1] = {...} end },
  }
  svo.dict.latched = run("return {\n" .. entry_src .. "\n}", "latched entry", env).latched
  run(handler_src, "simplelatched", env)
  w.svo, w.entry = svo, svo.dict.latched
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

-- addaffdict runs onadded for a GMCP Add, a List and DIAGNOSE alike.
do
  local w = world()
  check("the entry has no onadded, so addaffdict cannot take sip balance", w.entry.onadded, nil)
  check("the entry has no count, so DIAGNOSE passes it nothing", w.entry.count, nil)
end

-- A GMCP List (svo.addaff) and DIAGNOSE both run aff.oncompleted with nothing.
do
  local w = world()
  w.entry.aff.oncompleted()
  check("aff.oncompleted with nothing adds latched", w.added[1], w.entry)
  check("aff.oncompleted with nothing takes no sip balance", w.strips, 0)
end

do
  local w = world()
  w.entry.aff.oncompleted('gained')
  check("aff.oncompleted('gained') adds latched", w.added[1], w.entry)
  check("aff.oncompleted('gained') takes sip balance once", w.strips, 1)
end

-- The gain line's handler is the one place that says 'gained'.
do
  local w = world()
  w.svo.valid.simplelatched()
  local call = w.lifevision[1]
  check("the gain line files one claim", #w.lifevision, 1)
  check("the claim is latched's aff action", call and call[1], 'latched_aff action')
  check("the claim runs the default oncompleted", call and call[2], nil)
  check("the claim says 'gained'", call and call[3], 'gained')

  -- and that claim, completed as lifevision would, takes the balance once
  w.entry.aff.oncompleted(call and call[3])
  check("the gain line takes sip balance once", w.strips, 1)
end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then print("FAILED") os.exit(1) end
print("ALL PASS")
