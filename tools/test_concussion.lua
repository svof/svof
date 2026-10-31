--[[
concussion: the game's third head affliction, beside damagedhead and
mangledhead (AFFLICTION SHOW, captured 2026-10-20). Restoration to the head
cures it outright, and its cure line is damagedhead's. svof used to count it
as mangledhead.

It runs svof's real loaders through tools/svof_world.lua: GMCP's name and
its gain line, the shared cure line, DIAGNOSE, which head affliction doubles
commands and which warns of a pulp, and calcified skull taking the head's
damage up a level.

  lua tools/test_concussion.lua
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local function read(path)
  local f = assert(io.open(path, "r"))
  local s = f:read("*a")
  f:close()
  return s
end

local function gmcp_aff_add(w, name)
  w.env.gmcp.Char.Afflictions.Add = { name = name, cure = "", desc = "" }
  w.svo.signals.gmcpcharafflictionsadd:emit()
end

local function has(svo, name) return svo.affs[name] ~= nil end

do -- GMCP's name
  local w = world.new()
  local svo = w.svo
  eq(svo.dict.sstosvoa.concussion, "concussion", "GMCP's concussion is svof's")
  gmcp_aff_add(w, "concussion")
  eq(has(svo, "concussion"), true, "GMCP adds concussion")
  eq(has(svo, "mangledhead"), false, "and not mangledhead")
end

do -- its gain line
  local w = world.new()
  local svo = w.svo
  svo.stats.currenthealth = 3000
  w.run(read("src/triggers/svo (aliases, triggers)/svo/Poisons + Generic lines/Serious_concussion.lua"), "gain")
  -- with illusions checked, the line counts when health went down with it
  svo.stats.currenthealth = 2500
  w.prompt()
  eq(has(svo, "concussion"), true, "the massive trauma line gives concussion")
  eq(has(svo, "mangledhead"), false, "and not mangledhead")
end

-- "Your head feels stronger and healthier."
local CURED = read("src/triggers/svo (aliases, triggers)/svo/General/svo_cure_damagedhead.lua")

do -- the shared cure line takes concussion when svof applied for it
  local w = world.new()
  local svo = w.svo
  svo.addaffdict(svo.dict.concussion)
  svo.addaffdict(svo.dict.damagedhead)
  svo.doaction(svo.dict.curingconcussion.waitingfor)
  w.run(CURED, "cured")
  w.prompt()
  eq(has(svo, "concussion"), false, "the cure line cures concussion when svof applied for it")
  eq(has(svo, "damagedhead"), true, "and leaves damagedhead")
end

do -- and damagedhead otherwise
  local w = world.new()
  local svo = w.svo
  svo.addaffdict(svo.dict.concussion)
  svo.addaffdict(svo.dict.damagedhead)
  svo.doaction(svo.dict.curingdamagedhead.waitingfor)
  w.run(CURED, "cured")
  w.prompt()
  eq(has(svo, "damagedhead"), false, "the cure line cures damagedhead when svof applied for it")
  eq(has(svo, "concussion"), true, "and leaves concussion")
end

for _, case in ipairs({ { "concussion", "damagedhead" }, { "damagedhead", "concussion" } }) do
  -- restoration with both can cure either, and outside blackout GMCP says
  -- which: the line then only claims the cure, and the other one stays
  local applied, cured = case[1], case[2]
  local w = world.new()
  local svo = w.svo
  w.env.gmcp.Char.Afflictions.List = {
    { name = "concussion", cure = "", desc = "" }, { name = "damagedhead", cure = "", desc = "" },
  }
  svo.signals.gmcpcharafflictionslist:emit()
  svo.doaction(svo.dict["curing" .. applied].waitingfor)
  w.env.gmcp.Char.Afflictions.Remove = { cured }
  svo.signals.gmcpcharafflictionsremove:emit()
  w.run(CURED, "cured")
  w.prompt()
  eq(has(svo, cured), false, "applied for " .. applied .. " and GMCP removed " .. cured .. ": it's gone")
  eq(has(svo, applied), true, "and " .. applied .. ", which GMCP still reports, stays")
  eq(w.inflight(), "", "with nothing left in flight")
end

do -- restoration to the head for it
  local w = world.new()
  local svo = w.svo
  svo.addaffdict(svo.dict.concussion)
  eq(not not svo.dict.concussion.salve.isadvisable(), true, "concussion's salve is advisable")
  w.sent = {}
  svo.dict.concussion.salve.onstart()
  eq(w.sent[1], "apply restoration to head", "and applies restoration to the head")
end

do -- DIAGNOSE
  local w = world.new()
  local svo = w.svo
  svo.valid.diag('concussion')
  eq(svo.sk.diag_list.concussion, true, "DIAGNOSE reports concussion")
  local diag = read("src/triggers/svo (aliases, triggers)/svo/General/triggers.json")
  eq(select(2, diag:gsub('"pattern": "has a serious concussion%."', "")), 1, "on one trigger")
  eq(read("src/triggers/svo (aliases, triggers)/svo/General/concussion.lua"), "svo.valid.diag('concussion')",
    "which is concussion's")
end

for _, case in ipairs({ { "concussion", 2 }, { "mangledhead", 1 }, { "damagedhead", 1 } }) do
  -- concussion doubles commands, as its amnesia drops them (the user, 2026-10-31)
  local aff, times = case[1], case[2]
  local w = world.new()
  local svo = w.svo
  svo.addaffdict(svo.dict[aff])
  w.sent = {}
  svo.snd("look")
  eq(#w.sent, times, aff .. " sends a command " .. times .. " time(s)")
end

for _, case in ipairs({ { "mangledhead", 1 }, { "concussion", 0 } }) do
  -- prone with a mangled head can be pulped (the user, 2026-10-31)
  local aff, warns = case[1], case[2]
  local w = world.new()
  local svo = w.svo
  local n = 0
  local warn = svo.sk.warn
  svo.sk.warn = function(what) if what == 'pulpable' then n = n + 1 end return warn(what) end
  svo.addaffdict(svo.dict.prone)
  svo.addaffdict(svo.dict[aff])
  eq(n, warns, "prone with " .. aff .. " warns of a pulp " .. warns .. " time(s)")
end

do -- calcified skull takes the head's damage up a level
  local DONE = read("src/triggers/svo (aliases, triggers)/svo/Sculpting/Calcified_Skull_Concussion.lua")
  for _, case in ipairs({
    { nil, "damagedhead" }, { "damagedhead", "mangledhead" }, { "mangledhead", "mangledhead" },
  }) do
    local before, after = case[1], case[2]
    local w = world.new()
    local svo = w.svo
    svo.addaffdict(svo.dict.calcifiedskull)
    if before then svo.addaffdict(svo.dict[before]) end
    w.run(DONE, "calcified")
    w.prompt()
    local heads = {}
    for _, name in ipairs({ "damagedhead", "mangledhead", "concussion" }) do
      if has(svo, name) then heads[#heads + 1] = name end
    end
    eq(table.concat(heads, " "), after, "calcified skull with " .. tostring(before) .. " leaves " .. after)
    eq(has(svo, "calcifiedskull"), false, "and ends the calcification")
  end
end

do -- @affs, and the default priorities
  local tag = read("src/scripts/svo (core)/svo Utilities/Custom prompt tags/@affs.lua")
  eq(tag:match('\n%s*concussion%s*=%s*"([^"]*)"'), "conc", "@affs shows it as conc")
  local prios = read("src/resources/default_prios")
  eq(prios:find('"concussion"', 1, true) ~= nil, true, "the default salve list has concussion")
  eq(prios:find('"concussion_salve"', 1, true) ~= nil, true, "and slow curing")
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
