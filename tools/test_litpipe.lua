--[[
Logic-level test for svo.valid.litpipe in
`src/scripts/svo (trigger functions)/Main_trigger_functions.lua`, the answer
to lighting one pipe ("You carefully light...").

The line names the pipe's description, not which pipe it is, so litpipe
marks lit the pipe whose ID the latest LIGHT command named, read from
commandTracker's lastCommands (newest first). Only the latest LIGHT counts:
one by another name, after an older LIGHT <id>, used to fall through to that
older command and mark its pipe lit, so an out pipe was believed lit until a
smoke failed (vadi2, 2026-10-28).

The function is extracted from the real source by anchor text and run in a
stub environment, so it is what ships. It proves nothing about Mudlet or the
game.

Run: lua tools/test_litpipe.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local SRC = "src/scripts/svo (trigger functions)/Main_trigger_functions.lua"
local START_ANCHOR = "function svo.valid.litpipe(gag2)"

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return (data:gsub("\r\n", "\n"))
end

local source = read_file(SRC)
local s = source:find(START_ANCHOR, 1, true)
local e = s and source:find("\nend\n", s, true)
if not (s and e) then error("litpipe not found in " .. SRC .. " - update this test's anchor") end
local block = source:sub(s, e + 4)

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

-- runs litpipe with lastCommands, and returns each pipe's lit and lit2
local function light(commands)
  local pipes = { pnames = { 'valerian', 'elm', 'skullcap' } }
  pipes.valerian = { id = 101, id2 = 201, lit = false, lit2 = false }
  pipes.elm = { id = 102, id2 = 202, lit = false, lit2 = false }
  pipes.skullcap = { id = "103", id2 = 0, lit = false, lit2 = false }
  local svo = { valid = {} }
  local env = {
    svo = svo, pipes = pipes, sys = { sync = true }, conf = {},
    lastCommands = commands, rawget = rawget, ipairs = ipairs, tonumber = tonumber, _G = nil,
  }
  env._G = env
  local chunk, err
  if setfenv then
    chunk, err = loadstring(block, "litpipe")
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(block, "litpipe", "t", env)
  end
  if not chunk then error("could not load litpipe: " .. tostring(err)) end
  chunk()
  svo.valid.litpipe()
  local lit = {}
  for _, name in ipairs(pipes.pnames) do
    lit[#lit + 1] = string.format("%s=%s/%s", name, tostring(pipes[name].lit), tostring(pipes[name].lit2))
  end
  return table.concat(lit, " ")
end

local none = "valerian=false/false elm=false/false skullcap=false/false"

eq(light({ "light 102" }), "valerian=false/false elm=true/false skullcap=false/false",
  "LIGHT <id> marks that pipe lit")
eq(light({ "light 201" }), "valerian=false/true elm=false/false skullcap=false/false",
  "and a second pipe's ID marks the second pipe")
eq(light({ "light 103" }), "valerian=false/false elm=false/false skullcap=true/false",
  "an ID kept as a string still matches")
eq(light({ "light 102  " }), "valerian=false/false elm=true/false skullcap=false/false",
  "trailing spaces are ignored")
eq(light({ "smoke 101", "outr valerian", "light 102" }), "valerian=false/false elm=true/false skullcap=false/false",
  "commands that aren't LIGHT are passed over")
eq(light({ "light meerschaum", "light 102" }), none,
  "LIGHT by name after an older LIGHT <id> leaves the pipes as they were")
eq(light({ "light pipes", "light 102" }), none, "and so does LIGHT PIPES after one")
eq(light({ "light 999", "light 102" }), none, "an ID no pipe has marks nothing, not an older LIGHT's")
eq(light({}), none, "with no commands, nothing is marked")
eq(light(nil), none, "nor with no lastCommands at all")

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
