--[[
What each herb's empty handler rules out, now that svo.dict_setup derives
empty.herb_affs from the entries' eatcure instead of a hand-written table in
Empty_cure_handling.lua.

It runs svof's real loaders through tools/svof_world.lua, for every class:

  * the derived lists are the hand-written table they replace, name for name
  * each list is sorted and holds a name once
  * an empty eat of each herb takes herb balance once and rules out its whole
    list, and nothing else
  * running dict_setup again keeps the same tables and doesn't double a name
  * a new entry joins its herb's list, and leaves it when it's gone; a block
    that puts a defence up doesn't
  * an affliction a player defines stays out of the lists, and an empty kelp
    still rules it out once, through empty.defined

  lua tools/test_herb_cures.lua
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

-- the hand-written table this replaces, as it was on in-client-svof at
-- 63186305
local BEFORE = {
  goldenseal = {'dissonance', 'impatience', 'stupidity', 'dizziness', 'epilepsy', 'shyness', 'depression',
   'shadowmadness', 'mycalium', 'sandfever', 'fulminated', 'unweavingmind'},
  kelp = {'asthma', 'healthleech', 'sensitivity', 'clumsiness', 'weakness', 'parasite', 'rebbies'},
  lobelia = {'claustrophobia', 'recklessness', 'agoraphobia', 'loneliness', 'masochism', 'vertigo', 'guilt', 'spiritburn', 'tenderskin', 'horror',
   'hypochondria', 'madness'},
  ginseng = {'haemophilia', 'darkshade', 'relapsing', 'addiction', 'illness', 'lethargy', 'flushings', 'unweavingbody'},
  ash = {'hallucinations', 'hypersomnia', 'confusion', 'paranoia', 'dementia', 'crescendo'},
  bellwort = {'generosity', 'pacifism', 'justice', 'inlove', 'peace', 'pyre', 'retribution', 'timeloop', 'indifference'},
  bloodroot = {'paralysis', 'slickness', 'pyramides'},
}

local function sorted_copy(t)
  local c = {}
  for i, v in ipairs(t) do c[i] = v end
  table.sort(c)
  return c
end

local function joined(t) return table.concat(t, ",") end

local function keys(t)
  local k = {}
  for name in pairs(t) do k[#k + 1] = name end
  table.sort(k)
  return k
end

local classes = {}
do
  local w = world.new({ class = "Infernal" })
  for class in pairs(w.svo.knownskills) do classes[#classes + 1] = class end
  table.sort(classes)
end
eq(#classes > 20, true, "every class is read")

for _, class in ipairs(classes) do
  local w = world.new({ class = class })
  local svo = w.svo
  local herb_affs = svo.empty.herb_affs
  eq(joined(keys(herb_affs)), joined(keys(BEFORE)), class .. ": the same seven herbs")

  for herb, before in pairs(BEFORE) do
    local list = herb_affs[herb]
    eq(joined(list), joined(sorted_copy(before)), class .. ": " .. herb .. " rules out what it did")
    local seen, sorted = {}, true
    for i, name in ipairs(list) do
      if seen[name] then eq(name, nil, class .. ": " .. herb .. " lists a name once") end
      seen[name] = true
      if i > 1 and list[i - 1] > name then sorted = false end
    end
    eq(sorted, true, class .. ": " .. herb .. "'s list is sorted")

    -- an empty eat: herb balance once, its list ruled out, nothing else
    for _, name in ipairs(list) do svo.addaffdict(svo.dict[name]) end
    local other = herb == 'kelp' and 'paralysis' or 'weakness'
    svo.addaffdict(svo.dict[other])
    local lost, lostbal_herb = 0, svo.lostbal_herb
    svo.lostbal_herb = function(...) lost = lost + 1 return lostbal_herb(...) end
    svo.empty['eat_' .. herb]()
    svo.lostbal_herb = lostbal_herb
    eq(lost, 1, class .. ": an empty " .. herb .. " takes herb balance once")
    local left = {}
    for _, name in ipairs(list) do if svo.affs[name] then left[#left + 1] = name end end
    eq(joined(left), "", class .. ": an empty " .. herb .. " rules out its whole list")
    eq(not not svo.affs[other], true, class .. ": and keeps " .. other)
    svo.rmaff(other)
  end
end

do -- dict_setup again: the same tables, no name twice
  local w = world.new()
  local svo = w.svo
  local kelp = svo.empty.herb_affs.kelp
  local before = joined(kelp)
  svo.dict_setup()
  svo.dict_setup()
  eq(svo.empty.herb_affs.kelp, kelp, "dict_setup keeps kelp's table")
  eq(joined(kelp), before, "and lists each name once")
end

do -- an entry added to the dictionary, and taken out
  local w = world.new()
  local svo = w.svo
  svo.dict.testkelpy = {
    herb = { eatcure = { 'kelp', 'aurum' }, isadvisable = function() return false end, oncompleted = function() end },
    aff = { oncompleted = function() svo.addaffdict(svo.dict.testkelpy) end },
    gone = { oncompleted = function() svo.rmaff('testkelpy') end },
  }
  -- a block that puts a defence up cures nothing
  svo.dict.testkelpdef = {
    herb = { def = true, eatcure = { 'kelp', 'aurum' }, isadvisable = function() return false end, oncompleted = function() end },
  }
  svo.dict_setup()
  local listed = joined(svo.empty.herb_affs.kelp)
  eq(("," .. listed .. ","):find(",testkelpy,", 1, true) ~= nil, true, "a new kelp entry joins kelp's list")
  eq(("," .. listed .. ","):find(",testkelpdef,", 1, true), nil, "a kelp defence doesn't")
  svo.addaffdict(svo.dict.testkelpy)
  svo.empty.eat_kelp()
  eq(svo.affs.testkelpy, nil, "so an empty kelp rules it out")
  svo.dict.testkelpy, svo.dict.testkelpdef = nil, nil
  svo.dict_setup()
  eq(("," .. joined(svo.empty.herb_affs.kelp) .. ","):find(",testkelpy,", 1, true), nil, "and it leaves once it's gone")
end

do -- an affliction a player defines: empty.defined rules it out, once
  local w = world.new({ class = "Monk" })
  local svo, A = w.svo, w.svo.afflictions
  svo.conf.customdefinitions = true
  A.drafts.itchy = { cures = "Eat Kelp / Eat Aurum", gain = { "You feel itchy all over." } }
  eq(A.install("itchy"), true, "a kelp affliction installs")
  eq(svo.dict.itchy.playerdefined, true, "marked as a player's")
  eq(("," .. joined(svo.empty.herb_affs.kelp) .. ","):find(",itchy,", 1, true), nil, "and kept out of kelp's list")
  for _, how in ipairs({ "its own empty kelp", "weakness's empty kelp" }) do
    svo.addaffdict(svo.dict.itchy)
    svo.addaffdict(svo.dict.weakness)
    local ruled, rmaff = 0, svo.rmaff
    svo.rmaff = function(which)
      if which == "itchy" then ruled = ruled + 1 end
      return rmaff(which)
    end
    if how == "its own empty kelp" then svo.dict.itchy.herb.empty() else svo.dict.weakness.herb.empty() end
    svo.rmaff = rmaff
    eq(ruled, 1, how .. " rules it out once")
    eq(svo.affs.itchy, nil, how .. " leaves it gone")
  end
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
