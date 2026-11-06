--[[
Two handlers checked a key named asleep, which svof never had: sleep is
svof's. Neither ever ran.

  * svo.valid.symp_asleep, on "You are asleep and can do nothing. WAKE will
    attempt to wake you.", the game refusing a command sent while asleep.
    What svof had in flight failed, so it's cleared and goes again once
    awake; nothing is sent while asleep. The wake and a cure being recorded
    stay.
  * svo.valid.transfixily, on the transfixed and arms-bound refusals, which
    the game gives only to someone awake. It takes sleep off, for blackout,
    where the wake line can be missed. Outside it, GMCP decides.

The first sleep symptom and the stun symptom clear what's in flight through
the same svo.cancel_sent_actions, and keep a cure being recorded too.

It runs svof's real loaders through tools/svof_world.lua.

  lua tools/test_asleep.lua
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

do -- asleep already, and a command refused
  local w = world.new()
  local svo = w.svo
  svo.addaffdict(svo.dict.sleep)
  svo.doaction(svo.dict.asthma.herb)
  svo.doaction(svo.dict.slickness.smoke)
  svo.doaction(svo.dict.anorexia.salve)
  svo.doaction(svo.dict.stupidity.focus)
  svo.doaction(svo.dict.sleep.misc)
  svo.doaction(svo.dict.curingsleep.waitingfor)
  svo.doaction(svo.dict.asthma.gone)
  svo.paragraph_length = 1
  svo.valid.symp_asleep()
  local inflight = w.inflight()
  eq(inflight:find("asthma_herb", 1, true), nil, "the refusal clears the herb svof had in flight")
  eq(inflight:find("slickness_smoke", 1, true), nil, "and the smoke")
  eq(inflight:find("anorexia_salve", 1, true), nil, "and the salve")
  eq(inflight:find("stupidity_focus", 1, true), nil, "and the focus")
  eq(inflight:find("sleep_misc", 1, true) ~= nil, true, "and keeps the wake")
  eq(inflight:find("curingsleep_waitingfor", 1, true) ~= nil, true, "and the wait for it")
  eq(inflight:find("asthma_gone", 1, true) ~= nil, true, "and a cure being recorded")
end

-- The first sleep symptom and the stun symptom clear what's in flight the same
-- way, and killing an action while going through them skipped the next. Both
-- keep a cure the paragraph already showed, as symp_asleep does
local function in_flight_cleared(label, setup, symptom)
  local w = world.new()
  local svo = w.svo
  setup(svo)
  local affs = { { "asthma", "herb" }, { "slickness", "smoke" }, { "anorexia", "salve" }, { "stupidity", "focus" } }
  for _, a in ipairs(affs) do svo.doaction(svo.dict[a[1]][a[2]]) end
  svo.doaction(svo.dict.paralysis.gone)
  svo.paragraph_length = 1
  symptom(svo)
  local inflight = w.inflight()
  for _, a in ipairs(affs) do
    eq(inflight:find(a[1] .. "_" .. a[2], 1, true), nil, label .. " clears " .. a[1] .. "_" .. a[2])
  end
  eq(inflight:find("paralysis_gone", 1, true) ~= nil, true, label .. " keeps a cure being recorded")
end

in_flight_cleared("the first sleep symptom", function() end, function(svo) svo.dict.sleep.aff.symptom() end)
in_flight_cleared("the stun symptom", function(svo) svo.addaffdict(svo.dict.stun) end, function(svo) svo.valid.symp_stun() end)

do -- a cure line, then the stun symptom, in one paragraph: the cure stands
  local w = world.new()
  local svo = w.svo
  svo.conf.aillusion = false
  svo.addaffdict(svo.dict.paralysis)
  svo.addaffdict(svo.dict.stun)
  w.prompt()
  svo.paragraph_length = 1
  svo.checkaction(svo.dict.paralysis.gone, true)
  svo.lifevision.add(svo.actions.paralysis_gone.p)
  svo.paragraph_length = 2
  svo.valid.symp_stun()
  w.prompt()
  eq(svo.affs.paralysis, nil, "a paralysis cure line before a stun symptom still cures it")
end

do -- the transfixed refusal, in blackout
  local w = world.new()
  local svo = w.svo
  svo.addaffdict(svo.dict.sleep)
  svo.valid.transfixily()
  eq(svo.affs.sleep, nil, "a transfixed refusal takes sleep off")
end

do -- and while GMCP still reports sleep
  local w = world.new()
  local svo = w.svo
  w.env.gmcp.Char.Afflictions.List = { { name = "sleeping", cure = "", desc = "" } }
  svo.signals.gmcpcharafflictionslist:emit()
  eq(svo.affs.sleep ~= nil, true, "GMCP's sleeping is svof's sleep")
  svo.valid.transfixily()
  eq(svo.affs.sleep ~= nil, true, "a transfixed refusal leaves sleep while GMCP reports it")
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
