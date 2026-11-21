--[[
The herb and smoke cure-line maps in Main trigger functions, derived from the
dictionary's entries (cure_groups) instead of two literal tables.

A cure line ("<aff> is cured") claims the action svof has in flight for aff,
or else the one it sent with the same herb or pipe for another affliction. The
group of afflictions that share a herb or pipe is what decides that, and the
handlers svo.valid.herb_cured_<aff> and svo.valid.smoke_cured_<aff> are made
from it.

For every class svof knows, through tools/svof_world.lua, this checks:

  * each herb's and pipe's group, read from the handlers made for it, is
    the old literal table plus the three unweaving afflictions (the one
    intended change), so no handler that was made is lost and nothing else
    joins a group: no defence (def = true), no anti-illusion probe
  * every svo.valid.herb_cured_* and smoke_cured_* a trigger under
    src/triggers calls exists
  * checkasthma, whose cure block is on a pipe, has no smoke_cured handler
    and is in no group
  * with unweavingbody's ginseng in flight, haemophilia's cure line claims
    it. Before, unweavingbody was in no group, so the line found nothing in
    flight and the action hung

The groups are read from the handlers' own upvalues (herbname, pipe), so this
needs no public table that only a test would use.

  lua tools/test_cure_line_maps.lua
]]

local world = dofile("tools/svof_world.lua")

-- the literal tables the derivation replaced, as they were
local OLD = {
  herb = {
    ash        = {'hallucinations', 'hypersomnia', 'confusion', 'paranoia', 'dementia', 'crescendo'},
    bellwort   = {'generosity', 'pacifism', 'justice', 'inlove', 'peace', 'pyre', 'retribution', 'timeloop', 'indifference'},
    bloodroot  = {'paralysis', 'slickness', 'pyramides'},
    ginger     = {'melancholichumour', 'cholerichumour', 'phlegmatichumour', 'sanguinehumour'},
    ginseng    = {'haemophilia', 'darkshade', 'relapsing', 'addiction', 'illness', 'lethargy', 'flushings'},
    goldenseal = {'dissonance', 'impatience', 'stupidity', 'dizziness', 'epilepsy', 'shyness', 'depression', 'shadowmadness', 'mycalium', 'sandfever', 'fulminated'},
    kelp       = {'asthma', 'healthleech', 'sensitivity', 'clumsiness', 'weakness', 'parasite', 'rebbies'},
    lobelia    = {'claustrophobia', 'recklessness', 'agoraphobia', 'loneliness', 'masochism', 'vertigo', 'guilt', 'tenderskin', 'spiritburn', 'horror', 'hypochondria', 'madness'},
  },
  smoke = {
    valerian = {'disloyalty', 'slickness', 'manaleech', 'hellsight'},
    pear     = {'pressure'},
    elm      = {'deadening', 'aeon', 'tension', 'earworm'},
  },
}
-- what joins them: the afflictions the dictionary says each cures, that the
-- old tables left out
local JOINED = {
  herb = { ginseng = {'unweavingbody'}, goldenseal = {'unweavingmind'} },
  smoke = { elm = {'unweavingspirit'} },
}
local UPVALUE = { herb = "herbname", smoke = "pipe" }
-- handlers written out by hand, which no group makes: insomnia is a defence
-- goldenseal strips, and its herb block is def, so no group takes it
local HAND_WRITTEN = { herb_cured_insomnia = true }

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local function expected_group(balance, item)
  local t = {}
  for _, n in ipairs(OLD[balance][item]) do t[#t + 1] = n end
  for _, n in ipairs((JOINED[balance] or {})[item] or {}) do t[#t + 1] = n end
  table.sort(t)
  return table.concat(t, ",")
end

local function upvalue(f, name)
  for i = 1, 60 do
    local n, v = debug.getupvalue(f, i)
    if not n then return nil end
    if n == name then return v end
  end
end

-- {item = "a,b,c"} for the handlers of balance, plus the handler names read
-- by hand that name no item
local function groups_of(svo, balance)
  local by_item, unowned = {}, {}
  local prefix = balance .. "_cured_"
  for key, f in pairs(svo.valid) do
    if type(key) == "string" and key:sub(1, #prefix) == prefix and type(f) == "function" then
      local item = upvalue(f, UPVALUE[balance])
      if item then
        by_item[item] = by_item[item] or {}
        table.insert(by_item[item], key:sub(#prefix + 1))
      elseif not HAND_WRITTEN[key] then
        unowned[#unowned + 1] = key
      end
    end
  end
  for item, names in pairs(by_item) do
    table.sort(names)
    by_item[item] = table.concat(names, ",")
  end
  return by_item, unowned
end

-- every class svof knows
local classes = {}
do
  local w = world.new({ class = "Infernal" })
  for class in pairs(w.svo.knownskills) do classes[#classes + 1] = class end
  table.sort(classes)
end
eq(#classes >= 10, true, "svof knows its classes")

local seen_in_a_class = {}
for _, class in ipairs(classes) do
  local w = world.new({ class = class })
  local svo = w.svo
  for _, balance in ipairs({ "herb", "smoke" }) do
    local got, unowned = groups_of(svo, balance)
    eq(#unowned, 0, class .. ": every " .. balance .. "_cured_ handler comes from a group (" .. table.concat(unowned, ",") .. ")")
    local items = {}
    for item in pairs(OLD[balance]) do items[#items + 1] = item end
    table.sort(items)
    for _, item in ipairs(items) do
      eq(got[item], expected_group(balance, item), class .. ": " .. item .. "'s group")
    end
    for item in pairs(got) do
      eq(OLD[balance][item] ~= nil, true, class .. ": " .. item .. " is a " .. balance .. " that had a group")
    end
  end

  -- a probe is in no group, and its handler is not made
  eq(svo.valid.smoke_cured_checkasthma, nil, class .. ": no smoke_cured_checkasthma")
  eq(svo.valid.herb_cured_checkasthma, nil, class .. ": no herb_cured_checkasthma")
  for _, balance in ipairs({ "herb", "smoke" }) do
    for item, names in pairs((groups_of(svo, balance))) do
      for name in names:gmatch("[^,]+") do
        eq(svo.anti_illusion_probes[name], nil, class .. ": " .. name .. " is a probe and is in " .. item .. "'s group")
      end
    end
  end
  seen_in_a_class[class] = true
end

-- every handler a trigger calls exists, in every class that makes them
do
  local called = {}
  local files = io.popen('git ls-files -- "src/triggers/*.lua" "src/triggers/*.json" "src/aliases/*.lua" "src/aliases/*.json"')
  local nfiles = 0
  for path in files:lines() do
    local f = io.open(path, "r")
    if f then
      local text = f:read("*a")
      f:close()
      nfiles = nfiles + 1
      for _, prefix in ipairs({ "herb_cured_", "smoke_cured_" }) do
        for name in text:gmatch("valid%." .. prefix .. "([%w_]+)") do called[prefix .. name] = path end
      end
    end
  end
  files:close()
  local n = 0
  for _ in pairs(called) do n = n + 1 end
  eq(nfiles > 100, true, "read the trigger scripts (" .. nfiles .. " files)")
  eq(n > 40, true, "found the herb and smoke cure calls (" .. n .. ")")

  -- a class's own affliction has its trigger enabled only for that class, so
  -- a name needs to exist in some class, and in every class that has its entry
  local made = {}
  for _, class in ipairs(classes) do
    local svo = world.new({ class = class }).svo
    for key in pairs(svo.valid) do made[key] = true end
  end
  for name, path in pairs(called) do
    eq(made[name], true, path .. " calls svo.valid." .. name .. ", which no class makes")
  end
end

-- the behaviour change: svof eats ginseng for unweavingbody and the game cures
-- haemophilia instead, which ginseng also takes. The cure line claims the
-- action in flight and puts haemophilia's in its place.
do
  local w = world.new()
  local svo = w.svo
  w.env.getStopWatchTime = function() return 1 end
  svo.addaffdict(svo.dict.unweavingbody)
  svo.addaffdict(svo.dict.haemophilia)
  svo.doaction(svo.dict.unweavingbody.herb)
  eq(w.inflight(), "unweavingbody_herb", "unweavingbody's ginseng is in flight")
  svo.valid.herb_cured_haemophilia()
  eq(w.inflight(), "haemophilia_herb", "haemophilia's cure line claims it")
  w.prompt()
  eq(svo.affs.haemophilia, nil, "and haemophilia is cured")
  eq(not not svo.affs.unweavingbody, true, "while unweavingbody stays")
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
