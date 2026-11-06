--[[
Mucous in your lungs, a tempered phlegmatic humour's effect on smoking: a
longer smoke recovery, not an affliction (svo.dict.mucouslungs).

It runs svof's real loaders through tools/svof_world.lua and checks:

  * both mucous lines cancel the smoke in flight and take smoke balance for
    the 6-second recovery, at the prompt and not before it, so a paragraph
    found to be an illusion changes nothing.
  * the cough line ends that recovery early, at the prompt, once, and only
    that recovery: it leaves an ordinary smoke's recovery alone.
  * both lines answer svof's asthma check, which then isn't in flight.
  * the aeon strategies for tree, shrugging and dragonheal count clogged
    lungs, as they counted the old mucous affliction.
  * no affliction is claimed or kept.

  lua tools/test_mucous.lua
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local function got_smoke_balance(w)
  local n = 0
  for _, e in ipairs(w.events) do
    if e.name == "svo got balance" and e.args[1] == 'smoke' then n = n + 1 end
  end
  return n
end

local function smoking(w)
  local svo = w.svo
  svo.conf.aillusion = true
  svo.conf.batch = false
  svo.checkaction(svo.dict.slickness.smoke, true)
  svo.paragraph_length = 1
  return svo
end

for _, line in ipairs({ 'got_mucous', 'have_mucous' }) do
  local w = world.new()
  local svo = smoking(w)
  svo.valid[line]()
  eq(svo.actions.slickness_smoke ~= nil, true, line .. ": nothing changes before the prompt")
  eq(svo.bals.smoke, true, line .. ": smoke balance included")
  w.prompt()
  eq(svo.actions.slickness_smoke, nil, line .. ": the prompt cancels the smoke")
  eq(svo.bals.smoke, false, line .. ": and takes smoke balance")
  eq(svo.lungs_clogged(), true, line .. ": the lungs are clogged")
  eq(svo.affs.mucous, nil, line .. ": and no affliction is claimed")
  w.advance(5.9)
  eq(svo.bals.smoke, false, line .. ": smoke balance is still out after 5.9s")
  w.advance(0.2)
  eq(svo.bals.smoke, true, line .. ": and back after 6s")
  eq(svo.lungs_clogged(), false, line .. ": and the lungs aren't clogged then")
end

do -- a mucous line in a paragraph found to be an illusion
  local w = world.new()
  local svo = smoking(w)
  svo.valid.got_mucous()
  svo.ignore_illusion("test: the rest of the paragraph shows an illusion")
  w.prompt()
  eq(svo.bals.smoke, true, "illusion: smoke balance stays")
  eq(svo.lungs_clogged(), false, "illusion: and the lungs aren't clogged")
end

do -- the cough line ends mucous's recovery early, once
  local w = world.new()
  local svo = smoking(w)
  svo.valid.got_mucous()
  w.prompt()
  local before = got_smoke_balance(w)
  w.advance(2)
  svo.paragraph_length = 1
  svo.valid.mucous_woreoff()
  eq(svo.bals.smoke, false, "cough: nothing changes before the prompt")
  w.prompt()
  eq(svo.bals.smoke, true, "cough: the prompt gives smoke balance back")
  eq(got_smoke_balance(w), before + 1, "cough: and says so")
  w.advance(5)
  eq(got_smoke_balance(w), before + 1, "cough: and the recovery's timer doesn't give it back again")
  svo.paragraph_length = 1
  svo.valid.mucous_woreoff()
  w.prompt()
  eq(got_smoke_balance(w), before + 1, "cough: a second cough line changes nothing")
end

do -- the cough line leaves an ordinary smoke's recovery alone
  local w = world.new()
  local svo = smoking(w)
  svo.lostbal_smoke()
  svo.paragraph_length = 1
  svo.valid.mucous_woreoff()
  w.prompt()
  eq(svo.bals.smoke, false, "cough during a smoke's own recovery: smoke balance stays out")
end

for _, line in ipairs({ 'got_mucous', 'have_mucous' }) do -- svof's own asthma check
  local w = world.new()
  local svo = w.svo
  svo.conf.aillusion = true
  svo.conf.batch = false
  svo.checkaction(svo.dict.checkasthma.smoke, true)
  svo.paragraph_length = 1
  svo.valid[line]()
  w.prompt()
  eq(svo.actions.checkasthma_smoke, nil, line .. ": answers the asthma check")
  eq(svo.bals.smoke, false, line .. ": and takes smoke balance")
end

do -- aeon with clogged lungs: the strategies cure aeon another way
  local w = world.new()
  local svo = smoking(w)
  svo.addaffdict(svo.dict.aeon)
  eq(not not svo.tree.aeon[1](), false, "aeon alone: no tree")
  svo.valid.have_mucous()
  w.prompt()
  eq(not not svo.tree.aeon[1](), true, "aeon and clogged lungs: tree")
  eq(not not svo.shrugging.aeon[1](), true, "and shrugging")
  eq(not not svo.dragonheal.aeon[1](), true, "and dragonheal")
  w.advance(7)
  eq(not not svo.tree.aeon[1](), false, "once the recovery's over: no tree")
end

do -- no mucous affliction
  local w = world.new()
  eq(w.svo.dict.mucous, nil, "no mucous entry")
  eq(w.svo.dict.mucouslungs.aff, nil, "and mucouslungs isn't an affliction")
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
