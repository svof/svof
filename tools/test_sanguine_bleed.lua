--[[
Logic-level regression test for where the bleeding an inundated sanguine
humour gives comes from: sanguinehumour's inundated handler in
`src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua`
and the Char.Vitals handler in
`src/scripts/svo (setup, misc, empty, funnies, dor)/Setup.lua`.

Same approach as tools/test_bare_dict.lua: the code under test is extracted
from the real source files by anchor text and executed in a stub environment,
so it is a substring of what ships rather than a reimplementation, and the
test fails loudly if the anchors move instead of silently testing stale logic.

What it covers: Char.Vitals reports bleeding as "Bleed: N", and the Vitals
handler records that amount. Vitals arrives before the prompt, and the
inundated line is processed at the prompt, so inundated used to overwrite the
game's amount with its own, the sanguine level times 250, until the next
Vitals. Now:

  * a Vitals with a Bleed: value marks the paragraph, and the mark is cleared
    after the prompt's lifevision processing.
  * a Vitals without one leaves no mark.
  * with the mark, inundated leaves the bleeding amount alone and still
    removes the humour.
  * without it, as in blackout, which stops Vitals, inundated records the
    level times 250.

A control strips the mark check from the real inundated handler and expects
it to overwrite the game's amount, so the checks can't pass without it.

It proves nothing about Mudlet integration, the order the game sends GMCP
and text in, or real combat.

Run: lua tools/test_sanguine_bleed.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local SETUP = "src/scripts/svo (setup, misc, empty, funnies, dor)/Setup.lua"

local INUNDATED_START = "        inundated = function()\n          local min = 250\n"
local INUNDATED_END = "\n        end,"
local VITALS_START = "signals.gmcpcharvitals:connect(function()\n"
local VITALS_END = "end, 'update gmcpcharvitals')"

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  -- a Windows checkout may have CRLF; the anchors are written with LF
  return (data:gsub("\r\n", "\n"))
end

local function between(source, path, start, finish)
  local s = source:find(start, 1, true)
  if not s then error("start anchor not found in " .. path .. "; update this test's anchors") end
  local e = source:find(finish, s, true)
  if not e then error("end anchor not found in " .. path .. "; update this test's anchors") end
  return source:sub(s, e + #finish - 1)
end

local function load_in(block, chunkname, env)
  -- Mudlet runs Lua 5.1, where only loadstring() takes a source string and
  -- the environment is applied with setfenv. Branch on setfenv rather than on
  -- a version string so this runs under either.
  local chunk, err
  if setfenv then
    chunk, err = loadstring(block, chunkname)
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(block, chunkname, "t", env)
  end
  if not chunk then error("could not load the extracted code: " .. tostring(err)) end
  return chunk()
end

local checks, failures = 0, 0
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures = failures + 1
    print(string.format("FAIL %s: got %s, want %s", desc, tostring(got), tostring(want)))
  end
end

-- inundated, from sanguinehumour's entry: the first one after its header
local dict = read_file(DICT)
local entry = dict:find("\n    sanguinehumour = {\n", 1, true)
if not entry then error("sanguinehumour's entry not found in " .. DICT) end
local inundated_block = between(dict:sub(entry), DICT, INUNDATED_START, INUNDATED_END)
inundated_block = "return function()\n" .. inundated_block:sub(#"        inundated = function()\n" + 1,
  -#"\n        end," - 1) .. "\nend"

-- Runs inundated with sanguine at level, bleeding already at bleeding (nil:
-- not bleeding), and the paragraph marked or not. Returns the bleeding
-- amount and whether sanguine is still recorded.
local function inundate(block, level, bleeding, marked)
  local affs = {sanguinehumour = {}}
  local svo = {dict = {sanguinehumour = {count = level}, bleeding = {count = bleeding or 0}}}
  if bleeding then affs.bleeding = {} end
  function svo.addaffdict() affs.bleeding = affs.bleeding or {} end
  function svo.updateaffcount() end
  function svo.rmaff(name) affs[name] = nil end
  local f = load_in(block, "inundated under test", {affs = affs, svo = svo, sk = {gmcp_bleed_seen = marked}})
  f()
  return affs.bleeding and svo.dict.bleeding.count or nil, affs.sanguinehumour ~= nil
end

local amount, kept = inundate(inundated_block, 3, 1234, true)
check("with GMCP's amount this paragraph, inundated leaves it", amount, 1234)
check("with GMCP's amount, the humour is removed", kept, false)
amount, kept = inundate(inundated_block, 3, nil, true)
check("with GMCP saying no bleeding, inundated adds none", amount, nil)
amount, kept = inundate(inundated_block, 3, nil, nil)
check("without GMCP's amount, inundated records the level times 250", amount, 750)
check("without GMCP's amount, the humour is removed", kept, false)
amount = inundate(inundated_block, 2, 900, nil)
check("without GMCP's amount, the level's amount replaces the old one", amount, 500)

-- The control: inundated without the mark check overwrites the game's amount.
local stripped, n = inundated_block:gsub("if not sk%.gmcp_bleed_seen then", "do")
check("the control found the mark check to take out", n, 1)
check("control: without the check, GMCP's amount is overwritten", (inundate(stripped, 3, 1234, true)), 750)

-- The Vitals handler
local setup = read_file(SETUP)
local vitals_block = between(setup, SETUP, VITALS_START, VITALS_END)

local function vitals(charstats)
  local handler
  local onprompt = {}
  local sk = {}
  function sk.onprompt_beforeaction_add(name, f) onprompt[name] = f end
  local recorded
  local svo = {dict = {bleeding = {aff = {oncompleted = function(n) recorded = n end}}},
    rmaff = function() recorded = 0 end}
  local env = {
    signals = {gmcpcharvitals = {connect = function(_, f) handler = f end}},
    gmcp = {Char = {Vitals = {charstats = charstats}}},
    stats = {}, svo = svo, sk = sk, ipairs = ipairs, tonumber = tonumber,
  }
  load_in("return function()\n" .. vitals_block .. "\nend", "vitals under test", env)()
  handler()
  return sk, onprompt, recorded
end

local sk, onprompt, recorded = vitals({"Bleed: 900", "Rage: 0"})
check("a Vitals with Bleed: marks the paragraph", sk.gmcp_bleed_seen, true)
check("and records the game's amount", recorded, 900)
check("the mark has a reset after the prompt", type(onprompt.gmcpbleedseen), 'function')
if onprompt.gmcpbleedseen then onprompt.gmcpbleedseen() end
check("the reset clears the mark", sk.gmcp_bleed_seen, nil)

sk = vitals({"Bleed: 0", "Rage: 0"})
check("a Vitals with Bleed: 0 marks the paragraph too", sk.gmcp_bleed_seen, true)

sk, onprompt = vitals({"Rage: 0"})
check("a Vitals without Bleed: leaves no mark", sk.gmcp_bleed_seen, nil)
check("and registers no reset", onprompt.gmcpbleedseen, nil)

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then print("FAILED") os.exit(1) end
print("ALL PASS")
