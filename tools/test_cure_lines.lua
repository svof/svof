--[[
Cure lines for 14 afflictions tree can cure (empty.treecurables). svof had
the handlers for each, and AFFLICTION SHOW (captured 2026-10-20,
claude-notes/reference/affliction_show.lua) has each one's cure line, but
twelve had no trigger on that line at all and two had no tree one. So a
cure was seen only through GMCP or the empty-cure inference, never in
blackout, and a tree touch that cured one stayed in flight.

For each name, this finds the cure line in the real trigger files and runs
the script of the trigger that matches it, through tools/svof_world.lua:

  * the herb, smoke or salve trigger before the prompt finishes the cure
    svof sent
  * the General cures trigger takes it off in a passive cure
  * the Tree cures trigger finishes a tree touch

  lua tools/test_cure_lines.lua
]]

local world = dofile("tools/svof_world.lua")

local GENERAL = "src/triggers/svo (aliases, triggers)/svo/General/"

-- the capture's cure line for each
local LINES = {
  depression = "Maybe things aren't so bad after all.",
  parasite = "The leeching of your strength comes to an end.",
  retribution = "The terrible sense of foreboding lifts.",
  shadowmadness = "Your sanity reestablishes itself.",
  timeloop = "You break out of the feedback loop.",
  flushings = "The prickling in your skin fades and you feel blessedly cool.",
  mycalium = "Your thoughts suddenly crystalise, the insidious whispers falling abruptly silent.",
  pyramides = "The burning in your veins abruptly fades.",
  rebbies = "Your skin ceases secreting slime.",
  sandfever = "Your fever finally breaks, the terrible burning retreating.",
  earworm = "The endlessly playing song in your mind falls silent.",
  slashedthroat = "The bleeding gash in your throat closes up completely.",
  itching = "Thankfully, the itching subsides.",
  fulminated = "You are no longer suffering from the ravages of fulminous energy.",
}
-- the balance svof cures each with, for the trigger before the prompt
local SENT = {
  depression = 'herb', parasite = 'herb', retribution = 'herb', shadowmadness = 'herb', timeloop = 'herb',
  flushings = 'herb', mycalium = 'herb', pyramides = 'herb', rebbies = 'herb', sandfever = 'herb',
  earworm = 'smoke', slashedthroat = 'salve', itching = 'salve', fulminated = 'herb',
}

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local function read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

-- the scripts of the triggers in a triggers.json whose pattern is line, by
-- the name muddler gives each script file
local function scripts_for(dir, line, under)
  local json = assert(read(dir .. "triggers.json"), dir)
  local found = {}
  -- each item's name comes before its patterns; take the nearest name
  -- before each match
  local pos = 1
  while true do
    local s = json:find('"pattern": "' .. line:gsub('"', '\\"') .. '"', pos, true)
    if not s then break end
    local before = json:sub(1, s)
    local name
    for n in before:gmatch('"name": "([^"]+)"') do name = n end
    local script = read(dir .. name:gsub(" ", "_") .. ".lua")
    if script and (not under or name:find(under, 1, true)) then found[#found + 1] = script end
    pos = s + 1
  end
  return found
end

for aff, line in pairs(LINES) do
  -- before the prompt: the cure svof sent
  local before = scripts_for(GENERAL, line, "svo cured")
  eq(#before, 1, aff .. ": one cure trigger before the prompt")
  if before[1] then
    local w = world.new()
    local svo = w.svo
    -- a cure that ends faster than half the ping looks fake: give the
    -- action a second
    w.env.getStopWatchTime = function() return 1 end
    svo.addaffdict(svo.dict[aff])
    svo.doaction(svo.dict[aff][SENT[aff]])
    w.run(before[1], aff .. " cured")
    w.prompt()
    eq(svo.affs[aff], nil, aff .. ": its " .. SENT[aff] .. " cure takes it off")
  end

  -- General cures: a passive cure
  local generic = scripts_for(GENERAL .. "General cures/", line)
  eq(#generic, 1, aff .. ": one General cures trigger")
  if generic[1] then
    local w = world.new()
    local svo = w.svo
    svo.addaffdict(svo.dict[aff])
    svo.passive_cure_paragraph = true
    w.run(generic[1], aff .. " generic")
    w.prompt()
    eq(svo.affs[aff], nil, aff .. ": a passive cure takes it off")
  end

  -- Tree cures: a touch in flight
  local tree = scripts_for(GENERAL .. "Tree cures/", line)
  eq(#tree, 1, aff .. ": one Tree cures trigger")
  if tree[1] then
    local w = world.new()
    local svo = w.svo
    svo.addaffdict(svo.dict[aff])
    svo.doaction(svo.dict.touchtree.misc)
    w.run(tree[1], aff .. " tree")
    w.prompt()
    eq(svo.affs[aff], nil, aff .. ": a tree touch takes it off")
    eq(w.inflight():find("touchtree_misc", 1, true), nil, aff .. ": and the touch is done")
  end
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
