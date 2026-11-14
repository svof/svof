--[[
What every svo.dict entry does, worked out by running it, so a change that
rewrites an entry (a hand-written one made by basicaff or basicdef, a field
moved, a list derived) can be shown to leave its behaviour alone. The build
gates compare script text, so they flag every such rewrite and say nothing
about whether it still does the same thing. This says that.

It loads svof's real loaders for a class through tools/svof_world.lua, with
the default priorities and one fixed order for pairs(), time and chance,
and calls every function on every entry (isadvisable, oncompleted,
onstart, empty and the rest) in every state that decides what it does.
The state is made of inputs:

  affs.<name>      the affliction is tracked
  defc.<name>      the defence is up
  affsp, defup, keepup .<name>
                   that flag set
  bals.<name>=false
                   the balance is gone (every balance starts on)
  sys, conf, sk, me .<key>=true or false
                   a setting turned the other way; an unset key only where
                   svof sets it to true or false somewhere, or conf says it
                   is a boolean option
  stats.<key>=<n>  a vital at a tenth of its value (every vital starts at
                   3000)
  pipes.<herb>.<key>=0, rift.invcontents.<item>=0
                   a pipe or an item run out (every pipe starts lit with 10
                   puffs, every item at 10), or a pipe flag turned
  act.<action>     that action is in flight, such as act.weakness_herb
  doing.<name>     one of that entry's actions is in flight
  busy.<balance>   some other action is in flight on that balance
  gmcp.<name>, gmcpdef.<name>
                   GMCP reports that affliction or defence

Nothing is listed by hand: a function's inputs are the keys it reads. The
first call, with nothing flipped, reads some of them in some order, which
is one path through the function. Each input it read is then flipped in
turn, with the ones read before it as they were, which gives the next
paths, until every path has run once. From the paths comes one decision
diagram over the inputs in name order, with every test that doesn't change
the result left out. There is only one such diagram for a behaviour, so
two functions that do the same thing describe the same, whatever order
they check things in, and whatever they read and then ignore.

A call's result is everything it did: what it returned or the error it
raised, what it sent, every key it changed in the tables above and in svo,
svo.affl, svo.gaffl, svo.gdefc and the entries, the actions it put in
flight or took off, timers, temp triggers and handlers it made or killed,
raised events and signals, echoes, links, prompt-queue and lifevision
additions. Lists are sorted, apart from what it sent. Fields that are not
functions (eatcure, actions, customwait and so on) are described as they
are, apart from the priorities, which are default_prios' and not the
entry's.

svof's own machinery is called as one unit, and the call is part of the
result: rmaff, addaffdict and the rest of B.HELD, the signals' handlers,
and, for in-flight actions of other entries, the codepaste helpers. What
these read stays as it is rather than becoming an input. So a rewrite that
still calls svo.rmaff('weakness') where the original did is the same, and
one that clears affs.weakness itself instead is not.

A function that declares parameters is also described with each of the
arguments in B.ARGS, under its key with the arguments after it, such as
darkshade.aff.oncompleted(6000).

What it doesn't cover: numbers and strings beyond the flips above, such as
conf.curemethod (conconly here) or a count's level; arguments other than
those in B.ARGS, such as a limb name; the order of anything but sends; a table a
function walks without reading a key of it (pairs over svo.affs makes no
inputs); the timers, prompt-queue functions and signals a call leaves
behind, which are listed but not run; Mudlet, the game, and trigger items,
as tools/svof_world.lua says. A function that walks a table it also reads
keys of has every combination of its inputs tried instead, up to MAXDIMS
of them. One with more paths than MAXRUNS, or more inputs than MAXINPUTS,
is tried with each input flipped alone and each pair flipped, and says so
("partial").

  lua tools/dict_behaviour.lua --dump FILE [--class C]... [NAME]...
      write every entry's description, one per line, for each class
      (default: every class svof knows)
  lua tools/dict_behaviour.lua --show NAME [--class C]
      print one entry's descriptions: for each function, every way
      through it and its result
  lua tools/dict_behaviour.lua --against DIR [--class C]... [NAME]...
      compare the checkout at DIR (its src/) with this one, entry by
      entry, and print the states in which a function differs

tools/compare_dict_behaviour.py runs --against with a git revision instead
of a directory, for every class at once.
]]

local HERE = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "tools/"
local world = dofile(HERE .. "svof_world.lua")

local B = {}

-- A function with more paths than MAXRUNS, or more inputs than MAXINPUTS,
-- is tried with each input flipped alone and each pair flipped (each alone
-- past MAXPAIRS inputs), and says so ("partial"). One that walks a table
-- has every combination tried, up to MAXDIMS inputs.
B.MAXRUNS = 4096
B.MAXINPUTS = 40
B.MAXDIMS = 12
B.MAXPAIRS = 24

local unpack = unpack or table.unpack
local function pack(...) return { n = select("#", ...), ... } end
local G_next = next
-- raw, as Lua 5.1 iterates: 5.2+ honours a __pairs that Mudlet's 5.1 never
-- calls, and Penlight's maps have one
local function G_pairs(t) return G_next, t, nil end

local function sorted(list)
  table.sort(list, function(a, b) return tostring(a) < tostring(b) end)
  return list
end

local function sorted_keys(t)
  local r = {}
  for k in G_pairs(t) do r[#r + 1] = k end
  return sorted(r)
end

-- the bit for input i (1-based) of a combination
local function bit(mask, i)
  return math.floor(mask / 2 ^ (i - 1)) % 2 == 1
end

-- a string the same way under every Lua: %q writes a newline as a
-- backslash and a newline, and words control characters differently
local function quote(s)
  return '"' .. (tostring(s):gsub('[%c"\\]', function(c)
    if c == "\n" then return "\\n" end
    if c == "\r" then return "\\r" end
    if c == "\t" then return "\\t" end
    if c == '"' or c == "\\" then return "\\" .. c end
    return string.format("\\%03d", c:byte())
  end)) .. '"'
end

-- a table address, or a line in an error, changes from run to run
local function scrub(s)
  s = tostring(s):gsub("table: 0?x?%x+", "table"):gsub("function: 0?x?%x+", "function")
  -- "name:123: message", as error() prefixes it, minus the place
  s = s:gsub("^[^\n]-:%d+: ", "")
  -- Lua 5.1 says "attempt to index local 'x' (a nil value)" where 5.2+
  -- says "attempt to index a nil value (local 'x')"; both become
  -- "attempt to index a nil value"
  s = s:gsub("attempt to ([%a ]-) %a+ '[^']*' %(a (%a+) value%)", "attempt to %1 a %2 value")
  s = s:gsub("attempt to ([%a ]-) a (%a+) value %([^)]*%)", "attempt to %1 a %2 value")
  -- and names a for loop's iterator "(for generator)" where 5.4 says "for iterator"
  s = s:gsub("'%(for generator%)'", "'for iterator'")
  return s
end

-- ===== one instrumented svof =====

-- opts.class, opts.root, opts.patch: as for world.new
function B.new(opts)
  opts = opts or {}
  local w = world.new({ class = opts.class, root = opts.root, patch = opts.patch, priorities = true,
    repeatable = true })
  local svo, env = w.svo, w.env
  local I = { w = w, svo = svo, class = svo.me.class }

  local proxies = {}      -- proxy table -> info
  local touched = {}      -- the proxies written since the last reset
  local nested_read = {}  -- the nested tables under a key a call read
  local signals_touched = {}  -- the signals whose handlers a call changed
  local changed = {}      -- the proxies the call under test wrote
  local dims = {}         -- input name -> { apply = function }
  local tracing = false   -- reads make inputs only while a function runs
  local helper_depth = 0  -- inside a codepaste helper
  local held_depth = 0    -- inside svof's machinery: a signal or B.HELD
  local reads             -- the inputs read in this call
  local entry_name        -- the entry whose function runs
  local own_actions = {}  -- that entry's action names
  local reports = {}      -- what GMCP reports, by input name

  -- the action tables svo.dict holds, by table, for describing a value
  local action_of = {}
  local entry_of = {}
  local function index_dict()
    for name, e in G_pairs(svo.dict) do
      if type(e) == "table" then
        local raw = proxies[e] and proxies[e].shadow or e
        local isentry = false
        for _, sub in G_pairs(raw) do
          if type(sub) == "table" and sub.action_name == name then
            action_of[sub] = sub.name
            isentry = true
          end
        end
        if isentry then entry_of[e] = name end
      end
    end
  end
  index_dict()

  -- the action tables of an entry, by name, in name order
  local function actions_of(name)
    local e, r = svo.dict[name], {}
    if type(e) ~= "table" then return r end
    local raw = proxies[e] and proxies[e].shadow or e
    for _, sub in G_pairs(raw) do
      if type(sub) == "table" and sub.action_name == name and type(sub.name) == "string" then
        r[#r + 1] = sub
      end
    end
    table.sort(r, function(a, b) return a.name < b.name end)
    return r
  end
  I.actions_of = actions_of

  local function action_by_name(full)
    local name, bal = tostring(full):match("^(.-)_([%w]+)$")
    local e = name and svo.dict[name]
    local sub = type(e) == "table" and e[bal]
    if type(sub) == "table" and sub.name == full then return sub end
  end

  -- ----- values, the same way every time -----

  local function ser(v, depth)
    local t = type(v)
    if t == "string" then return quote(v) end
    if t == "number" then
      if v ~= v then return "nan" end
      if v == math.huge or v == -math.huge then return v > 0 and "inf" or "-inf" end
      if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
      return string.format("%.6g", v)
    end
    if t == "boolean" or t == "nil" then return tostring(v) end
    if t == "function" then return "fn" end
    if t ~= "table" then return t end
    if action_of[v] then return "@" .. action_of[v] end
    if entry_of[v] then return "@" .. entry_of[v] end
    depth = depth or 0
    if depth >= 3 then return "{..}" end
    local raw = proxies[v] and proxies[v].shadow or v
    local parts, n = {}, 0
    while raw[n + 1] ~= nil do
      n = n + 1
      parts[n] = ser(raw[n], depth + 1)
    end
    for _, k in ipairs(sorted_keys(raw)) do
      if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then
        parts[#parts + 1] = tostring(k) .. "=" .. ser(raw[k], depth + 1)
      end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  I.ser = ser

  -- ----- proxies: a table emptied into a shadow, so every read and write
  -- goes through the metatable -----

  -- kind: what a read of a key makes an input of, see on_read
  local function proxy(t, name, kind)
    if proxies[t] then return proxies[t] end
    local shadow = {}
    for k, v in G_pairs(t) do shadow[k] = v end
    for k in G_pairs(shadow) do rawset(t, k, nil) end
    local info = { t = t, name = name, kind = kind, shadow = shadow, base = {}, dirty = nil, before = nil,
                   oldmt = getmetatable(t) }
    for k, v in G_pairs(shadow) do info.base[k] = v end
    local mt = {}
    if info.oldmt then for k, v in G_pairs(info.oldmt) do mt[k] = v end end
    local oldindex = info.oldmt and info.oldmt.__index
    mt.__index = function(_, k)
      local v = shadow[k]
      if tracing then
        info.on_read(k, v)
        local list = info.nested and info.nested[k]
        if list and not list.read then
          list.read = true
          nested_read[#nested_read + 1] = list
        end
      end
      if v == nil and oldindex then
        if type(oldindex) == "function" then return oldindex(t, k) end
        return oldindex[k]
      end
      return v
    end
    -- a table that is only watched makes no inputs, so a read can go
    -- straight to the shadow, which is much quicker than a function: svof
    -- reads its action tables and svo itself all the time
    if kind == "watch" and not oldindex then mt.__index = shadow end
    -- dirty: written since the last reset; before: the value a key had
    -- before the call under test first wrote it
    mt.__newindex = function(_, k, v)
      if tracing then
        local b = info.before
        if not b then
          b = {}
          info.before = b
          changed[#changed + 1] = info
        end
        if b[k] == nil then b[k] = { shadow[k] } end
      end
      if not info.dirty then
        info.dirty = {}
        touched[#touched + 1] = info
      end
      info.dirty[k] = true
      shadow[k] = v
    end
    setmetatable(t, mt)
    proxies[t] = info
    info.on_read = function() end
    return info
  end

  -- svof's code is compiled in env, so its pairs and next can see through a
  -- proxy; Lua 5.1 has no __pairs
  local function shadow_of(t) local p = proxies[t] return p and p.shadow or t end
  -- and in one order, the one world.new's sorted_pairs uses everywhere else
  env.pairs = function(t)
    local p = proxies[t]
    if not p then return world.sorted_pairs(t) end
    return world.sorted_pairs(p.shadow)
  end
  -- the key after k in that order: next(t) is how svof asks whether a table
  -- is empty, and sometimes which entry is first
  env.next = function(t, k)
    local raw = shadow_of(t)
    local keys = world.sorted_keys(raw)
    local i = 1
    if k ~= nil then
      while keys[i] ~= nil and keys[i] ~= k do i = i + 1 end
      i = i + 1
    end
    local key = keys[i]
    if key == nil then return nil end
    return key, raw[key]
  end
  local tbl = {}
  for k, v in G_pairs(env.table) do tbl[k] = v end
  for _, f in ipairs({ "size", "is_empty", "contains", "index_of", "n_complement" }) do
    local orig = env.table[f]
    if orig then tbl[f] = function(t, ...) return orig(shadow_of(t), ...) end end
  end
  tbl.keys = function(t)
    local r = {}
    for k in G_pairs(shadow_of(t)) do r[#r + 1] = k end
    table.sort(r, world.key_less)
    return r
  end
  env.table = tbl

  -- ----- the inputs -----

  -- every key svof's sources set to a literal true or false
  local boolean_keys = {}
  local sources = world.tree_sources(opts.root or "")

  -- How many parameters a function declares, other than "_", read from the
  -- line it starts on: Lua 5.1 can't say. svof's loaders are compiled as
  -- "=<loader>" and its scripts as "=<path>", which name their sources.
  local source_lines = {}
  local function params_of(fn)
    local info = debug.getinfo(fn, "S")
    local name = info.source and info.source:match("^=(.*)$")
    local src = name and sources[name]
    if not src or not info.linedefined or info.linedefined < 1 then return 0 end
    local lines = source_lines[name]
    if not lines then
      lines = {}
      for l in (src .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = l end
      source_lines[name] = lines
    end
    local list = (lines[info.linedefined] or ""):match("function%s*[%w_.:]*%s*%(([^)]*)%)")
    local n = 0
    for p in (list or ""):gmatch("[^,%s]+") do if p ~= "_" then n = n + 1 end end
    return n
  end
  for _, src in G_pairs(sources) do
    for key in src:gmatch("([%a_][%w_]*)%s*=%s*true%f[^%w_]") do boolean_keys[key] = true end
    for key in src:gmatch("([%a_][%w_]*)%s*=%s*false%f[^%w_]") do boolean_keys[key] = true end
    for key in src:gmatch("%[['\"]([%a_][%w_]*)['\"]%]%s*=%s*true%f[^%w_]") do boolean_keys[key] = true end
    for key in src:gmatch("%[['\"]([%a_][%w_]*)['\"]%]%s*=%s*false%f[^%w_]") do boolean_keys[key] = true end
  end
  local function conf_boolean(k)
    local c = svo.config_dict and svo.config_dict[k]
    return type(c) == "table" and c.type == "boolean"
  end

  local function input(id, apply)
    if held_depth > 0 then return end
    if not dims[id] then dims[id] = { apply = apply } end
    -- reads: the inputs a call read, as a set and in the order it read them
    if reads and not reads[id] then
      reads[id] = true
      reads[#reads + 1] = id
    end
  end

  -- a true or false key turned the other way. A key not set is one only in
  -- a table of flags, or where svof sets that key to true or false: in sys,
  -- conf, sk and me an unset key is as often a timer or a table to come
  local function flag_input(info, prefix)
    local flags_only = B.FLAG_TABLES[prefix]
    return function(k, v)
      if type(k) ~= "string" or (v ~= nil and type(v) ~= "boolean") then return end
      local base = info.base[k]
      if base ~= nil and type(base) ~= "boolean" then return end
      if base == nil and not flags_only and not boolean_keys[k] and not (prefix == "conf" and conf_boolean(k)) then
        return
      end
      if B.EXCLUDE[prefix .. "." .. k] then return end
      -- named by the state it sets: a flag table's key set is its bare
      -- name, such as affs.weakness; anything else carries the value, such
      -- as bals.herb=false or conf.keepup=true
      local id = prefix .. "." .. k
      if base or not B.PRESENCE[prefix] then id = id .. "=" .. tostring(not base) end
      input(id, function() info.t[k] = not base end)
    end
  end

  -- also a number: to nought, or for a vital, to a tenth
  local function number_input(info, prefix, low)
    local flag = flag_input(info, prefix)
    return function(k, v)
      local base = info.base[k]
      if type(base) == "number" and type(k) == "string" then
        if base == 0 then return end
        if B.EXCLUDE[prefix .. "." .. k] then return end
        local id = prefix .. "." .. k .. "=" .. ser(low(base))
        input(id, function() info.t[k] = low(base) end)
      else
        flag(k, v)
      end
    end
  end

  local function in_flight(act)
    svo.actions:set(act.name, { p = act, timerid = 0,
      completed = function(other, arg) act[other or "oncompleted"](arg) end })
    local inuse = svo.bals_in_use
    inuse[act.balance] = inuse[act.balance] or {}
    inuse[act.balance][act.name] = act
    svo.actions_performed[act.action_name] = act
  end

  -- something else on a balance: an action no entry has
  local stand_ins = {}
  local function stand_in(balance)
    if not stand_ins[balance] then
      stand_ins[balance] = { name = "other_" .. balance, action_name = "other_" .. balance, balance = balance,
        oncompleted = function() end, onstart = function() end }
    end
    return stand_ins[balance]
  end

  local function act_input(full)
    local own = own_actions[full]
    if own then
      input("act." .. full, function() in_flight(own) end)
      return
    end
    local b = full:match("^other_(.+)$")
    if b then input("busy." .. b, function() in_flight(stand_in(b)) end) return end
    if helper_depth > 0 then return end
    local act = action_by_name(full)
    if act then input("act." .. full, function() in_flight(act) end) end
  end

  local function doing_input(name)
    if name == entry_name then
      for _, act in ipairs(actions_of(name)) do act_input(act.name) end
      return
    end
    local b = tostring(name):match("^other_(.+)$")
    if b then input("busy." .. b, function() in_flight(stand_in(b)) end) return end
    if helper_depth > 0 then return end
    local acts = actions_of(name)
    if #acts == 0 then return end
    -- one of its actions: the first in this order, else by name
    local pick
    for _, bal in ipairs(B.BALANCE_ORDER) do
      for _, act in ipairs(acts) do if not pick and act.balance == bal then pick = act end end
    end
    pick = pick or acts[1]
    input("doing." .. name, function() in_flight(pick) end)
  end

  -- An input another world found, made known here so a comparison can try
  -- it: -> whether this world has it. The tracked tables are in by_name.
  local by_name = {}
  function I.ensure(id)
    if dims[id] then return true end
    local kind, rest = id:match("^(%a+)%.(.+)$")
    if not kind then return false end
    if kind == "act" then
      local act = action_by_name(rest)
      if act then input(id, function() in_flight(act) end) end
    elseif kind == "busy" then
      input(id, function() in_flight(stand_in(rest)) end)
    elseif kind == "doing" then
      local was = entry_name
      entry_name = nil
      doing_input(rest)
      entry_name = was
    elseif kind == "gmcp" or kind == "gmcpdef" then
      input(id, function() reports[id] = true end)
    else
      local tname, key = id:gsub("=.*$", ""):match("^(.+)%.([^.]+)$")
      local info = by_name[tname]
      if info then info.on_read(key, info.shadow[key]) end
    end
    return dims[id] ~= nil
  end

  -- ----- the state every call starts from -----

  -- cures are possible: every pipe lit and full, every item in stock, vitals
  -- full, curing paused so nothing else svof does sends anything
  svo.conf.paused = true
  for i, herb in ipairs({ "elm", "valerian", "skullcap" }) do
    local p = svo.pipes[herb]
    p.id, p.lit, p.puffs, p.filledwith = i, true, 10, herb
  end
  for item in G_pairs(svo.rift.invcontents) do svo.rift.invcontents[item] = 10 end
  for _, v in ipairs({ "health", "mana", "endurance", "willpower" }) do
    svo.stats["max" .. v] = 3000
    svo.stats["current" .. v] = 3000
  end
  for k in G_pairs(svo.actions_performed) do svo.actions_performed[k] = nil end
  for k in G_pairs(svo.bals_in_use) do svo.bals_in_use[k] = nil end
  for _, k in ipairs(sorted({ unpack(svo.actions._keys) })) do svo.actions:set(k, nil) end

  -- GMCP's word on an affliction or a defence, as an input
  svo.gmcp_reports = function(aff)
    local id = "gmcp." .. tostring(aff)
    if tracing then input(id, function() reports[id] = true end) end
    return reports[id] or false
  end
  svo.gmcp_def_reports = function(def)
    local id = "gmcpdef." .. tostring(def)
    if tracing then input(id, function() reports[id] = true end) end
    return reports[id] or false
  end

  -- calls recorded as they happen
  local calls
  local function record(what) if calls then calls[#calls + 1] = what end end
  for _, f in ipairs({ "add", "addcust" }) do
    local orig = svo.lifevision[f]
    svo.lifevision[f] = function(...)
      local t = {}
      for i = 1, select("#", ...) do t[i] = ser((select(i, ...))) end
      record("lifevision." .. f .. "(" .. table.concat(t, ",") .. ")")
      return orig(...)
    end
  end
  for _, f in ipairs({ "onprompt_beforeaction_add", "onprompt_beforelifevision_add" }) do
    svo.sk[f] = function(name) record(f .. "(" .. ser(name) .. ")") end
  end

  -- the codepaste helpers, as units
  for _, k in ipairs(sorted_keys(svo.codepaste)) do
    local f = svo.codepaste[k]
    if type(f) == "function" then
      svo.codepaste[k] = function(...)
        helper_depth = helper_depth + 1
        local r = pack(pcall(f, ...))
        helper_depth = helper_depth - 1
        if not r[1] then error(r[2], 0) end
        return unpack(r, 2, r.n)
      end
    end
  end

  -- the signals, as svof's machinery: what their handlers read stays as it
  -- is, and which signal a call emits is part of its result
  local signal_name = {}
  for _, k in ipairs(sorted_keys(svo.signals)) do
    local sig = svo.signals[k]
    if type(sig) == "table" and not signal_name[sig] then signal_name[sig] = k end
  end
  do
    local any
    for sig in G_pairs(signal_name) do any = sig break end
    local Signal = getmetatable(any).__index
    for _, f in ipairs({ "emit", "emit_with_accumulator" }) do
      local orig = Signal[f]
      Signal[f] = function(self, ...)
        if tracing and held_depth == 0 then
          local a = {}
          local args = pack(...)
          for i = f == "emit" and 1 or 2, args.n do a[#a + 1] = ser(args[i]) end
          record("signal " .. tostring(signal_name[self] or "?") .. "(" .. table.concat(a, ",") .. ")")
        end
        held_depth = held_depth + 1
        local r = pack(pcall(orig, self, ...))
        held_depth = held_depth - 1
        if not r[1] then error(r[2], 0) end
        return unpack(r, 2, r.n)
      end
    end
    -- the signals whose handlers a call blocked, unblocked, connected or
    -- disconnected, to put back
    for _, f in ipairs({ "block", "unblock", "connect", "disconnect" }) do
      local orig = Signal[f]
      Signal[f] = function(self, ...)
        if tracing then signals_touched[self] = true end
        return orig(self, ...)
      end
    end
  end

  -- the calls whose own reads are held, as for a signal, and which are part
  -- of a call's result instead
  for _, path in ipairs(B.HELD) do
    local owner, key = svo, path
    local parent, child = path:match("^(.-)%.(.+)$")
    if parent then owner, key = svo[parent], child end
    local orig = owner[key]
    if type(orig) == "function" then
      owner[key] = function(...)
        if tracing and held_depth == 0 then
          local a = {}
          local args = pack(...)
          for i = 1, args.n do a[i] = ser(args[i]) end
          record(path .. "(" .. table.concat(a, ",") .. ")")
        end
        held_depth = held_depth + 1
        local r = pack(pcall(orig, ...))
        held_depth = held_depth - 1
        if not r[1] then error(r[2], 0) end
        return unpack(r, 2, r.n)
      end
    end
  end

  -- the tables whose keys are inputs, and what each read makes
  local mode = svo.defs.mode
  local tenth = function(v) return math.floor(v / 10) end
  local zero = function() return 0 end
  local function track(t, name, kind)
    local info = proxy(t, name, kind)
    if kind == "flag" then info.on_read = flag_input(info, name)
    elseif kind == "low" then info.on_read = number_input(info, name, tenth)
    elseif kind == "zero" then info.on_read = number_input(info, name, zero)
    end
    return info
  end
  local affs = track(svo.affs, "affs", "aff")
  affs.on_read = function(k)
    if type(k) ~= "string" then return end
    local e = svo.dict[k]
    if type(e) ~= "table" then return end
    input("affs." .. k, function()
      svo.affs[k] = { p = e, sw = 1 }
      local rec = { sw = 1 }
      if e.count ~= nil then rec.count = e.count end
      svo.affl[k] = rec
    end)
  end
  track(svo.defc, "defc", "flag")
  track(svo.bals, "bals", "flag")
  track(svo.sys, "sys", "flag")
  track(svo.conf, "conf", "flag")
  track(svo.sk, "sk", "flag")
  track(svo.me, "me", "flag")
  track(svo.affsp, "affsp", "flag")
  track(svo.stats, "stats", "low")
  track(svo.defdefup[mode], "defup", "flag")
  track(svo.defkeepup[mode], "keepup", "flag")
  for _, herb in ipairs({ "elm", "valerian", "skullcap" }) do track(svo.pipes[herb], "pipes." .. herb, "zero") end
  track(svo.rift.invcontents, "rift.invcontents", "zero")
  local performed = proxy(svo.actions_performed, "actions_performed", "performed")
  performed.on_read = function(k) doing_input(k) end
  local inuse = proxy(svo.bals_in_use, "bals_in_use", "inuse")
  inuse.on_read = function(k)
    if type(k) == "string" then input("busy." .. k, function() in_flight(stand_in(k)) end) end
  end
  local acts = proxy(svo.actions, "actions", "map")
  acts.on_read = function(k) if type(k) == "string" and k:find("_") then act_input(k) end end
  for _, info in G_pairs(proxies) do by_name[info.name] = info end
  -- written, not read: what a call changes in them is part of its result
  for _, t in ipairs({ { svo.affl, "affl" }, { svo.gaffl, "gaffl" }, { svo.gdefc, "gdefc" } }) do
    proxy(t[1], t[2], "watch")
  end
  -- every entry's own fields, such as a count, and its action tables',
  -- which a call to another entry's function can change, as a wait's
  -- customwait
  for _, name in ipairs(sorted_keys(svo.dict)) do
    local e = svo.dict[name]
    if entry_of[e] then
      for _, b in ipairs(sorted_keys(e)) do
        local sub = e[b]
        if type(sub) == "table" and action_of[sub] then proxy(sub, "dict." .. name .. "." .. b, "watch") end
      end
      proxy(e, "dict." .. name, "watch")
    end
  end
  proxy(svo, "svo", "watch")

  -- the tables inside these, up to three deep, such as sk's send queue,
  -- sk.warnings' warned flags and sk.priochangecache.special: put back as
  -- they were before a call that read the key they hang from. Every way to
  -- them is through that key, which the proxy sees.
  local kept = {}
  local function keep_nested(t, depth, into, path)
    for _, k in ipairs(sorted_keys(t)) do
      local v = t[k]
      if type(v) == "table" and not proxies[v] and not getmetatable(v) and not kept[v] then
        kept[v] = true
        local copy = {}
        for kk, vv in G_pairs(v) do copy[kk] = vv end
        local here = path .. "." .. tostring(k)
        into[#into + 1] = { t = v, copy = copy, path = here }
        if depth > 1 then keep_nested(v, depth - 1, into, here) end
      end
    end
  end
  for _, t in ipairs({ svo.sk, svo.sys, svo.conf, svo.me }) do
    local info = proxies[t]
    info.nested = {}
    for _, k in ipairs(sorted_keys(info.shadow)) do
      local v = info.shadow[k]
      if type(v) == "table" and not proxies[v] and not getmetatable(v) and not kept[v] then
        local list = {}
        kept[v] = true
        local copy = {}
        for kk, vv in G_pairs(v) do copy[kk] = vv end
        local path = info.name .. "." .. tostring(k)
        list[1] = { t = v, copy = copy, path = path }
        keep_nested(v, 2, list, path)
        info.nested[k] = list
      end
    end
  end
  -- every signal's blocked handlers, always, and the local state of their
  -- handlers, such as Setup's haddragonform, which an upvalue holds
  local signal_kept = {}
  local upvalues = {}
  for sig in G_pairs(signal_name) do
    local kept_sig = {}
    for _, q in ipairs({ "handlers_block", "handlers" }) do
      local t = rawget(sig, q)
      if type(t) == "table" then
        local copy = {}
        for kk, vv in G_pairs(t) do copy[kk] = vv end
        kept_sig[#kept_sig + 1] = { t = t, copy = copy }
        -- a queue keeps its entries one table further in
        for _, inner in ipairs({ "data", "data_position" }) do
          if type(rawget(t, inner)) == "table" then
            local c = {}
            for kk, vv in G_pairs(t[inner]) do c[kk] = vv end
            kept_sig[#kept_sig + 1] = { t = t[inner], copy = c }
          end
        end
      end
    end
    signal_kept[sig] = kept_sig
    for _, q in ipairs({ "handlers", "pre_emit_funcs", "post_emit_funcs" }) do
      local queue = rawget(sig, q)
      if type(queue) == "table" and type(queue.data) == "table" then
        for _, f in G_pairs(queue.data) do
          if type(f) == "function" then
            local i = 1
            while true do
              local uname, v = debug.getupvalue(f, i)
              if not uname then break end
              local tv = type(v)
              if tv == "boolean" or tv == "number" or tv == "string" or tv == "nil" then
                upvalues[#upvalues + 1] = { f = f, i = i, v = v }
              end
              i = i + 1
            end
          end
        end
      end
    end
  end

  -- an action's and an affliction's stopwatches
  local STOPWATCHES = { sw = true, actionwatch = true }

  -- the queues a call adds to, empty at the start of each
  local QUEUES = { "onpromptfuncs", "onpromptaifuncs" }

  -- timer ids from the same start in every call: svof keeps them, such as
  -- sys.blockoutr, and svof_world's count would carry on from call to call
  local timer_n = 0
  env.tempTimer = function(t, f)
    timer_n = timer_n + 1
    local id = 1000 + timer_n
    w.timers[id] = { at = w.now + t, f = f, seq = id }
    return id
  end
  env.killTimer = function(id) w.timers[id] = nil return true end
  -- the temp triggers and event handlers a call makes go again, and the
  -- ones it kills come back, so their ids are the same whatever ran before
  local base_triggers, base_handlers = #w.triggers, #w.handlers
  local kills = {}
  local function killer(list)
    return function(id)
      local t = list[id]
      if not t then return false end
      kills[#kills + 1] = { t, t.killed }
      t.killed = true
      if tracing then record("kill " .. ser(t.pattern or t.name)) end
      return true
    end
  end
  env.killTrigger = killer(w.triggers)
  env.killAnonymousEventHandler = killer(w.handlers)

  -- ----- one call -----

  local function reset()
    for _, info in ipairs(touched) do
      for k in G_pairs(info.dirty) do info.shadow[k] = info.base[k] end
      info.dirty = nil
    end
    touched = {}
    for _, info in ipairs(changed) do info.before = nil end
    changed = {}
    for k in G_pairs(svo.bals_in_use) do svo.bals_in_use[k] = nil end
    -- the OrderedMap's _keys went into the shadow with its entries
    local keys = acts.shadow._keys
    for i = #keys, 1, -1 do keys[i] = nil end
    for k in G_pairs(acts.shadow) do if k ~= "_keys" then acts.shadow[k] = nil end end
    for _, q in ipairs(QUEUES) do svo.sk[q] = {} end
    local l = svo.lifevision.l
    local lk = rawget(l, "_keys")
    for i = #lk, 1, -1 do rawset(l, lk[i], nil) lk[i] = nil end
    for k in G_pairs(reports) do reports[k] = nil end
    for k in G_pairs(w.timers) do w.timers[k] = nil end
    timer_n = 0
    local function restore(list)
      for _, n in ipairs(list) do
        local t, copy = n.t, n.copy
        for k in G_pairs(t) do if copy[k] == nil then rawset(t, k, nil) end end
        for k, v in G_pairs(copy) do if rawget(t, k) ~= v then rawset(t, k, v) end end
      end
    end
    for sig in G_pairs(signals_touched) do restore(signal_kept[sig]) end
    signals_touched = {}
    for _, list in ipairs(nested_read) do
      restore(list)
      list.read = nil
    end
    nested_read = {}
    for _, u in ipairs(upvalues) do
      local _, v = debug.getupvalue(u.f, u.i)
      if v ~= u.v then debug.setupvalue(u.f, u.i, u.v) end
    end
    for i = #w.triggers, base_triggers + 1, -1 do w.triggers[i] = nil end
    for i = #w.handlers, base_handlers + 1, -1 do w.handlers[i] = nil end
    for i = #kills, 1, -1 do kills[i][1].killed = kills[i][2] kills[i] = nil end
    w.sent, w.echoes, w.links, w.events = {}, {}, {}, {}
    w.writes = {}
    for k in G_pairs(w.unknown_globals) do w.unknown_globals[k] = nil end
  end
  I.reset = reset

  local function result(ok, ret)
    local parts = {}
    if ok then
      local r = {}
      for i = 1, ret.n do r[i] = ser(ret[i]) end
      parts[#parts + 1] = "return " .. table.concat(r, ",")
    else
      parts[#parts + 1] = "error " .. scrub(ret[1])
    end
    if #w.sent > 0 then parts[#parts + 1] = "send " .. table.concat(w.sent, " | ") end
    -- what changed, key by key, in name order
    local changes = {}
    table.sort(changed, function(a, b) return a.name < b.name end)
    for _, info in ipairs(changed) do
      -- an entry's stopwatch records that something ran, not what
      local skip = info.name:find("^dict%.") and STOPWATCHES or {}
      for _, k in ipairs(sorted_keys(info.before)) do
        local old, new = info.before[k][1], info.shadow[k]
        local name = info.name .. "." .. tostring(k)
        if skip[k] or info == performed or info == inuse then
          -- the last two follow from the actions in flight
        elseif info == acts then
          if (old == nil) ~= (new == nil) then
            changes[#changes + 1] = (new == nil and "-" or "+") .. "act." .. tostring(k)
          end
        elseif info.kind == "aff" or info.name == "affl" then
          if (old == nil) ~= (new == nil) then
            changes[#changes + 1] = (new == nil and "-" or "+") .. name
          elseif type(new) == "table" and info.name == "affl" and ser(old) ~= ser(new) then
            changes[#changes + 1] = name .. "=" .. ser(new)
          end
        elseif type(old) == "function" and type(new) == "function" then
          if old ~= new then changes[#changes + 1] = name .. "=new fn" end
        elseif old ~= new then
          changes[#changes + 1] = name .. "=" .. ser(new)
        end
      end
    end
    -- and what changed inside the nested tables it reached, such as a
    -- command it put on sk.sendqueue
    for _, list in ipairs(nested_read) do
      for _, n in ipairs(list) do
        local t, copy, differs = n.t, n.copy, false
        for k, v in G_pairs(t) do if copy[k] ~= v then differs = true break end end
        if not differs then for k in G_pairs(copy) do if rawget(t, k) == nil then differs = true break end end end
        if differs then changes[#changes + 1] = n.path .. "=" .. ser(t) end
      end
    end
    table.sort(changes)
    if #changes > 0 then parts[#parts + 1] = "set " .. table.concat(changes, " ") end
    local timers = {}
    for _, t in G_pairs(w.timers) do timers[#timers + 1] = ser(t.at - w.now) end
    if #timers > 0 then parts[#parts + 1] = "timers " .. table.concat(sorted(timers), " ") end
    local made = {}
    for i = base_triggers + 1, #w.triggers do
      local t = w.triggers[i]
      made[#made + 1] = t.kind .. " " .. ser(t.pattern) .. (t.killed and " killed" or "")
    end
    for i = base_handlers + 1, #w.handlers do
      made[#made + 1] = "handler " .. ser(w.handlers[i].name) .. (w.handlers[i].killed and " killed" or "")
    end
    if #made > 0 then parts[#parts + 1] = "made " .. table.concat(sorted(made), " ") end
    local events = {}
    for _, e in ipairs(w.events) do
      local a = {}
      for i, v in ipairs(e.args) do a[i] = ser(v) end
      events[#events + 1] = e.name .. "(" .. table.concat(a, ",") .. ")"
    end
    if #events > 0 then parts[#parts + 1] = "events " .. table.concat(sorted(events), " ") end
    local echoes = {}
    for _, e in ipairs(w.echoes) do echoes[#echoes + 1] = quote(scrub(e)) end
    if #echoes > 0 then parts[#parts + 1] = "echo " .. table.concat(sorted(echoes), " ") end
    local links = {}
    for _, e in ipairs(w.links) do links[#links + 1] = quote(scrub(e)) end
    if #links > 0 then parts[#parts + 1] = "link " .. table.concat(sorted(links), " ") end
    for _, q in ipairs(QUEUES) do
      local names = sorted_keys(svo.sk[q])
      if #names > 0 then parts[#parts + 1] = q .. " " .. table.concat(names, " ") end
    end
    if #calls > 0 then parts[#parts + 1] = "calls " .. table.concat(sorted(calls), " ") end
    return table.concat(parts, "; ")
  end

  -- calls fn with these inputs on: -> its result, and the inputs it read
  local function call(fn, on)
    reset()
    for _, id in ipairs(on) do dims[id].apply() end
    changed = {}
    reads, calls = {}, {}
    tracing = true
    local ret = { n = 0 }
    local ok = xpcall(function()
      local r = pack(fn())
      for i = 1, r.n do ret[i] = r[i] end
      ret.n = r.n
    end, function(e) ret[1] = e return e end)
    tracing = false
    helper_depth, held_depth = 0, 0
    local got = reads
    reads = nil
    local out = result(ok, ret)
    calls = nil
    return out, got
  end
  I.call = call

  -- ----- one function: every path through it -----

  -- A run reads some inputs, in some order, and gives a result: that is one
  -- path. The first run has nothing flipped. Each input a run reads after
  -- the ones it was given is then flipped in turn, with the inputs read
  -- before it as they were, which is another path, until every path has
  -- run once. Every combination of inputs takes exactly one of them, so a
  -- function that checks ten things in turn costs eleven runs, not 1,024.
  -- -> what I.diagram makes of the paths, or, past MAXRUNS paths, what
  -- I.explore_partial finds
  function I.explore(fn)
    local paths, seen, nseen = {}, {}, 0
    local stack = { { forced = {}, k = 0 } }
    while #stack > 0 do
      -- every path waiting is one more run at least, so past this the
      -- function can't be finished; one that can is never stopped
      if #paths + #stack > B.MAXRUNS then return I.explore_partial(fn, seen) end
      local item = table.remove(stack)
      local on, val = {}, {}
      for _, c in ipairs(item.forced) do
        val[c[1]] = c[2]
        if c[2] then on[#on + 1] = c[1] end
      end
      local out, got = call(fn, on)
      I.runs = (I.runs or 0) + 1
      local cond = {}
      for j, id in ipairs(got) do
        cond[j] = { id, val[id] or false }
        if not seen[id] then
          seen[id] = true
          nseen = nseen + 1
        end
      end
      if nseen > B.MAXINPUTS then return I.explore_partial(fn, seen) end
      -- the run must take the path it was sent down: the same inputs read
      -- first, in the same order. One that walks a table sees a flipped
      -- key before it reads it, such as an action in flight in
      -- svo.actions:iter(), and leaves the path; that function has every
      -- combination of its inputs tried instead
      for j = 1, item.k do
        if not cond[j] or cond[j][1] ~= item.forced[j][1] then return I.explore_all(fn) end
      end
      paths[#paths + 1] = { cond = cond, result = out }
      for j = #cond, item.k + 1, -1 do
        local forced = {}
        for i = 1, j - 1 do forced[i] = cond[i] end
        forced[j] = { cond[j][1], not cond[j][2] }
        stack[#stack + 1] = { forced = forced, k = j }
      end
    end
    return I.diagram(paths)
  end

  -- Every combination of the inputs a function reads, for one that walks a
  -- table: the inputs found so far are tried in every combination, and an
  -- input a combination finds joins them, up to MAXDIMS. Each combination
  -- is a path that tests every input, so the diagram is the same as the
  -- paths would give. -> I.diagram's description, or I.explore_partial's
  -- past MAXDIMS inputs
  function I.explore_all(fn)
    local list, known, results = {}, {}, {}
    local mask = 0
    while mask < 2 ^ #list do
      local on = {}
      for i = 1, #list do if bit(mask, i) then on[#on + 1] = list[i] end end
      local out, got = call(fn, on)
      I.runs = (I.runs or 0) + 1
      results[mask + 1] = out
      for _, id in ipairs(got) do
        if not known[id] then
          known[id] = true
          list[#list + 1] = id
        end
      end
      if #list > B.MAXDIMS then return I.explore_partial(fn, known) end
      mask = mask + 1
    end
    local full = {}
    for m = 0, 2 ^ #list - 1 do
      local cond = {}
      for i = 1, #list do cond[i] = { list[i], bit(m, i) } end
      full[m + 1] = { cond = cond, result = results[m + 1] }
    end
    return I.diagram(full)
  end

  -- Too many paths: the result with nothing flipped, with each input seen
  -- flipped alone, and with each pair flipped (each alone only, past
  -- MAXPAIRS inputs). Not a full description, and it says so.
  function I.explore_partial(fn, seen)
    local names = sorted_keys(seen)
    local prows = {}
    prows[""] = (call(fn, {}))
    for i = 1, #names do
      prows[names[i]] = (call(fn, { names[i] }))
      if #names <= B.MAXPAIRS then
        for j = i + 1, #names do prows[names[i] .. "+" .. names[j]] = (call(fn, { names[i], names[j] })) end
      end
    end
    return { inputs = names, partial = true, prows = prows }
  end

  -- The paths as one decision diagram over the inputs in name order, with
  -- every test that doesn't change the result left out and every repeated
  -- part shared. There is one such diagram for a given behaviour, so two
  -- functions that do the same thing describe the same, whatever order
  -- they check things in, and whatever they read and then ignore.
  -- -> { inputs = {names it tests}, nodes, root }: a node is { result } or
  -- { var = index into inputs, lo = node when off, hi = node when on }
  function I.diagram(paths)
    local vars, isvar = {}, {}
    for _, p in ipairs(paths) do
      for _, c in ipairs(p.cond) do
        if not isvar[c[1]] then isvar[c[1]] = true vars[#vars + 1] = c[1] end
      end
    end
    table.sort(vars)
    local rank = {}
    for i, v in ipairs(vars) do rank[v] = i end
    local tests = {}
    for i, p in ipairs(paths) do
      local t = {}
      for _, c in ipairs(p.cond) do t[rank[c[1]]] = c[2] end
      tests[i] = t
    end
    -- Each path is a chain of its own tests ending in its result, with U,
    -- a part no path covers yet, on every other branch. The chains are
    -- merged two at a time, so the parts stay small. Every node is made
    -- once and a test whose two branches are the same node is left out,
    -- which is what makes the diagram the only one for its behaviour.
    local nodes, unique = {}, {}
    local U = 0
    local function terminal(r)
      local key = "r" .. r
      if not unique[key] then
        nodes[#nodes + 1] = { result = r }
        unique[key] = #nodes
      end
      return unique[key]
    end
    local function node(v, lo, hi)
      if lo == hi then return lo end
      local key = v .. ":" .. lo .. ":" .. hi
      if not unique[key] then
        nodes[#nodes + 1] = { var = v, lo = lo, hi = hi }
        unique[key] = #nodes
      end
      return unique[key]
    end
    local function chain(i)
      local t, ranks = tests[i], {}
      for r in G_pairs(t) do ranks[#ranks + 1] = r end
      table.sort(ranks)
      local n = terminal(paths[i].result)
      for j = #ranks, 1, -1 do
        local v = ranks[j]
        if t[v] then n = node(v, U, n) else n = node(v, n, U) end
      end
      return n
    end
    local function union(a, b, memo)
      if a == U then return b end
      if b == U or a == b then return a end
      local key = a .. "," .. b
      if memo[key] then return memo[key] end
      local na, nb = nodes[a], nodes[b]
      if not na.var and not nb.var then
        error("explore: two paths overlap and give different results")
      end
      local v = na.var
      if not v or (nb.var and nb.var < v) then v = nb.var end
      local alo, ahi, blo, bhi = a, a, b, b
      if na.var == v then alo, ahi = na.lo, na.hi end
      if nb.var == v then blo, bhi = nb.lo, nb.hi end
      local r = node(v, union(alo, blo, memo), union(ahi, bhi, memo))
      memo[key] = r
      return r
    end
    local level = {}
    for i = 1, #paths do level[i] = chain(i) end
    while #level > 1 do
      local merged = {}
      for i = 1, #level, 2 do
        merged[#merged + 1] = level[i + 1] and union(level[i], level[i + 1], {}) or level[i]
      end
      level = merged
    end
    local root = level[1]
    -- only the inputs the diagram tests, renumbered
    local used, inputs, renum = {}, {}, {}
    local function mark(n)
      if n == U then error("explore: the paths don't cover every case") end
      local nd = nodes[n]
      if nd.var and not used[n] then
        used[n] = true
        renum[nd.var] = true
        mark(nd.lo)
        mark(nd.hi)
      end
    end
    mark(root)
    for i, v in ipairs(vars) do if renum[i] then inputs[#inputs + 1] = v renum[i] = #inputs end end
    local out = {}
    for i, nd in ipairs(nodes) do
      out[i] = nd.var and { var = renum[nd.var], lo = nd.lo, hi = nd.hi } or { result = nd.result }
    end
    return { inputs = inputs, nodes = out, root = root, paths = #paths }
  end

  -- an input's name in a line: a defence such as "boar tattoo" has a space
  local function iname(n) return (n:gsub(" ", "~")) end

  -- One line: the inputs, then the diagram's nodes, each "input?off:on",
  -- children before parents and the root last, where rK is the Kth result
  -- and nK the Kth node, then the results, sorted
  function I.line(d)
    local inputs = {}
    for i, n in ipairs(d.inputs) do inputs[i] = iname(n) end
    if d.partial then
      local keys = sorted_keys(d.prows)
      local parts = {}
      for _, k in ipairs(keys) do parts[#parts + 1] = (k == "" and "-" or iname(k)) .. " => " .. d.prows[k] end
      return "partial [" .. table.concat(inputs, " ") .. "] " .. table.concat(parts, " || ")
    end
    local results, rindex = {}, {}
    for _, nd in ipairs(d.nodes) do
      if nd.result and not rindex[nd.result] then rindex[nd.result] = true results[#results + 1] = nd.result end
    end
    table.sort(results)
    for i, r in ipairs(results) do rindex[r] = i end
    local num, order = {}, {}
    local function visit(n)
      if num[n] then return end
      local nd = d.nodes[n]
      if nd.result then num[n] = "r" .. rindex[nd.result] return end
      visit(nd.lo)
      visit(nd.hi)
      order[#order + 1] = nd.var .. "?" .. num[nd.lo] .. ":" .. num[nd.hi]
      num[n] = "n" .. #order
    end
    visit(d.root)
    local res = {}
    for i, r in ipairs(results) do res[i] = i .. ": " .. r end
    return "[" .. table.concat(inputs, " ") .. "] " .. (#order > 0 and table.concat(order, " ") or num[d.root]) ..
      " || " .. table.concat(res, " || ")
  end

  -- Every way through a diagram: -> list of { on = {inputs}, off = {inputs},
  -- result }, the inputs that way tests, and how
  function I.cubes(d)
    local out = {}
    local function walk(n, on, off)
      local nd = d.nodes[n]
      if nd.result then
        out[#out + 1] = { on = { unpack(on) }, off = { unpack(off) }, result = nd.result }
        return
      end
      local name = d.inputs[nd.var]
      off[#off + 1] = name
      walk(nd.lo, on, off)
      off[#off] = nil
      on[#on + 1] = name
      walk(nd.hi, on, off)
      on[#on] = nil
    end
    walk(d.root, {}, {})
    return out
  end

  -- ----- an entry -----

  -- fields that only record what happened at runtime, or say where the
  -- table sits, and the priorities, which are default_prios' and not the
  -- entry's: a place there moves whenever an action before it comes or goes
  local RUNTIME = { sw = true, actionwatch = true, name = true, balance = true, action_name = true,
    aspriority = true, spriority = true }

  -- whose functions run: which in-flight actions are its own
  function I.enter(name)
    entry_name = name
    own_actions = {}
    for _, act in ipairs(actions_of(name)) do own_actions[act.name] = act end
  end
  function I.leave()
    reset()
    entry_name, own_actions = nil, {}
  end

  -- the function a description's key names, such as "weakness.herb.empty"
  function I.fn(name, key)
    local e = svo.dict[name]
    if not entry_of[e] or key:sub(1, #name + 1) ~= name .. "." then return nil end
    local plain, label = key:match("^(.-)%((.*)%)$")
    if plain then
      local v = I.fn(name, plain)
      local args = v and B.args_by_label[label]
      if args then return function() return v(unpack(args)) end end
      return nil
    end
    local rest = key:sub(#name + 2)
    local b, field = rest:match("^([^.]+)%.(.+)$")
    local v
    if b then
      local sub = e[b]
      v = type(sub) == "table" and sub[field]
    else
      v = e[rest]
    end
    if type(v) == "function" then return v end
  end

  -- -> { [key] = description line }, keys such as "weakness.herb.isadvisable"
  -- for a function and "weakness.herb" for the fields that are not, and
  -- { [key] = what explore found } for the functions
  function I.describe(name, only)
    local e = svo.dict[name]
    if not entry_of[e] then return nil end
    local raw = proxies[e].shadow
    I.enter(name)
    local found = {}
    local subinfos = {}
    for _, b in ipairs(sorted_keys(raw)) do
      local sub = raw[b]
      if type(sub) == "table" and proxies[sub] and sub.action_name == name then
        subinfos[#subinfos + 1] = proxies[sub]
      end
    end
    local out = {}
    local function fns_and_fields(t, prefix)
      local fields = {}
      for _, k in ipairs(sorted_keys(t)) do
        local v = t[k]
        if type(v) == "function" then
          local key = prefix .. "." .. k
          if not only or only[key] then
            found[key] = I.explore(v)
            out[key] = I.line(found[key])
          end
          -- and with arguments, when it takes any
          local nparams = params_of(v)
          for _, args in ipairs(B.ARGS) do
            local vkey = key .. "(" .. args.label .. ")"
            if nparams >= args.n and (not only or only[vkey]) then
              found[vkey] = I.explore(function() return v(unpack(args)) end)
              out[vkey] = I.line(found[vkey])
            end
          end
        elseif not RUNTIME[k] and not (type(v) == "table" and v.action_name == name) then
          fields[#fields + 1] = k .. "=" .. ser(v)
        end
      end
      if not only or only[prefix] then out[prefix] = table.concat(fields, " ") end
    end
    fns_and_fields(raw, name)
    for _, info in ipairs(subinfos) do
      local b = info.name:match("%.([^.]+)$")
      fns_and_fields(info.shadow, name .. "." .. b)
    end
    I.leave()
    return out, found
  end

  -- every entry's name, in name order
  function I.entries()
    local r = {}
    for _, name in ipairs(sorted_keys(svo.dict)) do
      if entry_of[svo.dict[name]] then r[#r + 1] = name end
    end
    return r
  end

  return I
end

-- The arguments a function that declares parameters is also called with,
-- each its own description, keyed as "<key>(<label>)": numbers below, at
-- and above the vitals (3000), such as an oldhp or a count, a flag, and a
-- second argument for one that takes two (general_cure's dontkeep). n is
-- how many parameters it needs.
B.ARGS = {
  { label = "1", n = 1, 1 },
  { label = "3", n = 1, 3 },
  { label = "6000", n = 1, 6000 },
  { label = "true", n = 1, true },
  { label = "1,true", n = 2, 1, true },
}
B.args_by_label = {}
for _, a in ipairs(B.ARGS) do B.args_by_label[a.label] = a end

-- inputs that are never tried: svof stays paused, so nothing else it does
-- sends anything
B.EXCLUDE = {
  ["conf.paused"] = true,
}

-- svof's own machinery for tracking afflictions and defences: what it
-- reads (the GMCP gate, the afftimes echo, whether the defence is up
-- already, the priority changes a keepup change sets off) stays as it is,
-- and a call to it is part of the result, with its arguments, as is what
-- it changes
B.HELD = { "rmaff", "addaffdict", "addaff", "removeaff", "removeafflevel",
  "defences.got", "defences.lost", "defs.keepup", "defs.defup" }

-- the tables where every key is a flag, set or not, and those where a set
-- key is named bare (a balance that is gone is bals.herb=false)
B.FLAG_TABLES = { affs = true, defc = true, bals = true, affsp = true, defup = true, keepup = true }
B.PRESENCE = { defc = true, affsp = true, defup = true, keepup = true }

-- which action stands for "one of that entry's actions is in flight"
B.BALANCE_ORDER = { "physical", "misc", "herb", "salve", "smoke", "sip", "purgative", "focus", "moss",
  "waitingfor", "aff", "gone" }

-- every class svof knows, as the game names it, as tools/defence_catalog.lua
-- loads them
function B.classes()
  local w = world.new({ class = "Infernal" })
  local r = {}
  for class in pairs(w.svo.knownskills) do
    r[#r + 1] = (class:gsub("(%a)(%a*)", function(a, b) return a:upper() .. b end))
  end
  table.sort(r)
  return r
end

-- a set of states in words: "when a, b; not c", where a and b are inputs
-- set and c one as it starts, and an input not named can be either
function B.when(on, off)
  local parts = {}
  if #on > 0 then parts[#parts + 1] = table.concat(on, ", ") end
  if #off > 0 then parts[#parts + 1] = "not " .. table.concat(off, ", ") end
  return #parts > 0 and ("when " .. table.concat(parts, "; ")) or "always"
end

-- ===== the command line =====

local function main(argv)
  local mode, target, classes, names = nil, nil, {}, {}
  local i = 1
  while i <= #argv do
    local a = argv[i]
    if a == "--dump" or a == "--show" or a == "--against" then
      mode, target = a:sub(3), argv[i + 1]
      i = i + 2
    elseif a == "--class" then
      classes[#classes + 1] = argv[i + 1]
      i = i + 2
    else
      names[#names + 1] = a
      i = i + 1
    end
  end
  if not mode or not target then
    io.stderr:write("usage: lua tools/dict_behaviour.lua --dump FILE | --show NAME | --against DIR [--class C]... [NAME]...\n")
    os.exit(2)
  end
  if #classes == 0 then classes = mode == "show" and { "Infernal" } or B.classes() end

  if mode == "dump" then
    local f = assert(io.open(target, "w"))
    local count = 0
    for _, class in ipairs(classes) do
      local I = B.new({ class = class })
      for _, name in ipairs(#names > 0 and names or I.entries()) do
        local d = I.describe(name)
        if d then
          for _, key in ipairs(sorted_keys(d)) do
            f:write(class, "\t", key, "\t", d[key], "\n")
            count = count + 1
          end
        end
      end
      io.stderr:write(string.format("%s: %d entries\n", class, #I.entries()))
    end
    f:close()
    print(string.format("wrote %d descriptions for %d classes to %s", count, #classes, target))
  elseif mode == "show" then
    local I = B.new({ class = classes[1] })
    local d, found = I.describe(target)
    if not d then print("no entry " .. target) os.exit(1) end
    for _, key in ipairs(sorted_keys(d)) do
      print(key)
      local f = found[key]
      if f and not f.partial then
        print(string.format("  inputs: %s (%d paths)", #f.inputs > 0 and table.concat(f.inputs, " ") or "none", f.paths))
        for _, c in ipairs(I.cubes(f)) do
          print("    " .. B.when(c.on, c.off) .. " =>")
          print("      " .. c.result)
        end
      else
        print("  " .. d[key])
      end
    end
  elseif mode == "against" then
    os.exit(B.against(target, classes, names) and 0 or 1)
  end
end

-- Where two diagrams give different results: -> list of { on, off, was,
-- now }, each a set of states, by the inputs it fixes on and off (any
-- input not named can be either), at most limit of them
function B.diff(da, db, limit)
  local out = {}
  local function walk(a, b, on, off)
    if #out >= limit then return end
    local na, nb = da.nodes[a], db.nodes[b]
    if na.result and nb.result then
      if na.result ~= nb.result then
        out[#out + 1] = { on = { unpack(on) }, off = { unpack(off) }, was = na.result, now = nb.result }
      end
      return
    end
    local va = na.var and da.inputs[na.var]
    local vb = nb.var and db.inputs[nb.var]
    local v = va
    if not v or (vb and vb < v) then v = vb end
    local alo, ahi, blo, bhi = a, a, b, b
    if va == v then alo, ahi = na.lo, na.hi end
    if vb == v then blo, bhi = nb.lo, nb.hi end
    off[#off + 1] = v
    walk(alo, blo, on, off)
    off[#off] = nil
    on[#on + 1] = v
    walk(ahi, bhi, on, off)
    on[#on] = nil
  end
  walk(da.root, db.root, {}, {})
  return out
end

-- One entry in two instrumented svofs, such as before and after a rewrite:
-- -> nil when either lacks it, else a list with one item per key that
-- differs, { key, was, now, states }, and how many keys there are. For a
-- function both describe in full, states lists where the two differ, as
-- B.diff gives it; it is nil for a field, or a function either describes
-- only in part, where was and now are the two lines.
function B.compare(A, Bw, name)
  local a, fa = A.describe(name)
  local b, fb = Bw.describe(name)
  if not a or not b then return nil end
  local keys, seen = {}, {}
  for k in pairs(a) do seen[k] = true keys[#keys + 1] = k end
  for k in pairs(b) do if not seen[k] then keys[#keys + 1] = k end end
  table.sort(keys)
  local out = {}
  for _, key in ipairs(keys) do
    if a[key] ~= b[key] then
      local item = { key = key, was = a[key], now = b[key] }
      local da, db = fa[key], fb[key]
      if da and db and not da.partial and not db.partial then item.states = B.diff(da, db, 50) end
      out[#out + 1] = item
    end
  end
  return out, #keys
end

-- the checkout at root against this one, entry by entry: -> true when no
-- function differs
function B.against(root, classes, names)
  if not root:find("[/\\]$") then root = root .. "/" end
  local same, differ, gone, new = 0, 0, 0, 0
  for _, class in ipairs(classes) do
    local old = B.new({ class = class, root = root })
    local cur = B.new({ class = class })
    local list, seen = {}, {}
    for _, n in ipairs(#names > 0 and names or old.entries()) do if not seen[n] then seen[n] = true list[#list + 1] = n end end
    for _, n in ipairs(#names > 0 and {} or cur.entries()) do if not seen[n] then seen[n] = true list[#list + 1] = n end end
    table.sort(list)
    local in_old, in_cur = {}, {}
    for _, n in ipairs(old.entries()) do in_old[n] = true end
    for _, n in ipairs(cur.entries()) do in_cur[n] = true end
    for _, name in ipairs(list) do
      if not in_old[name] and in_cur[name] then
        new = new + 1
        print(string.format("%s %s: new", class, name))
      elseif in_old[name] and not in_cur[name] then
        gone = gone + 1
        print(string.format("%s %s: gone", class, name))
      elseif in_old[name] then
        local items, n = B.compare(old, cur, name)
        same = same + n - #items
        for _, item in ipairs(items) do
          differ = differ + 1
          print(string.format("%s %s: differs", class, item.key))
          if item.states and #item.states > 0 then
            for i, s in ipairs(item.states) do
              if i > 20 then print(string.format("  ... and %d more", #item.states - 20)) break end
              print("  " .. B.when(s.on, s.off))
              print("    was: " .. s.was)
              print("    now: " .. s.now)
            end
          else
            print("  was: " .. tostring(item.was))
            print("  now: " .. tostring(item.now))
          end
        end
      end
    end
  end
  print(string.format("%d the same, %d differ, %d new entries, %d gone", same, differ, new, gone))
  return differ == 0 and gone == 0 and new == 0
end

-- run as a command, not loaded by a test such as test_dict_behaviour.lua
if arg and arg[0] and arg[0]:match("[^/\\]+$") == "dict_behaviour.lua" then
  main(arg)
end

return B
