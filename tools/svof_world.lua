--[[
Loads svof's real subsystems into plain Lua, for the logic-level tests that
need more of svof than one extracted block: the whole dictionary, the
defence records and the handlers svof generates from them at systemstart.

It runs the 22 required loaders in svo_init_system's order, then
svo.signals.systemstart, then svo.reset.bals, for the class you ask for, so
every svo.haveskillset gate in the source decides what loads exactly as it
does in Mudlet. The code is the shipped source, read from src/ at run time,
not a copy.

Mudlet itself is stubbed: sends, echoes, temp triggers, timers and raised
events are recorded, not performed. A temp trigger's pattern is kept, so a
test can feed svof an exact-match line and run what the trigger would run.
Regex triggers are recorded but not matched; call their handler directly.
A killed trigger stays recorded, marked killed, and no longer fires.
Nothing here proves anything about Mudlet, the game, or the static trigger
items in src/triggers, which this does not load.

Every global svof reads that neither Lua nor these stubs provide is counted
in world.unknown_globals, so a test can insist that list stays as expected
instead of a nil quietly standing in for something missing.

Usage, from the repo root:
  local world = dofile("tools/svof_world.lua")
  local w = world.new({ class = "Monk" })
  w.svo.dict.rebounding ...
]]

local world = {}

local ROOT = "src/scripts/"
world.LOADERS = {
  {"setup", "svo (setup, misc, empty, funnies, dor)/Setup.lua"},
  {"misc", "svo (setup, misc, empty, funnies, dor)/Miscellaneous_functions.lua"},
  {"empty", "svo (setup, misc, empty, funnies, dor)/Empty_cure_handling.lua"},
  {"dict", "svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"},
  {"sk", "svo (curing skeleton, controllers, action system)/Curing_skeleton.lua"},
  {"controllers", "svo (curing skeleton, controllers, action system)/Controllers.lua"},
  {"action", "svo (curing skeleton, controllers, action system)/Action_system.lua"},
  {"pipes", "svo (install, config, pipes, rift, parry, prios)/Pipes.lua"},
  {"rift", "svo (install, config, pipes, rift, parry, prios)/Rift.lua"},
  {"diag", "svo (trigger functions)/Diag_trigger_functions.lua"},
  {"valid_simple", "svo (trigger functions)/Simple_aff_trigger_functions.lua"},
  {"valid_main", "svo (trigger functions)/Main_trigger_functions.lua"},
  {"config", "svo (install, config, pipes, rift, parry, prios)/Config_system.lua"},
  {"install", "svo (install, config, pipes, rift, parry, prios)/Install_system.lua"},
  {"aliases", "svo (alias and defence functions)/Alias_functions.lua"},
  {"defences", "svo (alias and defence functions)/Defences.lua"},
  {"prio", "svo (install, config, pipes, rift, parry, prios)/Priorities.lua"},
  {"parry", "svo (install, config, pipes, rift, parry, prios)/Parry.lua"},
  {"funnies", "svo (setup, misc, empty, funnies, dor)/Funnies.lua"},
  {"dor", "svo (setup, misc, empty, funnies, dor)/Dor.lua"},
  {"customprompt", "svo (custom prompt, serverside)/Custom_prompt.lua"},
  {"serverside", "svo (custom prompt, serverside)/Serverside.lua"},
}

-- Scripts that are not loaders but define svo functions the loaders' code
-- calls, such as svo.startbalancewatch. Mudlet runs them as the package
-- loads, before svo_init_system calls the loaders.
world.SCRIPTS = {
  "svo (core)/Create_Svof_namespace.lua",
  "svo (core)/svo_Utilities.lua",
  "svo (core)/svo Utilities/Tree_curing_strats.lua",
  "svo (core)/svo Utilities/Restore_curing_strats.lua",
  "svo (core)/svo Utilities/Dragonheal_curing_strats.lua",
  "svo (core)/svo Utilities/Shrugging_curing_strats.lua",
  "svo (core)/svo Utilities/Fitness_curing_strats.lua",
  "svo (core)/svo Utilities/Rage_curing_strats.lua",
  "svo (core)/svo_Time_Tracking.lua",
  "svo (core)/svo_Class_Management.lua",
  "svo (core)/Load & init/svo_init_system.lua",
  "svo (core)/Load & init/svo.classchange.lua",
}

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return (data:gsub("\r\n", "\n"))
end
world.read_file = read_file

-- Mudlet runs Lua 5.1: loadstring plus setfenv. 5.2+ has load with an env.
local function compile(code, name, env)
  local chunk, err
  if setfenv then
    chunk, err = loadstring(code, "=" .. name)
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(code, "=" .. name, "t", env)
  end
  if not chunk then error("failed to compile " .. name .. ": " .. tostring(err)) end
  return chunk
end
world.compile = compile

-- The loaders' sources, read once. Lua 5.1 reads an unknown escape such as
-- \w as the letter alone, and 5.2+ refuses to compile it; one string in
-- Main_trigger_functions has one, so on a newer Lua it gets 5.1's reading.
local sources = {}
for _, path in ipairs(world.SCRIPTS) do sources[path] = read_file(ROOT .. path) end
for _, l in ipairs(world.LOADERS) do
  local src = read_file(ROOT .. l[2])
  if _VERSION ~= "Lua 5.1" then src = src:gsub("as \\w%+ draws", "as w+ draws") end
  sources[l[1]] = src
end

-- ===== the libraries svof requires =====

local G = {}
for k, v in pairs(_G) do G[k] = v end

-- luanotify declares itself with module(), which 5.2+ does not have: run it
-- in an environment that collects its globals into the module table instead
local function lua_module(path, name, require_fn)
  local M = {}
  local menv = setmetatable({}, {
    __index = function(_, k) if M[k] ~= nil then return M[k] end return G[k] end,
    __newindex = function(_, k, v) M[k] = v end,
  })
  rawset(menv, "module", function() end)
  rawset(menv, "require", require_fn)
  compile(read_file(path), name, menv)()
  return M
end

local PENLIGHT = ROOT .. "svo (core)/3rdparty/Penlight/"
for _, mod in ipairs({"utils", "tablex", "List", "class", "Map", "OrderedMap", "lexer", "stringx"}) do
  package.preload["pl." .. mod] = package.preload["pl." .. mod] or function()
    local chunk = assert(loadfile(PENLIGHT .. mod .. ".lua"))
    chunk()
    return package.loaded["pl." .. mod]
  end
end
-- pretty and dir do not compile on 5.4+, and dir and path need lfs; nothing
-- tested here prints a table or walks a directory
local PENLIGHT_STUBS = {
  ["pl.pretty"] = function() return { write = function(t) return tostring(t) end } end,
  ["pl.config"] = function() return {} end,
  ["pl.dir"] = function() return { makepath = function() return true end } end,
  ["pl.path"] = function() return { exists = function() return false end } end,
}
for name, f in pairs(PENLIGHT_STUBS) do package.preload[name] = package.preload[name] or f end
-- In Mudlet the Penlight scripts have run before svo_init_system, which
-- refuses to start without them
require("pl.tablex")

local function new_require()
  local loaded = {}
  local req
  local preload = {
    ["notify.signal"] = function()
      return lua_module(ROOT .. "svo (core)/3rdparty/notify/signal.lua", "notify.signal", function(n) return req(n) end)
    end,
    ["notify.double_queue"] = function()
      return lua_module(ROOT .. "svo (core)/3rdparty/notify/double_queue.lua", "notify.double_queue", function(n) return req(n) end)
    end,
    ["lfs"] = function() return { attributes = function() return nil end, mkdir = function() return true end } end,
    ["debug"] = function() return debug end,
  }
  req = function(name)
    if loaded[name] == nil then
      if preload[name] then loaded[name] = preload[name]()
      elseif name:find("^pl%.") then loaded[name] = require(name)
      else error("require: no module " .. name) end
    end
    return loaded[name]
  end
  return req
end

-- ===== Mudlet's additions to string and table =====

local function extend(lib, extra)
  local t = {}
  for k, v in pairs(lib) do t[k] = v end
  for k, v in pairs(extra) do t[k] = v end
  return t
end

local mudlet_string = {
  split = function(s, sep)
    local t = {}
    for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do t[#t + 1] = piece end
    return t
  end,
  title = function(s) return (s:gsub("^%l", string.upper)) end,
  trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
  starts = function(s, p) return s:sub(1, #p) == p end,
  ends = function(s, p) return p == "" or s:sub(-#p) == p end,
}
-- svof calls these as methods on strings, which go through the real string
-- table, so they have to be there too
for k, v in pairs(mudlet_string) do string[k] = string[k] or v end

local mudlet_table = {
  contains = function(t, ...)
    local args = {...}
    for k, v in pairs(t) do
      for _, a in ipairs(args) do if v == a or k == a then return true end end
    end
    return false
  end,
  is_empty = function(t) return next(t) == nil end,
  size = function(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end,
  keys = function(t) local r = {} for k in pairs(t) do r[#r + 1] = k end return r end,
  index_of = function(t, v) for i, x in ipairs(t) do if x == v then return i end end end,
  n_complement = function(a, b)
    local r, inb = {}, {}
    for _, v in ipairs(b) do inb[v] = true end
    for _, v in ipairs(a) do if not inb[v] then r[#r + 1] = v end end
    return r
  end,
  save = function() end,
  load = function() end,
  unpack = table.unpack or unpack,
  maxn = table.maxn or function(t)
    local n = 0
    for k in pairs(t) do if type(k) == "number" and k > n then n = k end end
    return n
  end,
}

local STDLIB = {"assert", "error", "ipairs", "next", "pairs", "pcall", "print", "rawequal", "rawget", "rawset",
  "select", "setmetatable", "getmetatable", "tonumber", "tostring", "type", "unpack", "xpcall", "math", "os",
  "io", "coroutine", "debug", "loadstring", "load", "setfenv", "getfenv", "collectgarbage"}

-- ===== one svof =====

-- opts.class: the class svof loads for (svo.me.class), default "Infernal"
-- opts.paused: leave curing paused, so a prompt runs lifevision and the
--   prompt queue but svof sends nothing of its own; default true
function world.new(opts)
  opts = opts or {}
  local w = {
    sent = {}, echoes = {}, links = {}, events = {}, triggers = {}, timers = {},
    unknown_globals = {}, now = 0,
  }
  local timerseq = 0
  local env = {}

  local function record_trigger(kind)
    return function(pattern, code)
      w.triggers[#w.triggers + 1] = { kind = kind, pattern = pattern, code = code }
      return #w.triggers
    end
  end
  local function noop() end
  local function echo(s) w.echoes[#w.echoes + 1] = tostring(s) end
  local function link(text, code) w.links[#w.links + 1] = tostring(text) .. " " .. tostring(code) end

  local mudlet = {
    tempTimer = function(t, f)
      timerseq = timerseq + 1
      w.timers[timerseq] = { at = w.now + t, f = f, seq = timerseq }
      return timerseq
    end,
    killTimer = function(id) w.timers[id] = nil return true end,
    tempTrigger = record_trigger("substring"),
    tempExactMatchTrigger = record_trigger("exact"),
    tempRegexTrigger = record_trigger("regex"),
    tempBeginOfLineTrigger = record_trigger("begin"),
    tempLineTrigger = function() return 0 end,
    -- a killed trigger stays in w.triggers, marked, and no longer fires
    killTrigger = function(id)
      if not w.triggers[id] then return false end
      w.triggers[id].killed = true
      return true
    end,
    registerAnonymousEventHandler = function() return 1 end,
    raiseEvent = function(name, ...) w.events[#w.events + 1] = { name = name, args = {...} } end,
    getMudletHomeDir = function() return "." end,
    createStopWatch = function() return 1 end, startStopWatch = noop,
    stopStopWatch = function() return 0 end, getStopWatchTime = function() return 0 end, resetStopWatch = noop,
    echo = echo, cecho = echo, decho = echo, hecho = echo, insertText = echo, cinsertText = echo,
    -- a link's text and the code it runs, such as the "(e!)" svof shows for an error
    echoLink = link, dechoLink = link, cechoLink = link, insertLink = link,
    deleteLine = noop, selectString = function() return -1 end, replace = noop, creplace = noop,
    setFgColor = noop, setBgColor = noop, setUnderline = noop, setBold = noop, setItalics = noop,
    moveCursor = noop, moveCursorEnd = noop, selectCurrentLine = noop, deselect = noop,
    fg = noop, bg = noop, resetFormat = noop, copy = noop, paste = noop, wrapLine = noop,
    getCurrentLine = function() return env.line end, getLineNumber = function() return 1 end,
    getLines = function() return {} end, getLineCount = function() return 1 end,
    getLastLineNumber = function() return 1 end, getTimestamp = function() return "" end,
    send = function(c) w.sent[#w.sent + 1] = c end,
    sendAll = function(...)
      for _, c in ipairs({...}) do if type(c) == "string" then w.sent[#w.sent + 1] = c end end
    end,
    sendGMCP = noop, sendSocket = noop, expandAlias = noop, denyCurrentSend = noop,
    printCmdLine = noop, clearCmdLine = noop,
    enableTrigger = noop, disableTrigger = noop, enableAlias = noop, disableAlias = noop,
    enableTimer = noop, disableTimer = noop, enableKey = noop, disableKey = noop,
    exists = function() return 1 end, isActive = function() return 1 end, setTriggerStayOpen = noop,
    getNetworkLatency = function() return 0.1 end, getEpoch = function() return w.now end,
    mudletOlderThan = function() return false end, getMudletVersion = function() return 4, 17, 0 end,
    getPackageInfo = function() return "66" end,
    display = noop, openUrl = noop, setConsoleBufferSize = noop, createLabel = noop, createBuffer = noop,
    isPrompt = function() return false end,
    lfs = { attributes = function() return nil end, mkdir = function() return true end },
    color_table = { red = {255, 0, 0}, white = {255, 255, 255} },
  }

  for _, n in ipairs(STDLIB) do env[n] = G[n] end
  -- Mudlet's print goes to the main window, so record it with the echoes
  env.print = function(...)
    local t = {}
    for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
    echo(table.concat(t, "\t"))
  end
  -- svof saves its settings under getMudletHomeDir(), which is the repo root
  -- here: reading is allowed, writing and deleting are refused and recorded
  w.writes = {}
  local function refuse(what)
    return function(path) w.writes[#w.writes + 1] = what .. " " .. tostring(path) return nil, "disabled in tests" end
  end
  env.io = extend(io, {
    open = function(path, mode)
      if mode and mode:find("[wa+]") then return refuse("write")(path) end
      return io.open(path, mode)
    end,
    -- io.write goes to whatever io.output last chose, and svof only ever
    -- chooses a file under getMudletHomeDir()
    output = refuse("output"), write = refuse("write"), close = function() return true end,
    popen = refuse("popen"),
  })
  env.os = extend(os, { remove = refuse("remove"), rename = refuse("rename"), execute = refuse("execute"),
    exit = refuse("exit") })
  env.string = extend(string, mudlet_string)
  env.table = extend(table, mudlet_table)
  env.unpack = G.unpack or table.unpack
  env.require = new_require()
  for k, v in pairs(mudlet) do env[k] = v end
  -- not logged in: no Char.Name, so loading does not run the login handlers
  env.gmcp = { Char = { Status = {}, Vitals = {}, Defences = {}, Afflictions = {}, Items = {} },
               Room = { Info = { exits = {} } } }
  env.matches, env.multimatches, env.line = {}, {}, ""
  -- svo_init_system checks Penlight is loaded before it starts
  env.package = package
  env._G = env
  setmetatable(env, { __index = function(_, k)
    w.unknown_globals[k] = (w.unknown_globals[k] or 0) + 1
    return nil
  end })

  -- svo_init_system runs the loaders in its own order, then systemstart,
  -- exactly as Mudlet's load event and a class change do
  env.svo = { me = { class = opts.class or "Infernal" } }
  for _, path in ipairs(world.SCRIPTS) do compile(sources[path], path, env)() end
  for _, l in ipairs(world.LOADERS) do compile(sources[l[1]], l[1], env)() end
  env.svo_init_system()
  local svo = env.svo
  assert(svo.systemloaded, "svo_init_system did not finish loading svof")
  svo.reset.bals()
  svo.conf.paused = opts.paused ~= false

  w.svo, w.env = svo, env

  -- Runs Lua the way a trigger or timer given a string would.
  function w.run(code, name)
    return compile(code, name or "code", env)()
  end

  -- Runs the timers due by now, in the order they would fire.
  function w.run_timers()
    while true do
      local due
      for _, t in pairs(w.timers) do
        if t.at <= w.now and (not due or t.at < due.at or (t.at == due.at and t.seq < due.seq)) then due = t end
      end
      if not due then return end
      w.timers[due.seq] = nil
      if type(due.f) == "string" then w.run(due.f, "timer") else due.f() end
    end
  end
  function w.advance(seconds) w.now = w.now + seconds w.run_timers() end

  -- A game line: the live temp triggers that match it exactly, as a
  -- substring or at its start run their code, in the order they were made.
  function w.line(text)
    env.line = text
    svo.paragraph_length = svo.paragraph_length + 1
    local ran = 0
    for _, t in ipairs(w.triggers) do
      local hit = not t.killed and ((t.kind == "exact" and t.pattern == text)
        or (t.kind == "substring" and text:find(t.pattern, 1, true))
        or (t.kind == "begin" and text:sub(1, #t.pattern) == t.pattern))
      if hit then
        ran = ran + 1
        if type(t.code) == "string" then w.run(t.code, "trigger") else t.code() end
      end
    end
    return ran
  end

  -- The prompt: lifevision settles the paragraph's claims, then the prompt
  -- queue runs and the gnomes are kicked (they send nothing while paused).
  function w.prompt()
    svo.send_in_the_gnomes()
    svo.paragraph_length = 0
  end

  -- GMCP, as Mudlet's event handlers hand it to svof's signals
  function w.gmcp_defence_add(name)
    env.gmcp.Char.Defences.Add = { name = name, desc = "" }
    svo.signals.gmcpchardefencesadd:emit()
  end
  function w.gmcp_defence_remove(name)
    env.gmcp.Char.Defences.Remove = { name }
    svo.signals.gmcpchardefencesremove:emit()
  end
  function w.gmcp_defence_list(names)
    local list = {}
    for i, name in ipairs(names) do list[i] = { name = name, desc = "" } end
    env.gmcp.Char.Defences.List = list
    svo.signals.gmcpchardefenceslist:emit()
  end

  function w.inflight()
    local t = {}
    for name in svo.actions:iter() do t[#t + 1] = name end
    table.sort(t)
    return table.concat(t, ", ")
  end

  return w
end

return world
