--[[
Logic-level test of how svof paces CURING PRIORITY.

The game takes 5 uses of CURING PRIORITY a second and refuses the rest, not
counting viewing or the health and mana swap (Announce #5450). A live run on
2026-11-01 went over it: with the saved class differing from the game's,
loading sent a sync, a reset of both curingsets and another sync, 12 uses. The
game replied "You have exceeded the spam threshold", three commands were lost,
and svof never sent them again, since its diff took them as sent. Both
defence lists and slowcuring's afflictions stayed empty until the next sync.

Four things let that happen, and this test covers each:
- The class change reset was sent directly, past the old counter.
- The counter restarted every second, wherever the sends fell. The game can
  take commands sent about a second apart together: in that run, commands sent
  0.88 s apart reached it 0.08 s apart.
- A command over the length limit was also sent directly, and the length count
  was never cleared after it, so every later priority went as its own command.
- A refused command was never sent again.

This runs the real loaders through tools/svof_world.lua and replays what svof
sent through a model of the game: its curingsets, and the limit, with every
command held to the next 0.9 s mark so commands sent close together arrive
together. The model is this test's reading of the announcement and of that
run, not the game's code, so it proves what svof sends, not what the game does.

Run: lua tools/test_prio_spam_limit.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function check(desc, ok, detail)
  checks = checks + 1
  if not ok then failures[#failures + 1] = desc .. (detail and (": " .. detail) or "") end
end

-- ===== what svof sends, with the time it went =====

local function new_run(class)
  local w = world.new({ class = class or "Magi" })
  local recorded = w.env.raiseEvent
  w.env.raiseEvent = function(name, ...)
    recorded(name, ...)
    w.svo.events(name, ...)
  end
  local run = { w = w, log = {}, seen = 0 }
  function run.collect()
    for i = run.seen + 1, #w.sent do run.log[#run.log + 1] = { at = w.now, cmd = w.sent[i] } end
    run.seen = #w.sent
  end
  function run.ticks(seconds)
    w.advance(0)
    run.collect()
    for _ = 1, math.floor(seconds / 0.05) do
      w.advance(0.05)
      run.collect()
    end
  end
  return run
end

local function is_use(cmd)
  local lower = cmd:lower()
  if not lower:find("^curing priority") then return false end
  return not (lower == "curing priority health" or lower == "curing priority mana"
    or lower == "curing priority list" or lower == "curing priority defence list")
end

local function uses(log, from)
  local out = {}
  for i = from or 1, #log do
    if is_use(log[i].cmd) then out[#out + 1] = log[i] end
  end
  return out
end

-- the most uses that reach the game within any one second
local function busiest_second(log)
  local arrivals = {}
  for _, entry in ipairs(uses(log)) do
    arrivals[#arrivals + 1] = (math.floor(entry.at / 0.9) + 1) * 0.9
  end
  local most = 0
  for i = 1, #arrivals do
    local count = 0
    for j = i, #arrivals do
      if arrivals[j] - arrivals[i] < 1 then count = count + 1 end
    end
    if count > most then most = count end
  end
  return most
end

-- ===== the game's curingsets =====

local function new_server()
  local server = { current = "normal", sets = {} }
  local function set(name)
    server.sets[name] = server.sets[name] or { defs = {}, affs = {} }
    return server.sets[name]
  end
  server.set = set

  local function apply(tab, rest)
    local name = {}
    for word in rest:gmatch("%S+") do
      if tonumber(word) or word == "reset" then
        tab[table.concat(name, " ")] = word ~= "reset" and word or nil
        name = {}
      else
        name[#name + 1] = word
      end
    end
  end

  function server.command(cmd)
    local lower = cmd:lower()
    local switch = lower:match("^curingset switch (%S+)$")
    if switch then server.current = switch return end
    local s = set(server.current)
    if lower == "curing priority reset" then s.affs = {} return end
    if lower == "curing priority defence list reset" then s.defs = {} return end
    local rest = lower:match("^curing priority defence (.*)$")
    if rest then apply(s.defs, rest) return end
    rest = lower:match("^curing priority (.*)$")
    if rest then apply(s.affs, rest) end
  end

  return server
end

local function replay(log)
  local server = new_server()
  for _, entry in ipairs(log) do server.command(entry.cmd) end
  return server
end

-- ===== the sequence from the live run =====

do
  local run = new_run("Magi")
  local svo = run.w.svo
  svo.conf.serverside = true
  svo.signals["svo config changed"]:emit("serverside")
  run.ticks(0.05)
  svo.classchange("Druid")
  run.ticks(0.05)
  svo.defkeepup[svo.defs.mode].deathsight = true
  svo.signals["svo keepup changed"]:emit(svo.defs.mode, "deathsight", true)
  run.ticks(20)

  local most = busiest_second(run.log)
  check("load, class change, sync: at most 5 uses reach the game in a second", most <= 5, most .. " did")

  local total = #uses(run.log)
  check("the sequence still sends more than the limit, or this proves nothing", total > 5, tostring(total))

  local server = replay(run.log)
  for _, name in ipairs({ "normal", "slowcuring" }) do
    check(name .. " holds afflictions at the end", next(server.set(name).affs) ~= nil)
    check(name .. " holds deathsight at the end", server.set(name).defs.deathsight ~= nil)
    check(name .. " holds no Magi defence at the end", server.set(name).defs.stoneskin == nil)
  end
  check("the curingset in use is unchanged", server.current == "normal", server.current)
end

-- ===== a small change isn't held back =====

do
  local run = new_run("Magi")
  run.ticks(5)
  local before = #run.log
  run.w.svo.sendcuringprio("paralysis 3", "affliction")
  run.w.advance(0)
  run.collect()
  check("one change goes out at once", #run.log == before + 1 and run.log[#run.log].cmd == "curing priority paralysis 3",
    run.log[#run.log] and run.log[#run.log].cmd)
end

-- ===== the pending order is kept, and the sets stay apart =====

do
  local run = new_run("Magi")
  run.ticks(5)
  local svo = run.w.svo
  local before = #run.log
  for i = 1, 9 do
    svo.sendcuringprio("first " .. i, "affliction")
    run.w.advance(0)
    svo.sendcuringprio("first " .. i + 1, "affliction")
    run.w.advance(0)
  end
  run.ticks(12)
  local sent = uses(run.log, before + 1)
  check("18 changes sent one by one all go out", #sent == 18, tostring(#sent))
  local inorder = true
  for i = 2, #sent do
    if sent[i].at < sent[i - 1].at then inorder = false end
  end
  local a, b = sent[1] and sent[1].cmd, sent[18] and sent[18].cmd
  check("in order", inorder and a == "curing priority first 1" and b == "curing priority first 10", tostring(b))
  check("at most 4 uses in the first two seconds", #(function()
    local out = {}
    for _, e in ipairs(sent) do if e.at - sent[1].at < 2 then out[#out + 1] = e end end
    return out
  end)() == 4)
end

-- ===== over the length limit =====

do
  local run = new_run("Magi")
  run.ticks(5)
  local svo = run.w.svo
  local before = #run.log
  local wanted = {}
  for i = 1, 400 do
    local prio = ("longafflictionname%03d 25"):format(i)
    wanted[i] = prio
    svo.sendcuringprio(prio, "affliction")
  end
  run.ticks(30)
  local sent = uses(run.log, before + 1)
  check("400 priorities over the limit take a few commands", #sent <= 6, #sent .. " commands")
  local all, longest = table.concat((function()
    local out = {}
    for _, e in ipairs(sent) do out[#out + 1] = e.cmd end
    return out
  end)(), " "), 0
  for _, e in ipairs(sent) do if #e.cmd > longest then longest = #e.cmd end end
  check("no command over 2048 characters", longest <= 2048, tostring(longest))
  local missing = 0
  for _, prio in ipairs(wanted) do
    if not all:find(prio, 1, true) then missing = missing + 1 end
  end
  check("every priority is sent", missing == 0, missing .. " missing")
  check("a command of only the prefix is never sent", not all:find("curing priority curing priority", 1, true))
end

-- ===== a refusal =====

do
  local run = new_run("Magi")
  run.ticks(5)
  local svo = run.w.svo
  local before = #run.log
  for i = 1, 6 do
    svo.sendcuringprio("lost " .. i, "affliction")
    run.w.advance(0)
  end
  run.collect()
  check("four went and two wait", #uses(run.log, before + 1) == 4, tostring(#uses(run.log, before + 1)))

  -- the game refuses them, one line for each
  for _ = 1, 3 do svo.hitpriospamlimit() end
  local after_refusal = #run.log
  run.w.advance(0)
  run.collect()
  check("nothing goes while the game is refusing", #run.log == after_refusal)

  run.ticks(12)
  local again = uses(run.log, after_refusal + 1)
  local order = {}
  for _, e in ipairs(again) do order[#order + 1] = e.cmd:match("(%d+)$") end
  check("everything recent goes again once, in order, with what waited after it",
    table.concat(order, " ") == "1 2 3 4 5 6", table.concat(order, " "))
end

-- a refusal of a slowcuring command goes back to slowcuring
do
  local run = new_run("Magi")
  run.ticks(5)
  local svo = run.w.svo
  svo.sendcuringprio("slowone 7", "affliction", true)
  run.w.advance(0)
  run.collect()
  local before = #run.log
  svo.hitpriospamlimit()
  run.ticks(5)
  local server = new_server()
  for i = before + 1, #run.log do server.command(run.log[i].cmd) end
  check("the resent command lands in slowcuring", server.set("slowcuring").affs.slowone == "7")
  check("and the game ends on normal", server.current == "normal", server.current)
end

-- the game keeps refusing: stop, and say so
do
  local run = new_run("Magi")
  run.ticks(5)
  local svo = run.w.svo
  svo.sendcuringprio("stubborn 7", "affliction")
  run.w.advance(0)
  run.collect()
  local function said()
    for _, text in ipairs(run.w.echoes) do
      if text:find("keeps refusing", 1, true) then return true end
    end
    return false
  end
  local sent_after = {}
  for try = 1, 3 do
    svo.hitpriospamlimit()
    run.ticks(3)
    sent_after[try] = #uses(run.log)
  end
  check("three tries send it again", sent_after[1] == 2 and sent_after[2] == 3 and sent_after[3] == 4,
    table.concat(sent_after, " "))
  check("no warning yet", not said())
  svo.hitpriospamlimit()
  run.ticks(5)
  check("the fourth gives up", #uses(run.log) == 4, tostring(#uses(run.log)))
  check("and warns", said())

  -- a later, separate refusal starts over
  run.ticks(31)
  svo.sendcuringprio("later 7", "affliction")
  run.w.advance(0)
  run.collect()
  local before = #uses(run.log)
  svo.hitpriospamlimit()
  run.ticks(5)
  check("a refusal much later tries again", #uses(run.log) == before + 1, (#uses(run.log) - before) .. " resent")
end

-- ===== a class change drops what was waiting =====

do
  local run = new_run("Magi")
  run.ticks(5)
  local svo = run.w.svo
  svo.conf.serverside = true
  for i = 1, 6 do
    svo.sendcuringprio("oldclass " .. i, "affliction")
    run.w.advance(0)
  end
  run.collect()
  local before = #run.log
  svo.sk.resetserversideprios()
  run.ticks(8)
  local stale = {}
  for i = before + 1, #run.log do
    if run.log[i].cmd:find("oldclass", 1, true) then stale[#stale + 1] = run.log[i].cmd end
  end
  check("the old class's waiting commands are not sent", #stale == 0, table.concat(stale, "; "))
  local server = new_server()
  server.set("normal").defs.stoneskin = "3"
  server.set("slowcuring").defs.stoneskin = "3"
  for i = before + 1, #run.log do server.command(run.log[i].cmd) end
  check("both curingsets are reset", not server.set("normal").defs.stoneskin and not server.set("slowcuring").defs.stoneskin)
end

-- ===== the trigger that reports a refusal =====

do
  local dir = "src/triggers/svo (aliases, triggers)/svo/General/Server-side commands/"
  local f = assert(io.open(dir .. "triggers.json", "r"))
  local json = f:read("*a")
  f:close()
  check("the trigger matches the game's whole line",
    json:find('"You have exceeded the spam threshold for curing priority. Please see Announce #5450 for details."', 1, true) ~= nil)
  f = assert(io.open(dir .. "Curing_priority_spam_limit.lua", "r"))
  local script = f:read("*a")
  f:close()
  check("and calls the handler", script:find("svo.hitpriospamlimit()", 1, true) ~= nil)
end

-- ===== the swap and viewing aren't held back =====

do
  local run = new_run("Magi")
  run.ticks(5)
  local svo = run.w.svo
  for i = 1, 8 do
    svo.sendcuringprio("busy " .. i, "affliction")
    run.w.advance(0)
  end
  run.collect()
  local before = #run.log
  svo.sendcuring("priority health")
  run.w.advance(0)
  run.collect()
  local found = false
  for i = before + 1, #run.log do
    if run.log[i].cmd == "curing priority health" then found = true end
  end
  check("the health swap goes straight out while priorities wait", found)
end

if #failures == 0 then
  print(("ALL PASS (%d checks)"):format(checks))
else
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(("%d of %d checks failed"):format(#failures, checks))
  os.exit(1)
end
