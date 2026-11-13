--[[
Logic-level test that svof's serverside sync sends the game's lovers
priority only one number per curingset, the lover's curse's.

Two svof actions sync under the game's name lovers. svof's inlove is the
lover's curse and has gamename lovers; the game reports it as lovers and
cures it by priority. svof's own lovers action is lust, which the game
cures with CURING REJECTION, not with a priority, and it had no gamename,
so the sync sent it as lovers too. Each curingset got two lovers numbers,
lust's and the curse's, and whichever landed last stood: with svof curing
lust, that was 26, and serverside stopped curing the lover's curse.

The lovers entry is marked noserverprio now and the sync sends nothing for
it. The test turns serverside on for a Magi, a Druid and a Monk, replays
everything svof sent through a reading of CURING PRIORITY and CURINGSET,
and checks that lovers gets one number in each curingset, inlove's, and
that no other game name stands for two actions. It then hands lust to serverside and
checks that the resync still says nothing for it. Last, it checks lust's
own tracking and REJECT curing still work. The model is this test's
reading of the commands, not the game's code, so it proves what svof
sends, not what the game does with it.

Run: lua tools/test_lust_serverprio.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function check(desc, ok, detail)
  checks = checks + 1
  if not ok then failures[#failures + 1] = desc .. (detail and (": " .. detail) or "") end
end

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

local function serverside_on(class)
  local w = world.new({ class = class })
  w.svo.conf.serverside = true
  w.svo.signals["svo config changed"]:emit("serverside")
  settle(w)
  return w
end

-- the number the sync gives an affliction action in a balance, the way
-- sk.sendpriorityswitch works it out, or 26 when it is left to svof
local function expected(w, action, balance)
  local sk = w.svo.sk
  local affs, _, ignoreaffs = sk.splitdefs(balance, w.svo.prio.getsortedlist(balance))
  for index, aff in pairs(affs) do
    if aff == action then return tostring(index > 25 and 25 or index) end
  end
  for _, aff in pairs(ignoreaffs) do
    if aff == action then return "26" end
  end
end

for _, class in ipairs({ "Magi", "Druid", "Monk" }) do
  local w = serverside_on(class)
  local svo = w.svo
  check(class .. ": lust is svof's lovers action, without a gamename",
    svo.dict.lovers.physical ~= nil and svo.dict.lovers.gamename == nil)
  check(class .. ": the lover's curse syncs as lovers", svo.dict.inlove.gamename == "lovers")

  local sends = affliction_sends(w.sent)
  local curse = expected(w, "inlove", "herb")
  for _, set in ipairs({ "normal", "slowcuring" }) do
    local got = sends[set] and sends[set].lovers or {}
    check(class .. ": " .. set .. " gets one lovers number", #got == 1, table.concat(got, ", "))
    -- slowcuring pools everything after 25 on 25, so the curse's number
    -- there is checked only for not being lust's 26
    if set == "normal" then
      check(class .. ": normal's lovers number is the curse's", got[1] == curse,
        ("%s, the curse is %s"):format(tostring(got[1]), tostring(curse)))
    else
      check(class .. ": slowcuring's lovers number isn't 26", got[1] ~= nil and got[1] ~= "26", tostring(got[1]))
    end
  end

  -- no other game name stands for two actions the sync sends
  local byname = {}
  for action, entry in pairs(svo.dict) do
    if type(entry) == "table" and type(entry.aff) == "table" and not entry.aff.notagameaff
      and not entry.noserverprio then
      local name = entry.gamename or action
      if byname[name] then
        check(class .. ": one action syncs as " .. name, false, byname[name] .. ", " .. action)
      end
      byname[name] = action
    end
  end
  check(class .. ": lovers syncs for inlove", byname.lovers == "inlove", tostring(byname.lovers))

  -- direct calls say nothing either, whether svof or serverside has lust
  local from = #w.sent + 1
  svo.sk.sendpriorityignore("lovers", "physical", {}, {}, {}, false)
  svo.sk.sendpriorityswitch("lovers", "physical", { lovers = 3 }, {}, {}, false)
  settle(w)
  local direct = affliction_sends(w.sent, from)
  check(class .. ": a direct send for lust sends nothing",
    not (direct.normal and direct.normal.lovers), direct.normal and table.concat(direct.normal.lovers or {}, ", "))

  -- hand lust to serverside: the resync still says nothing for it
  from = #w.sent + 1
  svo.setserverignore("lovers")
  svo.signals["svo serverignore changed"]:emit("lovers")
  svo.sk.handleserversideswitch()
  settle(w)
  local resync = affliction_sends(w.sent, from)
  for _, set in ipairs({ "normal", "slowcuring" }) do
    local got = resync[set] and resync[set].lovers or {}
    check(class .. ": lust on serverside: " .. set .. " gets no lovers number for it", #got == 0, table.concat(got, ", "))
  end
end

-- ===== lust's own tracking and curing are unchanged =====

do
  local w = serverside_on("Magi")
  local svo = w.svo
  svo.dict.lovers.tempmap = { "someone" }
  svo.dict.lovers.aff.oncompleted()
  check("lust is tracked", svo.affs.lovers ~= nil)
  check("lust has the name to reject", svo.dict.lovers.map.someone == true)
  check("lust is advisable to cure", svo.dict.lovers.physical.isadvisable() == true)
  local from = #w.sent + 1
  svo.dict.lovers.physical.onstart()
  local rejected = false
  for i = from, #w.sent do if w.sent[i] == "reject someone" then rejected = true end end
  check("lust's cure rejects the lover", rejected)
  svo.dict.lovers.physical.oncompleted("someone")
  check("rejecting the lover cures lust", svo.affs.lovers == nil)
  check("lust is still an affliction to GMCP and triggers", svo.dict.lovers.aff.notagameaff == nil)
end

if #failures == 0 then
  print(("ALL PASS (%d checks)"):format(checks))
else
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(("%d of %d checks failed"):format(#failures, checks))
  os.exit(1)
end
