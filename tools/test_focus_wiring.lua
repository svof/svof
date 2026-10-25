--[[
Static test of svof's focus wiring against the game's own list of what Focus
Mind cures.

A focus cure is wired in four places that nothing derives from one another:

  * a focus block on the affliction's dictionary entry, which decides when to
    focus for it
  * empty.focuscurables in Empty_cure_handling.lua, which a focus that cured
    nothing rules out
  * the generator in Main_trigger_functions.lua, which defines
    svo.valid.focus_cured_<name> for each name on its list
  * the Focus trigger chain in General/triggers.json, whose lines after
    "You focus your mind intently..." call those functions

This reads all four from the real sources and checks they agree, and that the
dictionary's focus blocks are the game's Focus Mind afflictions.

GAME_FOCUS is AFFLICTION SHOW's "Cure(s)" field, every affliction that lists
Focus Mind (captured 2026-10-21, claude-notes/reference/affliction_show.lua),
in svof's names: the game's lovers is svof's inlove and pacified is
pacifism.

Run: lua tools/test_focus_wiring.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local EMPTY = "src/scripts/svo (setup, misc, empty, funnies, dor)/Empty_cure_handling.lua"
local MAIN = "src/scripts/svo (trigger functions)/Main_trigger_functions.lua"
local CHAIN = "src/triggers/svo (aliases, triggers)/svo/General/triggers.json"

local GAME_FOCUS = {
  'agoraphobia', 'anorexia', 'claustrophobia', 'confusion', 'dementia',
  'dizziness', 'epilepsy', 'hallucinations', 'loneliness', 'inlove',
  'masochism', 'pacifism', 'paranoia', 'peace', 'recklessness', 'shyness',
  'stupidity', 'stuttering', 'vertigo',
}

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return (data:gsub("\r\n", "\n"))
end

local function names(list)
  local set = {}
  for name in list:gmatch("'([%w_]+)'") do set[name] = true end
  return set
end

local function sorted(set)
  local out = {}
  for name in pairs(set) do out[#out + 1] = name end
  table.sort(out)
  return out
end

-- names in a but not in b, as one string so a failure shows them all
local function missing(a, b)
  local out = {}
  for _, name in ipairs(sorted(a)) do
    if not b[name] then out[#out + 1] = name end
  end
  return table.concat(out, " ")
end

local checks, failures = 0, {}
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures[#failures + 1] = string.format("%s: got '%s', want '%s'", desc, tostring(got), tostring(want))
  end
end

-- the dictionary's focus blocks
local blocks, entry = {}, nil
for line in (read_file(DICT) .. "\n"):gmatch("([^\n]*)\n") do
  entry = line:match("^    ([%w_]+) = {") or entry
  if line:find("^      focus = {") then blocks[entry] = true end
end

local focuscurables = read_file(EMPTY):match("empty%.focuscurables = (%b{})")
if not focuscurables then error("empty.focuscurables not found in " .. EMPTY) end
focuscurables = names(focuscurables)

local generator = read_file(MAIN):match("%-%- focus\ndo\n  local afflist = (%b{})")
if not generator then error("the focus_cured_ generator not found in " .. MAIN) end
generator = names(generator)

-- the Focus chain's children, from its first line to svo focus2, its last
local triggers = read_file(CHAIN)
local s = triggers:find('"name": "Focus",', 1, true)
local e = s and triggers:find('"name": "svo focus2"', s, true)
if not e then error("the Focus chain not found in " .. CHAIN) end
local chain = {}
for name in triggers:sub(s, e):gmatch('"name": "svo cured ([%w_]+)"') do chain[name] = true end
local calls = {}
for name in triggers:sub(s, e):gmatch('svo%.valid%.focus_cured_([%w_]+)%(') do calls[name] = true end

local game = {}
for _, name in ipairs(GAME_FOCUS) do game[name] = true end

-- floors, so a parse that finds nothing can't pass
check("read at least 15 focus blocks", #sorted(blocks) >= 15, true)
check("read at least 15 names in empty.focuscurables", #sorted(focuscurables) >= 15, true)
check("read at least 15 names in the generator", #sorted(generator) >= 15, true)
check("read at least 15 lines in the Focus chain", #sorted(chain) >= 15, true)

-- every Focus Mind affliction can be focused for, and a focus is credited
check("Focus Mind afflictions with no focus block", missing(game, blocks), "")
check("Focus Mind afflictions not in empty.focuscurables", missing(game, focuscurables), "")
check("Focus Mind afflictions not in the generator", missing(game, generator), "")

-- and nothing else is focused for. fear's focus block is switched off with a
-- bare return false (the game cures fear with compose), and unknownmental
-- stands for any of the game's list.
local own = { fear = true, unknownmental = true }
for name in pairs(game) do own[name] = true end
check("focus blocks the game doesn't focus-cure", missing(blocks, own), "")
check("empty.focuscurables names the game doesn't focus-cure", missing(focuscurables, own), "")
check("generator names the game doesn't focus-cure", missing(generator, own), "")

-- a focus that cures one of them is credited to the focus: without its line
-- in the chain, svo focus2 finds no cure and svof reads the focus as empty
check("generator names with no line in the Focus chain", missing(generator, chain), "")

-- and every line calls a function the generator defines: Mudlet reports a
-- call to a missing one as a Lua error when its line arrives after a focus
check("Focus chain calls to a focus_cured_ the generator doesn't define", missing(calls, generator), "")

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
