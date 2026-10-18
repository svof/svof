--[[
Writes, or checks, src/resources/defence_catalog.lua: svof's own defences
that only some classes have, with what each class's version holds.

svof builds only the class it loads, so at runtime it can't tell that a
name is one of its own defences in another class, or copy that defence
into this one. The catalog is how: vcustomdef refuses to define a name in
it, and offers to copy svof's own instead, for a class svof's list is out
of date for, or a defence an artefact gives every class.

It runs svof's real loaders for every class svof knows (svo.knownskills),
through tools/svof_world.lua, so every skillset gate in the source decides
what a class has, exactly as it does in Mudlet. A defence every class has
is left out. One a class has differently from another, such as bear in
Tekura and in Metamorphosis, gets a version for each.

A version holds the defence's lines, its GMCP name, the command svof
sends and whether that takes balance, and, under rules, what else svof
does with it that a copy can't carry:
  tracked      svof doesn't raise it, only tracks it
  balances     svof raises it with another balance, such as smoke
  own_code     svof's own action for it does more than send its command
  ongot, onlost, onenable, specialskip, ondef
               a function on its record
  counted      svof counts it with a group, such as the channels
  handlers     hand-written handlers for its lines
  wait         svof waits for it after its command

It writes src/resources/prio_catalog.lua as well: every action with a
priority that only some classes have, defences or not, by balance, named
as the saved priority lists name them. svof saves its priorities from
the class it's in, and keeps the saved place of a name in this list that
the class doesn't have, for when the player is back in one that does. A
name no class has is dropped. svo.knownskills has the None class, which
svof loads for a class it doesn't know, so it's compared too.

  lua tools/defence_catalog.lua           check both files are current
  lua tools/defence_catalog.lua --write   write them

The check fails when the source has moved on and a file hasn't, the
same way tools/derived_lists_baseline.json does: regenerate them in the
commit that changes a defence or an action.
]]

local world = dofile("tools/svof_world.lua")

local OUT = "src/resources/defence_catalog.lua"
local PRIO_OUT = "src/resources/prio_catalog.lua"
-- the balances the saved priority lists hold (prio.export), but slow
-- curing, which names an action with its balance
local PRIO_BALANCES = { "herb", "smoke", "salve", "sip", "purgative", "physical", "focus", "moss", "misc" }
local LINE_FIELDS = { "on", "off", "def", "onr", "offr", "defr", "on_only", "on_free", "off_free", "offs" }
local RECORD_FUNCTIONS = { "ongot", "onlost", "onenable", "specialskip", "ondef" }

local function list(v)
  if type(v) == "string" then return { v } end
  local t = {}
  if type(v) == "table" then
    for i, l in ipairs(v) do t[i] = l end
  end
  return t
end

-- every class svof knows, by the name the game gives it
local classes = {}
do
  local w = world.new({ class = "Infernal" })
  for class in pairs(w.svo.knownskills) do classes[#classes + 1] = class end
  table.sort(classes)
end

local function title(class)
  return (class:gsub("(%a)(%a*)", function(a, b) return a:upper() .. b end))
end

-- one class's version of a defence
local function version(svo, name, rec)
  local v = { type = rec.type, rules = {} }
  for _, f in ipairs(LINE_FIELDS) do
    local l = list(rec[f])
    if #l > 0 then v[f] = l end
  end
  v.notondef = rec.invisibledef and true or nil
  v.nodef = rec.nodef and true or nil
  v.gmcp = svo.dict.svotossd[name] or nil
  local entry = svo.dict[name]
  local phys = type(entry) == "table" and type(entry.physical) == "table" and entry.physical or nil
  if phys then
    v.command = phys.action
    v.balanceless = phys.balanceless_act and true or nil
    if not phys.sendsaction then v.rules[#v.rules + 1] = "own_code" end
  end
  local others = {}
  if type(entry) == "table" then
    for bal, act in pairs(entry) do
      if type(act) == "table" and act.def and bal ~= "physical" then others[#others + 1] = bal end
    end
  end
  table.sort(others)
  if #others > 0 then
    v.rules[#v.rules + 1] = "balances"
    v.raisedwith = others
  elseif not phys then
    v.rules[#v.rules + 1] = "tracked"
  end
  for _, f in ipairs(RECORD_FUNCTIONS) do
    if type(rec[f]) == "function" then v.rules[#v.rules + 1] = f end
  end
  if rec.custom_def_type then
    v.rules[#v.rules + 1] = "counted"
    v.counted = rec.custom_def_type
  end
  for _, h in ipairs({ "got_", "lost_" }) do
    if svo.defs[h .. name] and not (svo.defences.generated or {})[h .. name] then
      v.rules[#v.rules + 1] = "handlers"
      break
    end
  end
  if svo.defences.waits[name] then v.rules[#v.rules + 1] = "wait" end
  table.sort(v.rules)
  if #v.rules == 0 then v.rules = nil end
  return v
end

-- ===== a stable text of a table, keys sorted =====

local function ser(v, indent)
  if type(v) == "string" then return string.format("%q", v) end
  if type(v) ~= "table" then return tostring(v) end
  local n = #v
  local parts = {}
  if n > 0 then
    for i = 1, n do parts[i] = ser(v[i], indent) end
    return "{ " .. table.concat(parts, ", ") .. " }"
  end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys)
  local inner = indent .. "  "
  for _, k in ipairs(keys) do
    local key = k:find("^[%a_][%w_]*$") and k or string.format("[%q]", k)
    parts[#parts + 1] = inner .. key .. " = " .. ser(v[k], inner)
  end
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end

-- ===== every class =====

-- the names in a class's priority lists, by balance, into had
local prio_had = {}
local function prio_names(svo)
  local lists = { slowcuring = svo.make_sync_prio_table("%s_%s") }
  for _, b in ipairs(PRIO_BALANCES) do lists[b] = svo.make_prio_table(b) end
  for balance, list in pairs(lists) do
    prio_had[balance] = prio_had[balance] or {}
    for _, name in pairs(list) do prio_had[balance][name] = (prio_had[balance][name] or 0) + 1 end
  end
end

local by_name, seen_in = {}, {}
for _, class in ipairs(classes) do
  local w = world.new({ class = title(class) })
  local svo = w.svo
  prio_names(svo)
  for name, rec in svo.defs_data:iter() do
    seen_in[name] = (seen_in[name] or 0) + 1
    local v = version(svo, name, rec)
    local key = ser(v, "")
    by_name[name] = by_name[name] or {}
    local versions = by_name[name]
    if not versions[key] then versions[key] = { data = v, classes = {} } end
    local c = versions[key].classes
    c[#c + 1] = class
  end
end

local catalog = {}
for name, versions in pairs(by_name) do
  if seen_in[name] < #classes then
    local out = {}
    for _, ver in pairs(versions) do
      ver.data.classes = ver.classes
      out[#out + 1] = ver.data
    end
    -- by their first class, which is the order a player sees them in
    table.sort(out, function (a, b) return a.classes[1] < b.classes[1] end)
    catalog[name] = out
  end
end

local text = "-- svof's own defences that only some classes have, and each class's\n"
  .. "-- version of them. Generated by tools/defence_catalog.lua from the\n"
  .. "-- defence records and dictionary, for every class: don't edit it, run\n"
  .. "--   lua tools/defence_catalog.lua --write\n"
  .. "return " .. ser(catalog, "") .. "\n"

local count, versions = 0, 0
for _, vs in pairs(catalog) do
  count = count + 1
  versions = versions + #vs
end

-- the names some classes have and the rest don't, one a line
local all = #classes
local prio_balances, prio_count, prio_parts = {}, 0, {}
for balance in pairs(prio_had) do prio_balances[#prio_balances + 1] = balance end
table.sort(prio_balances)
for _, balance in ipairs(prio_balances) do
  local names = {}
  for name, n in pairs(prio_had[balance]) do
    if n < all then names[#names + 1] = name end
  end
  table.sort(names)
  if #names > 0 then
    prio_count = prio_count + #names
    for i, name in ipairs(names) do names[i] = string.format("    %q", name) end
    prio_parts[#prio_parts + 1] = "  " .. balance .. " = {\n" .. table.concat(names, ",\n") .. "\n  }"
  end
end
local prio_text = "-- svof's own actions with a priority that only some classes have, by\n"
  .. "-- balance, named as the saved priority lists name them. Generated by\n"
  .. "-- tools/defence_catalog.lua from the dictionary, for every class: don't\n"
  .. "-- edit it, run\n"
  .. "--   lua tools/defence_catalog.lua --write\n"
  .. "return {\n" .. table.concat(prio_parts, ",\n") .. "\n}\n"

local outputs = {
  { OUT, text, string.format("%d defences, %d versions, from %d classes", count, versions, #classes) },
  { PRIO_OUT, prio_text, string.format("%d actions in %d balances, from %d classes", prio_count, #prio_parts,
    #classes) },
}

if (arg or {})[1] == "--write" then
  for _, o in ipairs(outputs) do
    local f = assert(io.open(o[1], "wb"))
    f:write(o[2])
    f:close()
    print(string.format("wrote %s: %s", o[1], o[3]))
  end
  os.exit(0)
end

local stale = false
for _, o in ipairs(outputs) do
  local f = io.open(o[1], "rb")
  local have = f and f:read("*a") or ""
  if f then f:close() end
  -- compare content, not line endings: a Windows checkout has CRLF
  if have:gsub("\r\n", "\n") ~= o[2] then
    print(string.format("FAIL: %s is out of date with src/. Run lua tools/defence_catalog.lua --write and commit it.", o[1]))
    stale = true
  else
    print(string.format("OK: %s is current: %s", o[1], o[3]))
  end
end
if stale then os.exit(1) end
