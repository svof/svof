--[[
Logic-level test of what a class change leaves in serverside's two
curingsets, normal and slowcuring.

svof keeps svof's priorities in two curingsets and switches to slowcuring in
aeon and retardation. On a class change it resets the serverside priorities,
so serverside stops keeping up the old class's defences, then reloads and
sends the new class's. The reset only reached the curingset in use, normal
outside aeon, so slowcuring kept the old class's defences on its list:
serverside tried to raise them the moment aeon or retardation switched to
it. svof cannot take them off afterwards, since the new class's dictionary
doesn't have them. In aeon it was the other way round: normal kept them.

The reset clears both curingsets now. That exposed a second fault: in slow
curing, svof sent normal's priorities without switching curingsets, so they
landed in slowcuring and normal, cleared by a class change in aeon, got
nothing back. They switch to normal and back now, the way slowcuring's
priorities already switched to slowcuring and back outside it.

svof resends nothing at the change itself. The next keepup, ignore or
defence mode change diffs against a blank snapshot and sends everything, so
the test makes one and checks both curingsets got it.

This runs all 23 real loaders through tools/svof_world.lua, turns serverside
on for a Magi with three Magi defences on keepup, changes class to Druid
with svo.classchange, in and out of aeon, and replays everything svof sent
through a model of the game's curingsets: which one is in use, and each
one's defence and affliction priorities. The model is this test's reading of
CURING PRIORITY and CURINGSET, not the game's code, so it proves what svof
sends, not what the game does with it.

Run: lua tools/test_classchange_curingsets.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function check(desc, ok, detail)
  checks = checks + 1
  if not ok then failures[#failures + 1] = desc .. (detail and (": " .. detail) or "") end
end

-- ===== the game's curingsets, as this test reads the commands =====

local function new_server()
  local sets = {}
  local server = { current = "normal" }
  local function set(name)
    sets[name] = sets[name] or { defences = {}, affs = {} }
    return sets[name]
  end
  server.set = set

  -- "name words 3 other 4" or "name reset": a name runs until a number or reset
  local function pairs_of(rest)
    local out, name = {}, {}
    for word in rest:gmatch("%S+") do
      if tonumber(word) or word == "reset" then
        out[#out + 1] = { table.concat(name, " "), word }
        name = {}
      else
        name[#name + 1] = word
      end
    end
    return out
  end

  function server.command(cmd)
    local lower = cmd:lower()
    local switch = lower:match("^curingset switch (%S+)$")
    if switch then server.current = switch return end
    if lower:match("^curingset new ") then set(lower:match("^curingset new (%S+)$")) return end

    local s = set(server.current)
    local rest = lower:match("^curing priority defence (.*)$")
    if rest then
      if rest == "list reset" then s.defences = {} return end
      for _, p in ipairs(pairs_of(rest)) do
        if p[2] == "reset" then s.defences[p[1]] = nil else s.defences[p[1]] = tonumber(p[2]) end
      end
      return
    end
    rest = lower:match("^curing priority (.*)$")
    if rest then
      if rest == "reset" then s.affs = {} return end
      for _, p in ipairs(pairs_of(rest)) do
        if p[1] == "" and p[2] == "reset" then s.affs = {} else s.affs[p[1]] = p[2] end
      end
    end
  end

  return server
end

-- svof holds back a priority command when it has sent several within a
-- second, so let every timer it has set run
local function settle(w)
  for _ = 1, 10 do w.advance(2) end
end

local function replay(w, server, from)
  for i = from or 1, #w.sent do server.command(w.sent[i]) end
  return #w.sent + 1
end

-- the defences on a curingset's list that the current class's svof doesn't
-- know as a defence, sorted
local function foreign(w, defences)
  local known = {}
  for action, entry in pairs(w.svo.dict) do
    for _, bal in pairs(entry) do
      if type(bal) == "table" and bal.def then known[(entry.gamename or action):lower()] = true end
    end
  end
  local out = {}
  for name in pairs(defences) do if not known[name] then out[#out + 1] = name end end
  table.sort(out)
  return out
end

-- ===== a Magi on serverside, changing to Druid =====

-- svof's names, and the game's, which the curingsets hold
local MAGI_DEFS = { "stoneskin", "reflection", "diamondskin" }
local MAGI_GAMENAMES = { "stoneskin", "reflections", "diamondskin" }
-- and one every class has, which the Druid puts on keepup after the change
local GENERAL_DEF = "deathsight"

local function magi_on_serverside()
  local w = world.new({ class = "Magi" })
  local svo = w.svo
  -- Mudlet hands svof's own events to svo.events through the svo_events
  -- handler, which the world only records. A class change needs it: "svo
  -- system loaded" retakes serverside's blank snapshot from the new
  -- dictionary, and without it the next resync reads the old class's.
  local recorded = w.env.raiseEvent
  w.env.raiseEvent = function(name, ...)
    recorded(name, ...)
    w.svo.events(name, ...)
  end
  for _, def in ipairs(MAGI_DEFS) do
    svo.defkeepup[svo.defs.mode][def] = true
  end
  svo.conf.serverside = true
  svo.signals["svo config changed"]:emit("serverside")
  settle(w)
  return w
end

local function run(in_aeon)
  local label = in_aeon and "in aeon" or "out of aeon"
  local w = magi_on_serverside()
  local server = new_server()
  local next_sent = replay(w, server)

  -- the setup put the Magi defences in both curingsets, or the rest proves nothing
  for _, name in ipairs({ "normal", "slowcuring" }) do
    for _, def in ipairs(MAGI_GAMENAMES) do
      check(label .. ": Magi " .. name .. " keeps up " .. def, server.set(name).defences[def] ~= nil)
    end
  end

  if in_aeon then
    -- aeon itself, not sys.sync alone: the class change's reload sets sync
    -- again from the afflictions it keeps
    w.svo.addaffdict(w.svo.dict.aeon)
    w.svo.sk.checkaeony()
    settle(w)
    next_sent = replay(w, server, next_sent)
    check(label .. ": slowcuring in use before the class change", server.current == "slowcuring", server.current)
  end

  w.svo.classchange("Druid")
  settle(w)
  next_sent = replay(w, server, next_sent)

  check(label .. ": svof is Druid", w.svo.me.class == "Druid", tostring(w.svo.me.class))
  for _, name in ipairs({ "normal", "slowcuring" }) do
    local left = foreign(w, server.set(name).defences)
    check(label .. ": no Magi defences left in " .. name, #left == 0, table.concat(left, ", "))
  end

  -- svof resends nothing at the change itself: the next keepup, ignore or
  -- defence mode change does, diffing against a blank snapshot, so it sends
  -- everything to both curingsets. The reset must not be sent after it.
  local svo = w.svo
  svo.defkeepup[svo.defs.mode][GENERAL_DEF] = true
  svo.signals["svo keepup changed"]:emit(svo.defs.mode, GENERAL_DEF, true)
  settle(w)
  replay(w, server, next_sent)
  for _, name in ipairs({ "normal", "slowcuring" }) do
    check(label .. ": Druid " .. name .. " keeps up " .. GENERAL_DEF,
      server.set(name).defences[GENERAL_DEF] ~= nil)
    check(label .. ": Druid " .. name .. " has affliction priorities", next(server.set(name).affs) ~= nil)
    local left = foreign(w, server.set(name).defences)
    check(label .. ": still no Magi defences in " .. name, #left == 0, table.concat(left, ", "))
  end
  check(label .. ": the curingset in use is unchanged",
    server.current == (in_aeon and "slowcuring" or "normal"), server.current)
end

run(false)
run(true)

-- ===== serverside off: a class change sends no curingset switch =====

do
  local w = world.new({ class = "Magi" })
  w.svo.classchange("Druid")
  settle(w)
  local switched = {}
  for _, cmd in ipairs(w.sent) do
    if cmd:lower():find("curingset", 1, true) then switched[#switched + 1] = cmd end
  end
  check("serverside off: no curingset command", #switched == 0, table.concat(switched, "; "))
end

if #failures == 0 then
  print(("ALL PASS (%d checks)"):format(checks))
else
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(("%d of %d checks failed"):format(#failures, checks))
  os.exit(1)
end
