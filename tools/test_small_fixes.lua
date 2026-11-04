--[[
Logic-level tests for small fixes to triggers and scripts that have no test
file of their own. Each section below says what it pins.

The trigger sections read each pattern, its type, multiline and the line delta
from the real triggers.json, match them against real game lines, and run the
real script. They model what Mudlet does: a multiline trigger gets multimatches
and leaves matches as an earlier trigger left it, and any other trigger gets
matches and leaves multimatches alone (TLuaInterpreter::setMatches). The rest
run the real loaders through tools/svof_world.lua. Names are placeholders.

This proves nothing about Mudlet or the game.

Run: lua tools/test_small_fixes.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local world = dofile("tools/svof_world.lua")

local TRIGGERS = "src/triggers/svo (aliases, triggers)/svo/"
local ME, ATTACKER, OTHER, STALE = "Simtester", "Attackerone", "Otherplayer", "Stalename"

local checks, failures = 0, {}
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures[#failures + 1] = string.format("%s: got %s, want %s", desc, tostring(got), tostring(want))
  end
end

local read_file = world.read_file

-- a trigger's flags and patterns, from the text of the triggers.json it is in
local function item(folder, name)
  local json = read_file(TRIGGERS .. folder .. "/triggers.json")
  local s = json:find('"name": "' .. name .. '"', 1, true)
  assert(s, name .. " is not in " .. folder .. "/triggers.json")
  local e = json:find('"name": ', s + 1, true) or #json
  local text = json:sub(s, e)
  local t = {
    multiline = text:match('"multiline": "(%a+)"') == "yes",
    delta = tonumber(text:match('"multilineDelta": "(%d+)"')),
    patterns = {},
  }
  for pattern, kind in text:gmatch('"pattern": "(.-)",\n%s*"type": "(%a+)"') do
    t.patterns[#t.patterns + 1] = { text = (pattern:gsub("\\(.)", "%1")), kind = kind }
  end
  return t
end

-- These patterns are anchors, \w+, escaped punctuation, groups and literal
-- text, which a Lua pattern says as well. Anything else raises, so a test can't
-- take a wrong answer for PCRE's. world.rex_stub reads more, but drops groups,
-- and the groups are what these tests are about.
local function lua_pattern(regex)
  local out, i = {}, 1
  while i <= #regex do
    local c = regex:sub(i, i)
    if c == "\\" then
      local after = regex:sub(i + 1, i + 1)
      assert(after == "w" or after:match("%p"), "unsupported escape in " .. regex)
      out[#out + 1] = "%" .. after
      i = i + 2
    else
      assert(not c:find("[|%[%]{}%?%*]"), "unsupported " .. c .. " in " .. regex)
      local magic = c:find("[%(%)%^%$%+%.]") or c:match("[%w%s]")
      out[#out + 1] = magic and c or ("%" .. c)
      i = i + 1
    end
  end
  return table.concat(out)
end

-- what a pattern gives a script for a line, the whole match first, or nil
local function match(w, p, line)
  if p.kind == "exactMatch" then
    return line == p.text and { line } or nil
  elseif p.kind == "startOfLine" then
    return line:sub(1, #p.text) == p.text and { p.text } or nil
  elseif p.kind == "lua" then
    w.env.line = line
    return w.run(p.text, "lua pattern") and { "true" } or nil
  elseif p.kind == "regex" then
    local captures = { line:match(lua_pattern(p.text)) }
    if captures[1] == nil then return nil end
    if not p.text:gsub("\\.", ""):find("(", 1, true) then return { line } end
    table.insert(captures, 1, line)
    return captures
  end
  error("no model for a pattern of type " .. tostring(p.kind))
end

-- feeds lines to a trigger as Mudlet would. Returns how often its script ran,
-- and the last error it raised
local function fire(w, folder, name, lines)
  local t = item(folder, name)
  local code = read_file(TRIGGERS .. folder .. "/" .. name:gsub(" ", "_") .. ".lua")
  local ran, err = 0, nil
  local function run()
    ran = ran + 1
    local ok, message = pcall(w.run, code, name)
    if not ok then err = tostring(message) end
  end

  local pending = {}
  for _, line in ipairs(lines) do
    if not t.multiline then
      for _, p in ipairs(t.patterns) do
        local m = match(w, p, line)
        if m then
          w.env.matches = m
          run()
          break
        end
      end
    elseif t.delta == 0 then
      local all = {}
      for i, p in ipairs(t.patterns) do
        all[i] = match(w, p, line)
        if not all[i] then all = nil break end
      end
      if all then
        w.env.multimatches = all
        run()
      end
    else
      local m = match(w, t.patterns[#pending + 1], line)
      if m then pending[#pending + 1] = m end
      if #pending == #t.patterns then
        w.env.multimatches = pending
        pending = {}
        run()
      end
    end
  end
  return ran, err
end

-- a fresh svof where an earlier trigger left this name in matches, nothing in
-- multimatches, and warnings kept
local function fresh(stale_name)
  local w = world.new({ class = "Monk" })
  w.svo.me.name = ME
  w.env.matches = { "an earlier line", stale_name }
  w.env.multimatches = nil
  w.warned = {}
  w.svo.givewarning = function(t) w.warned[#w.warned + 1] = t end
  return w
end
local function attacker_class(w, name) return w.svo.dict.gothit.happened.tempmap[name] end

-- Judgement two and three: both patterns on one line, so a judgement on
-- someone else matches neither script, and the scripts can read multimatches.
do
  local two_me = "The prayer of " .. ATTACKER .. " builds in strength as he fixates upon you, righteous fury evident in every word."
  local two_other = "The prayer of " .. ATTACKER .. " builds in strength as he fixates upon " .. OTHER .. ", righteous fury evident in every word."
  local three_me = "As the righteous words of " .. ATTACKER .. " build towards an ominous conclusion a light begins to shine upon you, its merciless glare a herald of danger."
  local three_other = "As the righteous words of " .. ATTACKER .. " build towards an ominous conclusion a light begins to shine upon " .. OTHER .. ", bathing him in a merciless glare."

  local w = fresh(STALE)
  local ran, err = fire(w, "Zeal", "Judgement two", { two_me })
  check("Judgement two at me fires", ran, 1)
  check("and raises nothing", err, nil)
  check("and warns with the attacker's name", w.warned[1] and w.warned[1].prefixwarning, ATTACKER .. " judging you")
  check("and records the priest", attacker_class(w, ATTACKER), "priest")

  w = fresh(STALE)
  ran, err = fire(w, "Zeal", "Judgement two", { two_other })
  check("Judgement two at another player doesn't fire", ran, 0)
  check("and raises nothing", err, nil)
  check("and doesn't warn", #w.warned, 0)

  w = fresh(STALE)
  ran, err = fire(w, "Zeal", "Judgement three", { three_me })
  check("Judgement three at me fires", ran, 1)
  check("and raises nothing", err, nil)
  check("and warns with the attacker's name", w.warned[1] and w.warned[1].prefixwarning, ATTACKER .. " judging you")

  w = fresh(STALE)
  ran, err = fire(w, "Zeal", "Judgement three", { three_other })
  check("Judgement three at another player doesn't fire", ran, 0)
  check("and raises nothing", err, nil)
end

-- Staff swing: multiline, so the name comes from the first line's capture and
-- not from whatever an earlier trigger left in matches.
do
  local swing = ATTACKER .. " swings her quarterstaff with all her might, generating a great wind."
  local wave = "The wave of force knocks you to the ground."

  local w = fresh(STALE)
  local ran, err = fire(w, "Groves", "Staff swing", { swing, wave })
  check("Staff swing fires on its two lines", ran, 1)
  check("and raises nothing", err, nil)
  check("and records the attacker", attacker_class(w, ATTACKER), "druid")
  check("not the stale name", attacker_class(w, STALE), nil)
  check("and no unknown attacker", attacker_class(w, "?"), nil)

  w = fresh(STALE)
  ran = fire(w, "Groves", "Staff swing", { swing })
  check("Staff swing needs its second line", ran, 0)
end

-- Lightbind: the caster's name is captured, and the line must be aimed at you.
do
  local at_me = "Golden chains of light coalesce in the hands of " .. ATTACKER .. ", and he casts them out to bind you to him."
  local at_other = "Golden chains of light coalesce in the hands of " .. ATTACKER .. ", and he casts them out to bind " .. OTHER .. " to him."

  local w = fresh(STALE)
  local ran, err = fire(w, "Psionics", "Lightbind", { at_me })
  check("Lightbind at me fires", ran, 1)
  check("and raises nothing", err, nil)
  check("and records the caster", attacker_class(w, ATTACKER), "psion")
  check("and no unknown attacker", attacker_class(w, "?"), nil)

  w = fresh(STALE)
  ran = fire(w, "Psionics", "Lightbind", { at_other })
  check("Lightbind at another player doesn't fire", ran, 0)
end

-- Jack-in-the-Box two: multiline, so whose name it yells comes from
-- multimatches. Reading matches warned about a name an earlier trigger left.
do
  local function line(who)
    return 'The music of the jack-in-the-box becomes faster and more frantic and a loud voice from within yells, "' .. who .. ", I'm a-cooomiiiiing!\""
  end

  local w = fresh(OTHER)
  local ran, err = fire(w, "Pranks", "Jack-in-the-Box two", { line(ME) })
  check("Jack-in-the-Box two at me fires", ran, 1)
  check("and raises nothing", err, nil)
  check("and warns, whatever matches holds", w.warned[1] and w.warned[1].prefixwarning, ME .. " Jack-in-the-Box you")

  w = fresh(ME)
  ran, err = fire(w, "Pranks", "Jack-in-the-Box two", { line(OTHER) })
  check("Jack-in-the-Box two at another player fires", ran, 1)
  check("and raises nothing", err, nil)
  check("and doesn't warn, though matches holds my name", #w.warned, 0)
end

-- tonguetied and mindravaged, which the game reports over GMCP. svof had no
-- name for either in sstosvoa, so an Add, a Remove and a List all passed it by.
do
  local function live()
    local w = fresh(STALE)
    w.env.gmcp.Char.Afflictions.List = {}
    w.svo.signals.gmcpcharafflictionslist:emit()
    return w
  end
  local function add(w, name)
    w.env.gmcp.Char.Afflictions.Add = { name = name, cure = "", desc = "" }
    w.svo.signals.gmcpcharafflictionsadd:emit()
    w.prompt()
  end
  local function remove(w, name)
    w.env.gmcp.Char.Afflictions.Remove = { name }
    w.svo.signals.gmcpcharafflictionsremove:emit()
    w.prompt()
  end
  local function listed(w, names)
    local t = {}
    for i, name in ipairs(names) do t[i] = { name = name, cure = "", desc = "" } end
    w.env.gmcp.Char.Afflictions.List = t
    w.svo.signals.gmcpcharafflictionslist:emit()
    w.prompt()
  end
  local function has(w, name) return w.svo.affs[name] ~= nil end

  for _, name in ipairs({ "tonguetied", "mindravaged" }) do
    local w = live()
    check(name .. ": the name is mapped", w.svo.dict.sstosvoa[name], name)
    check(name .. ": and back", w.svo.dict.svotossa[name], name)
    add(w, name)
    check(name .. ": a GMCP Add tracks it", has(w, name), true)
    remove(w, name)
    check(name .. ": a GMCP Remove clears it", has(w, name), false)
    listed(w, { name })
    check(name .. ": a GMCP List tracks it", has(w, name), true)
    listed(w, {})
    check(name .. ": a List without it clears it", has(w, name), false)
  end

  local w = live()
  add(w, "tonguetied")
  check("tonguetied's salve is advisable once GMCP adds it", w.svo.dict.tonguetied.salve.isadvisable() and true, true)
  w.svo.rmaff("tonguetied")
  w.prompt()
  check("a cure's timeout doesn't clear what GMCP still reports", has(w, "tonguetied"), true)

  -- the two lines of the attack, through the real triggers
  local PUPPET = ATTACKER .. " twists and contorts the wooden tongue of a puppet of " .. ME .. "."
  local PUPPET_OTHER = ATTACKER .. " twists and contorts the wooden tongue of a puppet of " .. OTHER .. "."
  local GAIN = "Your tongue twists and writhes in your mouth as if with a will of its own."
  local V = "Vodun & Puppetry"

  local function see(w, lines)
    for _, l in ipairs(lines) do
      fire(w, V, "tonguetied", { l })
      fire(w, V, "tonguetied gain", { l })
    end
    w.prompt()
    return has(w, "tonguetied")
  end
  local function blackout(aillusion)
    local b = fresh(STALE)
    b.env.gmcp.Char.Afflictions.List = {}
    b.svo.signals.gmcpcharafflictionslist:emit()
    b.svo.valid.simpleblackout()
    b.prompt()
    b.svo.conf.aillusion = aillusion
    check("the test is in blackout", b.svo.affs.blackout ~= nil, true)
    return b
  end

  check("GMCP live and silent: both lines don't add it", see(live(), { PUPPET, GAIN }), false)
  check("before GMCP is live, the gain line adds it", see(fresh(STALE), { GAIN }), true)

  check("blackout: the puppet line alone doesn't add it", see(blackout(true), { PUPPET }), false)
  check("blackout: the gain line alone doesn't add it", see(blackout(true), { GAIN }), false)
  check("blackout: the puppet line, then the gain line, adds it", see(blackout(true), { PUPPET, GAIN }), true)
  check("blackout: the gain line, then the puppet line, adds it", see(blackout(true), { GAIN, PUPPET }), true)
  check("blackout: a puppet of someone else doesn't count", see(blackout(true), { PUPPET_OTHER, GAIN }), false)

  w = blackout(true)
  see(w, { PUPPET })
  check("blackout: a prompt between the two lines starts over", see(w, { GAIN }), false)

  check("blackout, anti-illusion off: the gain line alone adds it", see(blackout(false), { GAIN }), true)
  check("blackout, anti-illusion off: the puppet line alone doesn't", see(blackout(false), { PUPPET }), false)
end

-- svo.getHighestKey started from -1, so it found no key when every value was
-- -1 or lower, and the curing pass that asked for one raised. svo.prio.insert
-- takes a negative priority from a player's script.
do
  local w = world.new({ class = "Monk" })
  local g = w.svo.getHighestKey
  check("getHighestKey: all negative", g({ a = -5, b = -2 }), "b")
  check("getHighestKey: -1 alone", g({ a = -1 }), "a")
  check("getHighestKey: 0 alone", g({ a = 0 }), "a")
  check("getHighestKey: mixed", g({ a = -5, b = 3 }), "b")
  check("getHighestKey: positive", g({ a = 3, b = 9 }), "b")
  check("getHighestKey: empty", g({}), nil)

  local d = w.svo.dict
  d.healhealth.sip.isadvisable = function() return true end
  d.healmana.sip.isadvisable = function() return false end
  w.svo.prio.insert("healhealth", "sip", -5)
  check("the test's priority is negative", d.healhealth.sip.aspriority, -5)
  local ok = pcall(w.svo.check_sip)
  check("the sip pass doesn't raise at a negative priority", ok, true)
  check("and sips", w.svo.doingaction("healhealth"), true)
end

-- svo.install.checkinvgmcp: `not t.location == 'inv'` was never true, so a pipe
-- on the floor took a pipe slot, and svof emptied it.
do
  local w = world.new({ class = "Monk" })
  local function list(location, id)
    w.env.gmcp.Char.Items.List = { location = location, items = { { id = id, name = "a wooden pipe" } } }
    w.svo.install.checkinvgmcp()
  end
  w.sent = {}
  list("room", 5)
  check("a pipe in a room's list isn't sent anything", #w.sent, 0)
  check("and takes no pipe slot", w.svo.pipes.valerian.id, 0)
  list("inv", 6)
  check("a pipe in the inventory is emptied", w.sent[1], "empty 6")
  check("and takes the slot", w.svo.pipes.valerian.id, 6)
end

-- svo.lc_sethitsneeded: a bare echof raised on hits that aren't a number,
-- which the shn alias can pass, as its pattern takes "." alone.
do
  local w = world.new({ class = "Magi" })
  w.run(read_file("src/scripts/svo (limbcounter)/svo_limbcounter.lua"), "limbcounter")
  local ok = pcall(w.svo.lc_sethitsneeded, nil, nil)
  check("shn without a number doesn't raise", ok, true)
end

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
