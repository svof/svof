--[[
Static test of how svof hands writhes to serverside, and of daeggerimpale,
an impale by an Apostate's daegger, which the game names apart from impaled.

svof tracked a daegger impale as impale and ignored GMCP's daeggerimpale, so
serverside never heard about it. It has its own entry now, writhed as impale
is, one of the two at a time, so a player can hand it to serverside from
vshow serverside. Everywhere svof holds back for an impale it holds back for
a daegger's too, as it did when both were impale.

This reads the real sources and checks:

  * roped is sent to serverside as entangled, the game's name for it
  * daeggerimpale's entry, its wait and its GMCP name
  * the parity: every line of svof's curing code that tests affs.impale, or
    names impale's writhe or wait, names daeggerimpale's too, except the
    contexts listed in ALONE, which are a blade's only
  * the triggers: the daegger's line, its expire line and its DIAGNOSE line
  * the serverside defaults and both default_prios copies

Run: lua tools/test_writhes.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local MAIN = "src/scripts/svo (trigger functions)/Main_trigger_functions.lua"
local SOURCES = {
  DICT, MAIN,
  "src/scripts/svo (curing skeleton, controllers, action system)/Curing_skeleton.lua",
  "src/scripts/svo (setup, misc, empty, funnies, dor)/Setup.lua",
  "src/scripts/svo (setup, misc, empty, funnies, dor)/Empty_cure_handling.lua",
  "src/triggers/svo (aliases, triggers)/svo/General/Symptoms/Full,_injured,_or_restrained_arms.lua",
}
local SERVER = "src/scripts/svo (custom prompt, serverside)/Serverside.lua"
local ALIAS = "src/scripts/svo (alias and defence functions)/Alias_functions.lua"
local TRIGGERS = "src/triggers/svo (aliases, triggers)/svo/"
local PRIOS = { "src/resources/default_prios", "default_prios" }

-- contexts where impale means a blade's only: impale's own writhe, the
-- fallback that waits on a blade's, Sentinel's dismember, which a knight's
-- impale sets up, and a knight's and a skirmisher's weapon lines
local ALONE = {
  ["entry impale"] = true,
  ["codepaste.writhingimpale"] = true,
  ["codepaste.checkdismemberkill"] = true,
  ["svo.valid.knighthood_disembowel"] = true,
  ["svo.valid.skirmish_drag"] = true,
}

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return (data:gsub("\r\n", "\n"))
end

local checks, failures = 0, {}
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures[#failures + 1] = string.format("%s: got %s, want %s", desc, tostring(got), tostring(want))
  end
end

local dict = read_file(DICT)

-- an entry of the dictionary's, from its name to the next at its indent
local function entry(name)
  local s = dict:find("\n    " .. name .. " = {\n", 1, true)
  if not s then return nil end
  local e = dict:find("\n    [%w_]+ = {\n", s + 1) or #dict
  return dict:sub(s, e)
end

-- roped
check("roped is sent to serverside as entangled", (entry("roped") or ""):find("\n      gamename = 'entangled',\n", 1, true) ~= nil, true)

-- the entry
local daegger = entry("daeggerimpale") or ""
check("daeggerimpale has an entry", daegger ~= "", true)
check("daeggerimpale is sent to serverside under its own name", daegger:find("gamename = 'daeggerimpale'", 1, true) ~= nil, true)
check("daeggerimpale is writhed", daegger:find("action = 'writhe'", 1, true) ~= nil, true)
check("daeggerimpale's writhe waits for impale's", daegger:find("not svo.doingaction('curingimpale') and not svo.doingaction('impale')", 1, true) ~= nil, true)
check("impale's writhe waits for daeggerimpale's", (entry("impale") or ""):find("not svo.doingaction('curingdaeggerimpale') and not svo.doingaction('daeggerimpale')", 1, true) ~= nil, true)
local wait = entry("curingdaeggerimpale") or ""
check("daeggerimpale has a wait", wait:find("customwait = 6", 1, true) ~= nil, true)
check("the expire line ends it", wait:find("withdrew = function() svo.rmaff('daeggerimpale') end", 1, true) ~= nil, true)
local sstosvoa = dict:match("\n    sstosvoa = {\n(.-)\n    },") or ""
check("GMCP's daeggerimpale is svof's", sstosvoa:match("\n      daeggerimpale = ([^\n]-),\n"), "'daeggerimpale'")

-- the other writhes respect it, through codepaste.writhe and
-- codepaste.writhingimpale
local writhe = dict:match("\ncodepaste%.writhe = function%(%)\n(.-)\nend\n") or ""
check("codepaste.writhe counts daeggerimpale's writhe", writhe:find("not svo.doingaction('curingdaeggerimpale') and not svo.doingaction('daeggerimpale')", 1, true) ~= nil, true)
local handlers = 0
for name in ("bound webbed roped hoisted transfixed"):gmatch("%a+") do
  if (entry(name) or ""):find("impale = function()\n          codepaste.writhingimpale()\n        end", 1, true) then
    handlers = handlers + 1
  end
end
check("writhes that run into an impale wait on the one svof has", handlers, 5)

-- the parity
local contexts = 0
for _, path in ipairs(SOURCES) do
  local context = "top"
  local n = 0
  for line in (read_file(path) .. "\n"):gmatch("([^\n]*)\n") do
    n = n + 1
    context = line:match("^    ([%w_]+) = {$") and ("entry " .. line:match("^    ([%w_]+) = {$"))
      or line:match("^function ([%w_%.]+)%(") or line:match("^([%w_%.]+) = function") or context
    local blade = line:find("affs%.impale%f[^%w_]") or line:find("dict%.impale%.misc") or line:find("dict%.curingimpale%.waitingfor")
    if blade then
      contexts = contexts + 1
      if not ALONE[context] and not line:find("daeggerimpale", 1, true) then
        check(string.format("%s:%d (%s) names daeggerimpale too", path, n, context), false, true)
      end
    end
  end
end
-- a floor, so a parse that finds nothing can't pass
check("read at least 15 lines naming impale", contexts >= 15, true)

-- the triggers
local function trigger(folder, name)
  local json = read_file(TRIGGERS .. folder .. "/triggers.json")
  local s = json:find('"name": "' .. name .. '"', 1, true)
  if not s then return nil end
  local e = json:find('"name": ', s + 1, true) or #json
  return json:sub(s, e)
end
local function script(folder, name)
  local f = io.open(TRIGGERS .. folder .. "/" .. name:gsub(" ", "_") .. ".lua", "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end
check("the daegger's line adds daeggerimpale", script("Apostasy", "Dagger impaled"), "svo.valid.proper_daeggerimpale()")
local withdrew = trigger("Apostasy", "Daegger withdrew") or ""
check("the expire line has a trigger", withdrew:find('"pattern": "You sigh in relief as the daegger withdraws itself from your belly."', 1, true) ~= nil, true)
check("the expire line's trigger is active", withdrew:find('"isActive": "yes"', 1, true) ~= nil, true)
check("the expire line ends the impale", script("Apostasy", "Daegger withdrew"), "svo.valid.daeggerimpale_withdrew()")
check("impale's DIAGNOSE line is a blade's only", (trigger("General", "impale") or ""):find("impaled by a daegger.", 1, true), nil)
check("the daegger's DIAGNOSE line has a trigger", (trigger("General", "daeggerimpale") or ""):find('"pattern": "impaled by a daegger."', 1, true) ~= nil, true)
check("the daegger's DIAGNOSE line names daeggerimpale", script("General", "daeggerimpale"), "svo.valid.diag('daeggerimpale')")
local main = read_file(MAIN)
check("svo.valid.daeggerimpale_withdrew is defined", main:find("\nfunction svo.valid.daeggerimpale_withdrew()\n", 1, true) ~= nil, true)
check("svo.valid.proper_daeggerimpale is defined", main:find("\nfunction svo.valid.proper_daeggerimpale()\n", 1, true) ~= nil, true)
check("the writhed loop makes svo.valid.writheddaeggerimpale", main:find("'impale', 'daeggerimpale', 'hoisted'}) do\nvalid['writhed'..aff]", 1, true) ~= nil, true)
-- the symptom handlers' own paths to simpleimpale and proper_impale don't
-- test affs.impale, so the parity above can't see them
for _, f in ipairs({ "symp_impale", "symp_impaled" }) do
  local body = main:match("\nfunction svo%.valid%." .. f .. "%(%)\n(.-)\nend\n") or ""
  check(f .. " holds back for a daegger's impale", body:find("^  %-%- [^\n]*\n  if affs%.daeggerimpale then return end\n") ~= nil, true)
end
local withdrawn = main:match("\nfunction svo%.valid%.daeggerimpale_withdrew%(%)\n(.-)\nend\n") or ""
check("the expire line ends an impale svof has for the daegger", withdrawn:find("and affs.impale then\n    valid.impale_withdrew()", 1, true) ~= nil, true)

-- GMCP's adds update canoutr, which addaffdict alone doesn't
local setup = read_file("src/scripts/svo (setup, misc, empty, funnies, dor)/Setup.lua")
for _, h in ipairs({ "track gained gmcp aff", "update list of gmcp affs" }) do
  -- from the handler's label back to its own connect, and no further
  local e = setup:find("\nend, '" .. h .. "')", 1, true) or 0
  local s = 0
  for at in setup:sub(1, e):gmatch("()\nsignals%.[%w_]+:connect%(") do s = at end
  local body = e > 0 and setup:sub(s, e) or ""
  check("GMCP's '" .. h .. "' updates canoutr", body:find("signals.canoutr:emit()", 1, true) ~= nil, true)
end

-- serverside: svof writhes it by default, as it does impale, until the
-- player hands it over
check("a new setup leaves daeggerimpale to svof", read_file(SERVER):find("\n    svo.serverignore.daeggerimpale = false", 1, true) ~= nil, true)
check("restoring the defaults leaves daeggerimpale to svof", read_file(ALIAS):find("\n  svo.unsetserverignore'daeggerimpale'\n", 1, true) ~= nil, true)

-- priorities: just below impale in both lists, in both copies
for _, path in ipairs(PRIOS) do
  local prios = read_file(path)
  for list, names in pairs({ slowcuring = { "impale_misc", "daeggerimpale_misc" }, misc = { "impale", "daeggerimpale" } }) do
    local body = prios:match("\n" .. list .. " = {\n(.-)\n}") or ""
    local blade = tonumber(body:match('%[(%d+)%] = "' .. names[1] .. '"'))
    local dagger = tonumber(body:match('%[(%d+)%] = "' .. names[2] .. '"'))
    check(string.format("%s: %s is just below %s", path, names[2], names[1]), dagger and blade and blade - dagger, 1)
  end
end

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
