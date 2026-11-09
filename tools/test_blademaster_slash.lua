--[[
The Blademaster slash lookback in proper_<status><limb>
(Main_trigger_functions.lua): a precise slash across the arms does so little
damage that the break can be regenerated, so the paragraph's
"Spinning to the left as ..." or "Spinning to the right as ..." line makes an
arm break a simple one. A leg broken in the same paragraph isn't.

Its pattern was written "\w+", and in a Lua 5.1 string "\w" is a plain "w",
so the lookback looked for the letter w and never matched a real line.

This reads the pattern from the real source and checks it against the
captured line in the comment beside it, as Lua 5.1 reads the string. Then it
runs the real handlers through tools/svof_world.lua on whole paragraphs.

  lua tools/test_blademaster_slash.lua
]]

local SRC = "src/scripts/svo (trigger functions)/Main_trigger_functions.lua"

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local f = assert(io.open(SRC, "r"))
local src = f:read("*a")
f:close()

local literal = src:match('find_until_last_paragraph%("(%^Spinning to the [^"]*)", \'pattern\'%)')
assert(literal, "the slash lookback moved or was reworded; update this test's anchor")

-- a string as Lua 5.1 reads it: an escape it doesn't know is the letter
-- after the backslash
local function as_lua51(s)
  return (s:gsub("\\(.)", function(c)
    local known = { n = "\n", t = "\t", ["\\"] = "\\", ['"'] = '"', ["'"] = "'" }
    return known[c] or c
  end))
end

local pattern = as_lua51(literal)
eq(literal:find("\\", 1, true), nil, "the pattern has no backslash escapes")

local RIGHT = "Spinning to the right as he draws 11 11 from its sheath, 11 delivers a precise slash across your arms."
local LEFT = "Spinning to the left as he draws 11 11 from its sheath, 11 delivers a precise slash across your arms."

-- the line in the comment beside it, the same with a name and a weapon, and
-- the left-hand slash the Two Arts trigger "Limb damage 3" matches too
for _, line in ipairs({
  RIGHT,
  "Spinning to the right as Dana draws ornate scimitar from its sheath, she delivers a precise slash across your arms.",
  LEFT,
}) do
  eq(line:find(pattern) ~= nil, true, "it matches: " .. line)
end

for _, line in ipairs({
  "Your left arm is greatly damaged from the beating.",
  "Spinning to the right as he draws 11 11 from its sheath, 11 delivers a precise slash across your legs.",
}) do
  eq(line:find(pattern), nil, "it doesn't match: " .. line)
end

-- the old spelling, as Lua 5.1 read it, matched none of them
local old = as_lua51(literal:gsub("as %%w%+ draws", "as \\w+ draws"))
eq(RIGHT:find(old), nil, "the old \\w spelling never matched")

-- The real handlers, on whole paragraphs, with anti-illusion on: SIMPLE for
-- a break that can be regenerated, FULL for one that can't (review of #892)
local world = dofile("tools/svof_world.lua")
local function broke(name, lines)
  local w = world.new()
  local svo = w.svo
  svo.conf.aillusion = true
  svo.paragraph_lines = {}
  for i, text in ipairs(lines) do svo.paragraph_lines[i] = { n = 0, text = text } end
  local simple = false
  local real = svo.valid["simple" .. name]
  svo.valid["simple" .. name] = function(...) simple = true return real(...) end
  svo.valid["proper_" .. name]()
  if simple then return "SIMPLE" end
  return svo.lifevision.l[name .. "_aff"] and "FULL" or "NONE"
end

local LEFT_ARM = "Your left arm is greatly damaged from the beating."
local RIGHT_ARM = "Your right arm is greatly damaged from the beating."
local LEFT_LEG = "Your left leg is greatly damaged from the beating."

eq(broke("mangledleftarm", { RIGHT, LEFT_ARM }), "SIMPLE", "a right-hand slash: the left arm's break is simple")
eq(broke("mangledleftarm", { LEFT, LEFT_ARM }), "SIMPLE", "a left-hand slash: the same")
eq(broke("mangledrightarm", { LEFT, RIGHT_ARM }), "SIMPLE", "and the right arm's")
eq(broke("mangledleftarm", { LEFT_ARM }), "FULL", "no slash: the arm's break is full")
eq(broke("mangledleftleg", { RIGHT, LEFT_LEG }), "FULL", "a slash and a leg break: the leg's is full")
eq(broke("mangledleftleg", { LEFT, LEFT_LEG }), "FULL", "and with a left-hand slash")

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
