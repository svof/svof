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
--               it. With no cure svof gives, the cure line ends it:
--               svo.valid.<name>_woreoff for a timed one, and
--               svo.valid.<name>_cured, its gone, for one only tracked
--   expire      svo.valid.<name>_woreoff, for a timed one, or with no timer
--               svo.valid.<name>_cured
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

-- The definitions to put into play, by name, saved under
-- <profile>/svo/custom/affs, which a package update leaves alone. Read at
-- the first systemstart and kept through a class change. A definition is
-- the spec afflictions.register takes, with what vcustomaff shows besides:
-- title, the game's name for it, and desc, its description
local custom_path = getMudletHomeDir() .. "/svo/custom/affs"

function afflictions.load()
  local t = {}
  if lfs.attributes(custom_path) then
    local ok, msg = pcall(table.load, custom_path, t)
    if not ok then
      svo.echof("<250,0,0>Couldn't%s read the afflictions you defined, in %s: %s", svo.getDefaultColor(), custom_path,
        tostring(msg))
      t = {}
    end
  end
  afflictions.custom = t
end

function afflictions.save()
  svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/custom")
  svo.tablesave(custom_path, afflictions.custom)
end

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

-- Why nothing would end spec's affliction, or nil. One with no cure of
-- svof's and no time ends on its cure or expire line, or on GMCP's Remove,
-- as 21 of the game's timed ones have no Default time (the capture,
-- 2026-10-21; the user, 2026-10-22), so it needs one of them, or svof
-- would track it for good
function afflictions.unending(spec)
  local cures = type(spec.cures) == 'table' and spec.cures or svo.affcures(spec.cures) or {}
  local timer = tonumber(spec.time) and tonumber(spec.time) > 0
  for _, cure in ipairs(cures) do
    if cure.kind ~= 'game' and cure.kind ~= 'time' then return nil end
  end
  if timer or spec.gmcp then return nil end
  for _, field in ipairs({ 'cured', 'curedpattern', 'expire' }) do
    if #lines(spec[field]) > 0 then return nil end
  end
  return "nothing would end it: with no cure of Svof's and no time, it needs a line it ends on or its GMCP name"
end

-- Registers an affliction from spec, after systemstart, or says why not.
-- spec is what svo.basicaff takes, and the lines (each one or a list; none
-- for a field the game says "none" for):
--   gain       the lines that afflict you with it
--   cured      the lines a cure of it prints
--   expire     the line a timed one ends on
--   diag       its DIAGNOSE line
--   gainpattern, curedpattern  patterns for gain and cure lines that vary,
--              as Mudlet's regex triggers take them
--   norandomcure  true when no tree, shrugging or other random cure takes it
function afflictions.register(name, spec)
  if afflictions.registered[name] then afflictions.unregister(name) end
  if type(spec) ~= 'table' then return false, "it has no definition" end
  -- the lines too, as install checks them: a class change or an update to
  -- Svof can bring a line a saved definition watches for, and one that
  -- clashes stays out, as a defined defence does
  local why = svo.dict[name] == nil and clash(name, spec) or afflictions.unending(spec)
    or afflictions.line_clash(name, spec)
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
  -- timed: with a timer, which basicaff makes only for a time it's given
  local timed, own_cure
  for _, cure in ipairs(cures) do
    if cure.kind == 'time' then
      timed = entry.waitingfor ~= nil
    elseif cure.kind ~= 'game' then
      own_cure = true
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
  -- the line it ends on with no timer to end: its gone
  local ended
  local function ends()
    if not ended then
      make(name .. '_cured', function()
        svo.checkaction(svo.dict[name].gone, true)
        if svo.actions[name .. '_gone'] then
          svo.lifevision.add(svo.actions[name .. '_gone'].p)
        end
      end)
      ended = string.format("svo.valid.%s_cured()", name)
    end
    return ended
  end
  -- With no cure of svof's, its cure line is the line it ends on: the game
  -- gives a Cured msg and no Expire msg for one only time cures, as for
  -- accentato and asphyxiating (the capture, 2026-10-20), and the game
  -- cures one svof only tracks, as icebound's Writhe (the user, 2026-10-22)
  if not own_cure and timed then
    cured_code[1] = string.format("svo.valid.%s_woreoff()", name)
  elseif not own_cure then
    cured_code[1] = ends()
  end
  local expired = timed and string.format("svo.valid.%s_woreoff()", name) or (#lines(spec.expire) > 0 and ends())
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
  local function pattern(p, code)
    ids[#ids + 1] = tempRegexTrigger(p, code)
  end
  local gained, cured = "svo.valid.simple" .. name .. "()", table.concat(cured_code, " ")
  for _, line in ipairs(lines(spec.gain)) do trigger(line, gained) end
  for _, p in ipairs(lines(spec.gainpattern)) do pattern(p, gained) end
  for _, line in ipairs(lines(spec.cured)) do trigger(line, cured) end
  for _, p in ipairs(lines(spec.curedpattern)) do pattern(p, cured) end
  -- its expire line ends its time, or, with no timer, it
  if expired then
    for _, line in ipairs(lines(spec.expire)) do trigger(line, expired) end
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

-- Defines name from spec and registers it, or says why not, and saves it.
-- A definition that doesn't register isn't kept.
function afflictions.define(name, spec)
  if not afflictions.custom then afflictions.load() end
  local ok, why = afflictions.register(name, spec)
  if not ok then return false, why end
  afflictions.custom[name] = spec
  afflictions.save()
  return true
end

function afflictions.undefine(name)
  if not afflictions.custom then afflictions.load() end
  afflictions.unregister(name)
  afflictions.custom[name] = nil
  afflictions.save()
end

-- ===== vcustomaff =====

-- vcustomaff, the commands for defining an affliction Svof doesn't know
-- (claude-notes/customaff-plan.md):
--   vcustomaff [list]                  list them, each a link to change it
--   vcustomaff game                    the game's afflictions Svof doesn't
--                                      know, from AFFLICTION LIST
--   vcustomaff <name>                  show one, starting it if new, filled
--                                      in from the game's AFFLICTION SHOW
--   vcustomaff <name> <field> <value>  set gmcp, cures, time, madness or
--                                      randomcure, or add a gain, cured,
--                                      expire or diag line
--   vcustomaff <name> gainpattern|curedpattern <pattern>
--   vcustomaff <name> line gain|cured|expire|diag  pick that line off the
--                                      screen
--   vcustomaff <name> fetch [game name]  fill it in from AFFLICTION SHOW
--   vcustomaff <name> test|install|delete
--   vcustomaff export [file], import <file>
-- Changes go to a draft, kept until Svof reloads; only install changes play.
-- The screens are vcustomdef's (svo.defences.ui).
local ui = svo.defences.ui
local link, label, unset_text, separator, line_list = ui.link, ui.label, ui.unset_text, ui.separator, ui.line_list
local pattern_matches = ui.pattern_matches

afflictions.drafts = afflictions.drafts or {}
-- GMCP names the game has confirmed this session, by AFFLICTION SHOW, and
-- the names it said it has no affliction for
afflictions.confirmed = afflictions.confirmed or {}
afflictions.unknown = afflictions.unknown or {}
-- words vcustomaff takes in place of a name
local reserved = { export = true, import = true, list = true, game = true, help = true }
-- the new definitions whose screen waits for the game's AFFLICTION SHOW, so
-- it's shown once, filled in
local show_waits = {}
local line_fields = { 'gain', 'cured', 'expire', 'diag', 'gainpattern', 'curedpattern' }
local line_labels = { gain = "gain", cured = "cure", expire = "expire", diag = "DIAGNOSE",
  gainpattern = "gain", curedpattern = "cure" }

local function copy(spec)
  local t = {}
  for k, v in pairs(spec) do t[k] = v end
  for _, k in ipairs(line_fields) do t[k] = line_list(spec[k]) end
  if type(spec.game) == 'table' then
    t.game = {}
    for k, v in pairs(spec.game) do t.game[k] = v end
  end
  return t
end

-- whether name is already svof's: an affliction, defence or action this
-- class has, a defence it has in another class, or one of its actions in
-- another class. One a definition registered is the player's
local function taken(name)
  if afflictions.registered[name] then return nil end
  if svo.dict[name] or svo.defs_data[name] then return "Svof already has " .. name end
  local defences = svo.defences
  if defences.catalog()[name] then return "Svof has a defence called " .. name .. " in other classes" end
  if defences.class_action(name) then return "Svof has its own " .. name .. " in other classes" end
end

-- whether the game knows gmcp as an affliction over GMCP: true, false, or
-- nil when svof can't tell without asking it. svof's own map is the game's
-- names, and AFFLICTION LIST shows every one, title-cased, as DEFENCE LIST
-- does the defences' (the user, 2026-10-20)
function afflictions.gmcp_known(gmcp)
  if svo.dict.sstosvoa[gmcp] ~= nil or (svo.gaffl and svo.gaffl[gmcp]) or afflictions.confirmed[gmcp] then
    return true
  end
  local list = afflictions.game_list
  if list and list.names[gmcp] then return true end
  if afflictions.unknown[gmcp] or (list and list.complete) then return false end
  return nil
end

-- Svof's own trigger patterns (tools/trigger_catalog.py), read once, when
-- first needed
local catalog
function afflictions.trigger_catalog()
  if catalog then return catalog end
  local path = afflictions.catalog_file or (svo.installationfolder() .. "/trigger_catalog.lua")
  local t, err = svo.read_data_file(path, "trigger_catalog")
  catalog = t or {}
  if t == nil then
    svo.echof("<250,0,0>Couldn't%s read Svof's list of its own trigger lines, in %s: %s", svo.getDefaultColor(),
      path, err)
  end
  return catalog
end

-- whether a catalog pattern of kind matches line
local function catalog_matches(kind, pattern, line)
  if kind == 'exact' then return line == pattern end
  if kind == 'sub' then return line:find(pattern, 1, true) ~= nil end
  if kind == 'start' then return line:sub(1, #pattern) == pattern end
  return pattern_matches(pattern, line)
end

-- whether a catalog condition, its patterns from first on, matches line:
-- one of them, or, marked all, each
local function catalog_cond(cond, first, line)
  for k = first, #cond do
    local hit = catalog_matches(cond[k][1], cond[k][2], line)
    if hit and not cond.all then return true end
    if not hit and cond.all then return false end
  end
  return cond.all and true or false
end

-- whether one of svof's triggers in the catalog matches line, a
-- definition's line of field: with need, only a line its parents' patterns
-- there match too, and, marked diag, only a line in DIAGNOSE's output
local function catalog_trigger(trig, line, field)
  if trig.diag and field ~= 'diag' then return false end
  if not catalog_cond(trig, 2, line) then return false end
  for _, cond in ipairs(trig.need or {}) do
    if not catalog_cond(cond, 1, line) then return false end
  end
  return true
end

-- Why spec's lines clash with a line svof or another definition watches
-- for, or nil. A clash makes one line count for two things, so nothing that
-- clashes goes into play, as for defences (the user, 2026-10-10): each line
-- against svof's triggers, its defences' lines and patterns and the other
-- definitions', and each pattern against their exact lines and its own
-- lines of another kind. Two patterns can't be checked against each other.
function afflictions.line_clash(name, spec)
  local mine, patterns = {}, {}
  for _, field in ipairs({ 'gain', 'cured', 'expire', 'diag' }) do
    for _, l in ipairs(line_list(spec[field])) do mine[#mine + 1] = { field, l } end
  end
  for _, field in ipairs({ 'gainpattern', 'curedpattern' }) do
    for _, p in ipairs(line_list(spec[field])) do patterns[#patterns + 1] = { field, p } end
  end
  -- within itself
  for i, a in ipairs(mine) do
    for j = i + 1, #mine do
      if a[2] == mine[j][2] and a[1] ~= mine[j][1] then
        return string.format("its %s line %q is its %s line too", line_labels[a[1]], a[2], line_labels[mine[j][1]])
      end
    end
    for _, p in ipairs(patterns) do
      if line_labels[p[1]] ~= line_labels[a[1]] and pattern_matches(p[2], a[2]) then
        return string.format("its %s pattern %q matches its own %s line %q", line_labels[p[1]], p[2],
          line_labels[a[1]], a[2])
      end
    end
  end
  -- svof's own triggers
  for _, folder in ipairs(afflictions.trigger_catalog()) do
    for i = 2, #folder do
      local trig = folder[i]
      for _, a in ipairs(mine) do
        if catalog_trigger(trig, a[2], a[1]) then
          return string.format("Svof's trigger %s / %s already watches for %q", folder[1], trig[1], a[2])
        end
      end
      for k = 2, #trig do
        local kind, pattern = trig[k][1], trig[k][2]
        -- a gain or cure pattern against an exact line the trigger takes
        -- as a whole, outside DIAGNOSE
        if kind == 'exact' and catalog_trigger(trig, pattern, 'gain') then
          for _, p in ipairs(patterns) do
            if pattern_matches(p[2], pattern) then
              return string.format("the pattern %q matches the line %q Svof's trigger %s / %s watches for", p[2],
                pattern, folder[1], trig[1])
            end
          end
        end
      end
    end
  end
  -- svof's defences, whose triggers are made from their records
  for def, rec in svo.defs_data:iter() do
    for _, field in ipairs({ 'on', 'off', 'def', 'on_only', 'on_free', 'off_free' }) do
      for _, theirs in ipairs(line_list(rec[field])) do
        for _, a in ipairs(mine) do
          if a[2] == theirs then return string.format("Svof's defence %s watches for %q", def, theirs) end
        end
        for _, p in ipairs(patterns) do
          if pattern_matches(p[2], theirs) then
            return string.format("the pattern %q matches Svof's defence %s's line %q", p[2], def, theirs)
          end
        end
      end
    end
    for _, field in ipairs({ 'onr', 'offr', 'defr' }) do
      for _, theirs in ipairs(line_list(rec[field])) do
        for _, a in ipairs(mine) do
          if pattern_matches(theirs, a[2]) then
            return string.format("Svof's defence %s's pattern %q matches %q", def, theirs, a[2])
          end
        end
      end
    end
    for _, sub in ipairs(line_list(rec.offs)) do
      for _, a in ipairs(mine) do
        if a[2]:find(sub, 1, true) then
          return string.format("Svof's defence %s watches for lines with %q in them", def, sub)
        end
      end
    end
  end
  -- the other definitions
  for other, theirs in pairs(afflictions.custom or {}) do
    if other ~= name then
      for _, field in ipairs({ 'gain', 'cured', 'expire', 'diag' }) do
        for _, l in ipairs(line_list(theirs[field])) do
          for _, a in ipairs(mine) do
            if a[2] == l then return string.format("your %s watches for %q too", other, l) end
          end
          for _, p in ipairs(patterns) do
            if pattern_matches(p[2], l) then
              return string.format("the pattern %q matches your %s's line %q", p[2], other, l)
            end
          end
        end
      end
      for _, field in ipairs({ 'gainpattern', 'curedpattern' }) do
        for _, p in ipairs(line_list(theirs[field])) do
          for _, a in ipairs(mine) do
            if pattern_matches(p, a[2]) then
              return string.format("your %s's pattern %q matches %q", other, p, a[2])
            end
          end
        end
      end
    end
  end
end

-- Why a defence's lines clash with a defined affliction's, or nil, for
-- defences.clash: the other half of line_clash's check of svof's defences,
-- so a defence defined or changed after an affliction can't take its line
-- either. lines are the defence's exact lines, subs the part-lines it
-- watches for and patterns its { field, pattern }s
function afflictions.defence_clash(lines, subs, patterns)
  local names = {}
  for name in pairs(afflictions.custom or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local spec = afflictions.custom[name]
    for _, field in ipairs({ 'gain', 'cured', 'expire', 'diag' }) do
      for _, theirs in ipairs(line_list(spec[field])) do
        for _, l in ipairs(lines) do
          if l == theirs then return string.format("your affliction %s watches for %q", name, l) end
        end
        for _, sub in ipairs(subs) do
          if theirs:find(sub, 1, true) then
            return string.format("your affliction %s's line %q has %q in it", name, theirs, sub)
          end
        end
        for _, p in ipairs(patterns) do
          if pattern_matches(p[2], theirs) then
            return string.format("the pattern %q matches your affliction %s's line %q", p[2], name, theirs)
          end
        end
      end
    end
    for _, field in ipairs({ 'gainpattern', 'curedpattern' }) do
      for _, p in ipairs(line_list(spec[field])) do
        for _, l in ipairs(lines) do
          if pattern_matches(p, l) then
            return string.format("your affliction %s's pattern %q matches %q", name, p, l)
          end
        end
      end
    end
  end
end

-- why a definition can't be installed, or nil
function afflictions.problem(name, spec)
  if not name:find("^%l[%l%d]*$") then return "a name is lower-case letters and digits, starting with a letter" end
  if reserved[name] then return name .. " is a command here, not a name" end
  local why = taken(name) or clash(name, spec)
  if why then return why end
  local cures
  cures, why = svo.affcures(spec.cures)
  if not cures then return why end
  why = afflictions.unending(spec)
  if why then return why end
  if #line_list(spec.gain) == 0 and #line_list(spec.gainpattern) == 0 and not spec.gmcp then
    return "it needs a line saying you have it, or its GMCP name, or Svof can't tell when you do"
  end
  if spec.gmcp then
    local known = afflictions.gmcp_known(spec.gmcp)
    if known == false then return "the game has no affliction called " .. spec.gmcp .. " over GMCP" end
    if known == nil then return "Svof couldn't check its GMCP name " .. spec.gmcp .. " with the game" end
  end
  for _, field in ipairs({ 'gainpattern', 'curedpattern' }) do
    for _, p in ipairs(line_list(spec[field])) do
      local bad = svo.defences.pattern_problem(p)
      if bad then return string.format("%s can't be a pattern: %s", p, bad) end
    end
  end
  return afflictions.line_clash(name, spec)
end

-- the draft of name, started from the installed one or new; nil and why
-- not when the name can't be a definition
local function draft(name)
  local d = afflictions.drafts[name]
  if d then return d end
  if not afflictions.custom then afflictions.load() end
  if afflictions.custom[name] then
    d = copy(afflictions.custom[name])
  else
    if not name:find("^%l[%l%d]*$") then
      return nil, "a name is lower-case letters and digits, starting with a letter"
    end
    if reserved[name] then return nil, name .. " is a command here, not a name" end
    local why = taken(name) or clash(name, {})
    if why then return nil, why end
    d = copy({})
    afflictions.drafts[name] = d
    -- if the game knows it by this name, the rest comes from the game
    afflictions.fetch(name, name)
    show_waits[name] = true
    return d
  end
  afflictions.drafts[name] = d
  return d
end

local function yes(v) return v and "yes" or "no" end

function afflictions.show(name)
  local d, why = draft(name)
  if not d then
    svo.echof("<250,0,0>Can't%s define %s: %s.", svo.getDefaultColor(), name, why)
    return
  end
  local waits = show_waits[name]
  show_waits[name] = nil
  if waits and afflictions.pending(name) then
    svo.echof("Asking the game about %s.", name)
    return
  end
  local installed = afflictions.custom[name]
  svo.echof("%s, an affliction you %s:", name, installed and "defined" or "are defining (not installed)")
  local cmd = "vcustomaff " .. name .. " "
  local function value(text, missing)
    if text then echo(text .. "  ") else unset_text(missing .. "  ") end
  end
  local function row(text_label, text, field, missing)
    label(text_label)
    value(text, missing)
    link("change", string.format("printCmdLine(%q)", cmd .. field .. " "), "Change " .. text_label)
    echo("\n")
  end
  if d.title then
    label("the game's:")
    echo(d.title .. "\n")
  end
  row("GMCP name:", d.gmcp, "gmcp", "(not set)")
  label("cures:")
  value(d.cures, "(not set)")
  link("change", string.format("printCmdLine(%q)", cmd .. "cures "), "As the game's Cure(s) says, such as Eat Kelp / Eat Aurum")
  echo("\n")
  local cures, cure_why = svo.affcures(d.cures)
  if d.cures and not cures then
    label("")
    setFgColor(255, 99, 71)
    echo(cure_why .. "\n")
    resetFormat()
  end
  local game, own = {}, false
  for _, cure in ipairs(cures or {}) do
    if cure.kind == 'game' then game[#game + 1] = cure[1] elseif cure.kind ~= 'time' then own = true end
  end
  if #game > 0 then
    label("")
    unset_text(string.format("Svof can't cure with %s, so %s\n", svo.concatand(game),
      own and "it leaves that to you" or "it only tracks it"))
  end
  local timed = false
  for _, cure in ipairs(cures or {}) do if cure.kind == 'time' then timed = true end end
  -- the game gives no Default time for some, which end on their line or GMCP
  if timed or d.time then
    row("lasts:", d.time and (d.time .. " seconds"), "time", "no time: its line or GMCP ends it")
  end
  label("random cures:")
  echo(d.norandomcure and "don't take it  " or "take it  ")
  link(d.norandomcure and "they do" or "they don't", string.format("svo.afflictions.set(%q, 'randomcure', %q)", name,
    d.norandomcure and "yes" or "no"), "Whether tree, shrugging and other random cures take it")
  echo("\n")
  label("madness:")
  echo(d.madness and "one of the madness afflictions  " or "not a madness affliction  ")
  link(d.madness and "it isn't" or "it is", string.format("svo.afflictions.set(%q, 'madness', %q)", name,
    d.madness and "no" or "yes"), "Whether it's one of the game's WhisperingMadness afflictions")
  echo("\n")
  local function lines_rows(field, verb, heading, capture)
    local l = line_list(d[field])
    for i, line in ipairs(l) do
      label(i == 1 and heading or "")
      echo(line .. "  ")
      link("x", string.format("svo.afflictions.unset(%q, %q, %d)", name, field, i), "Remove this line", 'remove')
      echo("\n")
    end
    label(#l == 0 and heading or "")
    if #l == 0 then unset_text("(no line)  ") end
    if capture then
      link("add a line from the screen", string.format("svo.afflictions.capture(%q, %q)", name, verb),
        "Pick the line from what's on screen")
      echo("  ")
    end
    link("type one", string.format("printCmdLine(%q)", cmd .. verb .. " "), "Type or paste the line")
    echo("\n")
  end
  local function pattern_rows(field, verb)
    for i, p in ipairs(line_list(d[field])) do
      label(i == 1 and "or matches:" or "")
      echo(p .. "  ")
      link("x", string.format("svo.afflictions.unset(%q, %q, %d)", name, field, i), "Remove this pattern", 'remove')
      echo("\n")
    end
    label("")
    link("add a pattern", string.format("printCmdLine(%q)", cmd .. verb .. " "),
      "For a line that varies: a pattern, as Mudlet's regex triggers take")
    echo("\n")
  end
  lines_rows('gain', 'gain', "gained when:", true)
  pattern_rows('gainpattern', 'gainpattern')
  lines_rows('cured', 'cured', "cured when:", true)
  pattern_rows('curedpattern', 'curedpattern')
  if timed then lines_rows('expire', 'expire', "wears off:", true) end
  lines_rows('diag', 'diag', "DIAGNOSE:", true)
  if d.desc then
    label("the game says:")
    unset_text(d.desc .. "\n")
  end
  separator()
  label("Actions:")
  link("get it from the game", string.format("svo.afflictions.fetch(%q, %q)", name, d.gmcp or name),
    "Ask the game with AFFLICTION SHOW")
  echo("  ")
  link("test", string.format("svo.afflictions.test(%q)", name), "Say what it would do")
  echo("  ")
  link("install", string.format("svo.afflictions.install(%q)", name), "Put it into play", 'go')
  echo("  ")
  link("delete", string.format("svo.afflictions.delete(%q)", name), "Take it out", 'remove')
  echo("\n")
end

function afflictions.set(name, field, value)
  local d, why = draft(name)
  if not d then
    svo.echof("<250,0,0>Can't%s define %s: %s.", svo.getDefaultColor(), name, why)
    return
  end
  value = value or ''
  if field == 'gmcp' then
    local gmcp = (value ~= '' and value:lower() ~= 'none') and value:lower() or nil
    local known = gmcp and afflictions.gmcp_known(gmcp)
    if known == false then
      svo.echof("The game has no affliction called %s over GMCP, so it can't be %s's GMCP name.", gmcp, name)
      return
    elseif gmcp and known == nil then
      svo.echof("Asking the game whether it knows an affliction called %s.", gmcp)
      afflictions.fetch(name, gmcp, 'gmcp')
      return
    end
    d.gmcp = gmcp
  elseif field == 'cures' then
    if value == '' then svo.echof("What cures %s? As the game's Cure(s) says, such as Eat Kelp / Eat Aurum.", name) return end
    d.cures = value
  elseif field == 'time' then
    local n = tonumber((value:match("^%s*(%d+)")))
    if not n or n <= 0 then svo.echof("How many seconds does %s last?", name) return end
    d.time = n
  elseif field == 'madness' then
    d.madness = svo.convert_string(value) and true or nil
  elseif field == 'randomcure' then
    d.norandomcure = (not svo.convert_string(value)) and true or nil
  elseif field == 'gain' or field == 'cured' or field == 'expire' or field == 'diag' then
    if value == '' then svo.echof("Which %s line?", line_labels[field]) return end
    d[field] = line_list(d[field])
    if not table.contains(d[field], value) then d[field][#d[field] + 1] = value end
  elseif field == 'gainpattern' or field == 'curedpattern' then
    if value == '' then svo.echof("Which pattern matches the %s line?", line_labels[field]) return end
    local bad = svo.defences.pattern_problem(value)
    if bad then svo.echof("Can't use %s as a pattern: %s.", value, bad) return end
    d[field] = line_list(d[field])
    if not table.contains(d[field], value) then d[field][#d[field] + 1] = value end
  else
    svo.echof("A definition has gmcp, cures, time, madness, randomcure, gain, cured, expire, diag, gainpattern and curedpattern; %s isn't one.", field)
    return
  end
  afflictions.show(name)
end

function afflictions.unset(name, field, i)
  local d = draft(name)
  if d and type(d[field]) == 'table' then table.remove(d[field], i) end
  afflictions.show(name)
end

-- shows the last lines on the screen, to click the one that says it
function afflictions.capture(name, which)
  if not (which == 'gain' or which == 'cured' or which == 'expire' or which == 'diag') then
    svo.echof("Pick a line for gain, cured, expire or diag.")
    return
  end
  local last = getLastLineNumber("main")
  local lines = getLines(math.max(0, last - 12), last)
  svo.echof("Click the %s line for %s:", line_labels[which], name)
  for _, l in ipairs(lines) do
    if l:find("%S") then
      echo("  ")
      link(l, string.format("svo.afflictions.set(%q, %q, %q)", name, which, l), "Use this line")
      echo("\n")
    end
  end
end

-- The game's own record of an affliction, AFFLICTION SHOW <name> (the
-- user's captures, 2026-10-20):
--   Affliction:         Addiction to curatives
--   Diagnose:           suffering from addiction.
--   Afflicted msg:      You feel a terrible hunger grow within you.
--   Cured msg:          Your terrible addiction seems to wane.
--   Cure(s):            Eat Ginseng / Eat Ferrum
--   Description:        Addiction causes you to slurp your elixirs and tonics
--   thirstily, using twice as many sips. ...
--   NoRandomCure:       No
--   WhisperingMadness:  Yes
--   Enlighten:          Yes
--   Tzantza:            Yes
--   Accentato:          Yes
--   CadmusCurse:        No
-- and for a timed one, Expire msg: before Cure(s): Time, and a last
-- Default time: 15 seconds. "none" is a message it doesn't have.
-- NoRandomCure: Yes means tree, shrugging, panacea and other random cures
-- don't take it, and WhisperingMadness: Yes that it's one of svof's madness
-- afflictions (the user, 2026-10-20). The reply ends at the prompt, as its
-- last label differs. For a name the game doesn't have, it says "There is
-- no such affliction." (the user, 2026-10-20).
-- The whole record, captured on muddlertest on 2026-10-20, shows two more
-- things. A second cure route is an entry of its own, on the next line,
-- indented to the values:
--   Cure(s):            Eat Lobelia / Eat Argentum
--                       Focus Mind
-- and 43 of the 203 titles don't start with the name, such as
-- grievouswounds' "Grievously wounded" and icebound's "Restricted by frozen
-- bonds", so a reply is the ask's whose turn it is (by_order)
local show_labels = { Diagnose = true, ["Afflicted msg"] = true, ["Cured msg"] = true, ["Expire msg"] = true,
  ["Cure(s)"] = true, Description = true, NoRandomCure = true, WhisperingMadness = true, Enlighten = true,
  Tzantza = true, Accentato = true, CadmusCurse = true, ["Default time"] = true }
local show_wraps = { Diagnose = true, ["Afflicted msg"] = true, ["Cured msg"] = true, ["Expire msg"] = true,
  ["Cure(s)"] = true, Description = true }

local function letters(s) return (tostring(s):lower():gsub("[^%l]", "")) end

-- whether the Affliction: line, the game's name for it, is about keyword:
-- "Addiction to curatives" for addiction, "Broken left arm" for
-- brokenleftarm. The start of a name answers, as for DEFENCE SHOW
local function show_answers(keyword, rest)
  local k = letters(keyword)
  return k ~= "" and letters(rest):sub(1, #k) == k
end

-- whether keyword is the game's name of the affliction titled title, its
-- first words run together, rather than the start of one
local function whole_words(keyword, title)
  local run = ""
  for word in tostring(title):lower():gmatch("%a+") do
    run = run .. word
    if run == keyword then return true end
  end
  return false
end

local function show_after(name)
  if afflictions.drafts[name] then afflictions.show(name) end
end

local function fill(name, asked, f, mode)
  local d = name and afflictions.drafts[name]
  if not (f and d) then return end
  local function value(field)
    local v = f[field] and f[field]:match("^%s*(.-)%s*$") or ""
    if v:lower() == 'none' then v = "" end
    return v
  end
  local mapped = svo.dict.sstosvoa[asked]
  if type(mapped) == 'string' and mapped ~= name then
    svo.echof("The game's %s is Svof's own %s, so there's no need to define it.", asked, mapped)
    return show_after(name)
  elseif mapped == false then
    svo.echof("Svof reads the game's %s another way on purpose, so it can't be defined.", asked)
    return show_after(name)
  end
  if whole_words(asked, f.Affliction) or afflictions.gmcp_known(asked) then
    afflictions.confirmed[asked] = true
    if mode == 'gmcp' or not d.gmcp then d.gmcp = asked end
  elseif mode == 'gmcp' then
    svo.echof("The game's %s is %s, so Svof can't take %s as its GMCP name. Use the game's name for it.", asked,
      tostring(f.Affliction), asked)
    return show_after(name)
  end
  if mode == 'gmcp' then return afflictions.show(name) end
  local function add(field, line)
    if line == '' then return end
    d[field] = line_list(d[field])
    if not table.contains(d[field], line) then d[field][#d[field] + 1] = line end
  end
  add('gain', value('Afflicted msg'))
  add('cured', value('Cured msg'))
  add('expire', value('Expire msg'))
  add('diag', value('Diagnose'))
  if value('Cure(s)') ~= '' and not d.cures then d.cures = value('Cure(s)') end
  local time = tonumber((value('Default time'):match("^(%d+)")))
  if time and not d.time then d.time = time end
  if d.norandomcure == nil and value('NoRandomCure') ~= '' then
    d.norandomcure = value('NoRandomCure'):lower() == 'yes' or nil
  end
  if d.madness == nil and value('WhisperingMadness') ~= '' then
    d.madness = value('WhisperingMadness'):lower() == 'yes' or nil
  end
  -- kept, not used (the user, 2026-10-20)
  d.game = { enlighten = value('Enlighten'), tzantza = value('Tzantza'), accentato = value('Accentato'),
    cadmuscurse = value('CadmusCurse') }
  if value('Affliction') ~= '' then d.title = value('Affliction') end
  if value('Description') ~= '' then d.desc = value('Description') end
  svo.echof("Filled in %s from the game's AFFLICTION SHOW %s.", name, asked)
  afflictions.show(name)
end

local show_reader = svo.gamereader.show{
  command = "affliction show",
  code = "svo.afflictions.show_line()",
  title = 'Affliction',
  label = "^(%a[%a%(%) ]-):%s+(.*)$",
  labels = show_labels,
  wraps = show_wraps,
  entries = { ["Cure(s)"] = " / " },
  answers = show_answers,
  by_order = true,
  none = "There is no such affliction.",
  reply = fill,
  none_reply = function (name, asked, mode)
    afflictions.unknown[asked] = true
    svo.gamereader.after_gag(function ()
      if mode == 'gmcp' then
        svo.echof("The game has no affliction called %s, so it can't be %s's GMCP name.", asked, tostring(name))
      else
        svo.echof("The game has no affliction called %s, so add its parts yourself.", asked)
        show_after(name)
      end
    end)
  end,
  timeout = function (defining, asked, mode)
    if mode == 'gmcp' then
      svo.echof("The game didn't answer about %s, so Svof can't take it as %s's GMCP name. Try again.", asked, defining)
    else
      svo.echof("The game didn't answer about an affliction called %s, so add its parts yourself.", asked)
      show_after(defining)
    end
  end,
}

-- mode 'gmcp' asks in order to set the GMCP name, which only the reply does
function afflictions.fetch(name, keyword, mode) show_reader.ask(name, keyword, mode) end
function afflictions.show_line() show_reader.line() end
function afflictions.pending(name) return show_reader.pending(name) end

-- AFFLICTION LIST, which reads the way DEFENCE LIST does (the user,
-- 2026-10-20): "All afflictions", a rule, then a name to a line, each the
-- affliction's GMCP name, title-cased, a page at a time, and MORE past its
-- end gets the line DEFENCE LIST's does
local list_end = 'An unseen presence whispers in your ear, "There is no more, friend."'
local function list_show(names)
  if #names == 0 then
    svo.echof("The game didn't send its list of afflictions.")
    return
  end
  local defined = {}
  for name, spec in pairs(afflictions.custom or {}) do
    defined[name] = true
    if type(spec.gmcp) == 'string' then defined[spec.gmcp] = true end
  end
  local unknown, renamed, ignored = {}, {}, {}
  for _, name in ipairs(names) do
    local mapped = svo.dict.sstosvoa[name]
    if defined[name] then
      -- (yours)
    elseif mapped == nil then
      unknown[#unknown + 1] = name
    elseif mapped == false then
      ignored[#ignored + 1] = name
    elseif mapped ~= name then
      renamed[#renamed + 1] = string.format("%s (%s)", name, mapped)
    end
  end
  local function plain(list)
    echo("  ")
    for i, text in ipairs(list) do
      echo(text)
      if i < #list then echo(i % 5 == 0 and ",\n  " or ", ") end
    end
    echo("\n")
  end
  if #unknown == 0 then
    svo.echof("Svof knows all %d afflictions the game lists, or you've defined them.", #names)
  else
    svo.echof("Of the %d afflictions the game lists, Svof doesn't know these %d. Click one to define it:", #names,
      #unknown)
    echo("  ")
    for i, name in ipairs(unknown) do
      link(name, string.format("svo.afflictions.show(%q)", name), "Define " .. name)
      if i < #unknown then echo(i % 6 == 0 and "\n  " or ", ") end
    end
    echo("\n")
  end
  if #renamed > 0 then
    svo.echof("Svof knows these under its own names, the game's first:")
    plain(renamed)
  end
  if #ignored > 0 then
    svo.echof("Svof reads these another way on purpose:")
    plain(ignored)
  end
end

local list_reader = svo.gamereader.list{
  command = "affliction list",
  code = "svo.afflictions.list_line()",
  first = "All afflictions",
  last_line = list_end,
  asking = "Asking the game for its list of afflictions.",
  got = function (names, complete)
    local set = {}
    for _, name in ipairs(names) do set[name] = true end
    afflictions.game_list = { names = set, complete = complete }
  end,
  show = list_show,
}

-- after, when given, runs once the list is read, instead of showing it
function afflictions.gamelist(after) list_reader.ask(after) end
function afflictions.list_line() list_reader.line() end

-- what test says it knows a line from
local function known_from(spec, field, patterns, gmcp)
  local parts = {}
  local n = #line_list(spec[field])
  if n > 0 then parts[#parts + 1] = string.format("%d line%s", n, n == 1 and "" or "s") end
  local p = patterns and #line_list(spec[patterns]) or 0
  if p > 0 then parts[#parts + 1] = string.format("%d pattern%s", p, p == 1 and "" or "s") end
  if gmcp then parts[#parts + 1] = gmcp end
  return #parts > 0 and svo.concatand(parts) or "nothing"
end

function afflictions.test(name)
  local d = afflictions.drafts[name] or (afflictions.custom and afflictions.custom[name])
  if not d then svo.echof("You haven't defined %s.", name) return end
  local cures, why = svo.affcures(d.cures)
  if cures then
    local t, game, untimed = {}, {}, false
    for _, cure in ipairs(cures) do
      if cure.kind == 'time' then
        if tonumber(d.time) and tonumber(d.time) > 0 then
          t[#t + 1] = string.format("waiting %s seconds", tostring(d.time))
        else
          untimed = true
        end
      elseif cure.kind == 'game' then
        game[#game + 1] = cure[1]
      elseif cure.kind == 'salve' then
        t[#t + 1] = string.format("applying %s%s", cure[1], cure.place and (" to " .. cure.place) or "")
      else
        t[#t + 1] = string.format("%s %s", ({ herb = "eating", smoke = "smoking", purgative = "sipping" })[cure.kind],
          cure[1])
      end
    end
    if #t > 0 then svo.echof("Svof cures %s by %s.", name, svo.concatand(t)) end
    if #game > 0 and #t > 0 then
      svo.echof("It's also cured by %s, which Svof can't do, so it leaves that to you.", svo.concatand(game))
    elseif #game > 0 then
      svo.echof("Svof only tracks %s: it's cured by %s, which Svof can't do.", name, svo.concatand(game))
    elseif #t == 0 and not untimed then
      svo.echof("Svof only tracks %s, as the game gives no cure for it.", name)
    end
    if untimed then
      svo.echof("Time cures it, and the game doesn't say how long, so its line or GMCP ends it, with no timer.")
    end
  else
    svo.echof("Svof can't cure %s yet: %s.", name, why)
  end
  svo.echof("It knows you have it from %s, and that it's cured from %s.",
    known_from(d, 'gain', 'gainpattern', d.gmcp and ("GMCP's " .. d.gmcp)),
    known_from(d, 'cured', 'curedpattern', d.gmcp and "GMCP"))
  svo.echof("Random cures %s it%s.", d.norandomcure and "don't take" or "take",
    d.madness and ", and it's one of the madness afflictions, whose cures wait while you have madness" or "")
  local problem = afflictions.problem(name, d)
  if problem then
    svo.echof("<250,0,0>It can't%s be installed yet: %s.", svo.getDefaultColor(), problem)
  else
    svo.echof("It's ready to install.")
  end
end

function afflictions.install(name)
  if not afflictions.custom then afflictions.load() end
  local d = afflictions.drafts[name] or (afflictions.custom[name] and copy(afflictions.custom[name]))
  if not d then svo.echof("You haven't defined %s.", name) return false end
  local problem = afflictions.problem(name, d)
  if problem then
    svo.echof("<250,0,0>Can't%s install %s: %s.", svo.getDefaultColor(), name, problem)
    return false
  end
  -- one you have stays had: unregister takes it off, and with no GMCP name
  -- nothing would put it back until its line came again
  local had = svo.affs[name] ~= nil
  afflictions.unregister(name)
  afflictions.custom[name] = d
  afflictions.drafts[name] = nil
  afflictions.save()
  if not svo.conf.customdefinitions then
    svo.echof("Saved %s. vconfig customdefinitions is off, so Svof doesn't add it.", name)
    return true
  end
  local ok, why = afflictions.register(name, d)
  if not ok then
    svo.echof("<250,0,0>Couldn't%s add %s: %s.", svo.getDefaultColor(), name, tostring(why))
    return false
  end
  if had then svo.addaffdict(svo.dict[name]) end
  svo.echof("Installed %s.", name)
  return true
end

function afflictions.delete(name)
  if not afflictions.custom then afflictions.load() end
  if not (afflictions.custom[name] or afflictions.drafts[name]) then
    svo.echof("You haven't defined %s.", name)
    return
  end
  afflictions.unregister(name)
  afflictions.custom[name] = nil
  afflictions.drafts[name] = nil
  afflictions.save()
  svo.echof("Deleted %s.", name)
end

function afflictions.export(path)
  if not afflictions.custom then afflictions.load() end
  path = (path and path ~= '') and path or (getMudletHomeDir() .. "/svo/custom/affs-export")
  local n = 0
  for _ in pairs(afflictions.custom) do n = n + 1 end
  svo.tablesave(path, afflictions.custom)
  svo.echof("Saved the %d affliction%s you defined to %s.", n, n == 1 and "" or "s", path)
end

local function import_from(t, path)
  local names = {}
  for name, spec in pairs(t) do
    if type(name) == 'string' and type(spec) == 'table' then names[#names + 1] = name end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    if afflictions.custom[name] then
      svo.echof("You already have %s, so the one in %s isn't used.", name, path)
    else
      local d = copy(t[name])
      d.gmcp = type(d.gmcp) == 'string' and d.gmcp:lower() or nil
      afflictions.drafts[name] = d
      if not afflictions.install(name) then afflictions.drafts[name] = nil end
    end
  end
end

function afflictions.import(path)
  if not afflictions.custom then afflictions.load() end
  if not path or path == '' or not lfs.attributes(path) then
    svo.echof("There's no file at %s.", tostring(path ~= '' and path or nil))
    return
  end
  local t = {}
  local ok, msg = pcall(table.load, path, t)
  if not ok then
    svo.echof("<250,0,0>Couldn't%s read %s: %s", svo.getDefaultColor(), path, tostring(msg))
    return
  end
  -- GMCP names the game hasn't confirmed this session are checked against
  -- its AFFLICTION LIST first
  for _, spec in pairs(t) do
    if type(spec) == 'table' and type(spec.gmcp) == 'string' and afflictions.gmcp_known(spec.gmcp:lower()) == nil then
      svo.echof("Checking the GMCP names in %s against the game's list of afflictions.", path)
      return afflictions.gamelist(function () import_from(t, path) end)
    end
  end
  import_from(t, path)
end

-- vcustomaff or vcustomaff list: every definition, a link to show and change
-- each
function afflictions.menu()
  if not afflictions.custom then afflictions.load() end
  local names, seen = {}, {}
  for name in pairs(afflictions.custom) do names[#names + 1] = name seen[name] = true end
  for name in pairs(afflictions.drafts) do if not seen[name] then names[#names + 1] = name end end
  table.sort(names)
  if #names == 0 then
    svo.echof("You haven't defined any afflictions.")
  else
    svo.echof("Afflictions you defined (click one to see or change it):")
    for _, name in ipairs(names) do
      local state = not afflictions.custom[name] and "not installed"
        or afflictions.drafts[name] and "changes not installed"
        or afflictions.registered[name] and "in use"
        or "installed, not in use"
      echo("  ")
      link(name, string.format("svo.afflictions.show(%q)", name), "See or change " .. name)
      echo(": " .. state .. "  ")
      link("test", string.format("svo.afflictions.test(%q)", name), "Say what it would do")
      echo("  ")
      link("delete", string.format("svo.afflictions.delete(%q)", name), "Take it out", 'remove')
      echo("\n")
    end
  end
  if svo.conf.customdefinitions then
    svo.echofn("Svof uses your definitions (vconfig customdefinitions is on). ")
    link("turn it off", 'svo.config.set("customdefinitions", false, true)',
      "Leave out your definitions and changes, from when Svof next loads", 'remove')
  else
    svo.echofn("Svof leaves out your definitions (vconfig customdefinitions is off). ")
    link("turn it on", 'svo.config.set("customdefinitions", true, true)',
      "Use your definitions and changes, from when Svof next loads", 'go')
  end
  echo("\n")
  echo("  ")
  link("define a new one", "printCmdLine('vcustomaff <name>')",
    "Put vcustomaff <name> on the command line: replace <name> with the game's name for it")
  echo("  ")
  link("see the game's afflictions Svof doesn't know", "svo.afflictions.gamelist()", "Compare with AFFLICTION LIST")
  echo("\n")
  afflictions.usage()
end

local forms = {
  { "<name>", "see one, or start it, filling it in from the game" },
  { "<name> gmcp|cures|time <value>", "set one of those" },
  { "<name> madness|randomcure yes|no", "whether it's a madness affliction, and whether random cures take it" },
  { "<name> gain|cured|expire|diag <line>", "add a line" },
  { "<name> gainpattern|curedpattern <pattern>", "add a pattern, for a line that varies" },
  { "<name> line gain|cured|expire|diag", "pick that line off the screen" },
  { "<name> fetch [game name]", "fill it in from the game's AFFLICTION SHOW" },
  { "<name> test|install|delete", "say what it would do, put it into play, or take it out" },
  { "game", "the game's afflictions Svof doesn't know" },
  { "export [file]|import <file>", "save your definitions to a file, or read them in" },
}
local placeholders = { ["<value>"] = true, ["yes|no"] = true, ["<line>"] = true, ["<pattern>"] = true,
  ["gain|cured|expire|diag"] = true, ["[game name]"] = true, ["[file]"] = true, ["<file>"] = true }

function afflictions.usage()
  svo.echof("vcustomaff takes (click one to put it on the command line):")
  for _, form in ipairs(forms) do
    echo("  ")
    link("vcustomaff " .. form[1], string.format("printCmdLine(%q)", "vcustomaff " .. form[1]), form[2])
    setFgColor(128, 128, 128)
    echo("  " .. form[2] .. "\n")
    resetFormat()
  end
end

-- what the vcustomaff alias passes on: everything after its name
function afflictions.command(rest)
  rest = (rest or ''):match("^%s*(.-)%s*$")
  local name, tail = rest:match("^(%S+)%s*(.-)$")
  if not name then return afflictions.menu() end
  name = name:lower()
  if name == 'list' then return afflictions.menu() end
  if name == 'help' then return afflictions.usage() end
  local verb, value = tail:match("^(%S*)%s*(.-)$")
  if name:find("^<") or verb:find("|", 1, true) or placeholders[verb] or placeholders[value] then
    svo.echof("Replace each <...> with what it stands for, and pick one of each a|b, such as vcustomaff bloodfire cures Eat Kelp.")
    return afflictions.usage()
  end
  if name == 'game' then return afflictions.gamelist() end
  if name == 'export' then return afflictions.export(tail) end
  if name == 'import' then return afflictions.import(tail) end
  verb = verb:lower()
  if verb == '' then return afflictions.show(name) end
  if verb == 'test' then return afflictions.test(name) end
  if verb == 'install' then return afflictions.install(name) end
  if verb == 'delete' then return afflictions.delete(name) end
  if verb == 'line' then return afflictions.capture(name, value:lower()) end
  if verb == 'fetch' then
    local d, why = draft(name)
    if not d then
      svo.echof("<250,0,0>Can't%s define %s: %s.", svo.getDefaultColor(), name, why)
      return
    end
    return afflictions.fetch(name, value ~= '' and value or d.gmcp or name)
  end
  return afflictions.set(name, verb, value)
end

-- after svof's own are all in, as a class change empties the dictionary.
-- vconfig customdefinitions off starts svof without them, as it does
-- without defined defences (the user, 2026-10-20)
signals.systemstart:connect(function ()
  if not afflictions.custom then afflictions.load() end
  if not svo.conf.customdefinitions then return end
  local names = {}
  for name in pairs(afflictions.custom) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local ok, why = afflictions.register(name, afflictions.custom[name])
    if not ok then
      svo.echof("Couldn't put your affliction %s into play: %s.", name, tostring(why))
    end
  end
end, 'register the afflictions a player defined')

end -- end of svo customaffs loader

if svo.systemloaded then svo.loader.customaffs() end
