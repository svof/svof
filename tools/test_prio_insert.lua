--[[
Logic-level test for svo.prio.insert, which `vset <action> <balance> <number>`
calls, in the slow curing list.

A slow curing entry is named action_balance, such as paranoia_focus. When the
number asked for was taken, the shuffle split that name with
svo.valid_sync_action before it set the entry's spriority and raised
"svo prio changed". When the number was free, insertat did neither: it
indexed svo.dict["paranoia_focus"], which is nil, and raised, so moving an
entry into any of the slow curing list's many gaps failed.

In an action's own balance, prio.insert checked no names: an unknown
action, an action without that balance, or a balance with no priority list
raised a Lua error, and its "no such balance" check never fired, because
svo.make_prio_table always returns a table. It refuses them now, and with
echoback (vset, which ignores the return) it says why, for slow curing names
too.

In slow curing, svo.valid_sync_action only checks that the entry exists, so
paranoia_aff, a table that isn't a cure, went into the list onto a free
number (and stayed there, saved with the rest), and raised onto a taken one.
prio.insert refuses a name with no slow curing number now. Every cure has
one: dict_setup gives one to every balance but aff, gone, waitingfor,
boosted and weakened.

svo.basictableindexdiff listed a value that moved once from each table, so
the shuffle above, prio.cleargaps and every other caller raised "svo prio
changed" twice for each entry that moved. It lists each value once now.

`vswapslow <action_balance> <action_balance>`, svo.prio_slowswap, checked
for the second balance before it parsed it, so it always said "What
balances do you want to use for swapping?", then swapped anyway. After a
swap its two lines disagreed: the plain line named the entries in one order
and the coloured line in the other, and with a number the plain line could
be wrong too. A misspelled name on either side raised a Lua error, and a
swap onto a free number stored the number as a string, which
svo.printordersync and prio.getsortedlist can't sort. It refuses names the
slow curing list doesn't have now, as prio.insert does, says the order the
swap left, and stores a number.

sk.notifypriodiffs, which vswapslow and a priority import raise their
events through, split each slow curing name into a local that hid the
loop's balance, so it looked the new number up in the entry's own
balance's snapshot (herb, physical) and every slow curing event said nil.

Like the other suites, this does not run svof or Mudlet. It runs the real
priorities loader from Priorities.lua, the real svo.valid_sync_action,
svo.make_prio_table, svo.make_sync_prio_table and their filtered forms,
svo.basictableindexdiff, svo.deepcopy, svo.prio_slowswap,
svo.printordersync, Serverside's priority snapshots and
sk.notifypriodiffs, and the real vset and vswapslow alias scripts, over a
small dictionary with the slow curing numbers default_prios gives those
entries. Mudlet's raiseEvent and svof's echo are stubs that record what
they get. The controls put the old insertat, the old name checks, the old
diff and the old swap back.

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
local CONTROLLERS = read_file(SCRIPTS .. "svo (curing skeleton, controllers, action system)/Controllers.lua")
local SERVERSIDE = read_file(SCRIPTS .. "svo (custom prompt, serverside)/Serverside.lua")
local VSWAPSLOW = read_file("src/aliases/svo (aliases, triggers)/svo/Swap_slow_mode_affliction_priorities.lua")

local DIFF = between(MISC, "svo.basictableindexdiff = function (t1, t2)", "svo.oldsend = _G.send")
-- Serverside's snapshots and notifypriodiffs, and the same with the old lookup, for the control
local SNAPSHOTS = between(SERVERSIDE, "function sk.getbeforestateprios()", "-- returns an alphabetically sorted")
local NOTIFY = between(SNAPSHOTS, "      for _, a in pairs(diff) do\n", "      end\n    else\n")
local SNAPSHOTS_OLD = swap(SNAPSHOTS, NOTIFY, [[
      for _, a in pairs(diff) do
        local _, action, balance = valid_sync_action(a)
        raiseEvent("svo prio changed", action, balance, afterstate[balance].action_prio[a], 'slowcuring')
]])
local SLOWSWAP = between(CONTROLLERS, "function svo.prio_slowswap(", "function svo.prio_swap(")
local PRINTORDERSYNC = between(CONTROLLERS, "function svo.printordersync(limited_around)", "\nend\n", true)

-- the old diff, which listed a value that moved from both tables, for the control
local DIFF_OLD = [[
svo.basictableindexdiff = function (t1, t2)
  local diff = {}
  -- have to use pairs to cover holes
  for k,v in pairs(t1) do
    if v ~= t2[k] then diff[#diff+1] = v end
  end
  for k,v in pairs(t2) do
    if v ~= t1[k] then diff[#diff+1] = v end
  end

  return diff
end
]]

-- and the old swap
local SLOWSWAP_OLD = [[
function svo.prio_slowswap(what, arg3, echoback, callback, ...)
  local sendf; if echoback then sendf = svo.echof else sendf = svo.errorf end
  local what, balance = what:match("(%w+)_(%w+)")
  local balance2
  if not tonumber(arg3) then
    svo.assert(balance and balance2, "What balances do you want to use for swapping?", sendf)
    arg3, balance2 = arg3:match("(%w+)_(%w+)")
  end

  local beforestate = sk.getbeforestateprios()

  if tonumber(arg3) then -- swap to a #
    local name, balance2 = svo.prio.getslowaction(tonumber(arg3))
    if not name then -- see if we have anyone in that # already
      svo.dict[what][balance].spriority = arg3
      if echoback then
        svo.echof("%s is now at %d.", what, arg3)
      end
    else -- if we do have someone at that #, swap them
      svo.dict[what][balance].spriority, svo.dict[name][balance2].spriority =
      svo.dict[name][balance2].spriority, svo.dict[what][balance].spriority
      if echoback then svo.echof("%s is now > %s.", what, name) end
      if echoback then svo.echof("<0,255,0>%s (%s) <255,255,255>> <0,255,0>%s (%s)", what, balance, name, balance2) end
    end
  else -- swap one action_balance with another action_balance
    if svo.dict[what][balance].spriority < svo.dict[arg3][balance2].spriority then
      svo.dict[what][balance].spriority, svo.dict[arg3][balance2].spriority =
      svo.dict[arg3][balance2].spriority, svo.dict[what][balance].spriority
      if echoback then svo.echof("%s is now > %s.", what, arg3) end
      if echoback then svo.echof("<0,255,0>%s (%s) <255,255,255>> <0,255,0>%s (%s)", arg3, balance2, what, balance) end
    elseif echoback then
      svo.echof("%s is already > %s.", what, arg3)
    end
  end

  local afterstate = sk.getafterstateprios()
  sk.notifypriodiffs(beforestate, afterstate)

  if callback and type(callback) == 'function' then callback(...) end
end
]]

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
-- and with the old name checks: slow curing names only, and silent
local CHECKS = between(PRIORITIES, "function prio.insert(action, balance, number, echoback)\n",
  "  local function getpriotable(balancename)")
local PRIORITIES_UNCHECKED = swap(PRIORITIES, CHECKS, [[
function prio.insert(action, balance, number, echoback)
  number = tonumber(number)

  if balance == 'balance' then balance = 'physical' end

  if balance == 'slowcuring' then
    local validaction, plainaction = svo.valid_sync_action(action)

    if not validaction then return false, plainaction end
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

-- opts.priorities, opts.diff, opts.slowswap, opts.snapshots: the source to run for each, default the shipped one
local function new_svof(opts)
  opts = opts or {}
  local events, echoes, printed = {}, {}, {}
  local noop = function() end
  local svo = {
    dict = {}, sys = {}, sk = {}, prio = {}, loader = {},
    signals = { saveconfig = { add_pre_emit = noop }, systemstart = { connect = noop } },
    pl = { dir = { makepath = noop } },
    echof = function(fmt, ...) echoes[#echoes + 1] = string.format(fmt, ...) end,
    debugf = noop, echofn = noop, showprompt = noop,
    getDefaultColorNums = { 255, 255, 255 },
    -- printordersync marks the defences players defined or changed: none here
    defences = { mark = function() return '' end, mark_colour = '', mark_key = function() return '' end },
    -- the snapshots notify only once svof has loaded
    systemloaded = true,
  }
  -- Serverside ignores nothing here
  svo.sk.shouldignoreserverside = function() return false end
  for _, e in ipairs(ENTRIES) do
    svo.dict[e[1]] = svo.dict[e[1]] or {}
    svo.dict[e[1]][e[2]] = { spriority = e[3], aspriority = e[4] }
  end
  -- a balance dict_setup gives no priority, as it does aff, gone and waitingfor
  svo.dict.paranoia.aff = {}
  -- and a plain field, such as unweavingbody's count
  svo.dict.paranoia.count = 0

  local env = setmetatable({
    svo = svo,
    getMudletHomeDir = function() return "home" end,
    raiseEvent = function(...) events[#events + 1] = { ... } end,
    -- what printordersync draws with
    selectString = function() return -1 end,
    setFgColor = noop, setLink = noop, resetFormat = noop, setUnderline = noop,
    echoLink = noop,
    echo = function(text) printed[#printed + 1] = text end,
    decho = function(text) printed[#printed + 1] = text end,
    unpack = unpack or table.unpack,
  }, { __index = _G })

  load_into(env, between(SETUP, "function svo.deepcopy(object)", "\nend\n", true), "deepcopy")
  load_into(env, between(SETUP, "function svo.assert(condition, msg, extra)", "\nend\n", true), "assert")
  load_into(env, between(MISC, "function svo.errorf(...)", "\nend\n", true), "errorf")
  load_into(env, opts.diff or DIFF, "basictableindexdiff")
  load_into(env, between(DICTIONARY, "svo.make_prio_table = function (filterbalance)",
    "svo.clear_balance_prios = function"), "make_prio_table")
  load_into(env, "local dict = svo.dict\n" .. between(ACTIONS, "svo.valid_sync_action = function(name)",
    "\nend\n", true), "valid_sync_action")
  load_into(env, "local sk = svo.sk\n" .. (opts.snapshots or SNAPSHOTS), "priority snapshots")
  load_into(env, "local sk = svo.sk\n" .. (opts.slowswap or SLOWSWAP), "prio_slowswap")
  load_into(env, PRINTORDERSYNC, "printordersync")
  load_into(env, opts.priorities or PRIORITIES, "Priorities")
  svo.loader.prio()

  local s = { svo = svo, events = events, echoes = echoes, printed = printed }

  -- the vswapslow alias, as Mudlet runs it on "vswapslow <what> <with>";
  -- returns what it raised, if anything
  function s.vswapslow(what, with)
    env.matches = { "vswapslow " .. what .. " " .. with, what, with }
    local _, err = pcall(load_into, env, VSWAPSLOW, "vswapslow")
    return err
  end

  -- svo.printordersync: what it raised, if anything
  function s.printordersync(...)
    local ran, err = pcall(svo.printordersync, ...)
    if not ran then return err end
  end

  -- the slow curing list as getsortedlist gives it, or what it raised
  function s.sortedslow()
    local ran, list = pcall(svo.prio.getsortedlist, 'slowcuring')
    if not ran then return "raised: " .. tostring(list) end
    return table.concat(list, " ")
  end

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

  -- "action balance number slowcuring" for each event, sorted, repeats kept
  function s.moved()
    local t = {}
    for _, ev in ipairs(events) do
      t[#t + 1] = string.format("%s %s %s %s", tostring(ev[2]), tostring(ev[3]), tostring(ev[4]), tostring(ev[5]))
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
eq(#s.events, 4, "vset onto a taken number: one event for each entry that moved, not two")
eq(s.events_name_entries(), true, "vset onto a taken number: every event names a dictionary entry")
eq(s.echoes[1], "Set paranoia_focus's priority in slowcuring balance to 20.", "vset onto a taken number: what vset says")

-- ===== names the slow curing list does not have =====

local SLOW_REFUSALS = {
  { "a balance the action lacks", "paranoia_herb", "paranoia doesn't operate on the herb balance" },
  { "a table that isn't a cure", "paranoia_aff", "paranoia_aff isn't in the slow curing list" },
  { "a plain field", "paranoia_count", "paranoia_count isn't in the slow curing list" },
  { "an unknown action", "nosuch_focus", "action nosuch doesn't exist" },
  { "no balance in the name", "paranoia",
    "actionname is in invalid format; it should be as 'actionname_balance'" },
}
for _, case in ipairs(SLOW_REFUSALS) do
  -- 15 is free in slow curing, 20 is doparry's
  for _, number in ipairs({ 15, 20 }) do
    local label = string.format("slow curing, %s, onto %d: ", case[1], number)
    s = new_svof()
    err, ok, msg = s.insert(case[2], "slowcuring", number)
    eq(err, nil, label .. "raised nothing")
    eq(ok, false, label .. "refused")
    eq(msg, case[3], label .. "why")
    eq(s.spriorities(), SPRIORITIES, label .. "no slow curing number moved")
    eq(s.aspriorities(), ASPRIORITIES, label .. "no own-balance number moved")
    eq(s.svo.dict.paranoia.aff.spriority, nil, label .. "the table that isn't a cure got no number")
    eq(#s.events, 0, label .. "no event")
    eq(#s.echoes, 0, label .. "nothing said without echoback")
  end
  s = new_svof()
  eq(s.vset(case[2], "slowcuring", "15"), nil, "vset, slow curing, " .. case[1] .. ": raised nothing")
  eq(s.echoes[1], "Can't set that priority: " .. case[3] .. ".", "vset, slow curing, " .. case[1] .. ": what vset says")
  eq(#s.echoes, 1, "vset, slow curing, " .. case[1] .. ": said once")
end

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

-- ===== a taken number in an action's own balance is unchanged =====

-- paranoia has 32; hallucinations goes there, and dementia and paranoia move down one
s = new_svof()
err, ok = s.insert("hallucinations", "focus", 32)
eq(err, nil, "own balance, a taken number: raised nothing")
eq(ok, true, "own balance, a taken number: returns true")
eq(s.aspriorities(), "hallucinations=32 dementia=30 paranoia=31 mindseye=50 defcheck=51 doparry=52 deathsight=53",
  "own balance, a taken number: the focus numbers")
eq(s.spriorities(), SPRIORITIES, "own balance, a taken number: no slow curing number moved")
eq(s.changes(), "dementia focus 30 nil | hallucinations focus 32 nil | paranoia focus 31 nil",
  "own balance, a taken number: an event for each entry that moved")
eq(#s.events, 3, "own balance, a taken number: one event for each entry that moved, not two")

-- ===== names an action's own balance does not have =====

local REFUSALS = {
  { "an unknown action", "nosuch", "focus", "action nosuch doesn't exist" },
  { "a balance the action lacks", "mindseye", "focus", "mindseye doesn't operate on the focus balance" },
  { "an unknown balance", "paranoia", "nosuchbal", "paranoia doesn't operate on the nosuchbal balance" },
  { "a balance with no priority", "paranoia", "aff", "paranoia doesn't operate on the aff balance" },
  { "a plain field", "paranoia", "count", "paranoia doesn't operate on the count balance" },
}
for _, case in ipairs(REFUSALS) do
  -- 40 is free in focus, 31 is dementia's
  for _, number in ipairs({ 40, 31 }) do
    local label = string.format("own balance, %s, onto %d: ", case[1], number)
    s = new_svof()
    err, ok, msg = s.insert(case[2], case[3], number)
    eq(err, nil, label .. "raised nothing")
    eq(ok, false, label .. "refused")
    eq(msg, case[4], label .. "why")
    eq(s.aspriorities(), ASPRIORITIES, label .. "no own-balance number moved")
    eq(s.spriorities(), SPRIORITIES, label .. "no slow curing number moved")
    eq(s.svo.dict.paranoia.aff.aspriority, nil, label .. "the balance with no priority got none")
    eq(#s.events, 0, label .. "no event")
    eq(#s.echoes, 0, label .. "nothing said without echoback")
  end
  s = new_svof()
  eq(s.vset(case[2], case[3], "40"), nil, "vset, " .. case[1] .. ": raised nothing")
  eq(s.echoes[1], "Can't set that priority: " .. case[4] .. ".", "vset, " .. case[1] .. ": what vset says")
  eq(#s.echoes, 1, "vset, " .. case[1] .. ": said once")
end

-- ===== svo.basictableindexdiff =====

-- sorted, so pairs order doesn't matter
local function diffof(t1, t2)
  local d = new_svof().svo.basictableindexdiff(t1, t2)
  table.sort(d)
  return table.concat(d, " ")
end
eq(diffof({ "a", "b", "c" }, { "b", "a", "c" }), "a b", "diff: each value that moved, once")
eq(diffof({ "a", "b" }, { "a", "b" }), "", "diff: nothing moved, nothing listed")
-- a value that is in one table only, as when Serverside starts or stops ignoring an action
eq(diffof({ "a", "b" }, { "a" }), "b", "diff: a value only the first table has")
eq(diffof({ "a" }, { "a", nil, "c" }), "c", "diff: a value only the second table has")
eq(diffof({ [1] = "a", [5] = "b" }, { "a", "b" }), "b", "diff: across a gap")

-- ===== prio.cleargaps: one event for each entry that moved =====

s = new_svof()
s.svo.prio.cleargaps('slowcuring')
eq(s.spriorities(), "hallucinations=1 dementia=2 paranoia=3 mindseye=4 defcheck=5 doparry=6 deathsight=7",
  "cleargaps, slow curing: the numbers")
eq(s.aspriorities(), ASPRIORITIES, "cleargaps, slow curing: no own-balance number moved")
eq(s.changes(), "deathsight physical 7 slowcuring | defcheck physical 5 slowcuring | dementia focus 2 slowcuring | "
  .. "doparry physical 6 slowcuring | hallucinations focus 1 slowcuring | mindseye physical 4 slowcuring | "
  .. "paranoia focus 3 slowcuring", "cleargaps, slow curing: an event for each entry that moved")
eq(#s.events, 7, "cleargaps, slow curing: one event for each entry, not two")

s = new_svof()
s.svo.prio.cleargaps('physical')
eq(s.aspriorities(), "hallucinations=30 dementia=31 paranoia=32 mindseye=1 defcheck=2 doparry=3 deathsight=4",
  "cleargaps, own balance: the numbers")
eq(s.changes(), "deathsight physical 4 nil | defcheck physical 2 nil | doparry physical 3 nil | mindseye physical 1 nil",
  "cleargaps, own balance: an event for each entry that moved")
eq(#s.events, 4, "cleargaps, own balance: one event for each entry, not two")

-- ===== vswapslow with two names =====

-- mindseye has 18, doparry 20: mindseye goes above
s = new_svof()
eq(s.vswapslow("mindseye_physical", "doparry_physical"), nil, "vswapslow two names: raised nothing")
eq(s.spriorities(), "hallucinations=10 dementia=11 paranoia=12 mindseye=20 defcheck=19 doparry=18 deathsight=22",
  "vswapslow two names: the two swapped")
eq(s.echoes[1], "mindseye is now > doparry.", "vswapslow two names: says the order")
eq(s.echoes[2], "<0,255,0>mindseye (physical) <255,255,255>> <0,255,0>doparry (physical)",
  "vswapslow two names: the coloured line says the same order")
eq(#s.echoes, 2, "vswapslow two names: asks nothing about balances")
eq(s.moved(), "doparry physical 18 slowcuring | mindseye physical 20 slowcuring",
  "vswapslow two names: one event for each entry, not two")

s = new_svof()
eq(s.vswapslow("doparry_physical", "mindseye_physical"), nil, "vswapslow, already above: raised nothing")
eq(s.spriorities(), SPRIORITIES, "vswapslow, already above: nothing moved")
eq(s.echoes[1], "doparry is already > mindseye.", "vswapslow, already above: says so")
eq(#s.echoes, 1, "vswapslow, already above: said once")
eq(#s.events, 0, "vswapslow, already above: no event")

-- ===== vswapslow onto a number =====

-- deathsight has 22, mindseye 18: deathsight goes down to 18, so mindseye is above it now
s = new_svof()
eq(s.vswapslow("deathsight_physical", "18"), nil, "vswapslow down onto a taken number: raised nothing")
eq(s.spriorities(), "hallucinations=10 dementia=11 paranoia=12 mindseye=22 defcheck=19 doparry=20 deathsight=18",
  "vswapslow down onto a taken number: the two swapped")
eq(s.echoes[1], "mindseye is now > deathsight.", "vswapslow down onto a taken number: says the order")
eq(s.echoes[2], "<0,255,0>mindseye (physical) <255,255,255>> <0,255,0>deathsight (physical)",
  "vswapslow down onto a taken number: the coloured line says the same order")
eq(s.moved(), "deathsight physical 18 slowcuring | mindseye physical 22 slowcuring",
  "vswapslow down onto a taken number: one event for each entry")

s = new_svof()
eq(s.vswapslow("mindseye_physical", "22"), nil, "vswapslow up onto a taken number: raised nothing")
eq(s.spriorities(), "hallucinations=10 dementia=11 paranoia=12 mindseye=22 defcheck=19 doparry=20 deathsight=18",
  "vswapslow up onto a taken number: the two swapped")
eq(s.echoes[1], "mindseye is now > deathsight.", "vswapslow up onto a taken number: says the order")
eq(s.echoes[2], "<0,255,0>mindseye (physical) <255,255,255>> <0,255,0>deathsight (physical)",
  "vswapslow up onto a taken number: the coloured line says the same order")
eq(type(s.svo.dict.mindseye.physical.spriority), "number", "vswapslow onto a taken number: stores a number")
eq(s.moved(), "deathsight physical 18 slowcuring | mindseye physical 22 slowcuring",
  "vswapslow up onto a taken number: one event for each entry, with its new number")

s = new_svof()
eq(s.vswapslow("mindseye_physical", "18"), nil, "vswapslow onto its own number: raised nothing")
eq(s.spriorities(), SPRIORITIES, "vswapslow onto its own number: nothing moved")
eq(s.echoes[1], "mindseye is already at 18.", "vswapslow onto its own number: says so")
eq(#s.events, 0, "vswapslow onto its own number: no event")

s = new_svof()
eq(s.vswapslow("mindseye_physical", "15"), nil, "vswapslow onto a free number: raised nothing")
eq(s.svo.dict.mindseye.physical.spriority, 15, "vswapslow onto a free number: stores the number as a number")
eq(s.spriorities(), "hallucinations=10 dementia=11 paranoia=12 mindseye=15 defcheck=19 doparry=20 deathsight=22",
  "vswapslow onto a free number: nothing else moved")
eq(s.echoes[1], "mindseye is now at 15.", "vswapslow onto a free number: says so")
eq(s.moved(), "mindseye physical 15 slowcuring", "vswapslow onto a free number: one event")
eq(s.sortedslow(), "deathsight_physical doparry_physical defcheck_physical mindseye_physical "
  .. "paranoia_focus dementia_focus hallucinations_focus", "vswapslow onto a free number: getsortedlist sorts it")
eq(s.printordersync(), nil, "vswapslow onto a free number: printordersync raised nothing")
local listed = false
for _, text in ipairs(s.printed) do if text == " (15) mindseye (physical)" then listed = true end end
eq(listed, true, "vswapslow onto a free number: printordersync lists it at 15")

-- the ^^ and vv links in printordersync pass a number, no echoback and printordersync to call after
s = new_svof()
local ran, linkerr = pcall(s.svo.prio_slowswap, "mindseye_physical", 15, false, s.svo.printordersync, 15)
eq(ran, true, "the printordersync link: raised nothing " .. tostring(linkerr))
eq(s.svo.dict.mindseye.physical.spriority, 15, "the printordersync link: moved the entry")
eq(#s.printed > 0, true, "the printordersync link: printed the list again")
s = new_svof()
ran, linkerr = pcall(s.svo.prio_slowswap, "deathsight_physical", 18, false, s.svo.printordersync, 18)
eq(ran, true, "the printordersync link onto a taken number: raised nothing " .. tostring(linkerr))
eq(s.svo.dict.deathsight.physical.spriority, 18, "the printordersync link onto a taken number: swapped")
local saidorder = false
for _, text in ipairs(s.echoes) do if text:find(" > ", 1, true) then saidorder = true end end
eq(saidorder, false, "the printordersync link onto a taken number: says no order without echoback")

-- what it returns
s = new_svof()
local _, okswap, why = pcall(s.svo.prio_slowswap, "mindseye_physical", "doparry_physical", true)
eq(okswap, true, "prio_slowswap returns true after a swap")
_, okswap, why = pcall(s.svo.prio_slowswap, "nosuch_physical", "doparry_physical", true)
eq(okswap, false, "prio_slowswap returns false for a refusal")
eq(why, "action nosuch doesn't exist", "prio_slowswap returns the reason")

-- ===== vswapslow with names the slow curing list does not have =====

for _, case in ipairs(SLOW_REFUSALS) do
  for _, pair in ipairs({ { case[2], "doparry_physical" }, { "doparry_physical", case[2] }, { case[2], "15" } }) do
    local label = string.format("vswapslow %s %s: ", pair[1], pair[2])
    s = new_svof()
    eq(s.vswapslow(pair[1], pair[2]), nil, label .. "raised nothing")
    eq(s.echoes[1], "Can't swap that: " .. case[3] .. ".", label .. "says why")
    eq(#s.echoes, 1, label .. "said once")
    eq(s.spriorities(), SPRIORITIES, label .. "no slow curing number moved")
    eq(s.svo.dict.paranoia.aff.spriority, nil, label .. "the table that isn't a cure got no number")
    eq(#s.events, 0, label .. "no event")
  end
  -- a script, with no echoback, gets an error, as it did for the old balances question
  s = new_svof()
  local ok, swaperr = pcall(s.svo.prio_slowswap, case[2], "doparry_physical")
  eq(ok, false, "prio_slowswap without echoback, " .. case[1] .. ": raised")
  eq(tostring(swaperr):find("Can't swap that: " .. case[3] .. ".", 1, true) ~= nil, true,
    "prio_slowswap without echoback, " .. case[1] .. ": with the reason")
  eq(s.spriorities(), SPRIORITIES, "prio_slowswap without echoback, " .. case[1] .. ": nothing moved")
end

-- ===== control: the old diff =====

s = new_svof({ diff = DIFF_OLD })
s.vset("paranoia_focus", "slowcuring", "20")
eq(#s.events, 8, "control: the old diff raised two events for each of the shuffle's four moves")
s = new_svof({ diff = DIFF_OLD })
s.svo.prio.cleargaps('slowcuring')
eq(#s.events, 14, "control: and for each of cleargaps' seven")
s = new_svof({ diff = DIFF_OLD })
s.vswapslow("mindseye_physical", "doparry_physical")
eq(#s.events, 4, "control: and for each of vswapslow's two")

-- ===== control: the old lookup in notifypriodiffs =====

s = new_svof({ snapshots = SNAPSHOTS_OLD })
s.vswapslow("mindseye_physical", "doparry_physical")
eq(s.moved(), "doparry physical nil slowcuring | mindseye physical nil slowcuring",
  "control: the old lookup raised the swap's events without a number")
s = new_svof({ snapshots = SNAPSHOTS_OLD })
s.vswapslow("mindseye_physical", "15")
eq(s.moved(), "mindseye physical nil slowcuring", "control: onto a free number too")

-- ===== control: the old swap =====

s = new_svof({ slowswap = SLOWSWAP_OLD })
eq(s.vswapslow("mindseye_physical", "doparry_physical"), nil, "control: vswapslow two names raised nothing")
eq(s.echoes[1], "What balances do you want to use for swapping?", "control: and asked for the balances")
eq(s.svo.dict.mindseye.physical.spriority, 20, "control: then swapped anyway")
eq(s.echoes[2], "mindseye is now > doparry.", "control: said mindseye was above")
eq(s.echoes[3], "<0,255,0>doparry (physical) <255,255,255>> <0,255,0>mindseye (physical)",
  "control: and coloured it the other way round")
s = new_svof({ slowswap = SLOWSWAP_OLD })
s.vswapslow("deathsight_physical", "18")
eq(s.echoes[1], "deathsight is now > mindseye.", "control: moving down onto a number, said the wrong order")
s = new_svof({ slowswap = SLOWSWAP_OLD })
s.vswapslow("mindseye_physical", "15")
eq(type(s.svo.dict.mindseye.physical.spriority), "string", "control: a free number was stored as a string")
eq(s.sortedslow():find("compare", 1, true) ~= nil, true, "control: which getsortedlist can't sort")
eq(tostring(s.printordersync()):find("compare", 1, true) ~= nil, true, "control: nor printordersync")
for _, pair in ipairs({ { "nosuch_physical", "doparry_physical" }, { "doparry_physical", "nosuch_physical" },
    { "nosuch_physical", "15" }, { "doparry_physical", "mindseye_herb" }, { "paranoia_aff", "doparry_physical" } }) do
  s = new_svof({ slowswap = SLOWSWAP_OLD })
  eq(s.vswapslow(pair[1], pair[2]) ~= nil, true,
    string.format("control: vswapslow %s %s raised", pair[1], pair[2]))
end

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

-- ===== control: the old name checks =====

s = new_svof({ priorities = PRIORITIES_UNCHECKED })
err = s.insert("nosuch", "focus", 40)
eq(tostring(err):find("index", 1, true) ~= nil, true, "control: an unknown action onto a free number raised")
s = new_svof({ priorities = PRIORITIES_UNCHECKED })
err = s.insert("nosuch", "focus", 31)
eq(tostring(err):find("index is nil", 1, true) ~= nil, true, "control: onto a taken number, by a nil table index")
s = new_svof({ priorities = PRIORITIES_UNCHECKED })
eq(s.vset("paranoia_herb", "slowcuring", "15"), nil, "control: vset with a bad slow curing name raised nothing")
eq(#s.echoes, 0, "control: and said nothing")
s = new_svof({ priorities = PRIORITIES_UNCHECKED })
err, ok = s.insert("paranoia_aff", "slowcuring", 15)
eq(ok, true, "control: a table that isn't a cure went in onto a free number")
eq(s.svo.dict.paranoia.aff.spriority, 15, "control: and got a slow curing number")
s = new_svof({ priorities = PRIORITIES_UNCHECKED })
err = s.insert("paranoia_aff", "slowcuring", 20)
eq(tostring(err):find("index is nil", 1, true) ~= nil, true, "control: onto a taken number it raised")

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, m in ipairs(failures) do print("FAIL: " .. m) end
  os.exit(1)
end
print("ALL PASS")
