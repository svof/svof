-- Defences a player defines (vcustomdef), changes to svof's own, and copies
-- of svof's own from other classes, with the game readers (svo.gamereader)
-- and screen helpers (svo.defences.ui) Custom afflictions shares. They were
-- the second half of Defences.lua, and work on the records it keeps: this
-- loader runs straight after the defences one, and before the
-- customaffs and prio ones, so its systemstart handlers connect where they
-- did and a definition is registered before the saved priorities are read.

svo = svo or {}; svo.loader = svo.loader or {}
svo.loader.customdefs = function()

local sys, conf, sk, me, defs, defc = svo.sys, svo.conf, svo.sk, svo.me, svo.defs, svo.defc
local defences, defs_data, signals, lifevision = svo.defences, svo.defs_data, svo.signals, svo.lifevision

-- Defences the player defines (vcustomdef). They are saved under
-- <profile>/svo/custom/defs, which a package update leaves alone, and
-- registered again on every systemstart, as defs_data and svo.dict are both
-- made anew then, before the prio import, so a saved priority for one
-- applies. A definition is a table:
--   class        the class it belongs to, as the game names it, or 'all'
--                for one any class can have, such as an item's
--   skillset     for a class's, the group the defence lists show it in:
--                one of the class's skillsets, or a name the player gives
--                where svof's list of them is out of date (the user's
--                choice, 2026-10-10). One any class can have is general.
--   command      what svof sends to raise it
--   balanceless  true when raising it takes no balance
--   on, off      the exact lines saying you gained it and lost it
--   onr, offr, defr  patterns for gain, loss and DEF lines that vary, as
--                svof's own records have (the user, 2026-10-11), next to
--                the exact lines; only one Mudlet's rex library reads is
--                taken
--   def          the exact line DEF shows for it. Without one, each DEF
--                marks it gone, which test and install warn about
--   notondef     true for a defence DEF doesn't list, such as Pariah's
--                bloodiedknife, which DEF then leaves alone (svof's own
--                invisibledef)
--   gmcp         its name over GMCP, which is its serverside name as well.
--                With one, serverside raises it while serverside is on,
--                and svof does otherwise, unless vshow server leaves it to
--                svof; without one, only svof can (the user, 2026-10-10).
--                Only a name the game confirms is taken (the user,
--                2026-10-10): with a wrong one, svof would leave the
--                defence to serverside, which couldn't raise it either
--   copy         for a copy of svof's own defence from another class:
--                from, a class it was copied from; was, svof's version
--                then, to say when svof has updated it since; lines, the
--                other lines svof watches for, which a copy keeps as they
--                are
-- A name svof already uses is refused (vcustomdef with the name of one of
-- svof's own defences changes that instead, further down), and so is one
-- svof has in another class (defences.catalog), which can be copied in
-- instead, and one of svof's actions in another class that isn't a
-- defence (defences.class_action). A definition that clashes with this class's defences
-- (defences.clash), or fails to register, is reported and skipped.
-- vconfig customdefinitions off loads none, for a definition that has
-- broken curing.
local custom_path = getMudletHomeDir() .. "/svo/custom/defs"

function defences.custom_load()
  local t = {}
  if lfs.attributes(custom_path) then
    local ok, msg = pcall(table.load, custom_path, t)
    if not ok then
      svo.echof("<250,0,0>Couldn't%s read the defences you defined, in %s: %s", svo.getDefaultColor(), custom_path, tostring(msg))
      t = {}
    end
  end
  defences.custom = t
end

function defences.custom_save()
  svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/custom")
  svo.tablesave(custom_path, defences.custom)
end

-- whether svof already uses the name: a defence this class has, one an
-- item brings, or anything else in the dictionary, such as an affliction.
-- One a definition registered (defences.custom_registered) is the player's.
defences.custom_registered = defences.custom_registered or {}
-- what the GMCP names registered definitions took meant before
defences.gmcp_held = defences.gmcp_held or {}
local item_defences = { mindnet = true, lifevision = true, shroud = true }
function defences.custom_taken(name)
  if defences.custom_registered[name] then return false end
  return (defs_data[name] or svo.dict[name] or item_defences[name]) and true or false
end

-- a record's line or lines, as a new list
local function line_list(v)
  if type(v) == 'string' then return { v } end
  local t = {}
  if type(v) == 'table' then
    for i, l in ipairs(v) do t[i] = l end
  end
  return t
end

-- A lord and a lady of one element are one class: svo.knownskills lists
-- both, with the same skillset. A definition's class is the element's,
-- whichever the player is
local function class_key(class)
  class = tostring(class):lower()
  return class:match("^(%a+ elemental) lord$") or class:match("^(%a+ elemental) lady$") or class
end
defences.class_key = class_key

-- a class's skillsets, from svo.knownskills, or nil for a class svof
-- doesn't know
local function class_skills(class)
  local key = class_key(class)
  return svo.knownskills[key] or svo.knownskills[key .. " lord"]
end

local function class_title(class)
  if class == 'all' then return "every class" end
  return (class_key(class):gsub("(%a)(%a*)", function (a, b) return a:upper() .. b end))
end
defences.class_title = class_title -- for the hide list in Defences.lua

function defences.custom_applies(spec)
  return spec.class == 'all' or (type(spec.class) == 'string' and class_key(spec.class) == class_key(me.class))
end

-- vcustomdef's screens: links white, ones that take something out red,
-- and ones that put something into play green; labels in the colour of
-- svof's defence lists, and a part not set yet grey
local link_colours = { remove = { 255, 99, 71 }, go = { 0, 204, 0 } }
local function custom_link(text, code, hint, kind)
  local c = link_colours[kind] or { 255, 255, 255 }
  setUnderline(true)
  setFgColor(c[1], c[2], c[3])
  echoLink(text, code, hint, true)
  resetFormat()
end

local function custom_label(text)
  setFgColor(153, 204, 204)
  echo(string.format("  %-12s ", text))
  resetFormat()
end

local function custom_unset_text(text)
  setFgColor(128, 128, 128)
  echo(text)
  resetFormat()
end

-- a line between a list or screen and the links under it (the user's ask,
-- 2026-10-17)
local function custom_separator()
  custom_unset_text("  " .. string.rep("-", 70) .. "\n")
end

-- the screen helpers vcustomaff shares (Custom afflictions), and the hide
-- list in Defences.lua
defences.ui = { link = custom_link, label = custom_label, unset_text = custom_unset_text,
  separator = custom_separator, line_list = line_list }

-- Svof's own defences that only some classes have, with each class's
-- version: tools/defence_catalog.lua writes them, from every class, to
-- defence_catalog.lua in Svof's folder. Svof builds only the class it
-- loads, so this is how it knows a name is its own in another class. A
-- definition can't take such a name, and Svof's own can be copied in
-- instead (the user, 2026-10-10), for a class Svof's list is out of date
-- for, or a defence an artefact gives every class. Read once, when first
-- needed.
local catalog
function defences.catalog()
  if catalog then return catalog end
  local path = defences.catalog_file or (svo.installationfolder() .. "/defence_catalog.lua")
  local t, err = svo.read_data_file(path, "defence_catalog")
  catalog = t or {}
  if t == nil then
    svo.echof("<250,0,0>Couldn't%s read Svof's list of every class's defences, in %s: %s", svo.getDefaultColor(),
      path, err)
  end
  return catalog
end

-- Svof's own actions that only other classes have and that aren't
-- defences, such as fitness: the names in prio_catalog.lua (prio.catalog)
-- that this class doesn't have and defence_catalog.lua doesn't list, a
-- slow curing one by its name without its balance. A definition can't
-- take such a name. It would share the saved priority place Svof keeps
-- for its own (prio.kept), and clash with its own in a class that has it
local prio_names
function defences.class_action(name)
  if defences.custom_taken(name) or defences.catalog()[name] then return false end
  if not prio_names then
    prio_names = {}
    for balance, names in pairs(svo.prio.catalog()) do
      for action in pairs(names) do
        prio_names[balance == 'slowcuring' and action:match("^(.-)_%w+$") or action] = true
      end
    end
  end
  return prio_names[name] or false
end

local function class_action_problem(name)
  if defences.class_action(name) then
    return string.format("Svof has its own %s in other classes, and it isn't a defence, so give yours another name",
      name)
  end
end

-- the classes versions of a defence are for, as the game writes them, an
-- element's lord and lady as one
local function class_names(versions)
  local t, seen = {}, {}
  for _, v in ipairs(versions) do
    for _, c in ipairs(v.classes or {}) do
      local title = class_title(c)
      if not seen[title] then
        seen[title] = true
        t[#t + 1] = title
      end
    end
  end
  return svo.concatand(t)
end

-- whose a defence in this class is, for saying what a clash is with
local function whose(name)
  return (defences.custom_registered[name] and "your " or "Svof's ") .. name
end

-- the record fields that hold exact lines, and the ones that hold
-- patterns, for lines that vary
local exact_fields = { 'on', 'off', 'def', 'on_only', 'on_free', 'off_free' }
local pattern_fields = { 'onr', 'offr', 'defr' }
local kind_of = { on = "gain", off = "loss", def = "DEF", onr = "gain", offr = "loss", defr = "DEF" }

-- Mudlet's PCRE library, which tempRegexTrigger matches patterns with, or
-- nil where there's none
local function pcre()
  return rawget(_G, 'rex')
end

-- each pattern compiled once, since clash matches every pattern against
-- every line; false for one the library can't read
local compiled = setmetatable({}, { __mode = 'k' })

-- whether pattern matches line, by the library the trigger would use
local function pattern_matches(pattern, line)
  local rex = pcre()
  if not rex then return false end
  local byrex = compiled[rex]
  if not byrex then
    byrex = {}
    compiled[rex] = byrex
  end
  local re = byrex[pattern]
  if re == nil then
    local ok, made = pcall(rex.new, pattern)
    re = ok and made or false
    byrex[pattern] = re
  end
  if not re then return false end
  local ok, m = pcall(re.match, re, line)
  return ok and m ~= nil and m ~= false
end
defences.ui.pattern_matches = pattern_matches

-- why pattern can't be a definition's, or nil
function defences.pattern_problem(pattern)
  local rex = pcre()
  if not rex then return "Svof can't read patterns without Mudlet's rex library" end
  local ok, err = pcall(rex.new, pattern)
  if not ok then return "it isn't a pattern Svof can read (" .. tostring(err) .. ")" end
end

-- why one of spec's patterns can't be used, or nil, for those kept(field,
-- pattern) doesn't keep, such as svof's own. Such as ones a file brought
-- in, as typed ones are checked; svof can only check them where Mudlet's
-- rex library is
local function patterns_problem(spec, kept)
  if not pcre() then return end
  for _, field in ipairs(pattern_fields) do
    for _, p in ipairs(line_list(spec[field])) do
      local why = not (kept and kept(field, p)) and defences.pattern_problem(p)
      if why then return string.format("%s can't be a pattern: %s", p, why) end
    end
  end
end

-- Why a defence's lines, GMCP name or command clash with what this class
-- already has, or nil. A clash makes the game's word on one defence count
-- for another as well, so nothing that clashes goes into play (the user,
-- 2026-10-10). parts holds lines, every exact line the defence watches
-- for, and kinds, the same by kind (on, off, def); subs, the part-lines it
-- watches for (a record's offs); patterns, its patterns, each { field,
-- pattern } (onr, offr, defr); gmcp and command. Its lines are checked
-- against other defences' patterns, and its patterns against other
-- defences' lines and its own lines of another kind, by the library the
-- triggers match with. Two patterns can't be checked against each other.
-- For a change, lines and patterns are what it adds, which the other
-- defences are checked against, and selfpatterns all its patterns, which
-- kinds, all its lines, are
function defences.clash(name, parts)
  -- a pattern of one kind that matches its own line of another, so that
  -- the line would say both
  for _, p in ipairs(parts.selfpatterns or parts.patterns or {}) do
    for kind, lines in pairs(parts.kinds or {}) do
      if kind_of[kind] ~= kind_of[p[1]] then
        for _, line in ipairs(lines) do
          if pattern_matches(p[2], line) then
            return string.format("its %s pattern %q matches its own %s line %q", kind_of[p[1]], p[2], kind_of[kind], line)
          end
        end
      end
    end
  end
  local gmcp = parts.gmcp
  if gmcp then
    local mapped = svo.dict.sstosvod[gmcp]
    -- a registered definition's is mapped too. Saved ones that aren't
    -- aren't counted: as svof loads, two that share a name would each
    -- refuse the other, where this lets the first in
    if type(mapped) == 'string' and mapped ~= name then
      return string.format("GMCP's %s is already %s", gmcp, whose(mapped))
    end
  end
  local lines, subs = parts.lines or {}, parts.subs or {}
  for other, rec in defs_data:iter() do
    if other ~= name then
      for _, field in ipairs(exact_fields) do
        for _, theirs in ipairs(line_list(rec[field])) do
          for _, line in ipairs(lines) do
            if line == theirs then return string.format("%s already watches for %q", whose(other), line) end
          end
          for _, sub in ipairs(subs) do
            if theirs:find(sub, 1, true) then return string.format("%s's line %q has %q in it", whose(other), theirs, sub) end
          end
        end
      end
      for _, sub in ipairs(line_list(rec.offs)) do
        for _, line in ipairs(lines) do
          if line:find(sub, 1, true) then return string.format("%s already watches for lines with %q in them", whose(other), sub) end
        end
      end
      -- its lines against their patterns, and its patterns against their
      -- lines
      for _, field in ipairs(pattern_fields) do
        for _, theirs in ipairs(line_list(rec[field])) do
          for _, line in ipairs(lines) do
            if pattern_matches(theirs, line) then
              return string.format("%s's pattern %q matches %q", whose(other), theirs, line)
            end
          end
        end
      end
      for _, p in ipairs(parts.patterns or {}) do
        for _, field in ipairs(exact_fields) do
          for _, theirs in ipairs(line_list(rec[field])) do
            if pattern_matches(p[2], theirs) then
              return string.format("the pattern %q matches %s's line %q", p[2], whose(other), theirs)
            end
          end
        end
      end
    end
  end
  -- and the afflictions the player defined (vcustomaff), whose lines are
  -- triggers as well
  local affclash = svo.afflictions and svo.afflictions.defence_clash
    and svo.afflictions.defence_clash(lines, subs, parts.patterns or {})
  if affclash then return affclash end
  local command = defences.command_key(parts.command)
  if command then
    -- what svof takes a command for when the player types it or serverside
    -- sends it, the registered definitions' included (defences.register)
    local act = sys.input_to_actions and sys.input_to_actions[command]
    local taken = act and (act.action_name or act.name)
    if taken and taken ~= name and defences.custom_registered[taken] then
      return string.format("your %s is raised with %q too", taken, parts.command)
    elseif taken and taken ~= name then
      return string.format("Svof already takes %q as %s's command", parts.command, taken)
    end
  end
end

-- the lines a copy of Svof's own carries besides the ones a definition
-- has, which come from Svof and can't be changed. Svof's patterns go in
-- the copy's onr, offr and defr, where they can
local copy_line_fields = { 'def', 'onr', 'offr', 'defr', 'on_only', 'on_free', 'off_free', 'offs' }

-- what a definition watches for and sends, for defences.clash
local function custom_parts(spec)
  local lines = {}
  local kinds = { on = line_list(spec.on), off = line_list(spec.off), def = line_list(spec.def) }
  for _, kind in ipairs({ 'on', 'off', 'def' }) do
    for _, l in ipairs(kinds[kind]) do lines[#lines + 1] = l end
  end
  local extra = type(spec.copy) == 'table' and type(spec.copy.lines) == 'table' and spec.copy.lines or {}
  for _, field in ipairs({ 'def', 'on_only', 'on_free', 'off_free' }) do
    for _, l in ipairs(line_list(extra[field])) do lines[#lines + 1] = l end
  end
  local patterns = {}
  for _, field in ipairs(pattern_fields) do
    for _, p in ipairs(line_list(spec[field])) do patterns[#patterns + 1] = { field, p } end
    for _, p in ipairs(line_list(extra[field])) do patterns[#patterns + 1] = { field, p } end
  end
  return { lines = lines, kinds = kinds, subs = line_list(extra.offs), patterns = patterns, gmcp = spec.gmcp,
    command = spec.command }
end

function defences.custom_register(name, spec)
  if type(spec.command) ~= 'string' or spec.command == '' then error("it has no command to raise it", 0) end
  if spec.gmcp then
    local mapped = svo.dict.sstosvod[spec.gmcp]
    if mapped and mapped ~= name then
      error(string.format("GMCP's %s is already Svof's %s", spec.gmcp, mapped), 0)
    end
  end
  svo.basicdef(name, spec.command, spec.balanceless, spec.gmcp, not spec.gmcp)
  if spec.gmcp then
    -- for defences.unregister to put back
    defences.gmcp_held[name] = { gmcp = spec.gmcp, mapped = svo.dict.sstosvod[spec.gmcp],
      gamename = svo.dict.svotossd[name] }
    svo.dict.sstosvod[spec.gmcp] = name
    svo.dict.svotossd[name] = spec.gmcp
  end
  -- a definition saved without a skillset has a group of its own
  local record = { type = spec.class == 'all' and 'general' or spec.skillset or 'custom',
    on = spec.on, off = spec.off, def = spec.def, invisibledef = spec.notondef or nil }
  -- a copy of Svof's own keeps the other lines Svof watches for
  local extra = type(spec.copy) == 'table' and type(spec.copy.lines) == 'table' and spec.copy.lines or {}
  for _, field in ipairs(copy_line_fields) do
    local l = line_list(extra[field])
    if field == 'def' and #l > 0 then
      if type(spec.def) == 'string' then table.insert(l, 1, spec.def) end
      record.def = l
    elseif #l > 0 then
      record[field] = l
    end
  end
  -- its patterns, for lines that vary
  for _, field in ipairs(pattern_fields) do
    local l = line_list(record[field])
    for _, p in ipairs(line_list(spec[field])) do l[#l + 1] = p end
    if #l > 0 then record[field] = l end
  end
  defences.register(name, record, nil, true)
  defences.custom_registered[name] = true
end

signals.systemstart:connect(function ()
  defences.custom_registered, defences.gmcp_held = {}, {}
  -- read whether or not they're added, for vcustomdef to list and change
  if not defences.custom then defences.custom_load() end
  if not conf.customdefinitions then return end

  local names = {}
  for name, spec in pairs(defences.custom) do
    if defences.custom_applies(spec) then names[#names + 1] = name end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local copy = type(defences.custom[name].copy) == 'table'
    if copy and defs_data[name] and defences.custom[name].class == 'all' then
      -- a copy for every class isn't needed in a class with Svof's own,
      -- which is used instead
    elseif copy and defs_data[name] then
      svo.echofn("Svof has its own %s in this class now, so your copy of it isn't used. ", name)
      custom_link("(delete it)", string.format("svo.defences.custom_delete(%q)", name), "Delete your copy of " .. name,
        'remove')
      echo("\n")
    elseif defences.custom_taken(name) and defs_data[name] then
      -- saved in another class, where svof's own didn't show: it can
      -- become a change to svof's own instead
      svo.echofn("Svof has its own %s in this class, so the one you defined isn't used. ", name)
      custom_link("(make it a change to Svof's own)", string.format("svo.defences.custom_to_change(%q)", name),
        "Put your definition's lines, command and GMCP name into a change to Svof's own " .. name)
      echo(" ")
      custom_link("(delete it)", string.format("svo.defences.custom_delete(%q)", name),
        "Delete your definition of " .. name, 'remove')
      echo("\n")
    elseif defences.custom_taken(name) then
      svo.echof("Svof has its own %s now, so the one you defined isn't used.", name)
    else
      -- one that clashes with this class's defences, which a class change
      -- or an update to Svof can bring, stays out
      -- as does one named after Svof's own action in another class
      local clash = class_action_problem(name) or defences.clash(name, custom_parts(defences.custom[name]))
      local ok, err = clash == nil, clash
      if ok then ok, err = pcall(defences.custom_register, name, defences.custom[name]) end
      if not ok then
        svo.echof("<250,0,0>Couldn't%s add the defence %s you defined: %s", svo.getDefaultColor(), name, tostring(err))
      elseif copy then
        defences.copy_check(name)
      end
    end
  end
end, 'register the defences the player defined')

-- vcustomdef, the commands for defining one (the repo owner's, 2026-09-22):
--   vcustomdef [list]                list them, each a link to change it
--   vcustomdef game                  the game's defences Svof doesn't know,
--                                    from DEFENCE LIST
--   vcustomdef <name>                show one, starting it if new
--   vcustomdef <name> <field> <text> set class, skillset, command,
--                                    balanceless, gmcp or def, or add a got
--                                    or lost line
--   vcustomdef <name> gotpattern|lostpattern|defpattern <pattern>
--                                    add a pattern, for a line that varies
--   vcustomdef <name> line <got|lost|def>  pick that line off the screen
--   vcustomdef <name> fetch [game name]  fill its lines from the game's
--                                    DEFENCE SHOW, which a new definition
--                                    and a GMCP name do by themselves
--   vcustomdef <name> test           say what it would do
--   vcustomdef <name> install        put it into play, and save it
--   vcustomdef <name> delete         take it out
--   vcustomdef <svof's name> ...     the same, changing svof's own defence
--   vcustomdef <svof's name> reset   put svof's own back
--   vcustomdef <name> copy           copy svof's own from another class
--   vcustomdef svof [all]            svof's own, this class's or every
--                                    class's, each a link to change it
--   vcustomdef export [file], import <file>
-- Changes go to a draft, kept until Svof reloads; only install changes play.
defences.custom_drafts = defences.custom_drafts or {}
-- words vcustomdef takes in place of a name
local custom_reserved = { export = true, import = true, list = true, game = true, help = true, svof = true }
-- the definitions whose class the player chose, which the game's word on
-- a defence doesn't change
local class_chosen = {}
-- the new definitions whose screen waits for the game's DEFENCE SHOW, so
-- it's shown once, filled in
local show_waits = {}

local function custom_copy(spec)
  local t = {}
  for k, v in pairs(spec) do t[k] = v end
  for _, k in ipairs({'on', 'off'}) do
    if type(spec[k]) == 'table' then
      t[k] = {}
      for i, line in ipairs(spec[k]) do t[k][i] = line end
    elseif type(spec[k]) == 'string' then
      t[k] = { spec[k] }
    else
      t[k] = {}
    end
  end
  -- patterns, for lines that vary, only when it has some
  for _, k in ipairs(pattern_fields) do
    if spec[k] then t[k] = line_list(spec[k]) end
  end
  return t
end

-- why a skillset can't hold a definition, or nil
local function skillset_problem(skillset)
  if type(skillset) ~= 'string' or not skillset:find("^%l+$") then return "a skillset is one word of letters" end
  if skillset == 'general' or skillset == 'dragoncraft' then return skillset .. " is Svof's own group, not a skillset" end
end

-- why a definition can't be installed, or nil
function defences.custom_problem(name, spec)
  if not name:find("^%l[%l%d]*$") then return "a name is lower-case letters and digits, starting with a letter" end
  if custom_reserved[name] then return name .. " is a command here, not a name" end
  if defences.custom_taken(name) then return "Svof already has " .. name end
  local versions = defences.catalog()[name]
  if versions and type(spec.copy) ~= 'table' then
    return string.format("Svof has its own %s for %s, so use vcustomdef %s copy to copy it in instead", name,
      class_names(versions), name)
  end
  local why = class_action_problem(name)
  if why then return why end
  if type(spec.copy) == 'table' then
    local why = defences.copy_problem(name, spec)
    if why then return why end
  end
  if spec.class ~= 'all' and not (type(spec.class) == 'string' and class_skills(spec.class)) then
    return "its class isn't one Svof knows"
  end
  if type(spec.command) ~= 'string' or spec.command == '' then return "it has no command to raise it" end
  if not ((type(spec.on) == 'table' and #spec.on > 0) or type(spec.on) == 'string' or #line_list(spec.onr) > 0
      or spec.gmcp) then
    return "it needs a line saying you gained it, or its GMCP name, or Svof can't tell when it's up"
  end
  if spec.class ~= 'all' then
    if not spec.skillset then return "pick which of its class's skillsets to show it under" end
    local why = skillset_problem(spec.skillset)
    if why then return why end
  end
  local why = patterns_problem(spec)
  if why then return why end
  -- its lines, GMCP name and command against the class's other defences
  return defences.clash(name, custom_parts(spec))
end

-- the draft of name, started from the installed one or new; nil and why
-- not when the name can't be a definition
local function custom_draft(name)
  local d = defences.custom_drafts[name]
  if d then return d end
  if defences.custom[name] then
    d = custom_copy(defences.custom[name])
  else
    if not name:find("^%l[%l%d]*$") then
      return nil, "a name is lower-case letters and digits, starting with a letter"
    end
    if custom_reserved[name] then return nil, name .. " is a command here, not a name" end
    if defences.custom_taken(name) then return nil, "Svof already has a defence or action called " .. name end
    local versions = defences.catalog()[name]
    if versions then
      return nil, string.format("Svof has its own %s for %s. vcustomdef %s copy copies it in instead", name,
        class_names(versions), name)
    end
    local why = class_action_problem(name)
    if why then return nil, why end
    d = { class = class_key(me.class), on = {}, off = {} }
    defences.custom_drafts[name] = d
    -- if the game knows it by this name, its lines come from the game
    defences.custom_fetch(name, name)
    show_waits[name] = true
    return d
  end
  defences.custom_drafts[name] = d
  return d
end

-- the patterns in field, for lines that vary, under the exact lines: each
-- with a link to remove it, then a link to add one with vcustomdef's verb
local function pattern_rows(name, cmd, patterns, field, verb)
  for i, p in ipairs(patterns) do
    custom_label(i == 1 and "or matches:" or "")
    echo(p .. "  ")
    custom_link("x", string.format("svo.defences.custom_unset(%q, %q, %d)", name, field, i), "Remove this pattern",
      'remove')
    echo("\n")
  end
  custom_label("")
  custom_link("add a pattern", string.format("printCmdLine(%q)", cmd .. verb .. " "),
    "For a line that varies: a pattern, as Mudlet's regex triggers take")
  echo("\n")
end

-- what serverside does about a definition: it knows a defence by its GMCP
-- name, so raises one with a GMCP name while serverside is on, unless
-- vshow server leaves it to Svof
local function custom_serverside(name, d)
  if not d.gmcp then return "can't raise it without a GMCP name, so Svof does" end
  local installed = defences.custom[name]
  if installed and installed.gmcp and not svo.serverignore[name] then return "leaves it to Svof" end
  return "raises it while serverside is on, and Svof otherwise"
end

-- tells serverside to stop raising a definition, by the name it knows it
-- by, in both curing sets: once the definition is gone or renamed, svof's
-- next sync of priorities can't name it
local function custom_server_forget(name)
  if not (conf.serverside and svo.serverignore[name] and svo.dict[name] and svo.dict[name].physical) then return end
  sk.priochangecache = sk.priochangecache or {}
  sk.priochangecache.physical = sk.priochangecache.physical or {}
  sk.priochangecache.slowcuring = sk.priochangecache.slowcuring or {}
  sk.priochangecache.slowcuring.physical = sk.priochangecache.slowcuring.physical or {}
  sk.sendpriorityignore(name, 'physical', {}, {}, sk.priochangecache.physical, false)
  sk.sendpriorityignore(name, 'physical', {}, {}, sk.priochangecache.slowcuring.physical, true)
end

function defences.custom_show(name)
  -- one of svof's own is changed rather than defined
  if defences.is_own(name) then return defences.edit_show(name) end
  -- and one svof has in other classes is copied in
  if not (defences.custom[name] or defences.custom_drafts[name]) and defences.catalog()[name] then
    return defences.copy_offer(name)
  end
  local d, why = custom_draft(name)
  if not d then
    svo.echof("<250,0,0>Can't%s define %s: %s.", svo.getDefaultColor(), name, why)
    return
  end
  -- a new one asks the game for its lines, and is shown once it answers
  local waits = show_waits[name]
  show_waits[name] = nil
  if waits and defences.fetch_pending(name) then
    svo.echof("Asking the game for %s's lines.", name)
    return
  end
  local installed = defences.custom[name]
  if type(d.copy) == 'table' then
    svo.echof("%s, a copy of Svof's own from %s%s:", name, class_names({ { classes = { tostring(d.copy.from) } } }),
      installed and "" or " (not installed)")
  else
    svo.echof("%s, a defence you %s:", name, installed and "defined" or "are defining (not installed)")
    -- one defined before Svof had it in another class
    if defences.catalog()[name] then
      svo.echofn("Svof has its own %s for %s now. ", name, class_names(defences.catalog()[name]))
      custom_link("(use Svof's own instead)", string.format("svo.defences.copy_offer(%q)", name),
        "Copy Svof's own " .. name .. ", with your lines")
      echo("\n")
    end
  end
  local cmd = "vcustomdef " .. name .. " "
  -- a value, or a grey placeholder for one not set
  local function value(text, missing)
    if text then echo(text .. "  ") else custom_unset_text(missing .. "  ") end
  end
  local function row(label, text, field, missing)
    custom_label(label)
    value(text, missing)
    custom_link("change", string.format("printCmdLine(%q)", cmd .. field .. " "), "Change " .. label)
    echo("\n")
  end
  row("class:", class_title(d.class), "class")
  -- a class's goes under one of its skillsets: a link for each
  if d.class ~= 'all' then
    custom_label("skillset:")
    value(d.skillset, "(not set)")
    for _, skillset in ipairs(class_skills(d.class) or {}) do
      if skillset ~= d.skillset then
        custom_link(skillset, string.format("svo.defences.custom_set(%q, 'skillset', %q)", name, skillset),
          "Show it under " .. skillset:title())
        echo("  ")
      end
    end
    custom_link("type one", string.format("printCmdLine(%q)", cmd .. "skillset "), "One Svof doesn't list for the class")
    echo("\n")
  end
  row("command:", d.command, "command", "(not set)")
  row("balance:", d.balanceless and "takes none" or "takes balance", "balanceless")
  row("GMCP name:", d.gmcp, "gmcp", "(not set)")
  custom_label("serverside:")
  echo(custom_serverside(name, d))
  if d.gmcp and defences.custom_registered[name] then
    echo("  ")
    custom_link("vshow server", "svo.showserverside()", "Choose whether serverside or Svof raises it")
  end
  echo("\n")
  local function patterns(field, verb) pattern_rows(name, cmd, line_list(d[field]), field, verb) end
  for _, which in ipairs({ { 'on', 'got', "gained when:" }, { 'off', 'lost', "lost when:" } }) do
    local lines = d[which[1]]
    for i, line in ipairs(lines) do
      custom_label(i == 1 and which[3] or "")
      echo(line .. "  ")
      custom_link("x", string.format("svo.defences.custom_unset(%q, %q, %d)", name, which[1], i), "Remove this line",
        'remove')
      echo("\n")
    end
    custom_label(#lines == 0 and which[3] or "")
    if #lines == 0 then custom_unset_text("(no line)  ") end
    custom_link("add a line from the screen", string.format("svo.defences.custom_capture(%q, %q)", name, which[2]), "Pick the line from what's on screen")
    echo("  ")
    custom_link("type one", string.format("printCmdLine(%q)", cmd .. which[2] .. " "), "Type or paste the line")
    echo("\n")
    patterns(which[1] .. 'r', which[2] .. "pattern")
  end
  if d.notondef then
    custom_label("DEF shows:")
    echo("nothing, as DEF doesn't list it  ")
    custom_link("it does", string.format("printCmdLine(%q)", cmd .. "def "), "Type or paste the line DEF shows")
    echo("\n")
  else
    custom_label("DEF shows:")
    value(d.def, "(no line)")
    custom_link("pick from the screen", string.format("svo.defences.custom_capture(%q, 'def')", name), "Pick the line from what's on screen")
    echo("  ")
    custom_link("type it", string.format("printCmdLine(%q)", cmd .. "def "), "Type or paste the line")
    echo("  ")
    custom_link("DEF doesn't list it", string.format("svo.defences.custom_set(%q, 'def', 'none')", name),
      "For a defence DEF doesn't show, which DEF then leaves alone")
    echo("\n")
    patterns('defr', "defpattern")
  end
  -- what a copy keeps from svof's own as it is
  local extra = type(d.copy) == 'table' and type(d.copy.lines) == 'table' and d.copy.lines or {}
  local kept = 0
  for _, field in ipairs(copy_line_fields) do kept = kept + #line_list(extra[field]) end
  if kept > 0 then
    custom_label("also:")
    echo(string.format("%d more of Svof's own lines and patterns, kept as they are\n", kept))
  end
  custom_separator()
  custom_label("Actions:")
  custom_link("get its lines from the game", string.format("svo.defences.custom_fetch(%q, %q)", name, d.gmcp or name),
    "Ask the game with DEFENCE SHOW")
  echo("  ")
  custom_link("test", string.format("svo.defences.custom_test(%q)", name), "Say what it would do")
  echo("  ")
  custom_link("install", string.format("svo.defences.custom_install(%q)", name), "Put it into play", 'go')
  echo("  ")
  custom_link("delete", string.format("svo.defences.custom_delete(%q)", name), "Take it out", 'remove')
  echo("\n")
end

function defences.custom_set(name, field, value)
  if defences.is_own(name) then return defences.edit_set(name, field, value) end
  local d, why = custom_draft(name)
  if not d then
    svo.echof("<250,0,0>Can't%s define %s: %s.", svo.getDefaultColor(), name, why)
    return
  end
  value = value or ''
  if field == 'class' then
    local class = class_key(value)
    if class ~= 'all' and not class_skills(class) then
      svo.echof("Svof doesn't know a class called %s. Use a class's name, or all.", value)
      return
    end
    -- a skillset of the class it was for doesn't carry over
    if class ~= class_key(d.class) and d.skillset and not table.contains(class_skills(class) or {}, d.skillset) then
      d.skillset = nil
    end
    d.class = class
    class_chosen[name] = true
  elseif field == 'skillset' then
    local skillset = (value:lower():gsub("%s+", ""))
    local why = skillset_problem(skillset)
    if why then svo.echof("Can't show %s under %s: %s.", name, value, why) return end
    d.skillset = skillset
  elseif field == 'command' then
    if value == '' then svo.echof("What does Svof send to raise %s?", name) return end
    d.command = value
  elseif field == 'balanceless' then
    d.balanceless = svo.convert_string(value) and true or nil
  elseif field == 'serverside' then
    svo.echof("Serverside raises a defence by its GMCP name, so give %s one and it does while serverside is on. vshow server can leave it to Svof.", name)
    return
  elseif field == 'gmcp' then
    local gmcp = (value ~= '' and value:lower() ~= 'none') and value:lower() or nil
    -- only a name the game confirms: one it hasn't yet is asked about,
    -- and the reply sets it
    local known = gmcp and defences.gmcp_known(gmcp)
    if known == false then
      svo.echof("%s", defences.gmcp_refusal(name, gmcp))
      return
    elseif gmcp and known == nil then
      svo.echof("Asking the game whether GMCP knows a defence called %s.", gmcp)
      defences.custom_fetch(name, gmcp, 'gmcp')
      return
    end
    d.gmcp = gmcp
    -- the game shows the defence it reports by that name, and the screen
    -- follows its answer
    if d.gmcp then
      svo.echof("Asking the game for %s's lines.", name)
      defences.custom_fetch(name, d.gmcp)
      return
    end
  elseif field == 'got' or field == 'lost' then
    if value == '' then svo.echof("Which line says you %s %s?", field == 'got' and "gained" or "lost", name) return end
    local lines = d[field == 'got' and 'on' or 'off']
    if not table.contains(lines, value) then lines[#lines + 1] = value end
  elseif field == 'def' then
    -- none: DEF doesn't list it, so DEF leaves it alone
    if value:lower() == 'none' then
      d.def, d.defr, d.notondef = nil, nil, true
    else
      d.def, d.notondef = value ~= '' and value or nil, nil
    end
  elseif field == 'gotpattern' or field == 'lostpattern' or field == 'defpattern' then
    -- a pattern, for a line that varies, as svof's own records have
    local key = field == 'gotpattern' and 'onr' or field == 'lostpattern' and 'offr' or 'defr'
    if value == '' then
      svo.echof("Which pattern matches the line that %s?", field == 'gotpattern' and ("says you gained " .. name)
        or field == 'lostpattern' and ("says you lost " .. name) or ("DEF shows for " .. name))
      return
    end
    local why = defences.pattern_problem(value)
    if why then
      svo.echof("Can't use %s as a pattern: %s.", value, why)
      return
    end
    d[key] = line_list(d[key])
    if not table.contains(d[key], value) then d[key][#d[key] + 1] = value end
    if key == 'defr' then d.notondef = nil end
  else
    svo.echof("A definition has class, skillset, command, balanceless, gmcp, got, lost, def, gotpattern, lostpattern and defpattern; %s isn't one.", field)
    return
  end
  defences.custom_show(name)
end

function defences.custom_unset(name, which, i)
  if defences.is_own(name) then return defences.edit_unset(name, which, i) end
  local d = custom_draft(name)
  if d and d[which] then table.remove(d[which], i) end
  defences.custom_show(name)
end

-- shows the last lines on the screen, to click the one that says it
function defences.custom_capture(name, which)
  if which ~= 'got' and which ~= 'lost' and which ~= 'def' then
    svo.echof("Pick a line for got, lost or def.")
    return
  end
  local last = getLastLineNumber("main")
  local lines = getLines(math.max(0, last - 12), last)
  svo.echof("Click the line that %s:", which == 'got' and ("says you gained " .. name)
    or which == 'lost' and ("says you lost " .. name) or ("DEF shows for " .. name))
  for _, line in ipairs(lines) do
    if line:find("%S") then
      echo("  ")
      custom_link(line, string.format("svo.defences.custom_set(%q, %q, %q)", name, which, line), "Use this line")
      echo("\n")
    end
  end
end

-- Readers for the game's SHOW and LIST commands, shared by vcustomdef
-- (DEFENCE SHOW and DEFENCE LIST) and vcustomaff (AFFLICTION SHOW and
-- AFFLICTION LIST): svo.gamereader.show and svo.gamereader.list each make
-- one, for one command, from its settings.
svo.gamereader = svo.gamereader or {}
local gamereader = svo.gamereader

-- The game answers a SHOW in the order it's asked, and under lag long
-- after: 60 to 90 seconds in the live test of 2026-10-18, where the reply
-- about arcaneshield came once svof had stopped waiting for it, and filled
-- moontest. So a reader takes only a reply about what it asked, and one svof
-- stopped waiting for is gagged and left out, for up to late_wait seconds.
-- A LIST page svof stopped waiting for is gagged the same way
gamereader.late_wait = 120

-- starts svof's output on a line of its own, rather than after a prompt
function gamereader.fresh_line()
  moveCursorEnd("main")
  if getCurrentLine() ~= "" then echo("\n") end
end
local fresh_line = gamereader.fresh_line

-- The game's reply is gagged as it's read, and the prompt after it
-- (svo.deleteLineP). Echoed from the trigger, svof's output would go with
-- the line being deleted, so it waits until the line is gone
function gamereader.after_gag(f)
  tempTimer(0, function ()
    fresh_line()
    f()
  end)
end
local after_gag = gamereader.after_gag

-- A reader of one SHOW command's replies. o holds:
--   command      what svof sends, with the name after it
--   code         the code of the trigger reading the replies while one is due
--   title        the label a reply starts with, such as Defence
--   last         the label it ends at, or nil when it ends at the prompt
--   label        the pattern a "Label: value" line matches
--   labels       the labels taken, and wraps, the ones whose value the game
--                carries onto the next line
--   entries      the wraps whose value can be several entries, each on a line
--                of its own, indented, and what joins them, such as Cure(s)'s
--                second route
--   none         the line the game sends for a name it doesn't have, if any
--   answers(keyword, rest)  whether the title line's value is about keyword
--   by_order     the title doesn't always name what was asked, so a reply
--                that answers no ask is the oldest's, and the player's own
--                asks are watched, to be left alone
--   keyword_of(rest)  the title line's GMCP name, if it gives one
--   reply(name, asked, fields, mode)  the reply, once its lines are gagged;
--                fields holds the labels' values, title's among them, and
--                keyword, keyword_of's
--   none_reply(name, asked, mode)  the game doesn't have it
--   timeout(name, asked, mode)  the game didn't answer in time
-- The reader's ask(name, keyword, mode) asks about keyword for name, the
-- definition being made, mode being the caller's own. line() is the
-- trigger's, pending(name) says whether svof waits on an answer for name,
-- and stop() stops waiting for the one asked last.
function gamereader.show(o)
  local r = { fetching = {} }
  -- the asks sent that the game hasn't answered yet, oldest first
  local unanswered = {}
  -- the trigger reading the replies while one is due, and whether the
  -- reply being read is a late one
  local fetch_reader, late_reply

  local function reader_check()
    local due = #unanswered > 0 or r.fetching.fields or late_reply
    if due and not fetch_reader then
      fetch_reader = tempRegexTrigger("^", o.code)
    elseif not due and fetch_reader then
      killTrigger(fetch_reader)
      fetch_reader = nil
    end
  end

  -- takes ask off the list, answered, and the ones asked before it, as
  -- their answers can't come after it
  local function answered(ask)
    while unanswered[1] do
      local first = table.remove(unanswered, 1)
      if first.timer then killTimer(first.timer) end
      first.answered = true
      if first == ask then return end
    end
  end

  -- an ask svof stops waiting for still gets its answer, which is gagged
  -- until late_wait is up
  local function stop_waiting(ask)
    if not ask or ask.answered or ask.timer then return end
    ask.timer = tempTimer(gamereader.late_wait, function ()
      for i, a in ipairs(unanswered) do
        if a == ask then table.remove(unanswered, i) break end
      end
      reader_check()
    end)
  end

  function r.stop()
    if r.fetching.timer then killTimer(r.fetching.timer) end
    stop_waiting(r.fetching.ask)
    r.fetching = {}
    reader_check()
  end

  -- whether svof is waiting on the game's answer for name, to fill it in,
  -- so its screen waits for the answer
  function r.pending(name)
    local fetching = r.fetching
    return fetching.name == name and fetching.mode ~= 'gmcp' and not fetching.fields
  end

  local function done()
    local fetching = r.fetching
    local name, asked, fields, mode = fetching.name, fetching.keyword, fetching.fields, fetching.mode
    r.stop()
    after_gag(function () o.reply(name, asked, fields, mode) end)
  end

  -- The game answers in the order it's asked (Achaea keeps command order),
  -- so with by_order a SHOW the player sends takes its place among svof's,
  -- and its reply is theirs. One handler a command, as the reader is made
  -- again each time svof loads
  local sending
  if o.by_order then
    gamereader.watching = gamereader.watching or {}
    if gamereader.watching[o.command] then killAnonymousEventHandler(gamereader.watching[o.command]) end
    gamereader.watching[o.command] = registerAnonymousEventHandler("sysDataSendRequest", function (_, command)
      if sending or type(command) ~= 'string' then return end
      local keyword = command:lower():match("^%s*" .. o.command .. "%s+(%S.-)%s*$")
      if not keyword then return end
      local ask = { keyword = keyword, player = true }
      unanswered[#unanswered + 1] = ask
      stop_waiting(ask)
      reader_check()
    end)
  end

  function r.ask(name, keyword, mode)
    if type(keyword) ~= 'string' or not keyword:find("%S") then return end
    r.stop()
    r.fetching = { name = name, keyword = keyword:lower(), mode = mode }
    local fetching = r.fetching
    fetching.ask = { keyword = fetching.keyword }
    unanswered[#unanswered + 1] = fetching.ask
    reader_check()
    fetching.timer = tempTimer(5 + svo.getping(), function()
      fetching = r.fetching
      fetching.timer = nil
      if fetching.fields then done() return end
      local asked, defining, asked_mode = tostring(fetching.keyword), fetching.name, fetching.mode
      r.stop()
      fresh_line()
      o.timeout(defining, asked, asked_mode)
    end)
    -- svof says what it's asking, so the command isn't echoed
    sending = true
    send(o.command .. " " .. fetching.keyword, false)
    sending = nil
  end

  -- every line while a reply is due: a reply starts at its title line and
  -- ends at its last label or the prompt, and is gagged, with the prompt
  -- after it
  function r.line()
    local fetching = r.fetching
    if isPrompt and isPrompt() then
      late_reply = nil
      if fetching.fields then done() else reader_check() end
      return
    end
    local text = line
    local label, rest = text:match(o.label)
    -- a late reply, gagged to its end
    if late_reply then
      svo.deleteLineP()
      if o.last and label == o.last then
        late_reply = nil
        reader_check()
      end
      return
    end
    if not fetching.fields then
      if label == o.title then
        -- the first ask it's about. None is a SHOW svof didn't send, such
        -- as the player's own, which is left alone
        local ask
        for _, a in ipairs(unanswered) do
          if o.answers(a.keyword, rest) then ask = a break end
        end
        if not ask and o.by_order then ask = unanswered[1] end
        if not ask then return end
        answered(ask)
        if ask.player then
          reader_check()
          return
        end
        svo.deleteLineP()
        -- the fetch waiting takes a reply about what it asked, from an
        -- earlier ask too, as when it's asked again under lag; any other is
        -- late
        if fetching.keyword and (ask == fetching.ask or o.answers(fetching.keyword, rest)) then
          fetching.fields = { keyword = o.keyword_of and o.keyword_of(rest) or nil, [o.title] = rest }
        else
          late_reply = true
        end
      elseif o.none and text == o.none then
        -- which doesn't say what it's about, so answers the first ask
        local ask = unanswered[1]
        if not ask then return end
        answered(ask)
        if ask.player then
          reader_check()
          return
        end
        if ask.keyword ~= fetching.keyword then
          svo.deleteLineP()
          reader_check()
          return
        end
        local asked, name, mode = fetching.keyword, fetching.name, fetching.mode
        r.stop()
        svo.deleteLineP()
        o.none_reply(name, asked, mode)
      end
      return
    end
    svo.deleteLineP()
    if label and o.labels[label] then
      fetching.fields[label] = rest
      fetching.last = label
      if label == o.last then done() end
    elseif fetching.last and o.wraps[fetching.last] then
      local prev = fetching.fields[fetching.last]
      -- a value wrapped at the screen width goes on at the line's start, and
      -- another entry is indented to the values
      local join = o.entries and o.entries[fetching.last]
      if join and text:find("^%s") then
        fetching.fields[fetching.last] = prev:match("^(.-)%s*$") .. join .. text:match("^%s*(.-)%s*$")
      else
        fetching.fields[fetching.last] = prev .. (prev:find("%s$") and "" or " ") .. text
      end
    end
  end

  return r
end

-- A reader of one LIST command, which shows a name to a line and a page at
-- a time:
--   All defences
--   ------------------------------------------------
--   Accursedresolve
--   Acrobatics
--   [Type MORE if you wish to continue reading. (8% shown)]
-- and MORE past its end gets the game's end line. o holds:
--   command      what svof sends
--   code         the code of the trigger reading the list
--   first        the line the list starts with, such as All defences
--   last_line    the line MORE gets past the end, if known
--   asking       what svof says as it asks
--   got(names, complete)  the names read, in lower case, and whether the
--                last page came, as soon as the list ends
--   show(names)  what svof shows once the list is gagged, when nothing
--                waits for it
-- The reader's ask(after) sends it, reading and hiding it page by page,
-- then runs after, when given, instead of show. line() is the trigger's.
function gamereader.list(o)
  local r = {}
  local listing = {}
  -- A list that ends before the game's last page, having waited too long
  -- for one, leaves the game a page to send: the first, or the one after
  -- MORE (first is false). Under lag it comes late, as in the live test of
  -- 2026-10-18, and is gagged then, for up to late_wait seconds
  local list_owed
  -- the trigger reading the list, and a page owed
  local list_reader

  local function list_reader_check()
    local due = listing.pages or list_owed
    if due and not list_reader then
      list_reader = tempRegexTrigger("^", o.code)
    elseif not due and list_reader then
      killTrigger(list_reader)
      list_reader = nil
    end
  end

  local function list_stop()
    if listing.timer then killTimer(listing.timer) end
    listing = {}
    list_reader_check()
  end

  -- the page owed is gagged when it comes, until late_wait is up
  local function owe(page)
    list_owed = page
    if not page.timer then
      page.timer = tempTimer(gamereader.late_wait, function ()
        page.gone = true
        if list_owed == page then list_owed = nil end
        list_reader_check()
      end)
    end
    list_reader_check()
  end

  -- a line while a page is owed: true when it's that page's, which is
  -- gagged. It starts the way the page owed does, and ends at the prompt
  -- after it, or at a line no page has
  local function owed_line(text)
    local page, prompt = list_owed, isPrompt and isPrompt()
    if not page.started then
      local starts = page.first and text == o.first
        or not page.first and (text:find("^%[File continued via MORE%]") or text == o.last_line)
      if prompt or not starts then return false end
      page.started = true
      svo.deleteLineP()
      return true
    end
    if not prompt and (text:find("^%a+%s*$") or text:find("^%-+%s*$") or text == o.last_line
        or text:find("^%[Type MORE if you wish to continue reading")) then
      svo.deleteLineP()
      return true
    end
    killTimer(page.timer)
    list_owed = nil
    list_reader_check()
    return prompt
  end

  -- The list read, or as much of it as came: handed to got (complete when
  -- its last page came), then shown, or handed to what asked for it (after)
  local function list_done(complete)
    local names, after = listing.names, listing.after
    -- the page the game still owes, when it ended waiting for one
    local page = not complete and (not names and (listing.reused or { first = true })
      or listing.more and { first = false })
    list_stop()
    if page and not page.gone then owe(page) end
    if names and #names > 0 then o.got(names, complete) end
    after_gag(function ()
      if after then return after() end
      o.show(names or {})
    end)
  end

  local function list_wait()
    if listing.timer then killTimer(listing.timer) end
    listing.timer = tempTimer(8 + svo.getping(), function()
      listing.timer = nil
      list_done(false)
    end)
  end

  function r.ask(after)
    -- the game still owes an earlier list's first page, which answers this
    -- one: asking again would have it start the list twice. One already
    -- coming is gagged to its end, and this list asks for its own
    local reused = list_owed and list_owed.first and not list_owed.started and list_owed
    if reused then list_owed = nil end
    list_stop()
    listing = { pages = 0, after = after, reused = reused or nil }
    list_reader_check()
    list_wait()
    svo.echof("%s", o.asking)
    -- svof says what it's asking, so the command isn't echoed
    if not reused then send(o.command, false) end
  end

  -- every line while the list is read: it starts at its first line, a MORE
  -- line asks for the next page, and a prompt with no MORE before it, or
  -- the game saying there's no more, ends it. Every line of it is gagged,
  -- with the prompts between and after its pages (svo.deleteLineP), and the
  -- "[File continued via MORE]" each page after the first starts with. A
  -- page owed to an earlier list comes before anything asked since
  function r.line()
    if list_owed and owed_line(line) then return end
    if not listing.pages then return end
    if isPrompt and isPrompt() then
      if listing.names and not listing.more then list_done(true) end
      return
    end
    local text = line
    if listing.names and o.last_line and text == o.last_line then
      svo.deleteLineP()
      list_done(true)
      return
    end
    if not listing.names then
      if text == o.first then
        listing.names = {}
        svo.deleteLineP()
        if listing.reused then killTimer(listing.reused.timer) end
        -- a page owed to an earlier list would have come before it
        if list_owed then
          killTimer(list_owed.timer)
          list_owed = nil
        end
      end
      return
    end
    if text:find("^%[File continued via MORE%]") then
      svo.deleteLineP()
      return
    end
    if text:find("^%[Type MORE if you wish to continue reading") then
      svo.deleteLineP()
      listing.pages = listing.pages + 1
      if listing.pages > 50 then
        list_done(false)
        return
      end
      listing.more = true
      list_wait()
      send("more", false)
      return
    end
    local name = text:match("^(%a+)%s*$")
    if name then
      listing.names[#listing.names + 1] = name:lower()
      listing.more = false
      svo.deleteLineP()
    elseif text:find("^%-+%s*$") then
      svo.deleteLineP()
    end
  end

  return r
end

-- The game's own record of a defence it knows, the ones GMCP reports.
-- DEFENCE SHOW <name> prints this (the owner's capture, 2026-10-09):
--   Defence:            Alertness (alertness)
--   Description:        Alertness allows you to see when people move into rooms
--   around you.
--   DefMsg:             Your senses are attuned to nearby movement.
--   EnactMsg:           You prick up your ears.
--   FadeMsg:            You cease your watchful alertness.
--   Profession:         No
--   Strippable:         Yes
-- with a long value carried onto the next line, or "There is no such
-- defence." for one it doesn't have. custom_fetch sends it and fills the
-- draft's empty parts from the reply: the name in brackets as its GMCP
-- name, EnactMsg as a gain line, FadeMsg as a loss line, and DefMsg as its
-- DEF line. Profession says whether it's a class's defence (the owner,
-- 2026-10-09): one that isn't is for every class, and for one that is the
-- player is asked which class, as the game doesn't say. A defence the game
-- doesn't have keeps the player's lines.
--
-- A GMCP name is only taken once the game confirms it (the user,
-- 2026-10-10): by DEFENCE SHOW's reply, by DEFENCE LIST, or by GMCP
-- sending it. Asked to set one the game hasn't confirmed this session,
-- custom_fetch asks DEFENCE SHOW (mode 'gmcp'), and the reply sets it, or
-- says the game has no such defence.
defences.gmcp_confirmed = defences.gmcp_confirmed or {}
defences.gmcp_unknown = defences.gmcp_unknown or {}

-- whether the game knows name as a defence over GMCP: true, false, or nil
-- when svof can't tell without asking it
function defences.gmcp_known(name)
  if svo.gdefc[name] or sk.gmcp_defs_seen[name] or defences.gmcp_confirmed[name] then return true end
  local list = defences.game_defences
  if list and list.names[name] then return true end
  if defences.gmcp_unknown[name] or (list and list.complete) then return false end
  return nil
end

-- what svof says refusing a GMCP name the game doesn't know
function defences.gmcp_refusal(name, gmcp)
  return string.format("The game has no defence called %s over GMCP, so it can't be %s's GMCP name. Check the name, or use vcustomdef %s gmcp none for a defence GMCP doesn't report.",
    gmcp, name, name)
end
local fetch_labels = { Description = true, DefMsg = true, EnactMsg = true, FadeMsg = true,
  Profession = true, Strippable = true }
local fetch_wraps = { Description = true, DefMsg = true, EnactMsg = true, FadeMsg = true }

-- whether the game's Defence: line, its name for the defence and its GMCP
-- name in brackets, is about keyword. The game's spelling needn't be the
-- one asked, as in "Tremor sense (tremorsense)", and it may take the start
-- of a name
local function answers(keyword, rest)
  local name, key = rest:match("^(.-)%s*%((%S+)%)%s*$")
  name, key = (name or rest:match("^(.-)%s*$")):lower(), key and key:lower() or ""
  return keyword ~= "" and (key:sub(1, #keyword) == keyword or name:sub(1, #keyword) == keyword)
end

-- shows what's being defined or changed, once the game has had its say
local function show_after_fetch(name)
  if defences.custom_drafts[name] or defences.edit_drafts[name] then defences.custom_show(name) end
end

-- fills in name's draft from the game's DEFENCE SHOW fields f, asked about
-- as asked
local function fetch_fill(name, asked, f, mode)
  -- a definition's draft, or a change being made to svof's own
  local d = name and (defences.custom_drafts[name] or defences.edit_drafts[name])
  if not (f and d) then return end
  local changing = d == defences.edit_drafts[name]
  local function value(label) return f[label] and f[label]:match("^%s*(.-)%s*$") or "" end
  local gmcpname = f.keyword or asked
  -- the game knows a defence by this GMCP name
  defences.gmcp_confirmed[gmcpname] = true
  local mapped = svo.dict.sstosvod[gmcpname]
  if mapped and mapped ~= name then
    if changing then
      svo.echof("Can't give %s the GMCP name %s: GMCP's %s is Svof's %s.", name, gmcpname, gmcpname, mapped)
    else
      svo.echof("The game's %s is Svof's own %s, so there's no need to define it.", gmcpname, mapped)
    end
    return show_after_fetch(name)
  end
  if mode == 'gmcp' then
    -- asked to set the GMCP name: the game's own spelling of it
    if gmcpname ~= asked then svo.echof("The game knows %s as %s over GMCP.", asked, gmcpname) end
    d.gmcp = gmcpname
    -- a change to svof's own takes the name and nothing else
    if changing then return defences.custom_show(name) end
  elseif not d.gmcp then
    d.gmcp = gmcpname
  end
  local on, off, def = value('EnactMsg'), value('FadeMsg'), value('DefMsg')
  if on ~= '' and not table.contains(d.on, on) then d.on[#d.on + 1] = on end
  if off ~= '' and not table.contains(d.off, off) then d.off[#d.off + 1] = off end
  -- a change's DEF lines are a list; and one DEF doesn't list keeps none
  if def ~= '' and type(d.def) == 'table' and not d.notondef then
    if not table.contains(d.def, def) then d.def[#d.def + 1] = def end
  elseif def ~= '' and not d.def and not d.notondef then
    d.def = def
  end
  svo.echof("Filled in %s from the game's DEFENCE SHOW %s.", name, gmcpname)
  -- svof's own keeps its class
  if d == defences.edit_drafts[name] then return defences.custom_show(name) end
  local profession = value('Profession'):lower()
  local chosen = class_chosen[name] or defences.custom[name]
  if profession == 'no' and not chosen then d.class = 'all' end
  defences.custom_show(name)
  if profession == 'no' and not chosen then
    svo.echof("The game says it isn't a profession defence, so any class can have it.")
  elseif profession == 'yes' and not chosen then
    defences.custom_ask_class(name)
  end
end

-- asks which class a profession defence belongs to, a link for each, an
-- element's lord and lady as one
function defences.custom_ask_class(name)
  local d = defences.custom_drafts[name]
  if not d then return end
  svo.echof("The game says %s is a profession defence. Which class has it? It's set to %s now:", name,
    class_title(d.class))
  local classes, seen = {}, {}
  for class in pairs(svo.knownskills) do
    local key = class_key(class)
    if key ~= 'none' and not seen[key] then
      seen[key] = true
      classes[#classes + 1] = key
    end
  end
  table.sort(classes)
  echo("  ")
  for i, class in ipairs(classes) do
    local title = class_title(class)
    custom_link(title, string.format("svo.defences.custom_set(%q, 'class', %q)", name, class), "It's " .. title .. "'s")
    echo(i < #classes and ", " or "\n")
    if i % 6 == 0 and i < #classes then echo("\n  ") end
  end
end

-- vcustomdef's DEFENCE SHOW. mode 'gmcp' asks in order to set the GMCP
-- name, which only the reply does
local show = gamereader.show{
  command = "defence show",
  code = "svo.defences.custom_fetch_line()",
  title = 'Defence',
  last = 'Strippable',
  label = "^(%a+):%s+(.*)$",
  labels = fetch_labels,
  wraps = fetch_wraps,
  none = "There is no such defence.",
  answers = answers,
  keyword_of = function (rest)
    local keyword = rest:match("%((%S+)%)%s*$")
    return keyword and keyword:lower()
  end,
  reply = fetch_fill,
  none_reply = function (name, asked, mode)
    defences.gmcp_unknown[asked] = true
    after_gag(function ()
      if mode == 'gmcp' then
        svo.echof("%s", defences.gmcp_refusal(name, asked))
      else
        svo.echof("The game has no defence called %s, so add its lines yourself.", tostring(asked))
        show_after_fetch(name)
      end
    end)
  end,
  timeout = function (defining, asked, mode)
    if mode == 'gmcp' then
      svo.echof("The game didn't answer about %s, so Svof can't take it as %s's GMCP name. Try again, or use vcustomdef %s gmcp none for a defence GMCP doesn't report.",
        asked, defining, defining)
    else
      svo.echof("The game didn't answer about a defence called %s, so add its lines yourself.", asked)
      show_after_fetch(defining)
    end
  end,
}

function defences.custom_fetch(name, keyword, mode) show.ask(name, keyword, mode) end
function defences.custom_fetch_line() show.line() end
-- whether svof is waiting on the game's DEFENCE SHOW for name, to fill it
-- in, so its screen waits for the answer
function defences.fetch_pending(name) return show.pending(name) end

-- DEFENCE LIST shows every defence the game reports over GMCP, a name to a
-- line and a page at a time (the owner's capture, 2026-10-09):
--   All defences
--   ------------------------------------------------
--   Accursedresolve
--   Acrobatics
--   [Type MORE if you wish to continue reading. (8% shown)]
-- and MORE past its end gets (the user, 2026-10-10):
--   An unseen presence whispers in your ear, "There is no more, friend."
-- custom_gamelist sends it, and MORE after each page, hiding the list as it
-- reads it, then shows the defences Svof doesn't track, each a link to
-- define it.
local list_end = 'An unseen presence whispers in your ear, "There is no more, friend."'

local function list_show(names)
  local custom_gmcp = {}
  for _, spec in pairs(defences.custom) do
    if type(spec.gmcp) == 'string' then custom_gmcp[spec.gmcp:lower()] = true end
  end
  local unknown, ignored = {}, {}
  for _, name in ipairs(names) do
    local mapped = svo.dict.sstosvod[name]
    if not custom_gmcp[name] then
      if mapped == nil then unknown[#unknown + 1] = name
      elseif mapped == false then ignored[#ignored + 1] = name end
    end
  end
  local function links(list)
    echo("  ")
    for i, name in ipairs(list) do
      custom_link(name, string.format("svo.defences.custom_show(%q)", name), "Define " .. name)
      if i < #list then echo(i % 6 == 0 and "\n  " or ", ") end
    end
    echo("\n")
  end
  if #unknown == 0 and #ignored == 0 then
    svo.echof("Svof tracks all %d defences the game lists, or you've defined them.", #names)
    return
  end
  if #unknown > 0 then
    svo.echof("Of the %d defences the game lists, Svof doesn't know these %d. Click one to define it:", #names, #unknown)
    links(unknown)
  end
  if #ignored > 0 then
    svo.echof("Svof knows these, but leaves them alone:")
    links(ignored)
  end
end

-- vcustomdef's DEFENCE LIST, kept for the session once read, so a GMCP
-- name can be checked against it (complete when its last page came)
local list = gamereader.list{
  command = "defence list",
  code = "svo.defences.custom_gamelist_line()",
  first = "All defences",
  last_line = list_end,
  asking = "Asking the game for its list of defences.",
  got = function (names, complete)
    local set = {}
    for _, name in ipairs(names) do set[name] = true end
    defences.game_defences = { names = set, complete = complete }
  end,
  show = function (names)
    if #names > 0 then
      list_show(names)
    else
      svo.echof("The game didn't send its list of defences.")
    end
  end,
}

-- after, when given, runs once the list is read, instead of showing it
function defences.custom_gamelist(after) list.ask(after) end
function defences.custom_gamelist_line() list.line() end

-- what svof says of a defence DEF lists, with no DEF line: a warning, not
-- a refusal, as some defences DEF doesn't show, such as Pariah's
-- bloodiedknife (the user, 2026-10-10)
local function no_def_warning(name)
  return string.format("Without a DEF line, each DEF marks %s gone, and keepup raises it again. Add the line DEF shows for it, or use vcustomdef %s def none if DEF doesn't list it.",
    name, name)
end

-- what test says a defence knows it's up or gone from: its lines, its
-- patterns (a count) and GMCP
local function known_from(lines, patterns, gmcp)
  local parts = {}
  if #lines > 0 then parts[#parts + 1] = string.format("%d line%s", #lines, #lines == 1 and "" or "s") end
  if patterns > 0 then parts[#parts + 1] = string.format("%d pattern%s", patterns, patterns == 1 and "" or "s") end
  if gmcp then parts[#parts + 1] = gmcp end
  return #parts > 0 and svo.concatand(parts) or "nothing, until DEF"
end

function defences.custom_test(name)
  if defences.is_own(name) then return defences.edit_test(name) end
  local d = defences.custom_drafts[name] or defences.custom[name]
  if not d then svo.echof("You haven't defined %s.", name) return end
  local on = type(d.on) == 'string' and { d.on } or d.on or {}
  local off = type(d.off) == 'string' and { d.off } or d.off or {}
  svo.echof("%s, for %s, %s:", name, class_title(d.class),
    d.class == 'all' and "in the main defence list" or d.skillset and ("under " .. d.skillset:title())
    or "under no skillset yet")
  svo.echof("Svof raises it by sending %q, which %s. Serverside %s.", tostring(d.command),
    d.balanceless and "takes no balance" or "takes balance", custom_serverside(name, d))
  svo.echof("It knows it's up from %s.", known_from(on, #line_list(d.onr), d.gmcp and ("GMCP's " .. d.gmcp)))
  svo.echof("It knows it's gone from %s.", known_from(off, #line_list(d.offr), d.gmcp and "GMCP"))
  if d.notondef then
    svo.echof("DEF doesn't list it, so DEF leaves it alone.")
  elseif not d.def and #line_list(d.defr) == 0 then
    svo.echof("%s", no_def_warning(name))
  end
  local problem = defences.custom_problem(name, d)
  if problem then
    svo.echof("<250,0,0>It can't%s be installed yet: %s.", svo.getDefaultColor(), problem)
  else
    svo.echof("It's ready to install.")
  end
end

function defences.custom_install(name)
  if defences.is_own(name) then return defences.edit_install(name) end
  local d = defences.custom_drafts[name] or (defences.custom[name] and custom_copy(defences.custom[name]))
  if not d then svo.echof("You haven't defined %s.", name) return false end
  local problem = defences.custom_problem(name, d)
  if problem then
    svo.echof("<250,0,0>Can't%s install %s: %s.", svo.getDefaultColor(), name, problem)
    return false
  end
  local had = defences.custom[name]
  if defences.custom_registered[name] then
    if had and had.gmcp ~= d.gmcp then custom_server_forget(name) end
    defences.unregister(name, true)
    defences.custom_registered[name] = nil
  end
  defences.custom[name] = d
  defences.custom_drafts[name] = nil
  defences.custom_save()

  -- serverside raises one with a GMCP name, as it does svof's own, from
  -- when it first has one, until vshow server says otherwise. Without one
  -- it can't, and left to serverside nothing would raise it. A copy of
  -- svof's own shares vshow server's choice with svof's own, which is
  -- by name in every class, so keeps it
  if defences.catalog()[name] then
    -- (the choice made for svof's own)
  elseif d.gmcp and not (had and had.gmcp) then
    svo.setserverignore(name)
  elseif not d.gmcp and svo.serverignore[name] then
    svo.unsetserverignore(name)
  end

  -- one taken out above and not put back in isn't up any more to svof
  if not conf.customdefinitions then
    defc[name] = nil
    svo.echof("Saved %s. vconfig customdefinitions is off, so Svof doesn't add it.", name)
  elseif not defences.custom_applies(d) then
    defc[name] = nil
    svo.echof("Saved %s. It's for %s, so Svof adds it when you're one.", name, class_title(d.class))
  else
    local ok, err = pcall(defences.custom_register, name, d)
    if not ok then
      defc[name] = nil
      svo.echof("<250,0,0>Couldn't%s add %s: %s.", svo.getDefaultColor(), name, tostring(err))
      return false
    end
    svo.echof("Installed %s. Add it to defup with vdefup %s, or to keepup with vkeep %s.", name, name, name)
  end
  if not d.def and #line_list(d.defr) == 0 and not d.notondef then svo.echof("%s", no_def_warning(name)) end
  return true
end

function defences.custom_delete(name)
  -- for one of svof's own, delete is reset, unless it names a definition
  -- saved for a class that doesn't have svof's
  if not (defences.custom[name] or defences.custom_drafts[name]) and defences.is_own(name) then
    return defences.edit_reset(name)
  end
  if not (defences.custom[name] or defences.custom_drafts[name]) then
    svo.echof("You haven't defined %s.", name)
    return
  end
  -- a name svof has in other classes, which a copy of svof's own takes
  local svofs = defences.catalog()[name] ~= nil
  if defences.custom_registered[name] then
    custom_server_forget(name)
    defences.unregister(name)
    defences.custom_registered[name] = nil
  end
  defences.custom[name] = nil
  defences.custom_drafts[name] = nil
  defences.custom_save()
  -- a copy's vshow server choice is svof's own's too, which stays
  if svo.serverignore[name] and not svofs then svo.unsetserverignore(name) end
  svo.echof("Deleted %s.", name)
end

-- how many defences the player defined, and how many changes to svof's
-- own they made, every class's
function defences.custom_counts()
  local defined, changed = 0, 0
  for _ in pairs(defences.custom or {}) do defined = defined + 1 end
  for _, names in pairs(defences.edits or {}) do
    for _ in pairs(names) do changed = changed + 1 end
  end
  return defined, changed
end

function defences.custom_export(path)
  path = (path and path ~= '') and path or (getMudletHomeDir() .. "/svo/custom/defs-export")
  local t = {}
  for name, spec in pairs(defences.custom) do t[name] = spec end
  local n, c = defences.custom_counts()
  -- the changes to svof's own go too, under a key no name can be
  if c > 0 then t._changes = defences.edits end
  svo.tablesave(path, t)
  svo.echof("Saved the %d defence%s you defined%s to %s.", n, n == 1 and "" or "s",
    c > 0 and string.format(" and %d change%s to Svof's own", c, c == 1 and "" or "s") or "", path)
end

-- why a GMCP name in a file can't be taken, or nil: the game has to
-- confirm it, as when it's typed
local function imported_gmcp_problem(gmcp)
  if type(gmcp) ~= 'string' then return nil end
  local known = defences.gmcp_known(gmcp:lower())
  if known then return nil end
  if known == false then return "the game has no defence called " .. gmcp:lower() .. " over GMCP" end
  return "Svof couldn't check its GMCP name " .. gmcp:lower() .. " with the game"
end

local function import_from(t, path)
  local names = {}
  for name, spec in pairs(t) do
    if type(name) == 'string' and name ~= '_changes' and type(spec) == 'table' then names[#names + 1] = name end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local problem = imported_gmcp_problem(t[name].gmcp)
    if defences.custom[name] then
      svo.echof("You already have %s, so the one in %s isn't used.", name, path)
    elseif defences.is_own(name) then
      svo.echof("Svof has its own %s, so the one in %s isn't used.", name, path)
    elseif problem then
      svo.echof("Didn't import %s from %s: %s. Check the name, or leave it out for a defence GMCP doesn't report.",
        name, path, problem)
    else
      local d = custom_copy(t[name])
      d.gmcp = type(d.gmcp) == 'string' and d.gmcp:lower() or nil
      defences.custom_drafts[name] = d
      if not defences.custom_install(name) then defences.custom_drafts[name] = nil end
    end
  end
  if type(t._changes) == 'table' then defences.edits_import(t._changes, path) end
end

function defences.custom_import(path)
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
  -- its DEFENCE LIST first
  local unchecked = false
  local function check(gmcp)
    if type(gmcp) == 'string' and defences.gmcp_known(gmcp:lower()) == nil then unchecked = true end
  end
  for name, spec in pairs(t) do
    if name == '_changes' and type(spec) == 'table' then
      for _, changes in pairs(spec) do
        for _, edit in pairs(type(changes) == 'table' and changes or {}) do
          if type(edit) == 'table' then check(edit.gmcp) end
        end
      end
    elseif type(spec) == 'table' then
      check(spec.gmcp)
    end
  end
  if unchecked then
    svo.echof("Checking the GMCP names in %s against the game's list of defences.", path)
    return defences.custom_gamelist(function () import_from(t, path) end)
  end
  import_from(t, path)
end

-- vcustomdef or vcustomdef list: every definition, a link to show and change
-- each
function defences.customdef_menu()
  local names, seen = {}, {}
  for name in pairs(defences.custom) do names[#names + 1] = name seen[name] = true end
  for name in pairs(defences.custom_drafts) do if not seen[name] then names[#names + 1] = name end end
  table.sort(names)
  if #names == 0 then
    svo.echof("You haven't defined any defences.")
  else
    svo.echof("Defences you defined (click one to see or change it):")
    for _, name in ipairs(names) do
      local spec = defences.custom_drafts[name] or defences.custom[name]
      local state = not defences.custom[name] and "not installed"
        or defences.custom_drafts[name] and "changes not installed"
        or defences.custom_registered[name] and "in use"
        or "installed, for another class"
      echo("  ")
      custom_link(name, string.format("svo.defences.custom_show(%q)", name), "See or change " .. name)
      echo(string.format(": %s%s, %s  ", type(spec.copy) == 'table' and "Svof's own, copied, for " or "",
        spec.class == 'all' and "every class"
        or class_title(spec.class) .. (spec.skillset and (" (" .. spec.skillset .. ")") or ""), state))
      custom_link("test", string.format("svo.defences.custom_test(%q)", name), "Say what it would do")
      echo("  ")
      custom_link("delete", string.format("svo.defences.custom_delete(%q)", name), "Take it out", 'remove')
      echo("\n")
    end
  end
  defences.edits_menu()
  -- vconfig customdefinitions, with a link to turn it the other way (the
  -- user's ask, 2026-10-16)
  if conf.customdefinitions then
    svo.echofn("Svof uses your definitions and changes (vconfig customdefinitions is on). ")
    custom_link("turn it off", 'svo.config.set("customdefinitions", false, true)',
      "Leave out your definitions and changes, from when Svof next loads", 'remove')
  else
    svo.echofn("Svof leaves out your definitions and changes (vconfig customdefinitions is off). ")
    custom_link("turn it on", 'svo.config.set("customdefinitions", true, true)',
      "Use your definitions and changes, from when Svof next loads", 'go')
  end
  echo("\n")
  echo("  ")
  custom_link("define a new one", "printCmdLine('vcustomdef <name>')",
    "Put vcustomdef <name> on the command line: replace <name> with its name, or one of Svof's to change it")
  echo("  ")
  custom_link("change one of Svof's own", "svo.defences.own_list()", "List Svof's own defences for your class")
  echo("  ")
  custom_link("see the game's defences Svof doesn't know", "svo.defences.custom_gamelist()", "Compare with DEFENCE LIST")
  echo("\n")
  defences.customdef_usage()
end

-- the classes that have skillset, as the game writes them, an element's
-- lord and lady as one
local function skillset_classes(skillset)
  local t, seen = {}, {}
  for class, skills in pairs(svo.knownskills) do
    local title = class_title(class)
    if not seen[title] and table.contains(skills, skillset) then
      seen[title] = true
      t[#t + 1] = title
    end
  end
  table.sort(t)
  return t
end
defences.skillset_classes = skillset_classes -- for the hide list in Defences.lua

-- vcustomdef svof [all]: Svof's own defences, by skillset, each a link to
-- change it, or for another class's, to copy it in (the user's ask,
-- 2026-10-16). Without all, this class's, the way the defence lists show
-- them; with all, every class's from the catalog too. The player's own
-- definitions are vcustomdef's list, not this one
function defences.own_list(all)
  local groups = {}
  local function add(group, name)
    if defences.custom_registered[name] then return end
    groups[group] = groups[group] or {}
    groups[group][name] = true
  end
  for group, names in pairs(defences.def_types) do
    for _, name in ipairs(names) do add(group, name) end
  end
  if all then
    for name, versions in pairs(defences.catalog()) do
      for _, v in ipairs(versions) do
        if v.type then add(v.type, name) end
      end
    end
  end
  -- general, then this class's skillsets, then the rest by name
  local order, seen = {}, {}
  local function put(group)
    if groups[group] and not seen[group] then
      order[#order + 1] = group
      seen[group] = true
    end
  end
  put('general')
  for _, skillset in ipairs(class_skills(me.class) or {}) do put(skillset) end
  local rest = {}
  for group in pairs(groups) do
    if not seen[group] then rest[#rest + 1] = group end
  end
  table.sort(rest)
  for _, group in ipairs(rest) do put(group) end

  local mine = class_skills(me.class) or {}
  if all then
    svo.echof("Svof's own defences, every class's, by skillset (click one to change it, or to copy another class's in):")
  else
    svo.echof("Svof's own defences for %s (click one to change it):", class_title(me.class))
  end
  local marked = {}
  for _, group in ipairs(order) do
    local names = {}
    for name in pairs(groups[group]) do names[#names + 1] = name end
    table.sort(names)
    local heading = ""
    if all and group == 'general' then
      heading = " (every class)"
    elseif all and not table.contains(mine, group) then
      local classes = skillset_classes(group)
      if #classes > 0 then heading = " (" .. table.concat(classes, ", ") .. ")" end
    end
    svo.echof("%s%s:", group:title(), heading)
    for i, name in ipairs(names) do
      local mark = defences.mark(name)
      if mark ~= '' then marked[mark] = true end
      echo("  ")
      local hint = defences.is_own(name) and defences.markhint("See or change Svof's own " .. name, name)
        or defences.custom[name] and "See your copy of " .. name
        or "Copy Svof's own " .. name .. " from another class"
      custom_link(name, string.format("svo.defences.custom_show(%q)", name), hint)
      if mark ~= '' then
        setFgColor(255, 170, 0)
        echo(mark)
        resetFormat()
      end
      if i % 3 == 0 or i == #names then
        echo("\n")
      else
        echo(string.rep(" ", math.max(1, 22 - #name - #mark)))
      end
    end
  end
  local key = defences.mark_key(marked, "<153,204,204>")
  if key then decho(key) end
  custom_separator()
  echo("  ")
  if all then
    custom_link("show only " .. class_title(me.class) .. "'s defences", "svo.defences.own_list()",
      "List Svof's own defences for your class (vcustomdef svof)")
  else
    custom_link("show every class's defences", "svo.defences.own_list(true)",
      "List Svof's own defences for every class, by skillset (vcustomdef svof all)")
  end
  -- hiding them is vshow hidelist's (the user's choice, 2026-10-16)
  echo("  ")
  custom_link("hide defences", all and "svo.showhidelist(true)" or "svo.showhidelist()",
    "Choose which skillsets and defences the defence lists show (vshow hidelist)")
  echo("\n")
end

-- every form of vcustomdef, each with what it does (the user's ask,
-- 2026-10-14). One command sets one thing; the screen vcustomdef <name>
-- shows has a link for each
local customdef_forms = {
  { "<name>", "see one, or start it, filling it in from the game" },
  { "<name> class|skillset|command|gmcp <value>", "set one of those" },
  { "<name> balanceless yes|no", "whether raising it takes balance" },
  { "<name> got|lost <line>", "add a line saying it's gained or lost" },
  { "<name> def <line>|none", "the line DEF shows, or none if DEF doesn't list it" },
  { "<name> gotpattern|lostpattern|defpattern <pattern>", "add a pattern, for a line that varies" },
  { "<name> line got|lost|def", "pick that line off the screen" },
  { "<name> fetch [game name]", "fill it in from the game's DEFENCE SHOW" },
  { "<name> test|install|delete", "say what it would do, put it into play, or take it out" },
  { "<name> copy", "copy Svof's own from another class" },
  { "<Svof's name> ...|reset", "change one of Svof's own, or put Svof's back" },
  { "svof [all]", "Svof's own defences to change: your class's, or every class's by skillset" },
  { "game", "the game's defences Svof doesn't know" },
  { "export [file]|import <file>", "save your definitions and changes to a file, or read them in" },
}

-- the values the forms above leave to fill in
local customdef_placeholders = { ["<value>"] = true, ["yes|no"] = true, ["<line>"] = true, ["<line>|none"] = true,
  ["<pattern>"] = true, ["got|lost|def"] = true, ["[game name]"] = true, ["[file]"] = true, ["<file>"] = true,
  ["[all]"] = true }

function defences.customdef_usage()
  svo.echof("vcustomdef takes (click one to put it on the command line):")
  for _, form in ipairs(customdef_forms) do
    echo("  ")
    custom_link("vcustomdef " .. form[1], string.format("printCmdLine(%q)", "vcustomdef " .. form[1]), form[2])
    setFgColor(128, 128, 128)
    echo("  " .. form[2] .. "\n")
    resetFormat()
  end
end

-- what the vcustomdef alias passes on: everything after its name
function defences.customdef_command(rest)
  rest = (rest or ''):match("^%s*(.-)%s*$")
  local name, tail = rest:match("^(%S+)%s*(.-)$")
  if not name then return defences.customdef_menu() end
  name = name:lower()
  if name == 'list' then return defences.customdef_menu() end
  if name == 'help' then return defences.customdef_usage() end
  -- a form from the usage, sent with its placeholders still in. Only the
  -- usage's own: a line or pattern can hold < > or |, such as a named group
  local verb, value = tail:match("^(%S*)%s*(.-)$")
  if name:find("^<") or verb:find("|", 1, true) or customdef_placeholders[verb] or customdef_placeholders[value] then
    svo.echof("Replace each <...> with what it stands for, and pick one of each a|b, such as vcustomdef shimmer command shimmer on.")
    return defences.customdef_usage()
  end
  if name == 'game' then return defences.custom_gamelist() end
  if name == 'svof' then
    if verb == '' or verb:lower() == 'all' then return defences.own_list(verb ~= '') end
    svo.echof("vcustomdef svof lists Svof's own defences for your class, and vcustomdef svof all every class's.")
    return
  end
  if name == 'export' then return defences.custom_export(tail) end
  if name == 'import' then return defences.custom_import(tail) end
  verb = verb:lower()
  if verb == '' then return defences.custom_show(name) end
  if verb == 'test' then return defences.custom_test(name) end
  if verb == 'install' then return defences.custom_install(name) end
  if verb == 'delete' then return defences.custom_delete(name) end
  if verb == 'copy' then return defences.copy_offer(name) end
  if verb == 'reset' then
    if defences.is_own(name) then return defences.edit_reset(name) end
    svo.echof("reset puts back a defence of Svof's own that you changed, and %s isn't one. delete takes out one you defined.", name)
    return
  end
  if verb == 'line' then return defences.custom_capture(name, value:lower()) end
  if verb == 'fetch' then
    if defences.is_own(name) then return defences.edit_fetch(name, value) end
    local d, why = custom_draft(name)
    if not d then
      svo.echof("<250,0,0>Can't%s define %s: %s.", svo.getDefaultColor(), name, why)
      return
    end
    return defences.custom_fetch(name, value ~= '' and value or d.gmcp or name)
  end
  return defences.custom_set(name, verb, value)
end

-- Svof's own defences, changed by the player: vcustomdef <svof's name>,
-- for a defence the game changed before svof caught up (the user's ask,
-- 2026-10-10). A change replaces svof's exact gain, loss and DEF lines and
-- its GMCP name, which serverside knows it by too, and for a defence
-- basicdef made, whose action only sends its command, the command, and its
-- patterns for lines that vary (the user, 2026-10-11). Svof's other ways
-- of raising a defence and the logic around it stay, and the change's
-- screen says which. Changes are saved under
-- <profile>/svo/custom/edits, apart from definitions, by whose they are
-- (the class, or 'all' for a defence every class has the same) and name.
-- Each holds only what differs from svof's own, and svof's version of that
-- when it was changed (was), so svof can say when an update has changed it
-- since. vconfig customdefinitions off leaves them out too.
local edits_path = getMudletHomeDir() .. "/svo/custom/edits"
-- notondef: DEF doesn't list it (svof's invisibledef), as definitions have
-- skillset: the one a class's defence is listed under, for a class update
-- that moved it (the user's ask, 2026-10-17)
local edit_fields = { 'on', 'off', 'def', 'onr', 'offr', 'defr', 'notondef', 'command', 'gmcp', 'skillset' }
local edit_labels = { on = "gain lines", off = "loss lines", def = "DEF lines", onr = "gain patterns",
  offr = "loss patterns", defr = "DEF patterns", notondef = "whether DEF lists it", command = "command",
  gmcp = "GMCP name", skillset = "skillset" }
-- svof's own version of each defence a change is in use for, to put back
defences.own = defences.own or {}
defences.edit_drafts = defences.edit_drafts or {}

function defences.edits_load()
  local t = {}
  if lfs.attributes(edits_path) then
    local ok, msg = pcall(table.load, edits_path, t)
    if not ok then
      svo.echof("<250,0,0>Couldn't%s read your changes to Svof's defences, in %s: %s", svo.getDefaultColor(),
        edits_path, tostring(msg))
      t = {}
    end
  end
  defences.edits = t
end

function defences.edits_save()
  svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/custom")
  svo.tablesave(edits_path, defences.edits)
end

-- whether two parts of a defence are the same: lines in any order, and no
-- GMCP name the same as none
local function same(a, b)
  if type(a) ~= 'table' or type(b) ~= 'table' then return (a or nil) == (b or nil) end
  if #a ~= #b then return false end
  local x, y = line_list(a), line_list(b)
  table.sort(x) table.sort(y)
  for i = 1, #x do
    if x[i] ~= y[i] then return false end
  end
  return true
end

-- whose a change to svof's own defence is: one from a class's skillsets is
-- the class's, and one every class has the same, such as a general one,
-- is every class's
local function edit_key(rec)
  local group = rec and rec.type
  if group == nil or group == 'general' or group == 'dragoncraft' then return 'all' end
  return class_key(me.class)
end

-- whether name is svof's own defence in this class, which the player can
-- change, rather than one they defined
function defences.is_own(name)
  return defs_data[name] ~= nil and not defences.custom_registered[name]
end

-- the change saved for svof's own defence name in this class, and whose
-- it is
local function edit_of(name)
  local key = edit_key(defs_data[name])
  return defences.edits and defences.edits[key] and defences.edits[key][name], key
end

local function physical_of(name)
  local entry = svo.dict[name]
  return type(entry) == 'table' and type(entry.physical) == 'table' and entry.physical or nil
end

-- svof's own version of a defence, which a change is made from and reset
-- puts back
local function own_version(name)
  local snap, phys = defences.own[name], physical_of(name)
  if snap then
    return { on = line_list(snap.on), off = line_list(snap.off), def = line_list(snap.def),
      onr = line_list(snap.onr), offr = line_list(snap.offr), defr = line_list(snap.defr),
      notondef = snap.invisibledef and true or nil, command = snap.command, gmcp = snap.gmcp,
      skillset = snap.type, sendsaction = phys and phys.sendsaction }
  end
  local rec = defs_data[name]
  return { on = line_list(rec.on), off = line_list(rec.off), def = line_list(rec.def),
    onr = line_list(rec.onr), offr = line_list(rec.offr), defr = line_list(rec.defr),
    notondef = rec.invisibledef and true or nil, command = phys and phys.action, gmcp = svo.dict.svotossd[name],
    skillset = rec.type, sendsaction = phys and phys.sendsaction }
end

-- the command that raises it, which svof also takes for its own when the
-- player types it or serverside sends it (sys.input_to_actions)
local function set_command(phys, command, onstart)
  local map = sys.input_to_actions
  -- the old command's, as it is and in lower case
  for _, old in ipairs({ phys.action, defences.command_key(phys.action) }) do
    if map[old] == phys then map[old] = nil end
  end
  phys.action = command
  phys.onstart = onstart or function () send(command, conf.commandecho) end
  local key = defences.command_key(command)
  if key then map[key] = phys end
  if key and command ~= key then map[command] = phys end
end

-- its GMCP name, which serverside knows it by too
local function set_gmcp(name, gmcp, gamename)
  local old = svo.dict.svotossd[name]
  if old and svo.dict.sstosvod[old] == name then svo.dict.sstosvod[old] = nil end
  svo.dict.svotossd[name] = gmcp
  if gmcp then svo.dict.sstosvod[gmcp] = name end
  if type(svo.dict[name]) == 'table' then svo.dict[name].gamename = gamename end
end

-- moves a defence the lists already have from one skillset to another:
-- its place in the lists, and whether it's hidden. One svof hasn't listed
-- yet, as it loads, is listed under its record's
local function regroup(name, from, to)
  if from == to then return end
  -- listed already: def_types starts again each load, and the hide list's
  -- map of defences to groups doesn't
  local list, listed = defences.def_types[from] or {}, false
  for i = #list, 1, -1 do
    if list[i] == name then
      table.remove(list, i)
      listed = true
    end
  end
  if not listed then return end
  if #list == 0 then defences.def_types[from] = nil end
  defences.def_types[to] = defences.def_types[to] or {}
  defences.def_types[to][#defences.def_types[to] + 1] = name
  local old = sk.ignored_defences[from]
  local hidden = old and old.t[name] or false
  if old then old.t[name] = nil end
  sk.ignored_defences[to] = sk.ignored_defences[to] or { status = false, t = {} }
  sk.ignored_defences[to].t[name] = hidden
  sk.ignored_defences_map[name] = to
end

-- puts a change into play over svof's own version, keeping that to put
-- back. A GMCP name svof has since given another defence stays that one's
local function edit_apply(name, edit)
  local rec, entry, phys = defs_data[name], svo.dict[name], physical_of(name)
  local snap = { on = rec.on, off = rec.off, def = rec.def, onr = rec.onr, offr = rec.offr, defr = rec.defr,
    invisibledef = rec.invisibledef, gmcp = svo.dict.svotossd[name],
    gamename = type(entry) == 'table' and entry.gamename or nil, command = phys and phys.action,
    onstart = phys and phys.onstart, type = rec.type }
  defences.own[name] = snap
  for _, field in ipairs({ 'on', 'off', 'def', 'onr', 'offr', 'defr' }) do
    if edit[field] then rec[field] = line_list(edit[field]) end
  end
  if edit.notondef ~= nil then rec.invisibledef = edit.notondef or nil end
  if edit.command and phys and phys.sendsaction then set_command(phys, edit.command) end
  if edit.skillset then
    regroup(name, rec.type, edit.skillset)
    rec.type = edit.skillset
  end
  local taken = edit.gmcp and svo.dict.sstosvod[edit.gmcp]
  if edit.gmcp ~= nil and not (taken and taken ~= name) then
    -- what the name meant before, such as a defence svof leaves alone
    if edit.gmcp then snap.held = taken end
    set_gmcp(name, edit.gmcp or nil, edit.gmcp or nil)
  end
end

-- puts svof's own version back
local function edit_restore(name)
  local snap = defences.own[name]
  if not snap then return end
  defences.own[name] = nil
  local rec, phys = defs_data[name], physical_of(name)
  if rec then
    rec.on, rec.off, rec.def, rec.invisibledef = snap.on, snap.off, snap.def, snap.invisibledef
    rec.onr, rec.offr, rec.defr = snap.onr, snap.offr, snap.defr
    if snap.type and rec.type ~= snap.type then
      regroup(name, rec.type, snap.type)
      rec.type = snap.type
    end
  end
  if phys and phys.action ~= snap.command then set_command(phys, snap.command, snap.onstart) end
  local mine = svo.dict.svotossd[name]
  if mine ~= snap.gmcp then
    set_gmcp(name, snap.gmcp, snap.gamename)
    if mine then svo.dict.sstosvod[mine] = snap.held end
  end
end

-- makes a defence's triggers again from its record's lines
local function rewire(name)
  for _, id in ipairs(defences.triggers_of[name] or {}) do killTrigger(id) end
  defences.wire_triggers(name, defs_data[name])
end

-- serverside knows a defence by its GMCP name: once that changes, svof's
-- next sync of priorities gives the server the new one. Before it changes,
-- custom_server_forget tells the server to stop raising the old one
local function server_renamed(name)
  if not (conf.serverside and sk.priosbeforechange) then return end
  for _, state in pairs(sk.priosbeforechange) do
    for prio, action in pairs(state.data or {}) do
      if action == name or action == name .. '_physical' then state.data[prio] = nil end
    end
  end
  sk.handleserversideswitch()
end

-- puts a change into play now, after svof loaded: over svof's own, or over
-- the change it replaces, telling serverside of a new GMCP name
local function edit_live(name, edit)
  local before = svo.dict.svotossd[name]
  local after = own_version(name).gmcp
  -- the change's name, unless another defence has it, which edit_apply
  -- leaves alone
  local taken = edit and edit.gmcp and svo.dict.sstosvod[edit.gmcp]
  if edit and edit.gmcp ~= nil and not (taken and taken ~= name) then after = edit.gmcp or nil end
  local renamed = before ~= after
  if renamed then custom_server_forget(name) end
  edit_restore(name)
  if edit then edit_apply(name, edit) end
  rewire(name)
  if renamed then server_renamed(name) end
end

-- the parts of a change svof has changed its own version of since: the
-- ones whose was isn't svof's now
local function edit_moved(name, edit)
  local own, moved = own_version(name), {}
  for _, field in ipairs(edit_fields) do
    if edit[field] ~= nil and not same((edit.was or {})[field], own[field]) then moved[#moved + 1] = field end
  end
  return moved
end

-- what a change adds to svof's own name, for defences.clash: the lines and
-- patterns svof's own doesn't have, and a command svof's own doesn't send,
-- against the class's other defences; and all its patterns against all
-- its lines of another kind. Its GMCP name is checked where it's set
local function edit_parts(name, edit)
  local own, lines, patterns, every, kinds = own_version(name), {}, {}, {}, {}
  for _, field in ipairs({ 'on', 'off', 'def' }) do
    kinds[field] = edit[field] and line_list(edit[field]) or own[field]
    for _, l in ipairs(line_list(edit[field])) do
      if not table.contains(own[field], l) then lines[#lines + 1] = l end
    end
  end
  for _, field in ipairs(pattern_fields) do
    for _, p in ipairs(edit[field] and line_list(edit[field]) or own[field]) do
      every[#every + 1] = { field, p }
      if not table.contains(own[field], p) then patterns[#patterns + 1] = { field, p } end
    end
  end
  local command = own.sendsaction and edit.command ~= own.command and edit.command or nil
  return { lines = lines, patterns = patterns, kinds = kinds, selfpatterns = every, command = command }
end

-- Puts this class's change to svof's own name into play, as svof loads or
-- registers the defence, saying if svof's own has changed since
function defences.edit_put(name)
  if not conf.customdefinitions or not defences.edits then return end
  local edit = edit_of(name)
  if not edit or defences.own[name] then return end
  -- one that clashes with this class's other defences, which a class
  -- change or an update to Svof can bring, stays out
  local clash = defences.clash(name, edit_parts(name, edit))
  if clash then
    svo.echofn("<250,0,0>Didn't%s use your change to Svof's own %s: %s. ", svo.getDefaultColor(), name, clash)
    custom_link("(see it)", string.format("svo.defences.custom_show(%q)", name), "See your change next to Svof's own")
    echo("\n")
    return
  end
  local moved = edit_moved(name, edit)
  edit_apply(name, edit)
  if #moved == 0 then return end
  for i, field in ipairs(moved) do moved[i] = edit_labels[field] end
  svo.echofn("Svof has updated the %s of its own %s since you changed it. Yours %s still in use: ",
    svo.concatand(moved), name, #moved == 1 and "is" or "are")
  custom_link("see both", string.format("svo.defences.custom_show(%q)", name), "See your change next to Svof's own")
  echo(", ")
  custom_link("use Svof's", string.format("svo.defences.edit_reset(%q)", name), "Delete your change and use Svof's",
    'remove')
  echo(", ")
  custom_link("keep yours", string.format("svo.defences.edit_keep(%q)", name), "Keep your change, and stop saying so")
  echo("\n")
end

-- At systemstart, before anything is made from the records: puts this
-- class's changes into play
function defences.edits_start()
  defences.own, defences.edit_drafts, defences.edit_converting = {}, {}, {}
  if not defences.edits then defences.edits_load() end
  if not conf.customdefinitions then return end
  for name in defs_data:iter() do defences.edit_put(name) end

  -- a change to a defence svof doesn't have any more. An item's defence
  -- registers later
  for _, key in ipairs({ 'all', class_key(me.class) }) do
    local names = {}
    for name in pairs(defences.edits[key] or {}) do
      if not defs_data[name] and not item_defences[name] then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do
      svo.echofn("Svof doesn't have %s any more, so your change to it isn't used. ", name)
      custom_link("(forget it)", string.format("svo.defences.edit_reset(%q, %q)", name, key),
        "Delete your change to " .. name, 'remove')
      echo("\n")
    end
  end
end

-- the change being made to svof's own name, started from the one saved or
-- from svof's own
local function edit_draft(name)
  local d = defences.edit_drafts[name]
  if d then return d end
  local own, edit = own_version(name), edit_of(name)
  local function from(field)
    if edit and edit[field] ~= nil then return edit[field] end
    return own[field]
  end
  d = { on = line_list(from('on')), off = line_list(from('off')), def = line_list(from('def')),
    onr = line_list(from('onr')), offr = line_list(from('offr')), defr = line_list(from('defr')),
    notondef = from('notondef') or nil, command = from('command'), gmcp = from('gmcp') or nil,
    skillset = from('skillset') }
  defences.edit_drafts[name] = d
  return d
end

-- whether a draft is what's installed: the change saved, or svof's own
local function draft_installed(name, d)
  local own, edit = own_version(name), edit_of(name)
  for _, field in ipairs(edit_fields) do
    local installed = own[field]
    if edit and edit[field] ~= nil then installed = edit[field] end
    if not same(d[field], installed) then return false end
  end
  return true
end

-- whether a change leaves a defence DEF lists with no DEF line or pattern
-- where svof's own had one, which test and install warn about
local function edit_drops_def(name, d)
  local own = own_version(name)
  return #d.def == 0 and #d.defr == 0 and (#own.def > 0 or #own.defr > 0) and not d.notondef
end

-- why a change can't be installed, or nil
local function edit_problem(name, d)
  local own = own_version(name)
  local mapped = d.gmcp and svo.dict.sstosvod[d.gmcp]
  if mapped and mapped ~= name then return "GMCP's " .. d.gmcp .. " is Svof's " .. mapped end
  if #d.on == 0 and #d.onr == 0 and (#own.on > 0 or #own.onr > 0) and not d.gmcp then
    return "it needs a line saying you gained it, or its GMCP name, or Svof can't tell when it's up"
  end
  -- its patterns svof's own doesn't have
  local why = patterns_problem(d, function (field, p) return table.contains(own[field], p) end)
  if why then return why end
  return defences.clash(name, edit_parts(name, d))
end

-- what svof does with a defence that lies elsewhere, outside its record and
-- entry
local outside_rules = {
  torch = "the ablaze affliction counting as torch for a fire Elemental Lord",
  dragonform = "your race over GMCP saying whether you're a dragon",
  shadowcloak = "your inventory over GMCP saying whether you wear your cloak",
  block = "losing it when you leave the room",
  listen = "losing it when you leave the room",
  eavesdrop = "losing it when you leave the room",
  lyre = "losing it when you leave the room",
}

-- the balances other than physical that svof raises name with, such as
-- rebounding's smoke
local function raised_with(name)
  local entry, others = svo.dict[name], {}
  if type(entry) ~= 'table' then return others end
  for balance, act in pairs(entry) do
    if type(act) == 'table' and act.def and balance ~= 'physical' then others[#others + 1] = balance end
  end
  table.sort(others)
  return others
end

-- why a change can't reach the command of svof's own name. Only basicdef's
-- actions are known to send their command and nothing else; a hand-written
-- one may build its command, such as riding's, or send a fixed one, such as
-- waterweird's, and svof can't tell which (the user, 2026-10-17)
local function fixed_command(name)
  local others = raised_with(name)
  if physical_of(name) then return "Svof's action for it is written by hand, so a change can't replace its command" end
  if #others > 0 then return "Svof raises it with " .. svo.concatand(others) .. ", so it has no command to change" end
  return "Svof doesn't raise it, it only tracks it"
end

-- what a change to svof's own defence doesn't reach, as svof does more
-- with it than the lines, GMCP name and command
local function edit_notes(name)
  local rec, phys = defs_data[name], physical_of(name)
  local notes = {}
  local function add(note) notes[#notes + 1] = note end
  if rec.on_only or rec.on_free or rec.off_free or rec.offs then add("other lines it watches for") end
  if rec.ongot or rec.onlost then add("what gaining or losing it does to your other defences and afflictions") end
  if rec.onenable then add("the defences it can't be up with on defup and keepup") end
  if rec.specialskip then add("when it holds off raising it") end
  if rec.ondef then add("what it reads from its DEF line") end
  if rec.custom_def_type then add(string.format("counting it with your other %s defences", rec.custom_def_type)) end
  -- (without physical, the command row says how svof raises it)
  local others = raised_with(name)
  if phys and #others > 0 then add("raising it with " .. svo.concatand(others) .. " as well") end
  if defences.waits[name] then add("the wait for it after its command") end
  for _, h in ipairs({ 'got_', 'lost_' }) do
    if defs[h .. name] and not (defences.generated and defences.generated[h .. name]) then
      add("its own handling of its lines")
      break
    end
  end
  if defences.prompt_decides[name] then add("deciding on each prompt whether it's a defence or an affliction") end
  if outside_rules[name] then add(outside_rules[name]) end
  return notes
end

function defences.edit_show(name)
  local d, own, edit, phys = edit_draft(name), own_version(name), edit_of(name), physical_of(name)
  svo.echof("%s, Svof's own defence%s%s:", name, edit and ", which you changed" or "",
    draft_installed(name, d) and "" or " (changes not installed)")
  svo.echof("A change replaces Svof's version, and Svof's updates to %s don't reach you while it's in use.", name)
  local cmd = "vcustomdef " .. name .. " "
  -- Svof's own, under a part the change differs in
  local function svofs(values)
    if #values == 0 then values = { "(none)" } end
    for i, value in ipairs(values) do
      custom_label("")
      custom_unset_text(string.format("%s %s\n", i == 1 and "Svof's:" or "       ", value))
    end
  end
  if phys and phys.sendsaction then
    custom_label("command:")
    echo(tostring(d.command) .. "  ")
    custom_link("change", string.format("printCmdLine(%q)", cmd .. "command "), "Change the command")
    echo("\n")
    if d.command ~= own.command then svofs({ tostring(own.command) }) end
  else
    custom_label("command:")
    echo(fixed_command(name) .. "\n")
  end
  custom_label("GMCP name:")
  if d.gmcp then echo(d.gmcp .. "  ") else custom_unset_text("(none)  ") end
  custom_link("change", string.format("printCmdLine(%q)", cmd .. "gmcp "), "Change the GMCP name")
  echo("\n")
  if not same(d.gmcp, own.gmcp) then svofs({ own.gmcp }) end
  -- the skillset it's listed under, which a class update can move it from
  custom_label("skillset:")
  if edit_key(defs_data[name]) == 'all' then
    echo(tostring(d.skillset) .. ", which every class has, so it stays there\n")
  else
    echo(tostring(d.skillset) .. "  ")
    for _, skillset in ipairs(class_skills(me.class) or {}) do
      if skillset ~= d.skillset then
        custom_link(skillset, string.format("svo.defences.custom_set(%q, 'skillset', %q)", name, skillset),
          "List it under " .. skillset:title())
        echo("  ")
      end
    end
    custom_link("type one", string.format("printCmdLine(%q)", cmd .. "skillset "), "One Svof doesn't list for the class")
    echo("\n")
    if d.skillset ~= own.skillset then svofs({ tostring(own.skillset) }) end
  end
  local unlisted = "nothing, as DEF doesn't list it"
  for _, which in ipairs({ { 'on', 'got', "gained when:" }, { 'off', 'lost', "lost when:" }, { 'def', 'def', "DEF shows:" } }) do
    local lines, isdef = d[which[1]], which[1] == 'def'
    if isdef and d.notondef then
      custom_label(which[3])
      echo(unlisted .. "  ")
      custom_link("it does", string.format("printCmdLine(%q)", cmd .. "def "), "Type or paste the line DEF shows")
      echo("\n")
    else
      for i, line in ipairs(lines) do
        custom_label(i == 1 and which[3] or "")
        echo(line .. "  ")
        custom_link("x", string.format("svo.defences.custom_unset(%q, %q, %d)", name, which[1], i), "Remove this line",
          'remove')
        echo("\n")
      end
      custom_label(#lines == 0 and which[3] or "")
      if #lines == 0 then custom_unset_text("(no line)  ") end
      custom_link("add a line from the screen", string.format("svo.defences.custom_capture(%q, %q)", name, which[2]),
        "Pick the line from what's on screen")
      echo("  ")
      custom_link("type one", string.format("printCmdLine(%q)", cmd .. which[2] .. " "), "Type or paste the line")
      if isdef then
        echo("  ")
        custom_link("DEF doesn't list it", string.format("svo.defences.custom_set(%q, 'def', 'none')", name),
          "For a defence DEF doesn't show, which DEF then leaves alone")
      end
      echo("\n")
    end
    if isdef and not (same(lines, own.def) and same(d.notondef, own.notondef)) then
      svofs(own.notondef and { unlisted } or own.def)
    elseif not isdef and not same(lines, own[which[1]]) then
      svofs(own[which[1]])
    end
    -- its patterns, for lines that vary, and svof's own where they differ
    if not (isdef and d.notondef) then
      local field = which[1] .. 'r'
      pattern_rows(name, cmd, d[field], field, which[2] .. "pattern")
      if not same(d[field], own[field]) then svofs(own[field]) end
    end
  end
  for i, note in ipairs(edit_notes(name)) do
    custom_label(i == 1 and "Svof keeps:" or "")
    echo(note .. "\n")
  end
  custom_separator()
  custom_label("Actions:")
  custom_link("get its lines from the game", string.format("svo.defences.edit_fetch(%q)", name), "Ask the game with DEFENCE SHOW")
  echo("  ")
  custom_link("test", string.format("svo.defences.custom_test(%q)", name), "Say what it would do")
  echo("  ")
  custom_link("install", string.format("svo.defences.custom_install(%q)", name), "Put it into play", 'go')
  echo("  ")
  custom_link("reset to Svof's", string.format("svo.defences.edit_reset(%q)", name), "Put Svof's own back", 'remove')
  echo("\n")
end

function defences.edit_set(name, field, value)
  local d, own = edit_draft(name), own_version(name)
  value = value or ''
  if field == 'command' then
    if not own.sendsaction then
      svo.echof("Can't change %s's command: %s.", name, fixed_command(name))
      return
    end
    if value == '' then svo.echof("What does Svof send to raise %s?", name) return end
    d.command = value
  elseif field == 'gmcp' then
    local gmcp = (value ~= '' and value:lower() ~= 'none') and value:lower() or nil
    local mapped = gmcp and svo.dict.sstosvod[gmcp]
    if mapped and mapped ~= name then
      svo.echof("Can't give %s the GMCP name %s: GMCP's %s is Svof's %s.", name, gmcp, gmcp, mapped)
      return
    end
    -- only a name the game confirms, or svof's own back again
    local new = gmcp and gmcp ~= own.gmcp
    local known = new and defences.gmcp_known(gmcp)
    if new and known == false then
      svo.echof("%s", defences.gmcp_refusal(name, gmcp))
      return
    elseif new and known == nil then
      svo.echof("Asking the game whether GMCP knows a defence called %s.", gmcp)
      defences.custom_fetch(name, gmcp, 'gmcp')
      return
    end
    d.gmcp = gmcp
  elseif field == 'def' and value:lower() == 'none' then
    -- DEF doesn't list it, so DEF leaves it alone
    d.def, d.defr, d.notondef = {}, {}, true
  elseif field == 'gotpattern' or field == 'lostpattern' or field == 'defpattern' then
    local key = field == 'gotpattern' and 'onr' or field == 'lostpattern' and 'offr' or 'defr'
    if value == '' then
      svo.echof("Which pattern matches the line that %s?", field == 'gotpattern' and ("says you gained " .. name)
        or field == 'lostpattern' and ("says you lost " .. name) or ("DEF shows for " .. name))
      return
    end
    -- svof's own back again needs no reading
    local why = not table.contains(own[key], value) and defences.pattern_problem(value)
    if why then
      svo.echof("Can't use %s as a pattern: %s.", value, why)
      return
    end
    if not table.contains(d[key], value) then d[key][#d[key] + 1] = value end
    if key == 'defr' then d.notondef = nil end
  elseif field == 'got' or field == 'lost' or field == 'def' then
    if value == '' then
      svo.echof("Which line %s?", field == 'got' and ("says you gained " .. name)
        or field == 'lost' and ("says you lost " .. name) or ("does DEF show for " .. name))
      return
    end
    local lines = d[field == 'got' and 'on' or field == 'lost' and 'off' or 'def']
    if not table.contains(lines, value) then lines[#lines + 1] = value end
    if field == 'def' then d.notondef = nil end
  elseif field == 'skillset' then
    if edit_key(defs_data[name]) == 'all' then
      svo.echof("Svof's own %s is a %s defence, which every class has, so its skillset stays.", name, tostring(own.skillset))
      return
    end
    -- as a definition's: weather weaving is weatherweaving
    local skillset = (value:lower():gsub("%s+", ""))
    if skillset == '' then svo.echof("Which skillset is %s in now?", name) return end
    local why = skillset_problem(skillset)
    if why then
      svo.echof("Can't list %s under %s: %s.", name, value, why)
      return
    end
    d.skillset = skillset
  elseif field == 'class' or field == 'balanceless' or field == 'serverside' then
    svo.echof("Svof's own %s keeps its class and balance. A change can replace its lines, patterns, GMCP name and skillset, and for some defences the command.", name)
    return
  else
    svo.echof("A change to Svof's own defence has command, gmcp, skillset, got, lost, def, gotpattern, lostpattern and defpattern; %s isn't one.", field)
    return
  end
  defences.edit_show(name)
end

function defences.edit_unset(name, which, i)
  local d = edit_draft(name)
  if d[which] then table.remove(d[which], i) end
  defences.edit_show(name)
end

-- asks the game for its lines, with DEFENCE SHOW, into the change
function defences.edit_fetch(name, keyword)
  local d = edit_draft(name)
  defences.custom_fetch(name, (keyword and keyword ~= '') and keyword or d.gmcp or name)
end

function defences.edit_test(name)
  local d, own, rec = edit_draft(name), own_version(name), defs_data[name]
  local key = edit_key(rec)
  svo.echof("%s, Svof's own, for %s:", name, key == 'all' and "every class" or key)
  local changes = {}
  for _, field in ipairs(edit_fields) do
    if not same(d[field], own[field]) then changes[#changes + 1] = edit_labels[field] end
  end
  if #changes == 0 then
    svo.echof("It's the same as Svof's own.")
  else
    svo.echof("Your change replaces its %s.", svo.concatand(changes))
  end
  svo.echof("It knows it's up from %s.", known_from(d.on, #d.onr, d.gmcp and ("GMCP's " .. d.gmcp)))
  svo.echof("It knows it's gone from %s.", known_from(d.off, #d.offr, d.gmcp and "GMCP"))
  if d.notondef then
    svo.echof("DEF doesn't list it, so DEF leaves it alone.")
  elseif edit_drops_def(name, d) then
    svo.echof("%s", no_def_warning(name))
  end
  local problem = edit_problem(name, d)
  if problem then
    svo.echof("<250,0,0>It can't%s be installed yet: %s.", svo.getDefaultColor(), problem)
  else
    svo.echof("It's ready to install.")
  end
end

-- Installs the change being made to svof's own name. The first time, it
-- says what a change does and asks again (sure)
function defences.edit_install(name, sure)
  if not defences.edits then defences.edits_load() end
  local d = defences.edit_drafts[name]
  if not d then svo.echof("You haven't changed anything in Svof's own %s.", name) return false end
  local problem = edit_problem(name, d)
  if problem then
    svo.echof("<250,0,0>Can't%s change %s: %s.", svo.getDefaultColor(), name, problem)
    return false
  end
  local own, edit, key = own_version(name), edit_of(name)
  -- only what differs from svof's own, and svof's own of that
  local new, was = {}, {}
  for _, field in ipairs(edit_fields) do
    if not (field == 'command' and not own.sendsaction) and not same(d[field], own[field]) then
      if type(d[field]) == 'table' then new[field] = line_list(d[field]) else new[field] = d[field] or false end
      if type(own[field]) == 'table' then was[field] = line_list(own[field]) else was[field] = own[field] end
    end
  end
  if not next(new) then
    defences.edit_drafts[name] = nil
    if edit then return defences.edit_reset(name) end
    svo.echof("That's the same as Svof's own %s, so there's nothing to change.", name)
    return true
  end
  if not edit and not sure then
    svo.echofn("Changing Svof's own %s replaces Svof's version of it, and Svof's updates to %s won't reach you until you reset it. ",
      name, name)
    custom_link("(change it)", string.format("svo.defences.edit_install(%q, true)", name), "Put your change into play",
      'go')
    echo("\n")
    return false
  end
  new.was = was
  local drops = edit_drops_def(name, d)
  defences.edits[key] = defences.edits[key] or {}
  defences.edits[key][name] = new
  defences.edit_drafts[name] = nil
  defences.edits_save()
  if not conf.customdefinitions then
    svo.echof("Saved your change to %s. vconfig customdefinitions is off, so Svof doesn't use it.", name)
  else
    edit_live(name, new)
    svo.echof("Changed Svof's own %s. vcustomdef %s reset puts Svof's back.", name, name)
  end
  if drops then svo.echof("%s", no_def_warning(name)) end
  -- a definition turned into this change goes now
  if defences.edit_converting[name] and defences.custom and defences.custom[name] then
    defences.custom[name] = nil
    defences.custom_save()
    svo.echof("Deleted your definition of %s, which this change replaces.", name)
  end
  defences.edit_converting[name] = nil
  return true
end

-- Puts svof's own version of name back, deleting the change. key, from
-- the list, names another class's change, which is only deleted
function defences.edit_reset(name, key)
  if not defences.edits then defences.edits_load() end
  local here = defs_data[name] and edit_key(defs_data[name])
  key = key or here
  -- a change being made, and not installed, is thrown away
  local draft = key == here and defences.edit_drafts[name]
  local drafted = draft and not draft_installed(name, draft)
  if key == here then defences.edit_drafts[name] = nil end
  local edit = key and defences.edits[key] and defences.edits[key][name]
  if not edit then
    svo.echof(drafted and "Threw away your change to %s." or "You haven't changed Svof's own %s.", name)
    return
  end
  defences.edits[key][name] = nil
  if not next(defences.edits[key]) then defences.edits[key] = nil end
  defences.edits_save()
  if key ~= here then
    svo.echof("Deleted your change to %s for %s.", name, class_title(key))
    return
  end
  if defences.own[name] then edit_live(name, nil) end
  svo.echof("Put Svof's own %s back.", name)
end

-- keeps the change to name after svof updated its own, and stops saying so
function defences.edit_keep(name)
  local edit = edit_of(name)
  if not edit then return end
  local own = own_version(name)
  edit.was = edit.was or {}
  for _, field in ipairs(edit_fields) do
    if edit[field] ~= nil then
      if type(own[field]) == 'table' then edit.was[field] = line_list(own[field]) else edit.was[field] = own[field] end
    end
  end
  defences.edits_save()
  svo.echof("Kept your change to %s.", name)
end

-- Turns a definition saved in another class, whose name is svof's own
-- defence in this one, into a change to svof's own: its lines join svof's,
-- and its command and GMCP name are taken where a change can have them.
-- The definition goes once the change is installed.
defences.edit_converting = defences.edit_converting or {}
function defences.custom_to_change(name)
  local spec = defences.custom and defences.custom[name]
  if not (spec and defences.is_own(name)) then return end
  defences.edit_drafts[name] = nil
  local d, own = edit_draft(name), own_version(name)
  local function add(list, lines)
    for _, l in ipairs(line_list(lines)) do
      if not table.contains(list, l) then list[#list + 1] = l end
    end
  end
  add(d.on, spec.on)
  add(d.off, spec.off)
  for _, field in ipairs(pattern_fields) do add(d[field], spec[field]) end
  if spec.def then
    add(d.def, spec.def)
    d.notondef = nil
  elseif spec.notondef then
    d.def, d.notondef = {}, true
  end
  if spec.command and own.sendsaction then
    d.command = spec.command
  elseif spec.command and spec.command ~= own.command then
    svo.echof("Svof makes %s's command itself, so the one you defined, %s, isn't used.", name, spec.command)
  end
  local mapped = spec.gmcp and svo.dict.sstosvod[spec.gmcp]
  if spec.gmcp and not (mapped and mapped ~= name) then d.gmcp = spec.gmcp end
  defences.edit_converting[name] = true
  svo.echof("Your definition of %s is in a change to Svof's own now. Install it to use it, and the definition goes.", name)
  defences.edit_show(name)
end

-- vcustomdef's list of the changes to svof's own, every class's, and the
-- ones being made
function defences.edits_menu()
  local changes = {}
  for key, names in pairs(defences.edits or {}) do
    for name in pairs(names) do changes[#changes + 1] = { name = name, key = key } end
  end
  for name, d in pairs(defences.edit_drafts) do
    local edit, key = edit_of(name)
    if not edit and not draft_installed(name, d) then changes[#changes + 1] = { name = name, key = key, draft = true } end
  end
  if #changes == 0 then return end
  table.sort(changes, function (a, b) return a.name < b.name or (a.name == b.name and a.key < b.key) end)
  svo.echof("Svof's own defences you changed:")
  for _, c in ipairs(changes) do
    local here = defs_data[c.name] ~= nil and edit_key(defs_data[c.name]) == c.key
    local state = c.draft and "not installed"
      or not here and "not for this class"
      or defences.edit_drafts[c.name] and not draft_installed(c.name, defences.edit_drafts[c.name]) and "changes not installed"
      or defences.own[c.name] and "in use"
      or "not in use, as vconfig customdefinitions is off"
    echo("  ")
    if here then
      custom_link(c.name, string.format("svo.defences.custom_show(%q)", c.name), "See or change " .. c.name)
    else
      echo(c.name)
    end
    echo(string.format(": %s, %s  ", class_title(c.key), state))
    custom_link(c.draft and "discard" or "reset", string.format("svo.defences.edit_reset(%q, %q)", c.name, c.key),
      c.draft and "Throw the change away" or "Delete the change, for Svof's own", 'remove')
    echo("\n")
  end
end

-- the changes to svof's own in a file vcustomdef export wrote
function defences.edits_import(changes, path)
  if not defences.edits then defences.edits_load() end
  local keys = {}
  for key, names in pairs(changes) do
    if type(key) == 'string' and type(names) == 'table' then keys[#keys + 1] = key end
  end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local names = {}
    for name, edit in pairs(changes[key]) do
      if type(name) == 'string' and type(edit) == 'table' then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do
      local edit = changes[key][name]
      local here = defs_data[name] and edit_key(defs_data[name]) == key
      local problem = imported_gmcp_problem(edit.gmcp)
      -- a GMCP name this class gives another defence, as edit_problem refuses
      local mapped = here and type(edit.gmcp) == 'string' and svo.dict.sstosvod[edit.gmcp:lower()]
      if not problem and mapped and mapped ~= name then
        problem = "GMCP's " .. edit.gmcp:lower() .. " is Svof's " .. mapped
      end
      -- its patterns, which must read, and for this class, a clash
      if not problem then
        problem = patterns_problem(edit, here and function (field, p) return table.contains(own_version(name)[field], p) end)
      end
      if not problem and here then problem = defences.clash(name, edit_parts(name, edit)) end
      if defences.edits[key] and defences.edits[key][name] then
        svo.echof("You already changed Svof's own %s, so the change in %s isn't used.", name, path)
      elseif problem then
        svo.echof("Didn't import the change to Svof's own %s from %s: %s.", name, path, problem)
      else
        if type(changes[key][name].gmcp) == 'string' then changes[key][name].gmcp = changes[key][name].gmcp:lower() end
        defences.edits[key] = defences.edits[key] or {}
        defences.edits[key][name] = changes[key][name]
        if conf.customdefinitions and defs_data[name] and edit_key(defs_data[name]) == key then
          edit_live(name, changes[key][name])
        end
        svo.echof("Added the change to Svof's own %s from %s.", name, path)
      end
    end
  end
  defences.edits_save()
end

-- Copies of svof's own defences from other classes (the user, 2026-10-10):
-- for a defence the game gave a class svof's list is out of date for, or
-- one an artefact gives every class, as the phylactery's mindnet does. A
-- copy is a definition (copy, in the definition's table) started from
-- svof's own version in another class, defences.catalog: its lines, DEF
-- line, GMCP name, command and balance, and its other lines and patterns
-- kept as they are. Only a defence svof raises by sending its command and
-- tracks by its lines can be copied: svof's other rules for it, such as
-- the defences it can't be up with, don't come with a copy. Artefact
-- versions so far have the GMCP name of the class's (the user,
-- 2026-10-10).
local copy_rules = {
  tracked = "Svof only tracks it there, it doesn't raise it",
  own_code = "Svof's action for it there does more than send its command",
  ongot = "gaining it changes your other defences or afflictions",
  onlost = "losing it changes your other defences or afflictions",
  onenable = "it can't be up with some of your other defences",
  specialskip = "Svof holds off raising it at times",
  ondef = "Svof reads what its DEF line says",
  handlers = "Svof handles its lines with code of its own",
  wait = "Svof waits for it after its command",
}
local item_configs = { mindnet = 'havemindnet', lifevision = 'havelifevision', shroud = 'haveshroud' }

-- why svof's own version v of name can't be copied, or nil
local function copy_refusal(name, v)
  if item_configs[name] then
    return string.format("it comes with an item, and vconfig %s adds Svof's own for that", item_configs[name])
  end
  local why = {}
  for _, rule in ipairs(v.rules or {}) do
    if rule == 'balances' then
      why[#why + 1] = "Svof raises it with " .. svo.concatand(v.raisedwith or {}) .. ", not a command"
    elseif rule == 'counted' then
      why[#why + 1] = string.format("Svof counts it with your other %s defences", tostring(v.counted))
    elseif copy_rules[rule] then
      why[#why + 1] = copy_rules[rule]
    else
      why[#why + 1] = "Svof does more with it than a copy can carry"
    end
  end
  if defences.prompt_decides[name] then
    why[#why + 1] = "Svof decides on each prompt whether it's a defence or an affliction"
  end
  if outside_rules[name] then why[#why + 1] = "Svof keeps " .. outside_rules[name] end
  if #why == 0 and type(v.command) ~= 'string' then why[#why + 1] = "Svof has no command for it" end
  if #why > 0 then return svo.concatand(why) end
end

-- the version of name from class, or nil, and its place in the list
local function version_from(name, class)
  for i, v in ipairs(defences.catalog()[name] or {}) do
    for _, c in ipairs(v.classes or {}) do
      if c == class then return v, i end
    end
  end
end

-- why a copy can't be installed, or nil: svof's own in the class it came
-- from has to be one a copy can carry
function defences.copy_problem(name, spec)
  local v = version_from(name, spec.copy.from)
  if not v then return string.format("Svof doesn't have %s for %s, which it was copied from", name, tostring(spec.copy.from)) end
  local why = copy_refusal(name, v)
  if why then return "it can't be copied: " .. why end
end

-- svof's own version v, as a copy keeps it to tell when it changes
local copy_fields = { 'type', 'command', 'balanceless', 'gmcp', 'notondef', 'on', 'off', 'def', 'onr', 'offr',
  'defr', 'on_only', 'on_free', 'off_free', 'offs' }
local function copy_was(v)
  local was = {}
  for _, field in ipairs(copy_fields) do
    if type(v[field]) == 'table' then was[field] = line_list(v[field]) else was[field] = v[field] end
  end
  return was
end

local function copy_same(a, b)
  for _, field in ipairs(copy_fields) do
    if not same(a[field], b[field]) then return false end
  end
  return true
end

-- vcustomdef <name> copy: svof's own versions of name in other classes,
-- each a link to copy it
function defences.copy_offer(name)
  if defences.is_own(name) then
    svo.echof("Svof has its own %s in this class, so there's nothing to copy. vcustomdef %s changes it.", name, name)
    return
  end
  local versions = defences.catalog()[name]
  if not versions then
    svo.echof("Svof doesn't have a defence called %s in any class, so define it with vcustomdef %s.", name, name)
    return
  end
  svo.echof("Svof has its own %s for %s, so it can't be defined again. If you have it as %s too, or from an artefact, copy Svof's own:",
    name, class_names(versions), tostring(me.class))
  for i, v in ipairs(versions) do
    echo(string.format("  for %s: %s  ", class_names({ v }),
      type(v.command) == 'string' and string.format("raised with %q", v.command) or "not raised by a command"))
    local why = copy_refusal(name, v)
    if why then
      echo("can't be copied: " .. why .. "\n")
    else
      custom_link("copy it", string.format("svo.defences.copy_own(%q, %d)", name, i),
        "Copy Svof's own " .. name .. " for " .. class_names({ v }), 'go')
      echo("\n")
    end
  end
end

-- Starts a copy of svof's own name, the ith version: into the definition
-- of name if there is one, keeping its class and skillset, and the lines
-- one the player defined had
function defences.copy_own(name, i)
  local versions = defences.catalog()[name]
  local v = versions and versions[tonumber(i) or 1]
  if not v or defences.is_own(name) then
    svo.echof("Svof doesn't have %s in another class to copy.", name)
    return
  end
  local why = copy_refusal(name, v)
  if why then
    svo.echof("Can't copy Svof's own %s: %s.", name, why)
    return
  end
  local had = defences.custom_drafts[name] or defences.custom[name]
  local d = { class = had and had.class or class_key(me.class), command = v.command,
    balanceless = v.balanceless, gmcp = v.gmcp, notondef = v.notondef,
    on = line_list(v.on), off = line_list(v.off),
    copy = { from = v.classes[1], was = copy_was(v), lines = {} } }
  local defs = line_list(v.def)
  d.def = table.remove(defs, 1)
  if #defs > 0 then d.copy.lines.def = defs end
  -- svof's patterns, which the copy shows and can change, and its other
  -- lines, kept as they are
  for _, field in ipairs(pattern_fields) do
    if v[field] then d[field] = line_list(v[field]) end
  end
  for _, field in ipairs(copy_line_fields) do
    if field ~= 'def' and not kind_of[field] and v[field] then d.copy.lines[field] = line_list(v[field]) end
  end
  if had and had.skillset then
    d.skillset = had.skillset
  elseif d.class ~= 'all' and table.contains(class_skills(d.class) or {}, v.type) then
    d.skillset = v.type
  end
  -- a definition the player made of it: its lines join svof's
  if had and type(had.copy) ~= 'table' then
    for _, field in ipairs({ 'on', 'off', 'onr', 'offr', 'defr' }) do
      for _, l in ipairs(line_list(had[field])) do
        d[field] = d[field] or {}
        if not table.contains(d[field], l) then d[field][#d[field] + 1] = l end
      end
    end
    if not d.def and had.def then d.def = had.def end
  end
  if had then class_chosen[name] = true end
  defences.custom_drafts[name] = d
  svo.echof("Copied Svof's own %s for %s. Check it, and install it to use it.", name, class_names({ v }))
  defences.custom_show(name)
end

-- After a copy registers as svof loads: says if svof's own has changed
-- since it was copied, or isn't in that class any more
function defences.copy_check(name)
  local spec = defences.custom[name]
  local v, i = version_from(name, spec.copy.from)
  if not v then
    svo.echofn("Svof doesn't have %s for %s any more. Your copy of it is still in use. ", name,
      class_names({ { classes = { tostring(spec.copy.from) } } }))
    custom_link("(delete it)", string.format("svo.defences.custom_delete(%q)", name), "Delete your copy of " .. name,
      'remove')
    echo("\n")
    return
  end
  if copy_same(spec.copy.was or {}, v) then return end
  svo.echofn("Svof has updated its own %s since you copied it. Your copy is still in use: ", name)
  custom_link("see Svof's", string.format("svo.defences.copy_offer(%q)", name), "See Svof's own " .. name)
  echo(", ")
  custom_link("copy it again", string.format("svo.defences.copy_own(%q, %d)", name, i), "Copy Svof's own again, to install")
  echo(", ")
  custom_link("keep yours", string.format("svo.defences.copy_keep(%q)", name), "Keep your copy, and stop saying so")
  echo("\n")
end

-- keeps a copy after svof updated its own, and stops saying so
function defences.copy_keep(name)
  local spec = defences.custom[name]
  local v = spec and type(spec.copy) == 'table' and version_from(name, spec.copy.from)
  if not v then return end
  spec.copy.was = copy_was(v)
  defences.custom_save()
  svo.echof("Kept your copy of %s.", name)
end

end -- end of svo customdefs loader

if svo.systemloaded then svo.loader.customdefs() end
