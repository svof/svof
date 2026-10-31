--[[
Static test that svof names no transmutation cure. They are gone from Achaea
(the repo owner, 2026-09-21): only the normal salves and elixirs are left.
Minerals are a different thing and still live, such as malachite smoked
for skullcap.

DEAD is the second name of each pair svof used to keep in
rift.vial_conversions, normal to transmutation.

It reads the real dictionary and checks:

  * no applycure, sipcure or actions list names a dead cure
  * rift.vial_conversions is gone, as nothing needs it now
  * svo.valid.defstrip no longer turns "density" into mass: the game
    doesn't say it when it strips mass (the user, 2026-10-31). GMCP and
    serverside still name mass density, which this leaves alone

  lua tools/test_transmutation.lua
]]

local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local RIFT = "src/scripts/svo (install, config, pipes, rift, parry, prios)/Rift.lua"
local TRIG = "src/scripts/svo (trigger functions)/Main_trigger_functions.lua"

local DEAD = {
  exothermic = 'caloric', sensory = 'epidermal', endothermia = 'frost', vitality = 'health',
  antigen = 'immunity', hovering = 'levitation', mentality = 'mana', density = 'mass',
  renewal = 'mending', reconstructive = 'restoration', haste = 'speed', toxin = 'venom',
}

local checks, failures = 0, {}
local function check(desc, ok)
  checks = checks + 1
  if not ok then failures[#failures + 1] = desc end
end

local function read(path)
  local f = assert(io.open(path, "r"))
  local s = f:read("*a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

local dict = read(DICT)
local lists, n = 0, 0
for line in dict:gmatch("[^\n]+") do
  local field, body = line:match("^%s*(%a+) = (%b{})")
  if field == 'applycure' or field == 'sipcure' then
    lists = lists + 1
    for name in body:gmatch("'(%w+)'") do
      n = n + 1
      check(field .. " names no transmutation cure: " .. line, not DEAD[name])
    end
  elseif field == 'actions' then
    for cmd in body:gmatch('"([^"]+)"') do
      local verb, item = cmd:match("^(%a+) (%a+)")
      if verb == 'apply' or verb == 'sip' or verb == 'drink' then
        check("actions sends no transmutation cure: " .. cmd, not DEAD[item])
      end
    end
  end
end
check("the dictionary has applycure and sipcure lists to check (found " .. lists .. ")", lists >= 40)
check("each of the live salves and elixirs is still somewhere", (function()
  for _, live in pairs(DEAD) do
    if not dict:find("'" .. live .. "'", 1, true) then return false end
  end
  return true
end)())

check("rift.vial_conversions is gone", not read(RIFT):find("vial_conversions", 1, true))
check("nothing reads rift.vial_conversions", not dict:find("vial_conversions", 1, true))

local trig = read(TRIG)
local defstrip = trig:match("function svo%.valid%.defstrip%(which%)(.-)\nend")
check("svo.valid.defstrip is where this test looks", defstrip ~= nil)
check("defstrip no longer turns density into mass", defstrip and not defstrip:find("'density'", 1, true))
check("and keeps its other wordings, such as insulation", defstrip and defstrip:find("['insulation']", 1, true) ~= nil)
check("GMCP and serverside still name mass density", dict:find("gamename = 'density'", 1, true) ~= nil)

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
