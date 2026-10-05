--[[
Logic-level test for slow curing (sys.sync, in aeon and retardation): what
svof sends when Action_system kicks the gnomes.

signals.changecuring swaps svo.make_gnomes_work for the sync gnome, which
sends one command and waits for it. Action_system used to keep its own copy,
taken at load, so its kicks after a finished, killed or timed-out action ran
the async gnome instead: one command per free balance, batched and sent on a
later timer without sk.gnomes_are_working set. cnrl.processcommand then took
them for the player's. In aeon, where autotsc turns deny mode on, it refused
them, and the refused actions stayed in flight, blocking the sync gnome until
they timed out and kicked the async gnome again. In retardation, override
mode let the batch through and paused curing as if the player had typed.

Action_system copied the logger the same way, so its lines ignored the saved
vconfig log, which the config loader applies after Action_system loads. A
check at the end covers that.

Like the other suites, this does not run svof or Mudlet. It runs the real
Action_system loader, both gnomes and the changecuring switch, the batch
send queue and doingstuff_inslowmode from Curing_skeleton, fancysend from
Miscellaneous_functions, cnrl.processcommand from Controllers and checkaeony
from Setup, over Penlight's OrderedMap, with svof's default settings. The
per-balance cure checks are stubs shaped like the real check_herb, and
Mudlet's send, timers and denyCurrentSend are stubs. The controls run
Action_system with its old copy put back.

Run: lua tools/test_slow_curing.lua
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
local CS = SCRIPTS .. "svo (curing skeleton, controllers, action system)/"
local SMEF = SCRIPTS .. "svo (setup, misc, empty, funnies, dor)/"
local SKELETON = read_file(CS .. "Curing_skeleton.lua")
local ACTIONS = read_file(CS .. "Action_system.lua")
local CONTROLLERS = read_file(CS .. "Controllers.lua")
local MISC = read_file(SMEF .. "Miscellaneous_functions.lua")
local SETUP = read_file(SMEF .. "Setup.lua")

-- Action_system with its load-time copy of the gnome, for the controls.
local LIVE_GNOMES = "local function make_gnomes_work() return svo.make_gnomes_work() end"
local COPIED_GNOMES = "local make_gnomes_work = svo.make_gnomes_work"
local ACTIONS_OLD_GNOMES = swap(ACTIONS, LIVE_GNOMES, COPIED_GNOMES)
-- and with its load-time copy of the logger
local ACTIONS_OLD_DEBUGF = swap(ACTIONS, "local function debugf(...) return svo.debugf(...) end",
  "local debugf = svo.debugf")

-- ===== Penlight, loaded the way svof ships it =====

for _, mod in ipairs({"utils", "tablex", "List", "class", "Map", "OrderedMap", "pretty", "lexer", "stringx"}) do
  package.preload["pl." .. mod] = function()
    local chunk, err = loadfile(SCRIPTS .. "svo (core)/3rdparty/Penlight/" .. mod .. ".lua")
    -- pretty.lua assigns to a loop variable, which Lua 5.1 allows and 5.4+
    -- refuses to compile. Nothing here prints a map.
    if not chunk and mod == "pretty" then return { write = tostring } end
    assert(chunk, err)
    chunk()
    return package.loaded["pl." .. mod]
  end
end
local OrderedMap = require("pl.OrderedMap")
local tablex = require("pl.tablex")

-- Mudlet adds string.trim; the sync gnome's debug line uses it.
string.trim = string.trim or function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local unpack = unpack or table.unpack

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

local function sig()
  return { connect = function() end, emit = function() end, block = function() end, unblock = function() end }
end

-- opts.actions: the Action_system source to run, default the shipped one
local function new_svof(opts)
  opts = opts or {}
  local log, timers, now = {}, {}, 0
  local denied

  local changecuring = { fns = {} }
  function changecuring:connect(f) self.fns[#self.fns + 1] = f end
  function changecuring:emit() for _, f in ipairs(self.fns) do f() end end

  -- svof's defaults (Setup.lua) for everything slow curing reads
  local svo = {
    dict = {}, affs = {}, actions = OrderedMap(), actions_performed = {}, bals_in_use = {},
    sys = { sync = false, wait = 1, lagcount = 0, lagcountmax = 3 },
    conf = { commandecho = true, commandechotype = 'fancy', batch = true, blockcommands = true,
             autotsc = true, repeatcmd = 0, sacdelay = 0.5, paused = false },
    sk = { systemscommands = {}, sendqueue = {}, sendqueuel = 18, achaea_command_max_length = 2048 },
    bals = { focus = true, salve = true, herb = true },
    signals = { changecuring = changecuring, curedwith_focus = sig(), sync = sig(), sysdatasendrequest = sig() },
    lifevision = { l = OrderedMap() },
    cnrl = {}, pl = { tablex = tablex, pretty = { write = tostring } },
    codepaste = {}, ignore = {}, serverignore = {},
    assert = assert,
    debugf = function() end,
    echof = function(fmt, ...) log[#log + 1] = { kind = "echo", text = (string.format(fmt, ...):gsub("<[%d,]+>", "")) } end,
    getDefaultColor = function() return "" end,
    concatand = function(t) return table.concat(t, ", ") end,
    syncdelay = function() return 1 end,
  }
  svo.affl = svo.affs

  local function tempTimer(t, f) timers[#timers + 1] = { at = now + t, f = f, seq = #timers } return #timers end
  -- Mudlet's send: sysDataSendRequest reaches cnrl.processcommand only in
  -- slow curing, where checkaeony unblocks it
  local function mudlet_send(cmd)
    denied = false
    if svo.sys.sync then svo.cnrl.processcommand(cmd) end
    log[#log + 1] = { kind = denied and "denied" or "sent", text = cmd }
  end
  -- Miscellaneous_functions reads it as _G.send, for svo.oldsend
  _G.send = mudlet_send

  local env = setmetatable({
    svo = svo, sk = svo.sk, sys = svo.sys, conf = svo.conf, affs = svo.affs, dict = svo.dict, bals = svo.bals,
    signals = svo.signals, cnrl = svo.cnrl, actions = svo.actions, lifevision = svo.lifevision,
    tempTimer = tempTimer, killTimer = function() end,
    createStopWatch = function() return 1 end, startStopWatch = function() end,
    echoLink = function() end, echo = function() end, decho = function() end, raiseEvent = function() end,
    denyCurrentSend = function() denied = true end, getNetworkLatency = function() return 0.1 end,
    getLastLineNumber = function() return 1 end, getTimestamp = function() return "t" end,
    getLineCount = function() return 1 end, expandAlias = function() end,
    sendAll = function(...)
      for _, c in ipairs({...}) do if type(c) == "string" then mudlet_send(c) end end
    end,
    unpack = unpack,
  }, { __index = _G })

  -- three afflictions, each cured on its own balance, focus first by priority
  local make = load_into(env, [[return function(aff, bal, cmd, p)
    return { name = aff .. '_' .. bal, action_name = aff, balance = bal, aspriority = p, spriority = p,
      isadvisable = function() return affs[aff] ~= nil end,
      onstart = function() send(cmd, false) end, oncompleted = function() end }
  end]], "make action")
  for aff, cure in pairs({ stupidity = { "focus", "focus", 3 }, anorexia = { "salve", "apply epidermal", 2 },
                           asthma = { "herb", "eat kelp", 1 } }) do
    svo.dict[aff] = { [cure[1]] = make(aff, cure[1], cure[2], cure[3]) }
    svo.affs[aff] = { p = svo.dict[aff] }
  end
  svo.dict.aeon = { smoke = { name = "aeon_smoke", action_name = "aeon", balance = "smoke",
    onstart = function() end, oncompleted = function() end } }

  -- the per-balance checks, shaped like the real check_herb: in sync mode they
  -- name the action, otherwise they do it
  for _, bal in ipairs({ "focus", "salve", "herb" }) do
    svo["check_" .. bal] = function(sync_mode)
      if not svo.bals[bal] or svo.usingbal(bal) then return end
      for name in pairs(svo.affs) do
        local act = svo.dict[name] and svo.dict[name][bal]
        if act and act.isadvisable() then
          if sync_mode then return act end
          svo.doaction(act)
          return
        end
      end
    end
  end
  for _, n in ipairs({ "sip", "purgative", "smoke", "moss", "misc", "balanceless_acts", "balanceful_acts" }) do
    svo["check_" .. n] = function() end
  end
  svo.sk.balance_controller = function() end

  -- the real code, in the order svo_init_system loads it
  load_into(env, "local oldecho\n" .. between(SETUP, "sk.checkaeony = function()", "\nend\n", true), "checkaeony")
  load_into(env, between(MISC, "svo.oldsend = _G.send", "function svo.yep"), "fancysend")
  load_into(env, between(SKELETON, "local function find_highest_action(tbl)", "function svo.send_in_the_gnomes()"),
    "gnomes and changecuring")
  load_into(env, between(SKELETON, "function sk.sendqueuecmd(...)", "function svo.sendcuring(what)") .. "\n"
    .. between(SKELETON, "function sk.dosendqueue()", "function svo.sk.setup9multicmd()")
    .. "\nsvo.sendc = sk.sendqueuecmd", "send queue")
  load_into(env, between(SKELETON, "function sk.doingstuff_inslowmode()", "function sk.checkwillpower()"),
    "doingstuff_inslowmode")
  load_into(env, "local cnrl = svo.cnrl\n" .. between(CONTROLLERS, "function svo.cnrl.processcommand(what)",
    "signals.sysdatasendrequest:connect(cnrl.processcommand"), "processcommand")
  load_into(env, opts.actions or ACTIONS, "Action_system")
  svo.loader.action()

  local s = { svo = svo }

  function s.run_timers()
    while #timers > 0 do
      table.sort(timers, function(a, b) return a.at < b.at or (a.at == b.at and a.seq < b.seq) end)
      if timers[1].at > now then break end
      table.remove(timers, 1).f()
    end
  end
  function s.advance(t) now = now + t; s.run_timers() end

  -- aeon or retardation arrives: checkaeony, then changecuring, as every caller does
  function s.slow_curing(aff)
    svo.affs[aff] = {}
    svo.sk.checkaeony()
    svo.signals.changecuring:emit()
  end

  -- a prompt where an aeon smoke finishes: lifevision completes it, then the
  -- prompt runs the current gnome (svo.send_in_the_gnomes)
  function s.prompt_with_finished_smoke()
    svo.checkaction(svo.dict.aeon.smoke, true)
    svo.actionfinished(svo.dict.aeon.smoke)
    svo.make_gnomes_work()
    s.run_timers()
  end

  function s.count(kind, pattern)
    local n = 0
    for _, entry in ipairs(log) do
      if entry.kind == kind and (not pattern or entry.text:find(pattern, 1, true)) then n = n + 1 end
    end
    return n
  end
  function s.sent() local t = {} for _, e in ipairs(log) do if e.kind == "sent" then t[#t + 1] = e.text end end return table.concat(t, " | ") end
  function s.inflight() local t = {} for k in svo.actions:iter() do t[#t + 1] = k end table.sort(t) return table.concat(t, ", ") end

  return s
end

-- ===== aeon: a cure finishes at a prompt =====

local s = new_svof()
s.slow_curing("aeon")
eq(s.svo.conf.blockcommands, true, "aeon: autotsc turned deny mode on")
s.prompt_with_finished_smoke()
eq(s.sent(), "focus", "aeon: the prompt sends one cure")
eq(s.count("denied"), 0, "aeon: nothing denied")
eq(s.inflight(), "stupidity_focus", "aeon: only that cure is in flight")
s.advance(2.5)
eq(s.sent(), "focus | focus", "aeon: after focus times out, focus again")
eq(s.count("denied"), 0, "aeon: still nothing denied")

s = new_svof({ actions = ACTIONS_OLD_GNOMES })
s.slow_curing("aeon")
s.prompt_with_finished_smoke()
eq(s.count("denied", "{apply epidermal}{eat kelp}"), 1, "control: aeon: the copied async gnome's batch is denied")
eq(s.inflight(), "anorexia_salve, asthma_herb, stupidity_focus", "control: aeon: the denied cures stay in flight")
s.advance(2.5)
eq(s.count("denied", "{focus}{apply epidermal}{eat kelp}"), 1, "control: aeon: after the timeouts, focus is denied too")

-- ===== aeon arrives while cures are in flight =====

for _, old in ipairs({ false, true }) do
  local label = old and "control: entering aeon: " or "entering aeon: "
  s = new_svof({ actions = old and ACTIONS_OLD_GNOMES or nil })
  s.svo.doaction(s.svo.dict.anorexia.salve)
  s.svo.doaction(s.svo.dict.asthma.herb)
  s.run_timers()
  s.slow_curing("aeon")    -- checkaeony kills both cures, and each kill kicks a gnome
  s.run_timers()
  if old then
    eq(s.count("denied"), 1, label .. "the kicks' batch is denied")
  else
    eq(s.count("denied"), 0, label .. "nothing denied")
    eq(s.sent(), "apply epidermal | eat kelp | focus", label .. "one cure sent after aeon starts")
    eq(s.inflight(), "stupidity_focus", label .. "one cure in flight")
  end
end

-- ===== retardation: autotsc turns override mode on =====

for _, old in ipairs({ false, true }) do
  local label = old and "control: retardation: " or "retardation: "
  s = new_svof({ actions = old and ACTIONS_OLD_GNOMES or nil })
  s.slow_curing("retardation")
  eq(s.svo.conf.blockcommands, false, label .. "autotsc turned override mode on")
  s.prompt_with_finished_smoke()
  eq(s.count("echo", "pausing curing for your commands."), old and 1 or 0, label .. "curing paused as if the player typed")
  eq(s.count("sent", "9multicmd"), old and 1 or 0, label .. "several cures sent at once")
  eq(s.sent(), old and "focus | 9multicmd {apply epidermal}{eat kelp}" or "focus", label .. "what was sent")
end

-- ===== normal curing is unchanged =====

-- the timeout's kick runs the async gnome either way
local logs = {}
for _, old in ipairs({ false, true }) do
  s = new_svof({ actions = old and ACTIONS_OLD_GNOMES or nil })
  s.svo.doaction(s.svo.dict.stupidity.focus)
  s.run_timers()
  s.advance(2.5)
  logs[#logs + 1] = s.sent()
end
eq(logs[1], "focus | 9multicmd {focus}{apply epidermal}{eat kelp}", "normal curing: a timeout kicks the async gnome")
eq(logs[1], logs[2], "normal curing: the same with the old copy")

-- ===== Action_system logs through the current logger =====

-- svo.updateloggingconfig replaces svo.debugf when the config loader applies
-- the saved vconfig log, which is after Action_system has loaded
for _, old in ipairs({ false, true }) do
  local label = old and "control: logging: " or "logging: "
  s = new_svof({ actions = old and ACTIONS_OLD_DEBUGF or nil })
  local lines = {}
  s.svo.debugf = function(fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end
  s.svo.doaction(s.svo.dict.stupidity.focus)
  local found = false
  for _, line in ipairs(lines) do
    if line == "actions: doing stupidity_focus" then found = true end
  end
  eq(found, not old, label .. "a logger set after load gets Action_system's lines")
end

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
