--[[
Logic-level test for svo.prio.insert, which `vset <action> <balance> <number>`
calls, in the slow curing list.

A slow curing entry is named action_balance, such as paranoia_focus. When the
number asked for was taken, the shuffle split that name with
svo.valid_sync_action before it set the entry's spriority and raised
"svo prio changed". When the number was free, insertat did neither: it
indexed svo.dict["paranoia_focus"], which is nil, and raised, so moving an
entry into any of the slow curing list's many gaps failed.

Like the other suites, this does not run svof or Mudlet. It runs the real
priorities loader from Priorities.lua, the real svo.valid_sync_action,
svo.make_prio_table, svo.make_sync_prio_table, svo.basictableindexdiff and
svo.deepcopy, and the real vset alias script, over a small dictionary with
the slow curing numbers default_prios gives those entries. Mudlet's raiseEvent
and svof's echo are stubs that record what they get. The control puts the
old insertat back.

Run: lua tools/test_prio_insert.lua
]]

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return (data:gsub("\r\n", "\n"))
end

-- From the start anchor to just before the end anchor, or through it.
local function between(source, start_anchor, end_anchor, through)
  local s = source:find(start_anchor, 1, true)
  if not s then error("start anchor not found: " .. start_anchor) end
  local e = source:find(end_anchor, s + 1, true)
  if not e then error("end anchor not found: " .. end_anchor) end
  if through then e = e + #end_anchor end
  return source:sub(s, e - 1)
end

-- Replaces the one occurrence of from, and refuses if there is not exactly one.
local function swap(source, from, to)
  local s, e = source:find(from, 1, true)
  assert(s and not source:find(from, e + 1, true), "expected exactly one occurrence of: " .. from)
  return source:sub(1, s - 1) .. to .. source:sub(e + 1)
end

local SCRIPTS = "src/scripts/"
local PRIORITIES = read_file(SCRIPTS .. "svo (install, config, pipes, rift, parry, prios)/Priorities.lua")
local ACTIONS = read_file(SCRIPTS .. "svo (curing skeleton, controllers, action system)/Action_system.lua")
local DICTIONARY = read_file(SCRIPTS .. "svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua")
local MISC = read_file(SCRIPTS .. "svo (setup, misc, empty, funnies, dor)/Miscellaneous_functions.lua")
local SETUP = read_file(SCRIPTS .. "svo (setup, misc, empty, funnies, dor)/Setup.lua")
local VSET = read_file("src/aliases/svo (aliases, triggers)/svo/Set_an_affliction_priority.lua")

-- Priorities.lua with the old insertat, for the control.
local INSERTAT = between(PRIORITIES, "  local function insertat(actionname, balancename, newprio)\n", "\n  end\n", true)
local PRIORITIES_OLD = swap(PRIORITIES, INSERTAT, [[
  local function insertat(actionname, balancename, newprio)
    if balancename ~= 'slowcuring' then
      svo.dict[actionname][balancename].aspriority = newprio
    else
      svo.dict[actionname][balancename].spriority = newprio
    end
    if echoback then svo.echof("Set %s's priority in %s balance to %d.", actionname, balancename, newprio) end
    raiseEvent("svo prio changed", actionname, balancename, newprio, (balancename == 'slowcuring' and 'slowcuring'))
  end
]])

-- ===== assertions =====

local failures, checks = {}, 0
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

-- ===== environment =====

local function load_into(env, code, name)
  local chunk, err
  if setfenv then
    chunk, err = loadstring(code, name)
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(code, name, "t", env)
  end
  if not chunk then error("failed to load " .. name .. ": " .. tostring(err)) end
  local ok, result = pcall(chunk)
  if not ok then error("failed to run " .. name .. ": " .. tostring(result)) end
  return result
end

-- slow curing and own-balance numbers, the slow curing ones from default_prios
local ENTRIES = {
  { "hallucinations", "focus", 10, 30 },
  { "dementia", "focus", 11, 31 },
  { "paranoia", "focus", 12, 32 },
  { "mindseye", "physical", 18, 50 },
  { "defcheck", "physical", 19, 51 },
  { "doparry", "physical", 20, 52 },
  { "deathsight", "physical", 22, 53 },
}

-- opts.priorities: the Priorities.lua source to run, default the shipped one
local function new_svof(opts)
  opts = opts or {}
  local events, echoes = {}, {}
  local noop = function() end
  local svo = {
    dict = {}, sys = {}, sk = {}, prio = {}, loader = {},
    signals = { saveconfig = { add_pre_emit = noop }, systemstart = { connect = noop } },
    pl = { dir = { makepath = noop } },
    echof = function(fmt, ...) echoes[#echoes + 1] = string.format(fmt, ...) end,
    debugf = noop,
  }
  for _, e in ipairs(ENTRIES) do
    svo.dict[e[1]] = svo.dict[e[1]] or {}
    svo.dict[e[1]][e[2]] = { spriority = e[3], aspriority = e[4] }
  end

  local env = setmetatable({
    svo = svo,
    getMudletHomeDir = function() return "home" end,
    raiseEvent = function(...) events[#events + 1] = { ... } end,
  }, { __index = _G })

  load_into(env, between(SETUP, "function svo.deepcopy(object)", "\nend\n", true), "deepcopy")
  load_into(env, between(MISC, "svo.basictableindexdiff = function (t1, t2)", "svo.oldsend = _G.send"),
    "basictableindexdiff")
  load_into(env, between(DICTIONARY, "svo.make_prio_table = function (filterbalance)",
    "-- func gets passed the action name to operate on, needs to return true"), "make_prio_table")
  load_into(env, "local dict = svo.dict\n" .. between(ACTIONS, "svo.valid_sync_action = function(name)",
    "\nend\n", true), "valid_sync_action")
  load_into(env, opts.priorities or PRIORITIES, "Priorities")
  svo.loader.prio()

  local s = { svo = svo, events = events, echoes = echoes }

  -- the vset alias, as Mudlet runs it on "vset <action> <balance> <number>";
  -- returns what it raised, if anything
  function s.vset(action, balance, number)
    env.matches = { "vset " .. action .. " " .. balance .. " " .. number, action, balance, number }
    local _, err = pcall(load_into, env, VSET, "vset")
    return err
  end

  -- svo.prio.insert: what it raised, if anything, then what it returned
  function s.insert(...)
    local ran, ok, msg = pcall(svo.prio.insert, ...)
    if not ran then return ok end
    return nil, ok, msg
  end

  -- "action balance number slowcuring" for each event, sorted and without repeats
  function s.changes()
    local seen, t = {}, {}
    for _, ev in ipairs(events) do
      local text = string.format("%s %s %s %s", tostring(ev[2]), tostring(ev[3]), tostring(ev[4]), tostring(ev[5]))
      if not seen[text] then seen[text] = true; t[#t + 1] = text end
    end
    table.sort(t)
    return table.concat(t, " | ")
  end

  -- every event names an entry that exists, as the event's listeners index it
  function s.events_name_entries()
    for _, ev in ipairs(events) do
      if ev[1] ~= "svo prio changed" or not (svo.dict[ev[2]] and svo.dict[ev[2]][ev[3]]) then return false end
    end
    return #events > 0
  end

  function s.spriorities()
    local t = {}
    for _, e in ipairs(ENTRIES) do t[#t + 1] = e[1] .. "=" .. svo.dict[e[1]][e[2]].spriority end
    return table.concat(t, " ")
  end
  function s.aspriorities()
    local t = {}
    for _, e in ipairs(ENTRIES) do t[#t + 1] = e[1] .. "=" .. svo.dict[e[1]][e[2]].aspriority end
    return table.concat(t, " ")
  end

  return s
end

local SPRIORITIES = "hallucinations=10 dementia=11 paranoia=12 mindseye=18 defcheck=19 doparry=20 deathsight=22"
local ASPRIORITIES = "hallucinations=30 dementia=31 paranoia=32 mindseye=50 defcheck=51 doparry=52 deathsight=53"

-- ===== a free slow curing number, through vset =====

local s = new_svof()
eq(s.vset("paranoia_focus", "slowcuring", "15"), nil, "vset into a gap: raised nothing")
eq(s.svo.dict.paranoia.focus.spriority, 15, "vset into a gap: paranoia_focus's slow curing number")
eq(s.spriorities(), "hallucinations=10 dementia=11 paranoia=15 mindseye=18 defcheck=19 doparry=20 deathsight=22",
  "vset into a gap: no other slow curing number moved")
eq(s.aspriorities(), ASPRIORITIES, "vset into a gap: no own-balance number moved")
eq(#s.events, 1, "vset into a gap: one event")
eq(s.changes(), "paranoia focus 15 slowcuring", "vset into a gap: the event names the action and balance apart")
eq(s.events_name_entries(), true, "vset into a gap: the event names a dictionary entry")
eq(s.echoes[1], "Set paranoia_focus's priority in slowcuring balance to 15.", "vset into a gap: what vset says")
eq(#s.echoes, 1, "vset into a gap: said once")

-- ===== a free number above the whole list =====

s = new_svof()
local err, ok, msg = s.insert("hallucinations_focus", "slowcuring", 100)
eq(err, nil, "insert above the list: raised nothing")
eq(ok, true, "insert above the list: returns true")
eq(msg, nil, "insert above the list: no message")
eq(s.svo.dict.hallucinations.focus.spriority, 100, "insert above the list: the slow curing number")
eq(s.spriorities(), "hallucinations=100 dementia=11 paranoia=12 mindseye=18 defcheck=19 doparry=20 deathsight=22",
  "insert above the list: no other slow curing number moved")
eq(s.changes(), "hallucinations focus 100 slowcuring", "insert above the list: the event")
eq(#s.echoes, 0, "insert above the list: nothing said without echoback")

-- ===== a taken number: the shuffle, as it was =====

-- doparry has 20; paranoia goes there, and the entries from 13 to 20 move down one
s = new_svof()
eq(s.vset("paranoia_focus", "slowcuring", "20"), nil, "vset onto a taken number: raised nothing")
eq(s.spriorities(), "hallucinations=10 dementia=11 paranoia=20 mindseye=17 defcheck=18 doparry=19 deathsight=22",
  "vset onto a taken number: the slow curing numbers")
eq(s.aspriorities(), ASPRIORITIES, "vset onto a taken number: no own-balance number moved")
eq(s.changes(), "defcheck physical 18 slowcuring | doparry physical 19 slowcuring | "
  .. "mindseye physical 17 slowcuring | paranoia focus 20 slowcuring",
  "vset onto a taken number: an event for each entry that moved")
eq(s.events_name_entries(), true, "vset onto a taken number: every event names a dictionary entry")
eq(s.echoes[1], "Set paranoia_focus's priority in slowcuring balance to 20.", "vset onto a taken number: what vset says")

-- ===== a name the slow curing list does not have =====

s = new_svof()
err, ok, msg = s.insert("paranoia_herb", "slowcuring", 15)
eq(err, nil, "a balance the action lacks: raised nothing")
eq(ok, false, "a balance the action lacks: refused")
eq(msg, "paranoia doesn't operate on the herb balance", "a balance the action lacks: why")
eq(s.spriorities(), SPRIORITIES, "a balance the action lacks: nothing moved")
eq(#s.events, 0, "a balance the action lacks: no event")

-- ===== a free number in an action's own balance is unchanged =====

s = new_svof()
err, ok = s.insert("paranoia", "focus", 40)
eq(err, nil, "own balance, a gap: raised nothing")
eq(ok, true, "own balance, a gap: returns true")
eq(s.svo.dict.paranoia.focus.aspriority, 40, "own balance, a gap: the focus number")
eq(s.spriorities(), SPRIORITIES, "own balance, a gap: no slow curing number moved")
eq(#s.events, 1, "own balance, a gap: one event")
local ev = s.events[1] or {}
eq(string.format("%s %s %s", tostring(ev[2]), tostring(ev[3]), tostring(ev[4])), "paranoia focus 40",
  "own balance, a gap: the event")
eq(not ev[5], true, "own balance, a gap: the event does not say slow curing")

-- ===== control: the old insertat =====

s = new_svof({ priorities = PRIORITIES_OLD })
err = s.vset("paranoia_focus", "slowcuring", "15")
eq(err ~= nil, true, "control: vset into a gap raised")
eq(tostring(err):find("index", 1, true) ~= nil, true, "control: by indexing a nil entry")
eq(s.spriorities(), SPRIORITIES, "control: nothing moved")
eq(#s.events, 0, "control: no event")
s = new_svof({ priorities = PRIORITIES_OLD })
eq(s.vset("paranoia_focus", "slowcuring", "20"), nil, "control: a taken number raised nothing already")
eq(s.svo.dict.paranoia.focus.spriority, 20, "control: and moved the entry")

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, m in ipairs(failures) do print("FAIL: " .. m) end
  os.exit(1)
end
print("ALL PASS")
