--[[
Tests tools/dict_behaviour.lua, the behavioural description of every
svo.dict entry that tools/compare_dict_behaviour.py compares between two
revisions.

A gate for rewriting entries is only worth something if it says "same" for
a rewrite that does the same thing, says "different" for one that doesn't,
and says where. So this loads the real dictionary, plants changes in a copy
of its source (svof_world's patch option), and checks both:

  * rewrites that change nothing describe the same: conditions checked in
    another order, an entry written as a constructor over its own name (the
    shape basicaff and basicdef conversions take), two independent
    statements swapped, and a read whose value is ignored
  * mistakes are caught, in exactly the states they change: a name dropped
    from fillskullcap's list of afflictions that hold it back (the check
    the single-source plan asks for), weakness's in-flight guard dropped, a
    pipe swapped, a balance swapped, a cure list reordered, a counted
    unknown no longer taken down, rmaff replaced by clearing affs, and
    darkshade's oldhp check reversed, which only an argument shows
  * the model it rests on: which inputs weakness's isadvisable has and what
    it gives in each state, descriptions the same on a second run, and the
    same whichever order the entries are described in
  * B.against on this tree against itself finds nothing

It proves the harness, not svof: nothing here is about Mudlet or the game.

Run: lua tools/test_dict_behaviour.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local B = dofile("tools/dict_behaviour.lua")

local checks, failures = 0, 0
local function check(desc, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL " .. desc .. (detail and (": " .. tostring(detail)) or ""))
  end
end

local CLASS = "Infernal"
local base = B.new({ class = CLASS })

-- A copy of svof with edits to the dictionary's source, each a plain-text
-- replacement inside one entry ("\n    <name> = {" up to the next entry),
-- which must appear there exactly once.
local function patched(edits)
  return B.new({ class = CLASS, patch = function(name, src)
    if name ~= "dict" then return src end
    for _, e in ipairs(edits) do
      local entry, old, new = e[1], e[2], e[3]
      local head = "\n    " .. entry .. " = {\n"
      local s = src:find(head, 1, true)
      assert(s, "no entry " .. entry .. " in the dictionary")
      local stop = src:find("\n    [%w_]+ = [{(]", s + #head) or #src
      local a, b = src:find(old, s, true)
      assert(a and b <= stop, "not found in " .. entry .. ": " .. old)
      local again = src:find(old, b + 1, true)
      assert(not (again and again <= stop), "more than once in " .. entry .. ": " .. old)
      src = src:sub(1, a - 1) .. new .. src:sub(b + 1)
    end
    return src
  end })
end

-- the real table of an entry, from its "{" to its closing "}"
local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local f = assert(io.open(DICT, "r"))
local source = f:read("*a"):gsub("\r\n", "\n")
f:close()
local function entry_table(name)
  local head = "\n    " .. name .. " = "
  local s = source:find(head .. "{\n", 1, true)
  assert(s, "no entry " .. name)
  local body = source:match("^%b{}", s + #head)
  assert(body, "no closing brace for " .. name)
  return body
end

local function differences(other, name)
  local items = B.compare(base, other, name)
  local by = {}
  for _, item in ipairs(items or {}) do by[item.key] = item end
  return by, items
end

local function keys(by)
  local r = {}
  for k in pairs(by) do r[#r + 1] = k end
  table.sort(r)
  return table.concat(r, ", ")
end

local function contains(list, x)
  for _, v in ipairs(list) do if v == x then return true end end
  return false
end

-- ===== the model =====

do
  local d, found = base.describe("weakness")
  local f = found["weakness.herb.isadvisable"]
  check("weakness's herb isadvisable is described in full", f and not f.partial)
  check("its inputs are its own actions in flight and the affliction",
    f and table.concat(f.inputs, " ") == "act.weakness_aff act.weakness_gone act.weakness_herb affs.weakness",
    f and table.concat(f.inputs, " "))
  local trues = {}
  for _, c in ipairs(base.cubes(f)) do
    if c.result == "return true" then trues[#trues + 1] = c end
  end
  check("it is true in one set of states", #trues == 1, #trues)
  local t = trues[1]
  check("there, the affliction is tracked and none of its actions is in flight",
    t and table.concat(t.on, " ") == "affs.weakness" and #t.off == 3
      and contains(t.off, "act.weakness_aff") and contains(t.off, "act.weakness_gone")
      and contains(t.off, "act.weakness_herb"))
  local again = base.describe("weakness")
  local same = true
  for k, v in pairs(d) do if again[k] ~= v then same = false end end
  check("a second description of weakness is the same", same)
  check("the cure list is a field", d["weakness.herb"] == 'eatcure={"kelp","aurum"}', d["weakness.herb"])
end

-- the same whichever order the entries are described in, and an entry
-- described again after all the others ran is the same as it was
do
  local fwd, rev = B.new({ class = CLASS }), B.new({ class = CLASS })
  local names = fwd.entries()
  local a, b = {}, {}
  for i = 1, #names do for k, v in pairs(fwd.describe(names[i])) do a[k] = v end end
  for i = #names, 1, -1 do for k, v in pairs(rev.describe(names[i])) do b[k] = v end end
  local total, differ, first = 0, 0, nil
  for k, v in pairs(a) do
    total = total + 1
    if b[k] ~= v then differ = differ + 1 first = first or k end
  end
  for k in pairs(b) do if a[k] == nil then differ = differ + 1 first = first or k end end
  check("every entry is described the same in either order", differ == 0,
    differ .. " of " .. total .. ", such as " .. tostring(first))
  check("the order check covered every entry", total > 2000, total)
  local again = fwd.describe(names[1])
  local same = true
  for k, v in pairs(again) do if a[k] ~= v then same = false end end
  check("the first entry described again last is the same", same)
end

-- ===== rewrites that change nothing =====

do
  local by = differences(patched({ { "weakness",
    "return (affs.weakness and\n            not svo.doingaction('weakness')) or false",
    "if svo.doingaction('weakness') then return false end\n          return affs.weakness ~= nil" } }), "weakness")
  check("checking the in-flight guard first describes the same", next(by) == nil, keys(by))
end

do
  -- the whole entry as a constructor over its name, as a conversion writes
  -- it: the name through a closure, not spelled out
  local body = entry_table("weakness")
  local made = body:gsub("'weakness'", "name"):gsub("svo%.dict%.weakness", "svo.dict[name]")
    :gsub("affs%.weakness", "affs[name]")
  check("the constructor rewrite changed the text", made ~= body and not made:find("weakness", 1, true))
  local by = differences(patched({ { "weakness", "weakness = " .. body,
    "weakness = (function(name) return " .. made .. " end)('weakness')" } }), "weakness")
  check("weakness made by a constructor over its name describes the same", next(by) == nil, keys(by))
end

do
  local by = differences(patched({ { "deadening",
    "svo.rmaff('deadening')\n          svo.lostbal_smoke()\n          sk.elm_smokepuff()",
    "svo.lostbal_smoke()\n          svo.rmaff('deadening')\n          sk.elm_smokepuff()" } }), "deadening")
  check("two independent statements swapped describe the same", next(by) == nil, keys(by))
end

do
  local by = differences(patched({ { "weakness",
    "return (affs.weakness and\n            not svo.doingaction('weakness')) or false",
    "local ignored = conf.keepup and defc.speed\n          return (affs.weakness and\n            not svo.doingaction('weakness')) or false" } }), "weakness")
  check("a read whose value is ignored describes the same", next(by) == nil, keys(by))
end

-- ===== mistakes, and where they show =====

do
  -- the single-source plan's own check: drop one name from one unless list
  local by = differences(patched({ { "fillskullcap",
    "affs.paralysis or affs.transfixed) and not conf.serverside) or false",
    "affs.paralysis) and not conf.serverside) or false" } }), "fillskullcap")
  local key = "fillskullcap.physical.isadvisable"
  check("dropping transfixed from fillskullcap's list changes only its isadvisable",
    keys(by) == key, keys(by))
  local states = by[key] and by[key].states
  check("and says in which states", states and #states > 0, states and #states)
  local all_transfixed, all_flip = true, true
  for _, s in ipairs(states or {}) do
    if not contains(s.on, "affs.transfixed") then all_transfixed = false end
    if not (s.was == "return false" and s.now == "return true") then all_flip = false end
  end
  check("each of them has transfixed", all_transfixed)
  check("and in each, fillskullcap was held back and now isn't", all_flip)
end

do
  local by = differences(patched({ { "weakness",
    "return (affs.weakness and\n            not svo.doingaction('weakness')) or false",
    "return affs.weakness and true or false" } }), "weakness")
  local key = "weakness.herb.isadvisable"
  check("dropping weakness's in-flight guard changes only its isadvisable", keys(by) == key, keys(by))
  local ok, n = true, 0
  for _, s in ipairs(by[key] and by[key].states or {}) do
    n = n + 1
    local inflight = contains(s.on, "act.weakness_aff") or contains(s.on, "act.weakness_gone")
      or contains(s.on, "act.weakness_herb")
    if not (contains(s.on, "affs.weakness") and inflight and s.was == "return false" and s.now == "return true") then
      ok = false
    end
  end
  check("only where weakness is tracked and one of its actions is in flight", ok and n > 0, n)
end

do
  local by = differences(patched({ { "deadening",
    'send("smoke " .. pipes.elm.id, conf.commandecho)',
    'send("smoke " .. pipes.valerian.id, conf.commandecho)' } }), "deadening")
  local item = by["deadening.smoke.onstart"]
  check("smoking the wrong pipe changes deadening's onstart", keys(by) == "deadening.smoke.onstart", keys(by))
  local s = item and item.states and item.states[1]
  check("it sends smoke 2 where it sent smoke 1",
    s and s.was:find("send smoke 1", 1, true) and s.now:find("send smoke 2", 1, true))
end

do
  local by = differences(patched({ { "weakness",
    "svo.rmaff('weakness')\n          svo.lostbal_herb()",
    "svo.rmaff('weakness')\n          svo.lostbal_salve()" } }), "weakness")
  local item = by["weakness.herb.oncompleted"]
  check("taking salve balance for a herb cure changes only its oncompleted",
    keys(by) == "weakness.herb.oncompleted", keys(by))
  local s = item and item.states and item.states[1]
  check("it shows salve balance gone where herb balance was",
    s and s.was:find("bals.herb=false", 1, true) and s.now:find("bals.salve=false", 1, true))
end

do
  local by = differences(patched({ { "weakness",
    "eatcure = {'kelp', 'aurum'},", "eatcure = {'aurum', 'kelp'}," } }), "weakness")
  local item = by["weakness.herb"]
  check("a reordered cure list is a different field", item ~= nil, keys(by))
  check("shown as the two fields", item and item.was == 'eatcure={"kelp","aurum"}'
    and item.now == 'eatcure={"aurum","kelp"}' and item.states == nil)
  check("and changes how the herb is eaten", by["weakness.herb.onstart"] ~= nil, keys(by))
end

do
  local by = differences(patched({ { "weakness",
    "svo.rmaff('weakness')\n          codepaste.remove_focusable()", "svo.rmaff('weakness')" } }), "weakness")
  local key = "weakness.gone.oncompleted"
  check("no longer counting down a hidden mental changes only weakness's gone", keys(by) == key, keys(by))
  local ok = true
  for _, s in ipairs(by[key] and by[key].states or {}) do
    if not contains(s.on, "affs.unknownmental") then ok = false end
  end
  check("and only where one is tracked", ok and by[key] and by[key].states and #by[key].states > 0)
end

do
  local by = differences(patched({ { "weakness",
    "svo.rmaff('weakness')\n          svo.lostbal_herb()",
    "affs.weakness = nil\n          svo.lostbal_herb()" } }), "weakness")
  local item = by["weakness.herb.oncompleted"]
  check("clearing affs instead of calling rmaff is a difference", item ~= nil, keys(by))
  local s = item and item.states and item.states[1]
  check("the rmaff call is part of what differs",
    s and s.was:find('rmaff("weakness")', 1, true) and not s.now:find('rmaff("weakness")', 1, true))
end

do
  -- a mistake only an argument shows: darkshade is added from a line only
  -- if health dropped below the oldhp it is given
  local d = base.describe("darkshade")
  check("a function that takes an argument is described with each of B.ARGS",
    d["darkshade.aff.oncompleted(1)"] ~= nil and d["darkshade.aff.oncompleted(6000)"] ~= nil)
  check("one that takes none is not", d["darkshade.gone.oncompleted(1)"] == nil)
  local by = differences(patched({ { "darkshade",
    "(not oldhp or stats.currenthealth < oldhp)", "(not oldhp or stats.currenthealth > oldhp)" } }), "darkshade")
  check("a reversed oldhp check is caught only where there is an oldhp",
    -- (true) too: comparing a number with true raises either way, but the
    -- error names the two the other way round
    keys(by) == "darkshade.aff.oncompleted(1), darkshade.aff.oncompleted(3), darkshade.aff.oncompleted(6000), "
      .. "darkshade.aff.oncompleted(true)",
    keys(by))
  local s = by["darkshade.aff.oncompleted(6000)"] and by["darkshade.aff.oncompleted(6000)"].states
  check("with health below the oldhp, darkshade was added and now isn't",
    s and #s == 1 and s[1].was:find("addaffdict", 1, true) and not s[1].now:find("addaffdict", 1, true))
end

-- ===== the rest =====

do
  local d, found = base.describe("touchtree")
  local f = found["touchtree.misc.empty"]
  check("a function with too many inputs says it is partial",
    f and f.partial and d["touchtree.misc.empty"]:sub(1, 8) == "partial ")
  local again = base.describe("touchtree")
  check("and a partial description is the same on a second run",
    again["touchtree.misc.empty"] == d["touchtree.misc.empty"])
end

do
  -- B.against prints; keep it quiet and look at what it returns
  local real = print
  print = function() end
  local ok = B.against("./", { CLASS }, { "weakness", "deadening", "fillskullcap" })
  print = real
  check("this tree against itself finds nothing", ok)
end

check("an entry svof doesn't have compares as nil", B.compare(base, base, "nosuchentry") == nil)

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then print("FAILED") os.exit(1) end
print("ALL PASS")
