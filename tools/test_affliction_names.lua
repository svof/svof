--[[
Static test of two afflictions svof filed under the wrong name.

  * A Dragoncraft enmeshment gives the game's enmesh: partly bound, so you
    can't parry, cured by time (AFFLICTION SHOW, captured 2026-10-20). svof
    recorded it as roped, entanglement, which is writhed out of, and mapped
    GMCP's enmesh to false. In blackout it writhed for ropes that weren't
    there, and it never tracked enmesh. It's a time-cured entry now.
  * homunculusmercury is svof's swellskin: the game's cure and DIAGNOSE lines
    for it are the ones svof's swellskin triggers read. GMCP's name was
    mapped to false, so GMCP never added or removed swellskin.

This reads the real sources and checks the entry, the GMCP map, the
enmeshment handler and the triggers.

Run: lua tools/test_affliction_names.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local MAIN = "src/scripts/svo (trigger functions)/Main_trigger_functions.lua"
local TRIGGERS = "src/triggers/svo (aliases, triggers)/svo/"

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
local function entry(name)
  -- an entry's line can carry a comment, as swellskin's does
  local s = dict:find("\n    " .. name .. " = {[^\n]*\n")
  if not s then return nil end
  -- to its own closing brace, so the comment above the next entry isn't read
  local e = dict:find("\n    }", s + 1, true) or #dict
  return dict:sub(s, e)
end

local sstosvoa = dict:match("\n    sstosvoa = {\n(.-)\n    },") or ""
local function mapped(gmcp) return sstosvoa:match("\n      " .. gmcp .. " = ([^\n]-),\n") end

-- enmesh
local enmesh = entry("enmesh") or ""
check("enmesh has an entry", enmesh ~= "", true)
check("enmesh waits the game's default time", enmesh:match("customwait = (%d+)"), "6")
check("enmesh's wait running out ends it", enmesh:find("ontimeout = function()\n          svo.rmaff('enmesh')", 1, true) ~= nil, true)
check("enmesh is not writhed", enmesh:find("writhe", 1, true), nil)
check("GMCP's enmesh is svof's", mapped("enmesh"), "'enmesh'")
check("GMCP's entangled is still roped", mapped("entangled"), "'roped'")

local main = read_file(MAIN)
local hit = main:match("\nfunction svo%.valid%.enmesh_hit%(%)\n(.-)\nend\n") or ""
check("an enmeshment adds enmesh", hit:find("valid.simpleenmesh()", 1, true) ~= nil, true)
check("an enmeshment adds no roped", hit:find("simpleroped", 1, true), nil)
local afflist = main:match("\n  local afflist = (%b{})") or ""
check("svo.valid.enmesh_woreoff is generated", afflist:find("'enmesh'", 1, true) ~= nil, true)

local function trigger(folder, name)
  local json = read_file(TRIGGERS .. folder .. "/triggers.json")
  local s = json:find('"name": "' .. name .. '"', 1, true)
  if not s then return "" end
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
for _, t in ipairs({
  { "Dragoncraft", "Enmeshment freed", "You manage to free yourself of the bonds clinging to your limbs.", "svo.valid.enmesh_woreoff()" },
  { "General", "enmesh", "unable to parry due to being partially bound.", "svo.valid.diag('enmesh')" },
}) do
  local item = trigger(t[1], t[2])
  check(t[2] .. " matches its line exactly", item:find('"pattern": "' .. t[3] .. '",\n%s*"type": "exactMatch"') ~= nil, true)
  check(t[2] .. " is active", item:find('"isActive": "yes"', 1, true) ~= nil, true)
  check(t[2] .. "'s script", script(t[1], t[2]), t[4])
end

-- homunculusmercury
check("GMCP's homunculusmercury is svof's swellskin", mapped("homunculusmercury"), "'swellskin'")
check("svof has a swellskin entry", entry("swellskin") ~= nil, true)

-- constricted, snared and vinewreathed: time-cured, with the default times,
-- cure and expire lines and DIAGNOSE lines AFFLICTION SHOW gives
for _, t in ipairs({
  { "constricted", 30, "You manage to wrestle the vines away from your limbs.", "being constricted by vines." },
  { "snared", 20, "You manage to disentangle yourself from the rope trap which had snared your ankles.", "tangled up by a rope snare." },
  { "vinewreathed", 20, "The vines flailing about your form recede.", "wreathed in flailing vines." },
}) do
  local name = t[1]
  local body = entry(name) or ""
  check(name .. " has an entry", body ~= "", true)
  check(name .. " waits the game's default time", body:match("customwait = (%d+)"), tostring(t[2]))
  check(name .. "'s wait running out ends it", body:find("ontimeout = function()\n          svo.rmaff('" .. name .. "')", 1, true) ~= nil, true)
  check(name .. " is not writhed", body:find("writhe", 1, true), nil)
  check("GMCP's " .. name .. " is svof's", mapped(name), "'" .. name .. "'")
  check("svo.valid." .. name .. "_woreoff is generated", afflist:find("'" .. name .. "'", 1, true) ~= nil, true)
  for _, tr in ipairs({
    { "svo " .. name .. " woreoff", t[3], "svo.valid." .. name .. "_woreoff()" },
    { name, t[4], "svo.valid.diag('" .. name .. "')" },
  }) do
    local item = trigger("General", tr[1])
    check(tr[1] .. " matches its line exactly", item:find('"pattern": "' .. tr[2]:gsub("%p", "%%%0") .. '",\n%s*"type": "exactMatch"') ~= nil, true)
    check(tr[1] .. " is active", item:find('"isActive": "yes"', 1, true) ~= nil, true)
    check(tr[1] .. "'s script", script("General", tr[1]), tr[3])
  end
end

-- deepsleep: its own entry, not sleep. You never wake from it on your own,
-- so svof mustn't try to wake you, which sleep's misc action does
local deepsleep = entry("deepsleep") or ""
check("deepsleep has an entry", deepsleep ~= "", true)
check("GMCP's deepsleep is svof's deepsleep", mapped("deepsleep"), "'deepsleep'")
check("GMCP's sleeping is still sleep", mapped("sleeping"), "'sleep'")
check("deepsleep has no action to wake", deepsleep:find("misc = {", 1, true), nil)
check("nor a wait to time out", deepsleep:find("waitingfor", 1, true), nil)
check("nor sends anything", deepsleep:find("send(", 1, true), nil)

-- and wherever svof's curing holds back for sleep, it holds back for
-- deepsleep. The exceptions only make sense for sleep itself: sleep's own
-- entry, which wakes you, and the misc check letting that wake through
-- (it returns early for deepsleep instead)
local SKELETON = "src/scripts/svo (curing skeleton, controllers, action system)/Curing_skeleton.lua"
local sleep_entry = entry("sleep") or ""
local outside_sleep = dict:gsub(sleep_entry:gsub("%p", "%%%0"), "", 1)
check("sleep's entry is found to leave out", #outside_sleep < #dict, true)
local SLEEP_ONLY = { "(not affs.sleep or j.p.misc.action_name == 'sleep')" }
for path, src in pairs({ [DICT] = outside_sleep, [SKELETON] = read_file(SKELETON) }) do
  -- a gate can run over several lines, so look at the statement around it
  for at in src:gmatch("()affs%.sleep") do
    local s = at
    while s > 1 and not src:sub(s - 1, s - 1):find("[\n]") do s = s - 1 end
    local line = src:sub(s, (src:find("\n", at, true) or #src))
    local around = src:sub(math.max(1, s - 200), (src:find("\n", at, true) or #src) + 200)
    local only = false
    for _, ok in ipairs(SLEEP_ONLY) do if line:find(ok, 1, true) then only = true end end
    if not only and not line:find("^%s*%-%-") then
      check(path:match("[^/]+$") .. ": holds back for deepsleep where it does for sleep: " .. line:gsub("^%s+", ""):sub(1, 60),
        line:find("affs.deepsleep", 1, true) ~= nil, true)
    end
  end
end
local misc_check = read_file(SKELETON):match("\nsvo%.check_misc = function%(sync_mode, onlyamnesia%)\n(.-)\n  end\n") or ""
check("the misc check returns early in deepsleep", misc_check:find("if affs.stun or affs.unconsciousness or affs.deepsleep then", 1, true) ~= nil, true)

print(string.format("%d checks, %d failures", checks, #failures))
if #failures > 0 then
  for _, msg in ipairs(failures) do print("FAIL: " .. msg) end
  os.exit(1)
end
print("ALL PASS")
