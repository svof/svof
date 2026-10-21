-- Afflictions a player defines (vcustomaff), put into play the way svof's own
-- are: svo.basicaff builds the dictionary entry, and this wires the rest,
-- the parts svof's own afflictions get from their trigger items and from the
-- lists the loaders build at load.
--
-- svof's afflictions are recognised by static trigger items, so each line of
-- a defined one is a temp trigger, calling the handlers svof's own call:
--   gain        svo.valid.simple<name>
--   cure        the cure-line handler for each cure (svo.valid_cure_line),
--               then svo.valid.generic while svof reads cures it didn't
--               send (svo.generics_enabled), as its General cures folder
--               does, and svo.valid.tree_cured unless no random cure takes
--               it
--   expire      svo.valid.<name>_woreoff, for a timed one
--   diagnose    svo.valid.diag, while svof is diagnosing, as the svo diag
--               trigger's children are
-- A purgative cure has no cure-line handler, as svof's voyria has none: the
-- sip reads as empty, and GMCP decides.
--
-- svo.dict is emptied on a class change and the loaders run again, so every
-- definition (afflictions.defined, which outlives that) is registered again
-- at systemstart. svo_init_system runs this loader straight after the
-- defences one and before prio's, so a definition is registered before the
-- saved priorities are read, as a defined defence is.

svo = svo or {}; svo.loader = svo.loader or {}
svo.afflictions = svo.afflictions or {}
svo.loader.customaffs = function()

local afflictions = svo.afflictions
local sk, valid, empty, signals, sys = svo.sk, svo.valid, svo.empty, svo.signals, svo.sys

-- the definitions to put into play, by name: what afflictions.register was
-- given. Kept through a class change
afflictions.defined = afflictions.defined or {}

-- what registering made, by name: the spec, its temp triggers, the svo.valid
-- handlers and the list entries. The last class's triggers and handlers go
-- first, as svo.valid outlives a class change
for _, ids in pairs(afflictions.triggers_of or {}) do
  for _, id in ipairs(ids) do killTrigger(id) end
end
for _, keys in pairs(afflictions.handlers_of or {}) do
  for _, key in ipairs(keys) do valid[key] = nil end
end
afflictions.registered, afflictions.triggers_of = {}, {}
afflictions.handlers_of, afflictions.gmcp_held = {}, {}
-- by balance and item, the names of registered afflictions that cure takes
afflictions.cures = { herb = {}, smoke = {}, salve = {}, purgative = {} }

-- the actions of registered afflictions that balance's cure with item takes,
-- for the cure-line handlers (Main trigger functions)
function afflictions.cures_with(balance, item)
  local names = afflictions.cures[balance] and afflictions.cures[balance][item]
  if not names then return nil end
  local list = {}
  for name in pairs(names) do list[#list + 1] = name end
  table.sort(list)
  local acts = {}
  for _, name in ipairs(list) do
    local act = svo.dict[name] and svo.dict[name][balance]
    if act then acts[#acts + 1] = act end
  end
  return acts
end

-- the empty-cure handler a cure's action runs, as svo.basicaff picks it
local function empty_key(cure)
  if cure.kind == 'herb' then return 'eat_' .. cure[1] end
  if cure.kind == 'smoke' then return 'smoke_' .. cure[1] end
  if cure.kind == 'purgative' then return 'sip_' .. cure[1] end
  if cure.kind == 'salve' then
    local placed = cure.place and ('apply_' .. cure[1] .. '_' .. cure.place)
    if placed and empty[placed] then return placed end
    return 'apply_' .. cure[1]
  end
end

local function lines(v)
  if type(v) == 'string' then return { v } end
  local t = {}
  for _, l in ipairs(type(v) == 'table' and v or {}) do
    if type(l) == 'string' and l ~= '' and l:lower() ~= 'none' then t[#t + 1] = l end
  end
  return t
end

local function remove_value(list, value)
  for i = #list, 1, -1 do
    if list[i] == value then table.remove(list, i) end
  end
end

-- the commands a player types that are the action's, as the dictionary's
-- systemstart map makes them for svof's own, unless the map gives one to
-- another action
local function map_commands(act)
  local map = sys.input_to_actions
  if not map then return end
  local function put(command) if not map[command] then map[command] = act end end
  for _, item in ipairs(act.eatcure or {}) do put("eat " .. item) end
  for _, item in ipairs(act.smokecure or {}) do put("smoke " .. item) put("puff " .. item) end
  for _, item in ipairs(act.sipcure or {}) do put("sip " .. item) put("drink " .. item) end
  for _, command in ipairs(act.actions or {}) do put(command) end
end

-- Why name can't be registered with spec, or nil: a name or GMCP name
-- either of svof's two vocabularies already has
local function clash(name, spec)
  local known = svo.dict.sstosvoa[name]
  if type(known) == 'string' and known ~= name then
    return string.format("Svof knows the game's %s as its own %s", name, known)
  end
  local gmcp = spec.gmcp
  if gmcp then
    local mapped = svo.dict.sstosvoa[gmcp]
    if mapped == false then
      return string.format("Svof leaves GMCP's %s out on purpose", gmcp)
    elseif mapped and mapped ~= name then
      return string.format("GMCP's %s is already Svof's %s", gmcp, mapped)
    end
  end
end

-- Registers an affliction from spec, after systemstart, or says why not.
-- spec is what svo.basicaff takes, and the lines (each one or a list; none
-- for a field the game says "none" for):
--   gain       the lines that afflict you with it
--   cured      the lines a cure of it prints
--   expire     the line a timed one ends on
--   diag       its DIAGNOSE line
--   norandomcure  true when no tree, shrugging or other random cure takes it
function afflictions.register(name, spec)
  if afflictions.registered[name] then afflictions.unregister(name) end
  if type(spec) ~= 'table' then return false, "it has no definition" end
  local why = svo.dict[name] == nil and clash(name, spec)
  if why then return false, why end
  local ok
  ok, why = svo.basicaff(name, spec)
  if not ok then return false, why end
  local entry = svo.dict[name]
  local cures = svo.affcures(spec.cures)
  if type(spec.cures) == 'table' then cures = spec.cures end

  if spec.gmcp then
    afflictions.gmcp_held[name] = { gmcp = spec.gmcp, mapped = svo.dict.sstosvoa[spec.gmcp] }
    svo.dict.sstosvoa[spec.gmcp] = name
    svo.dict.svotossa[name] = spec.gmcp
  end

  -- its names and priority places, as for svof's own
  local before = sk.getbeforestateprios()
  svo.dict_setup()
  svo.dict_validate()
  sk.notifypriodiffs(before, sk.getafterstateprios())

  local handlers = {}
  local function make(key, f)
    valid[key] = f
    handlers[#handlers + 1] = key
  end
  make('simple' .. name, function(arg)
    svo.checkaction(svo.dict[name].aff, true)
    svo.lifevision.add(svo.actions[name .. '_aff'].p, nil, arg)
  end)

  local cured_code = {}
  local timed
  for _, cure in ipairs(cures) do
    if cure.kind == 'time' then
      timed = true
    else
      local items = afflictions.cures[cure.kind]
      items[cure[1]] = items[cure[1]] or {}
      items[cure[1]][name] = true
      local key = empty_key(cure)
      empty.defined[key] = empty.defined[key] or {}
      empty.defined[key][name] = true
      local handler = svo.valid_cure_line(cure.kind, name, cure[1])
      if handler then
        make(cure.kind .. '_cured_' .. name, handler)
        cured_code[#cured_code + 1] = string.format("svo.valid.%s_cured_%s()", cure.kind, name)
      end
      map_commands(entry[cure.kind])
    end
  end
  if timed then
    make(name .. '_woreoff', function()
      svo.checkaction(svo.dict[name].waitingfor, true)
      if svo.actions[name .. '_waitingfor'] then
        svo.lifevision.add(svo.actions[name .. '_waitingfor'].p)
      end
    end)
  end
  afflictions.handlers_of[name] = handlers

  if not spec.norandomcure then empty.treecurables[#empty.treecurables + 1] = name end
  if spec.madness then empty.madness_affs[#empty.madness_affs + 1] = name end

  cured_code[#cured_code + 1] = string.format("if svo.generics_enabled then svo.valid.generic(%q) end", name)
  if not spec.norandomcure then
    cured_code[#cured_code + 1] = string.format("svo.valid.tree_cured(%q)", name)
  end
  local ids = {}
  local function trigger(line, code)
    ids[#ids + 1] = tempExactMatchTrigger(line, code)
  end
  for _, line in ipairs(lines(spec.gain)) do trigger(line, "svo.valid.simple" .. name .. "()") end
  for _, line in ipairs(lines(spec.cured)) do trigger(line, table.concat(cured_code, " ")) end
  if timed then
    for _, line in ipairs(lines(spec.expire)) do trigger(line, "svo.valid." .. name .. "_woreoff()") end
  end
  for _, line in ipairs(lines(spec.diag)) do
    trigger(line, string.format("if svo.actions.diag_physical then svo.valid.diag(%q) end", name))
  end
  afflictions.triggers_of[name] = ids

  afflictions.registered[name] = spec
  return true
end

-- Takes out what afflictions.register put in: its triggers, handlers, list
-- entries, GMCP name, commands and entry, and the affliction if svof thought
-- you had it.
function afflictions.unregister(name)
  local spec = afflictions.registered[name]
  if not spec then return end
  for _, id in ipairs(afflictions.triggers_of[name] or {}) do killTrigger(id) end
  afflictions.triggers_of[name] = nil
  for _, key in ipairs(afflictions.handlers_of[name] or {}) do valid[key] = nil end
  afflictions.handlers_of[name] = nil
  for _, items in pairs(afflictions.cures) do
    for item, names in pairs(items) do
      names[name] = nil
      if not next(names) then items[item] = nil end
    end
  end
  for key, names in pairs(empty.defined) do
    names[name] = nil
    if not next(names) then empty.defined[key] = nil end
  end
  remove_value(empty.treecurables, name)
  remove_value(empty.madness_affs, name)
  local held = afflictions.gmcp_held[name]
  if held then
    svo.dict.sstosvoa[held.gmcp] = held.mapped
    svo.dict.svotossa[name] = nil
    afflictions.gmcp_held[name] = nil
  end

  if svo.affs[name] then svo.rmaff(name) end
  if type(svo.dict[name]) == 'table' then
    for _, act in pairs(svo.dict[name]) do
      if type(act) == 'table' and act.name then
        svo.killaction(act)
        for key, mapped in pairs(sys.input_to_actions or {}) do
          if mapped == act then sys.input_to_actions[key] = nil end
        end
      end
    end
  end
  local before = sk.getbeforestateprios()
  svo.dict[name] = nil
  svo.dict_setup()
  svo.dict_validate()
  sk.notifypriodiffs(before, sk.getafterstateprios())
  afflictions.registered[name] = nil
end

-- Defines name from spec and registers it, or says why not: what vcustomaff
-- installs. A definition that doesn't register isn't kept.
function afflictions.define(name, spec)
  local ok, why = afflictions.register(name, spec)
  if not ok then return false, why end
  afflictions.defined[name] = spec
  return true
end

function afflictions.undefine(name)
  afflictions.unregister(name)
  afflictions.defined[name] = nil
end

-- after svof's own are all in, as a class change empties the dictionary.
-- vconfig customdefinitions off starts svof without them, as it does
-- without defined defences (the user, 2026-10-20)
signals.systemstart:connect(function ()
  if not svo.conf.customdefinitions then return end
  local names = {}
  for name in pairs(afflictions.defined) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local ok, why = afflictions.register(name, afflictions.defined[name])
    if not ok then
      svo.echof("Couldn't put your affliction %s into play: %s.", name, tostring(why))
    end
  end
end, 'register the afflictions a player defined')

end -- end of svo customaffs loader

if svo.systemloaded then svo.loader.customaffs() end
