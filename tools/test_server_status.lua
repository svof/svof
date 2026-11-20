--[[
Logic-level test of how svof reads the game's CURING STATUS.

svof reads the status into svo.sk.serverread.status, by its own name for each
setting, and keeps the rows it has no name for in statusother. Nothing acts on
it yet, and this test also checks that reading sends nothing.

The status below is a player's paste from 2026-11-15, as the game printed it.
It has only one value for "Curing Method" and for "Health/Mana Priority", so
what the game prints for the other choice of each isn't known here.

This runs the real loaders through tools/svof_world.lua. The trigger's
patterns are read from triggers.json and its script from the .lua beside it,
so a header the trigger wouldn't fire on fails here. Nothing here proves what
Mudlet does with a temp trigger made while a line is being matched: both
orders are run instead.

Run: lua tools/test_server_status.lua
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

local DASHES = ("-"):rep(78)

local STATUS = "Curing Status:\n" .. DASHES .. [[

Enabled:                   Yes
Reporting commands:        Yes

Sipping:                   Yes
Affliction Curing:         Yes
Defence Upkeep:            Yes

Curing Method:             Concoctions

Fallback Curing:           Yes

Custom Curing Priority:    Yes
Custom Defence Priority:   Yes
Health/Mana Priority:      Health
Sip health at:             90%
Sip mana at:               80%
Eat moss below health:     90%
Eat moss below mana:       70%
Use focus:                 Yes
Focus over herbs:          No
Use tree:                  No
Use clot:                  Yes
Clot at:                   60 bleeding
Clot to:                   0 bleeding
Use insomnia:              Yes
Will cure fractures above: 70% health
Will use mana above:       35% mana
Will clot health until:    70% health
Batch actions:             Yes
Use Kaido Transmute:       No
]] .. DASHES

local WANT = {
  enabled = true, reporting = true, sipping = true, afflictions = true, defences = true,
  method = "Concoctions", fallback = true, custompriority = true, customdefpriority = true,
  healthmana = "Health", siphealth = 90, sipmana = 80, mosshealth = 90, mossmana = 70,
  focus = true, focusoverherbs = false, tree = false, clot = true, clotat = 60, clotto = 0,
  insomnia = true, healthaffsabove = 70, manathreshold = 35, clothealth = 70, batch = true,
  kaidotransmute = false,
}

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

check("the trigger fires on the status header", trigger_fires("Curing Status:"))
check("and not on a row of it", not trigger_fires("Enabled:                   Yes"))

-- ===== the game's lines, through the trigger and the status reader =====

local function new_game(reader_sees_header)
  local w = world.new({ class = "Magi" })
  local g = { w = w, read = w.svo.sk.serverread, sk = w.svo.sk }

  local function readers()
    local live = {}
    for _, t in ipairs(w.triggers) do
      if not t.killed and t.kind == "regex" and t.pattern == "^" and t.code:find("serverstatus_line", 1, true) then
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
  return g
end

local function count(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

-- ===== a whole status =====

do
  local rows = 0
  for _ in pairs(WANT) do rows = rows + 1 end
  eq(rows, 26, "the paste's rows, all with a name in this test")
end

for _, sees in ipairs({ false, true }) do
  local tag = sees and " (reader run on the header)" or ""
  local g = new_game(sees)
  local sent = #g.w.sent
  eq(g.read.status, nil, "no status before one is read" .. tag)

  g.lines(STATUS)
  g.prompt()
  local status = g.read.status or {}
  eq(count(status), 26, "settings read" .. tag)
  for name, want in pairs(WANT) do eq(status[name], want, name .. tag) end
  eq(count(g.read.statusother), 0, "no row without a name" .. tag)
  eq(#g.readers(), 0, "the reader is gone once the status ends" .. tag)
  eq(g.read.statusreading, nil, "no status is left open" .. tag)
  eq(#g.w.sent, sent, "reading sends nothing" .. tag)

  -- every label in the table is one the paste has
  for label, name in pairs(g.sk.serverstatus_rows) do
    check("the paste has the row " .. label .. tag, STATUS:find("\n" .. label .. ":", 1, true) ~= nil)
    check("and the test expects " .. name .. tag, WANT[name] ~= nil)
  end

  -- a second status replaces the first
  g.lines((STATUS:gsub("Use tree:                  No", "Use tree:                  Yes", 1)
    :gsub("Sip health at:             90%%", "Sip health at:             75%%", 1)))
  eq(g.read.status.tree, true, "a second status replaces the first" .. tag)
  eq(g.read.status.siphealth, 75, "with its numbers" .. tag)
end

-- ===== a row the game adds later =====

do
  local g = new_game(true)
  g.lines((STATUS:gsub("Batch actions:             Yes", "Batch actions:             Yes\nUse something new:         Maybe", 1)))
  eq(count(g.read.status), 26, "a status with a new row is still read")
  eq(g.read.statusother and g.read.statusother["Use something new"], "Maybe", "and the new row is kept as printed")
end

-- ===== statuses that must change nothing =====

do
  local g = new_game(true)
  g.lines(STATUS)

  local function unchanged(desc)
    eq(count(g.read.status), 26, desc .. ": the status read before stays")
    eq(g.read.status.tree, false, desc .. ": with its values")
    eq(#g.readers(), 0, desc .. ": the reader is gone")
    eq(g.read.statusreading, nil, desc .. ": no status is left open")
  end

  local changed = lines_of((STATUS:gsub("Use tree:                  No", "Use tree:                  Yes", 1)))

  for i = 1, 12 do g.line(changed[i]) end
  g.prompt()
  unchanged("a status cut short by the prompt")
  for i = 13, #changed do g.line(changed[i]) end
  unchanged("and the rest of it arriving later")

  for i = 1, 12 do g.line(changed[i]) end
  g.line("You have been afflicted with paralysis.")
  for i = 13, #changed do g.line(changed[i]) end
  unchanged("another line in the middle of a status")

  g.line("Curing Status:")
  g.line("Enabled:                   No")
  g.line(DASHES)
  g.prompt()
  unchanged("a row before the opening dashes")

  g.line("Curing Status:")
  g.line(DASHES)
  g.line(DASHES)
  unchanged("a status with no rows")

  -- a line of dashes with no status open starts nothing
  g.line(DASHES)
  g.line("Use tree:                  Yes")
  g.line(DASHES)
  unchanged("dashes and rows with no header")
end

if #failures == 0 then
  print(("ALL PASS (%d checks)"):format(checks))
  os.exit(0)
else
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(("%d of %d checks failed"):format(#failures, checks))
  os.exit(1)
end
