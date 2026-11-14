--[[
Logic-level test of how svof reads the game's own affliction priorities.

svof reads CURING PRIORITY LIST, the line confirming a changed entry, the
curingset switch lines, the line refusing a stack an affliction can't have,
and the reset line, and keeps what they say in svo.sk.serverread. Nothing
acts on it yet, and this test also checks that reading sends nothing.

The two lists below are a player's captures from 2026-10-31, as the game
printed them at a width of 80: a level's entries wrap onto lines with no
number, and one wrapped line ends in a comma with no space after it. The
second list has a stack entry, unweavingmind(2). The third list, the
confirmations, the refused stack in a batch, the switch lines and the reset
line are from a live run on 2026-11-09. That run also showed that a list's
header names the curingset in use, that the slowcuring list's header has the
same form, and that a reset resets only the set in use.

This runs the real loaders through tools/svof_world.lua. The trigger's
patterns are read from triggers.json and its script from the .lua beside it,
so a line the handler knows that the trigger wouldn't fire on fails here. The
regex pattern is matched by the harness's stand-in, not by PCRE, and nothing
here proves what Mudlet does with a temp trigger made while a line is being
matched: both orders are run instead.

Run: lua tools/test_server_priority_list.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function check(desc, ok, detail)
  checks = checks + 1
  if not ok then failures[#failures + 1] = desc .. (detail and (": " .. tostring(detail)) or "") end
end
local function eq(got, want, desc)
  check(desc, got == want, ("got %s, want %s"):format(tostring(got), tostring(want)))
end

-- ===== the captures =====

local LIST_PLAIN = [[
Your affliction curing priorities for the priority set normal:
1:  aeon, anorexia, voyria, icebound
2:  paralysis, daeggerimpale, heartseed, prone
3:  itching, slickness, skullfractures, grievouswounds
4:  hellsight, asthma, torntendons, mindravaged
5:  dazed, scytherus, disloyalty, crackedribs, scalded, kkractlebrand,
frostbite
6:  manaleech, whisperingmadness, wristfractures
7:  concussion, impatience, deadening
8:  damagedleftleg, internalbleeding
9:  damagedrightleg, disrupted, timeloop, earworm
10: brokenleftleg, hypochondria, unweavingspirit, fratricide
11: brokenrightleg, addiction, bound, tension
12: transfixation, hypothermia, shadowmadness, pressure, diminished
13: damagedleftarm, entangled, depression
14: damagedrightarm, webbed, retribution
15: fear, brokenleftarm, parasite
16: brokenrightarm, stupidity
17: mangledrightleg, peace
18: mangledleftleg, lethargy
19: mangledhead, confusion, sleeping
20: damagedhead, clumsiness
21: mangledleftarm, weariness
22: mangledrightarm, recklessness
23: serioustrauma, sensitivity
24: mildtrauma, pacified, stridulating
25: lovers, epilepsy, justice, slashedthroat, laceratedthroat, shyness,
dizziness, nausea, selarnia, haemophilia, hallucinations, healthleech,
dementia, masochism, generosity, stuttering, paranoia, agoraphobia,
loneliness, claustrophobia, vertigo, hypersomnia, shivering, frozen, burning,
darkshade, dissonance, temperedmelancholic, temperedcholeric,
temperedsanguine, temperedphlegmatic, spiritburn, tenderskin, guilt, horror,
indifference, crushedthroat, calcifiedskull, calcifiedtorso, unweavingbody,
unweavingmind, tonguetied, pyramides, flushings, rebbies, mycalium, sandfever,
pyre, fulminated, crescendo
26: blindness, deafness, impaled, latched
Affs with priority 26 are ignored.]]

-- the same player's list after CURING PRIORITY UNWEAVINGMIND2 6, with asthma
-- moved to 1
local LIST_STACK = LIST_PLAIN
  :gsub("1:  aeon, anorexia", "1:  aeon, asthma, anorexia", 1)
  :gsub("4:  hellsight, asthma, torntendons", "4:  hellsight, torntendons", 1)
  :gsub("wristfractures\n", "wristfractures, unweavingmind(2)\n", 1)

-- A reset set, captured 2026-11-09 from a character with no screen width set,
-- so no level wraps: the game's defaults. Levels with nothing on them are
-- printed bare, nothing is at 26, and blindness and deafness aren't listed.
local LIST_DEFAULTS = [[
Your affliction curing priorities for the priority set normal:
1:  paralysis, aeon, peace, scytherus, anorexia, bound, whisperingmadness, sleeping, transfixation, voyria, webbed, prone, disrupted, latched, icebound
2:  entangled, hellsight, slickness, asthma, recklessness, impatience, daeggerimpale, impaled, heartseed, spiritburn, tenderskin, guilt, crushedthroat, calcifiedskull, calcifiedtorso
3:  brokenrightleg, brokenleftleg, damagedleftleg, lovers, confusion, pacified, clumsiness, healthleech, stupidity, manaleech, sensitivity, disloyalty, dissonance, temperedmelancholic, temperedcholeric, temperedsanguine, temperedphlegmatic, skullfractures, wristfractures, crackedribs, torntendons, retribution, grievouswounds
4:  damagedrightleg, mangledrightleg, mangledleftleg, epilepsy, nausea, weariness, addiction, deadening, hypochondria, lethargy, darkshade, hypothermia, unweavingbody, unweavingmind, unweavingspirit, mindravaged, mycalium
5:  itching, fear, brokenrightarm, brokenleftarm, dazed, justice, shyness, dizziness, haemophilia, masochism, vertigo, hypersomnia, shivering, frozen, scalded, kkractlebrand, pressure, frostbite
6:  damagedrightarm, damagedleftarm, mangledrightarm, mangledleftarm, hallucinations, generosity, agoraphobia, loneliness, claustrophobia, shadowmadness, tension, flushings, rebbies, crescendo
7:  damagedhead, mangledhead, concussion, dementia, paranoia, horror, depression, tonguetied, pyre
8:  mildtrauma, serioustrauma, burning, internalbleeding, pyramides, fulminated, earworm
9:  slashedthroat, laceratedthroat, parasite, timeloop, sandfever
10: selarnia, fratricide
11: stuttering
12: diminished
13:
14:
15:
16:
17:
18:
19:
20: indifference
21:
22:
23:
24: stridulating
25:
26:
Affs with priority 26 are ignored.]]

local CONFIRM_STACK = "You have set the 'unweavingmind(2)' affliction to the 6 priority."
local REFUSED_STACK = "The unweavingmind affliction can only have up to 5 stacks."
local RESET = "All your curing affliction priorities have been reset to defaults."
local SWITCH_NORMAL = "You will now cure using the normal set."
local SWITCH_SLOW = "You will now cure using the slowcuring set."

local function lines_of(text)
  local lines = {}
  for l in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
  return lines
end

-- ===== the trigger, as the package has it =====

local DIR = "src/triggers/svo (aliases, triggers)/svo/General/Server-side commands/"
local function read(path)
  local f = assert(io.open(path, "r"))
  local s = f:read("*a")
  f:close()
  return s
end

local trigger_script = read(DIR .. "Curing_priority_lines.lua")
local trigger_patterns = {}
do
  local json = read(DIR .. "triggers.json")
  local from = json:find('"name": "Curing priority lines"', 1, true)
  check("triggers.json has the trigger", from ~= nil)
  local to = from and json:find("%]", from)
  for pattern, kind in (from and json:sub(from, to) or ""):gmatch('"pattern": "(.-)",%s*"type": "(%w+)"') do
    trigger_patterns[#trigger_patterns + 1] = { pattern = (pattern:gsub("\\\\", "\\")), kind = kind }
  end
  eq(#trigger_patterns, 6, "the trigger's patterns")
  eq(trigger_script, "svo.sk.serverprio_line(line)", "the trigger's script")
end

local function trigger_fires(text)
  for _, p in ipairs(trigger_patterns) do
    if (p.kind == "startOfLine" and text:sub(1, #p.pattern) == p.pattern)
      or (p.kind == "exactMatch" and text == p.pattern)
      or (p.kind == "regex" and world.rex_stub.match(text, p.pattern)) then
      return true
    end
  end
  return false
end

-- ===== the game's lines, through the trigger and the list's reader =====

-- reader_sees_header: whether the reader, made while the header is being
-- matched, is run on the header too
local function new_game(reader_sees_header)
  local w = world.new({ class = "Magi" })
  local g = { w = w, read = w.svo.sk.serverread, sk = w.svo.sk }

  local function readers()
    local live = {}
    for _, t in ipairs(w.triggers) do
      if not t.killed and t.kind == "regex" and t.pattern == "^" and t.code:find("serverlist_line", 1, true) then
        live[#live + 1] = t
      end
    end
    return live
  end
  g.readers = readers

  function g.line(text, isprompt)
    w.env.line = text
    w.env.isPrompt = function() return isprompt or false end
    local before = readers()
    if not isprompt and trigger_fires(text) then w.run(trigger_script, "trigger") end
    for _, t in ipairs(reader_sees_header and readers() or before) do
      if not t.killed then w.run(t.code, "reader") end
    end
  end
  function g.lines(text) for _, l in ipairs(lines_of(text)) do g.line(l) end end
  function g.prompt() g.line("1000h, 1000m cexkdb-", true) end
  function g.count(set)
    local n = 0
    for _ in pairs(g.read.sets[set] or {}) do n = n + 1 end
    return n
  end
  return g
end

-- ===== a whole list =====

for _, sees in ipairs({ false, true }) do
  local tag = sees and " (reader run on the header)" or ""
  local g = new_game(sees)
  local sent = #g.w.sent
  g.lines(LIST_PLAIN)
  g.prompt()
  local normal = g.read.sets.normal or {}
  eq(g.count("normal"), 131, "entries read from the first list" .. tag)
  eq(normal.aeon, 1, "aeon" .. tag)
  eq(normal.icebound, 1, "icebound, which svof has no action for" .. tag)
  eq(normal.frostbite, 5, "frostbite, alone on a wrapped line" .. tag)
  eq(normal.pyre, 25, "pyre, after a wrap with no space" .. tag)
  eq(normal.sandfever, 25, "sandfever, before it" .. tag)
  eq(normal.crescendo, 25, "crescendo, the last of level 25" .. tag)
  eq(normal.latched, 26, "latched" .. tag)
  eq(normal.asthma, 4, "asthma" .. tag)
  eq(#g.readers(), 0, "the reader is gone once the list ends" .. tag)
  eq(g.read.list, nil, "no list is left open" .. tag)

  g.lines(LIST_STACK)
  normal = g.read.sets.normal or {}
  eq(g.count("normal"), 132, "entries read from the list with a stack entry" .. tag)
  eq(normal["unweavingmind(2)"], 6, "the stack entry" .. tag)
  eq(normal.unweavingmind, 25, "the plain entry beside it" .. tag)
  eq(normal.asthma, 1, "a second list replaces the first" .. tag)
  eq(#g.w.sent, sent, "reading sends nothing" .. tag)
end

-- ===== lists that must change nothing =====

do
  local g = new_game(true)
  g.lines(LIST_PLAIN)

  local function unchanged(desc)
    eq(g.count("normal"), 131, desc .. ": the set read before stays")
    eq(g.read.sets.normal.asthma, 4, desc .. ": with its numbers")
    eq(#g.readers(), 0, desc .. ": the reader is gone")
    eq(g.read.list, nil, desc .. ": no list is left open")
  end

  local stack = lines_of(LIST_STACK)

  for i = 1, 10 do g.line(stack[i]) end
  g.prompt()
  unchanged("a list cut short by the prompt")
  for i = 11, #stack do g.line(stack[i]) end
  unchanged("and the rest of it arriving later")

  for i = 1, 10 do g.line(stack[i]) end
  g.line("You have been afflicted with paralysis.")
  for i = 11, #stack do g.line(stack[i]) end
  unchanged("another line in the middle of a list")

  g.lines((LIST_STACK:gsub("26: blindness", "26: asthma, blindness", 1)))
  unchanged("an entry listed twice")

  g.lines((LIST_STACK:gsub("\n26: ", "\n27: ", 1)))
  unchanged("a level past 26")

  g.lines((LIST_STACK:gsub("\n3:  ", "\n2:  ", 1)))
  unchanged("a level given twice")

  g.line(stack[1])
  for _ = 1, 150 do g.line("pyre, fulminated,") end
  unchanged("a list that never ends")
  g.line(stack[#stack])
  unchanged("and its footer")

  g.line(stack[1])
  g.line(stack[#stack])
  unchanged("a list with no entries")
end

-- ===== the curingset, and a changed entry =====

do
  local g = new_game(true)
  local sent = #g.w.sent

  g.line(CONFIRM_STACK)
  eq(g.read.sets.normal, nil, "a change before any list was read is not kept")

  eq(g.read.active, nil, "the curingset in use isn't known at first")
  g.lines(LIST_PLAIN)
  eq(g.read.active, "normal", "a list's header names the curingset in use")
  g.line(CONFIRM_STACK)
  eq(g.read.sets.normal["unweavingmind(2)"], 6, "a changed stack entry")
  eq(g.read.sets.normal.unweavingmind, 25, "leaves the plain entry alone")
  eq(g.count("normal"), 132, "and adds one entry")

  g.line("You have set the 'paralysis' affliction to the 3 priority.")
  eq(g.read.sets.normal.paralysis, 3, "a changed plain entry")
  g.line("You have set the 'paralysis' affliction to the 26 priority.")
  eq(g.read.sets.normal.paralysis, 26, "an entry set to 26")
  g.line("You have set the 'paralysis' affliction to the 27 priority.")
  eq(g.read.sets.normal.paralysis, 26, "a number the game doesn't have is not kept")
  g.line("You have set the 'not an entry' affliction to the 3 priority.")
  eq(g.count("normal"), 132, "nor is a name that isn't an entry")

  -- svof wraps a change to the set not in use in two switches
  g.line(SWITCH_SLOW)
  eq(g.read.active, "slowcuring", "the switch to slowcuring")
  g.line("You have set the 'asthma' affliction to the 1 priority.")
  g.line(SWITCH_NORMAL)
  eq(g.read.sets.slowcuring, nil, "a change to a set that was never read is not kept")
  eq(g.read.sets.normal.asthma, 4, "and doesn't land in the other set")

  g.line(SWITCH_SLOW)
  g.read.active = nil
  g.lines((LIST_PLAIN:gsub("priority set normal", "priority set slowcuring", 1)))
  eq(g.read.active, "slowcuring", "the slowcuring list's header names it as the set in use")
  g.line("You have set the 'asthma' affliction to the 1 priority.")
  g.line(SWITCH_NORMAL)
  eq(g.count("slowcuring"), 131, "the slowcuring set's list is kept under its own name")
  eq(g.read.sets.slowcuring.asthma, 1, "a change between two switches goes to the set switched to")
  eq(g.read.sets.normal.asthma, 4, "and not to the one switched back to")

  -- ===== a batch with a refused stack =====

  -- the game's reply to CURING PRIORITY PARALYSIS 3 UNWEAVINGMIND9 6 ASTHMA 5
  g.line("You have set the 'paralysis' affliction to the 3 priority.")
  g.line(REFUSED_STACK)
  g.line("You have set the 'asthma' affliction to the 5 priority.")
  eq(g.read.sets.normal.paralysis, 3, "a batch's entry before a refused one")
  eq(g.read.sets.normal.asthma, 5, "and the one after it")
  eq(g.read.maxstacks.unweavingmind, 5, "the most stacks the game said an affliction has")
  eq(g.count("normal"), 132, "a refusal changes no entry")

  -- ===== a reset =====

  g.line(RESET)
  eq(g.read.sets.normal, nil, "a reset forgets the set in use")
  eq(g.count("slowcuring"), 131, "and not the other set")
  eq(g.read.active, "normal", "nor which set is in use")
  eq(g.read.maxstacks.unweavingmind, 5, "nor the stacks")

  -- the list after a reset: the game's defaults
  g.lines(LIST_DEFAULTS)
  local normal = g.read.sets.normal or {}
  eq(g.count("normal"), 129, "entries read from a reset set's list")
  eq(normal.latched, 1, "latched, in a level that doesn't wrap")
  eq(normal.icebound, 1, "icebound, the last of it")
  eq(normal.diminished, 12, "diminished, alone before the empty levels")
  eq(normal.indifference, 20, "indifference, between empty levels")
  eq(normal.stridulating, 24, "stridulating, before the empty last levels")
  eq(normal["unweavingmind(2)"], nil, "the reset set has no stack entry")
  eq(normal.blindness, nil, "the game's defaults don't list blindness")

  -- the game's reply to CURING PRIORITY BLIND 26
  g.line("You have set the 'blindness' affliction to the 26 priority.")
  eq(g.read.sets.normal.blindness, 26, "a changed entry the list didn't have is added")
  eq(g.count("normal"), 130, "as one entry")

  local stack = lines_of(LIST_STACK)
  for i = 1, 10 do g.line(stack[i]) end
  g.line(RESET)
  for i = 11, #stack do g.line(stack[i]) end
  eq(g.read.sets.normal, nil, "a reset in the middle of a list drops the list")
  eq(#g.readers(), 0, "and its reader")
  eq(g.count("slowcuring"), 131, "the other set still stays")

  g.read.active = nil
  g.line(RESET)
  eq(g.read.sets.slowcuring, nil, "a reset with the set in use unknown forgets every set")

  eq(#g.w.sent, sent, "none of it sends anything")
end

-- ===== every line the handler knows is one the trigger fires on =====

for _, text in ipairs({ lines_of(LIST_PLAIN)[1], CONFIRM_STACK, REFUSED_STACK, RESET, SWITCH_NORMAL, SWITCH_SLOW,
  -- the defence list's header and a defence's confirmation, captured 2026-11-09
  "Your defence priorities for curing set normal:", "You have set the 'cloak' defence to the 3 priority." }) do
  check("the trigger fires on: " .. text, trigger_fires(text))
end
check("the trigger leaves a defence line to the reader", not trigger_fires("cloak             : 3"))
check("the trigger leaves a level line to the reader", not trigger_fires("2:  paralysis, daeggerimpale, heartseed, prone"))

-- ===== entries =====

do
  local g = new_game(true)
  local name, stack = g.sk.serverentry("unweavingmind(2)")
  eq(name, "unweavingmind", "a stack entry's affliction")
  eq(stack, 2, "and its stack")
  name, stack = g.sk.serverentry("paralysis")
  eq(name, "paralysis", "a plain entry's affliction")
  eq(stack, nil, "which has no stack")
  for _, bad in ipairs({ "", "two words", "unweavingmind(2", "unweavingmind(x)", "(2)", "5: dazed" }) do
    eq(g.sk.serverentry(bad), nil, "not an entry: '" .. bad .. "'")
  end

  -- ===== the list's names svof has no action for =====

  -- As of 2026-11-09. A name leaves this list when svof gains an action for
  -- it, or a gamename or sstosvoa entry that names it; a name joining it
  -- means a rename lost one. blindness and deafness aren't here although the
  -- actions' gamename is blind and deaf: sk.serverlistnames has the names
  -- the game lists them under.
  local UNMAPPED = "dazed, diminished, fratricide, frostbite, grievouswounds, icebound, "
    .. "internalbleeding, kkractlebrand, stridulating"
  g.lines(LIST_STACK)
  eq(table.concat(g.sk.serverunmapped("normal"), ", "), UNMAPPED, "the list's names svof has no action for")
  eq(#g.sk.serverunmapped("slowcuring"), 0, "a set that wasn't read has none")

  local toserver, toaction = g.sk.serverprionames()
  eq(toserver.unweavingmind, "unweavingmind", "an action's name on the list")
  eq(toserver.ablaze, "burning", "an action the game names another way")
  eq(toaction.burning, "ablaze", "and back")
  eq(toserver.blindaff, "blindness", "an action svof sends under a name the game lists otherwise")
  eq(toaction.blindness, "blindaff", "and back")
  eq(toaction.icebound, nil, "a name svof has no action for")
end

if #failures == 0 then
  print(("ALL PASS (%d checks)"):format(checks))
else
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(("%d of %d checks failed"):format(#failures, checks))
  os.exit(1)
end
