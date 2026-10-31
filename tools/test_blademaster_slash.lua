--[[
The Blademaster slash lookback in proper_<status><limb>
(Main_trigger_functions.lua): a precise slash across the arms does so little
damage that the break can be regenerated, so the paragraph's
"Spinning to the right as ..." line makes the break a simple one.

Its pattern was written "\w+", and in a Lua 5.1 string "\w" is a plain "w",
so the lookback looked for the letter w and never matched a real line.

This reads the pattern from the real source and checks it against the
captured line in the comment beside it, as Lua 5.1 reads the string.

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

local literal = src:match('find_until_last_paragraph%("(%^Spinning to the right as [^"]*)", \'pattern\'%)')
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

-- the line in the comment beside it, and the same with a name and a weapon
for _, line in ipairs({
  "Spinning to the right as he draws 11 11 from its sheath, 11 delivers a precise slash across your arms.",
  "Spinning to the right as Dana draws ornate scimitar from its sheath, she delivers a precise slash across your arms.",
}) do
  eq(line:find(pattern) ~= nil, true, "it matches: " .. line)
end

for _, line in ipairs({
  "Spinning to the left as he draws 11 11 from its sheath, 11 delivers a precise slash across your arms.",
  "Your left arm is greatly damaged from the beating.",
}) do
  eq(line:find(pattern), nil, "it doesn't match: " .. line)
end

-- the old spelling, as Lua 5.1 read it, matched none of them
local old = as_lua51(literal:gsub("as %%w%+ draws", "as \\w+ draws"))
eq(("Spinning to the right as he draws 11 11 from its sheath, 11 delivers a precise slash across your arms."):find(old), nil,
  "the old \\w spelling never matched")

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
