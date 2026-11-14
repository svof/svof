--[[
nightsight is a general defence, not a Metamorphosis one: DEFENCE SHOW gives
it Profession: No, and the server raises it with a plain NIGHTSIGHT. svof
still sent a Metamorphosis class into a form for it first, and waited on that
morph, so if the morph didn't happen, svof never sent nightsight at all and
stayed on it until you raised it yourself. It also marked nightsight
undeffable for those classes, so serverside never raised it either.

It runs svof's real loaders through tools/svof_world.lua, for two
Metamorphosis classes and one without it.

  lua tools/test_nightsight.lua
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

for _, class in ipairs({ "Druid", "Sentinel", "Infernal" }) do
  local w = world.new({ class = class, paused = false })
  local svo = w.svo
  svo.conf.keepup = true
  svo.defkeepup[svo.defs.mode].nightsight = true
  w.prompt()
  w.advance(0.1)
  local sent = table.concat(w.sent, " | ")
  eq(sent, "nightsight on", class .. ": keepup sends nightsight on, and nothing else")
  eq(w.inflight(), "nightsight_physical", class .. ": and waits on no morph")
  eq(svo.dict.nightsight.physical.undeffable, nil, class .. ": serverside can raise it")
  w.line("Your vision sharpens with light as you gain night sight.")
  w.prompt()
  eq(svo.defc.nightsight, true, class .. ": the gain line puts it up")
  eq(w.inflight(), "", class .. ": leaving nothing in flight")
  if svo.codepaste.nonmorphdefs then
    svo.defc.nightsight = false
    eq(svo.codepaste.nonmorphdefs(), true, class .. ": a form waits on no nightsight")
  end
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
