--[[
Logic-level test that svof's serverside sync sends each affliction one
number per curingset.

The game keeps one CURING PRIORITY number per affliction. svof keeps one
priority list per balance, and the sync sent each balance's position on its
own. slickness is cured on herb (bloodroot) and on smoke (valerian), so
every sync sent it two numbers in each curingset, and which one stood
depended on pairs order: a Magi got `slickness 11` and `slickness 25` in
one batch.

The sync now splits all of a curingset's balances together. An affliction
on more than one gets the position on the balance its entry names in
serverpriobalance - herb, for slickness, since serverside picks bloodroot
or valerian itself - and the least urgent of its positions when it names
none. Its balances share one cache, so the number goes out once.

The test turns serverside on for every class, replays everything svof sent
through a reading of CURING PRIORITY and CURINGSET, and checks that every
affliction name gets one number in each curingset, that slickness's is its
herb position, and that every affliction on more than one balance names
one. It then moves slickness on each list and checks the resync sends one
number, its new herb position, or nothing when only smoke moved. Last, it
takes slickness's serverpriobalance away and checks the least urgent
position is sent. The model is this test's reading of the commands, not the
game's code, so it proves what svof sends, not what the game does with it.

lovers is left out of the one-number check: two svof actions sync under
that name, lust and the lover's curse, which is a separate fix.

Run: lua tools/test_serverprio_one_number.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function check(desc, ok, detail)
  checks = checks + 1
  if not ok then failures[#failures + 1] = desc .. (detail and (": " .. detail) or "") end
end

local CLASSES = { "Alchemist", "Apostate", "Bard", "Blademaster", "Depthswalker",
  "Druid", "Infernal", "Jester", "Magi", "Monk", "Occultist", "Paladin", "Priest",
  "Psion", "Runewarden", "Sentinel", "Serpent", "Shaman", "Sylvan", "Unnamable" }

-- the balances the normal curingset syncs
local BALANCES = { "herb", "smoke", "salve", "sip", "purgative", "physical", "moss", "misc" }

-- the name two svof actions share, fixed apart from this
local SHARED = { lovers = true }

-- svof holds back a priority command when it has sent several within a
-- second, so let every timer it has set run
local function settle(w)
  for _ = 1, 10 do w.advance(2) end
end

-- every affliction number each curingset was sent, in order, by name:
-- sends[curingset][name] = {number, ...}
local function affliction_sends(sent, from)
  local current, sends = "normal", {}
  for i = from or 1, #sent do
    local lower = sent[i]:lower()
    local switch = lower:match("^curingset switch (%S+)$")
    if switch then
      current = switch
    elseif not lower:match("^curing priority defence") then
      local rest = lower:match("^curing priority (.*)$")
      if rest and rest ~= "reset" then
        sends[current] = sends[current] or {}
        local name = {}
        for word in rest:gmatch("%S+") do
          if tonumber(word) or word == "reset" then
            local key = table.concat(name, " ")
            sends[current][key] = sends[current][key] or {}
            table.insert(sends[current][key], word)
            name = {}
          else
            name[#name + 1] = word
          end
        end
      end
    end
  end
  return sends
end

local function serverside_on(class, before)
  local w = world.new({ class = class })
  if before then before(w) end
  w.svo.conf.serverside = true
  w.svo.signals["svo config changed"]:emit("serverside")
  settle(w)
  return w
end

-- an action's position among a balance's afflictions in a sorted list,
-- counted the way the sync counts it, capped at 25
local function position(w, list, action, balance)
  local affs = w.svo.sk.splitdefs(balance, list)
  for index, aff in pairs(affs) do
    if aff == action then return index > 25 and 25 or index end
  end
end

-- slickness's normal position on a balance
local function normal_position(w, balance)
  return position(w, w.svo.prio.getsortedlist(balance), "slickness", balance)
end

-- slickness's slow curing position on a balance: the slow curing list
-- narrowed to that balance's actions, in order
local function slow_position(w, balance)
  local list = {}
  for _, item in ipairs(w.svo.prio.getsortedlist("slowcuring")) do
    local action, itembalance = item:match("^(.+)_([^_]+)$")
    if itembalance == balance then list[#list + 1] = action end
  end
  return position(w, list, "slickness", balance)
end

-- the number the sync should send slickness: the position on its
-- serverpriobalance, or with none the larger of herb and smoke
local function expected(w, where)
  local herb, smoke = where(w, "herb"), where(w, "smoke")
  local named = w.svo.dict.slickness.serverpriobalance
  local want = named and where(w, named) or math.max(herb, smoke)
  return tostring(want), herb, smoke
end

local function describe(got, herb, smoke)
  return ("%s, herb %s, smoke %s"):format(tostring(got), tostring(herb), tostring(smoke))
end

-- resyncs and returns what the normal curingset was sent for slickness
local function resync(w)
  local from = #w.sent + 1
  w.svo.sk.handleserversideswitch()
  settle(w)
  local sends = affliction_sends(w.sent, from)
  return sends.normal and sends.normal.slickness or {}
end

-- the highest aspriority on a balance's list
local function top(w, balance)
  local highest = 0
  for _, entry in pairs(w.svo.dict) do
    if type(entry) == "table" and type(entry[balance]) == "table" and entry[balance].aspriority then
      highest = math.max(highest, entry[balance].aspriority)
    end
  end
  return highest
end

for _, class in ipairs(CLASSES) do
  local w = serverside_on(class)
  local svo = w.svo
  check(class .. ": slickness is on herb and smoke", svo.dict.slickness.herb ~= nil and svo.dict.slickness.smoke ~= nil)
  check(class .. ": slickness syncs its herb position", svo.dict.slickness.serverpriobalance == "herb")

  -- every affliction the sync can send on more than one balance names the
  -- balance whose position it sends
  for action, entry in pairs(svo.dict) do
    if type(entry) == "table" and type(entry.aff) == "table" and not entry.aff.notagameaff then
      local on = {}
      for _, balance in ipairs(BALANCES) do
        local b = entry[balance]
        if type(b) == "table" and b.aspriority and not b.def and not b.uncurable and not b.irregular then
          on[#on + 1] = balance
        end
      end
      if #on > 1 then
        local found = false
        for _, balance in ipairs(on) do found = found or balance == entry.serverpriobalance end
        check(class .. ": " .. action .. " names one of its balances (" .. table.concat(on, ", ") .. ")",
          found, tostring(entry.serverpriobalance))
      end
    end
  end

  local sends = affliction_sends(w.sent)
  for _, set in ipairs({ "normal", "slowcuring" }) do
    check(class .. ": " .. set .. " was synced", sends[set] ~= nil)
    for name, numbers in pairs(sends[set] or {}) do
      if not SHARED[name] then
        check(class .. ": " .. set .. " gets one " .. name .. " number", #numbers == 1, table.concat(numbers, ", "))
      end
    end
  end

  local want, herb, smoke = expected(w, normal_position)
  local got = sends.normal and sends.normal.slickness or {}
  check(class .. ": normal's slickness number is its herb position", got[1] == want, describe(got[1], herb, smoke))
  want, herb, smoke = expected(w, slow_position)
  got = sends.slowcuring and sends.slowcuring.slickness or {}
  check(class .. ": slowcuring's slickness number is its herb position", got[1] == want, describe(got[1], herb, smoke))
end

-- ===== moving slickness on one list resyncs one number, or none =====

do
  local w = serverside_on("Magi")
  local slick = w.svo.dict.slickness

  -- herb to the top, above its smoke position: one number, 1
  slick.herb.aspriority = top(w, "herb") + 1
  check("Magi: slickness is lower on smoke than herb now", normal_position(w, "smoke") > 1)
  local got = resync(w)
  check("Magi: slickness to the top of herb sends one number, 1", #got == 1 and got[1] == "1", table.concat(got, ", "))

  -- smoke to the top too: the herb position stands, nothing to send
  slick.smoke.aspriority = top(w, "smoke") + 1
  check("Magi: slickness is first on smoke", normal_position(w, "smoke") == 1)
  got = resync(w)
  check("Magi: moving slickness on smoke sends nothing for it", #got == 0, table.concat(got, ", "))

  -- smoke to the bottom: still nothing
  slick.smoke.aspriority = -1000
  got = resync(w)
  check("Magi: slickness to the bottom of smoke sends nothing for it", #got == 0, table.concat(got, ", "))

  -- herb to the bottom: one number, its herb position again
  slick.herb.aspriority = -1000
  got = resync(w)
  local want, herb, smoke = expected(w, normal_position)
  check("Magi: slickness to the bottom of herb sends one number", #got == 1, table.concat(got, ", "))
  check("Magi: and it is its herb position", got[1] == want, describe(got[1], herb, smoke))
end

-- ===== with no serverpriobalance, the least urgent position =====

do
  local w = serverside_on("Magi", function(w) w.svo.dict.slickness.serverpriobalance = nil end)
  local sends = affliction_sends(w.sent)
  for _, set in ipairs({ "normal", "slowcuring" }) do
    local got = sends[set] and sends[set].slickness or {}
    local want, herb, smoke = expected(w, set == "normal" and normal_position or slow_position)
    check("Magi, no serverpriobalance: " .. set .. " gets one slickness number", #got == 1, table.concat(got, ", "))
    check("Magi, no serverpriobalance: " .. set .. "'s is the larger of herb and smoke", got[1] == want,
      describe(got[1], herb, smoke))
  end
end

if #failures == 0 then
  print(("ALL PASS (%d checks)"):format(checks))
else
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(("%d of %d checks failed"):format(#failures, checks))
  os.exit(1)
end
