--[[
Logic-level test of vconfig serverprios custom: the player's own serverside
affliction priorities.

In auto mode svof works out the game's affliction priorities from its own
lists. In custom mode it takes them from the game's list into
svo.serverprios, keeps them up from the lines confirming a change, and sends
only two things: 26 for an affliction it cures itself or is told to ignore,
and the player's number when that ends. Defence priorities are svof's in
both modes.

This covers:
- the switch to custom, which reads both curingsets and changes no number
  the game already has right
- the sync sending no affliction numbers in custom mode, and still sending
  defence numbers
- a change made in game, by a confirmation line and by a list
- an ignore going on and coming off
- a reset in game
- the switch back to auto, and stack entries surviving the round trip
- a class change, and serverside going on, in custom mode

It runs the real loaders through tools/svof_world.lua and feeds the game's
lines to the handlers the trigger and the list's reader call. The lists are
the captures in tools/test_server_priority_list.lua, read from that file. It
proves what svof sends and keeps, not what the game does with it.

Run: lua tools/test_server_priority_custom.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function check(desc, ok, detail)
  checks = checks + 1
  if not ok then failures[#failures + 1] = desc .. (detail and (": " .. tostring(detail)) or "") end
end
local function eq(got, want, desc)
  check(desc, got == want, ("got %s, want %s"):format(tostring(got), tostring(want)))
end

-- ===== the captured lists =====

local LIST_PLAIN, LIST_DEFAULTS
do
  local f = assert(io.open("tools/test_server_priority_list.lua", "r"))
  local src = f:read("*a"):gsub("\r\n", "\n")
  f:close()
  LIST_PLAIN = assert(src:match("local LIST_PLAIN = %[%[\n(.-)%]%]"), "LIST_PLAIN not found")
  LIST_DEFAULTS = assert(src:match("local LIST_DEFAULTS = %[%[\n(.-)%]%]"), "LIST_DEFAULTS not found")
end
local LIST_SLOW = LIST_PLAIN:gsub("priority set normal", "priority set slowcuring", 1)
local LIST_SLOW_DEFAULTS = LIST_DEFAULTS:gsub("priority set normal", "priority set slowcuring", 1)

local SWITCH_NORMAL = "You will now cure using the normal set."
local SWITCH_SLOW = "You will now cure using the slowcuring set."
local RESET = "All your curing affliction priorities have been reset to defaults."

-- ===== one svof, with serverside on =====

local function new_game()
  local w = world.new({ class = "Magi" })
  local svo = w.svo
  local g = { w = w, svo = svo, sk = svo.sk, mark = 0 }
  svo.conf.serverside = true

  function g.line(text, isprompt)
    w.env.line = text
    w.env.isPrompt = function() return isprompt or false end
    local readers = {}
    for _, t in ipairs(w.triggers) do
      if not t.killed and t.kind == "regex" and t.pattern == "^" and t.code:find("serverlist_line", 1, true) then
        readers[#readers + 1] = t
      end
    end
    if not isprompt then svo.sk.serverprio_line(text) end
    for _, t in ipairs(readers) do
      if not t.killed then w.run(t.code, "reader") end
    end
  end
  function g.lines(text)
    for l in (text .. "\n"):gmatch("(.-)\n") do g.line(l) end
  end
  -- lets everything queued go out, past the pacing of CURING PRIORITY
  function g.settle()
    for _ = 1, 30 do w.advance(1) end
  end
  -- what was sent since the last call, as one string with a line per command
  -- now: only what has gone out already, with no time passing, for the
  -- moments svof waits on the game's answer
  function g.sent(now)
    if now then w.advance(0) else g.settle() end
    local out = {}
    for i = g.mark + 1, #w.sent do out[#out + 1] = w.sent[i] end
    g.mark = #w.sent
    return "\n" .. table.concat(out, "\n") .. "\n"
  end
  function g.echoed(text)
    for _, e in ipairs(w.echoes) do
      if e:find(text, 1, true) then return true end
    end
    return false
  end
  function g.count(set)
    local n = 0
    for _ in pairs(svo.serverprios[set] or {}) do n = n + 1 end
    return n
  end
  function g.mode(mode)
    svo.conf.serverprios = mode
    svo.sk.serverpriosmode()
  end
  -- the game's answer to svof asking for both lists
  function g.answer(slow, normal)
    g.line(SWITCH_SLOW)
    g.lines(slow)
    g.line(SWITCH_NORMAL)
    g.lines(normal)
  end
  return g
end

-- whether a sent priority command sets name to number: " name number" ends
-- at a space or the end of the line
local function sets(sent, name, number)
  return sent:find(" " .. name .. " " .. number .. "[ \n]") ~= nil
end
-- whether any affliction priority was sent: CURING PRIORITY, but not its
-- DEFENCE form and not a list
local function any_affliction(sent)
  for cmd in sent:gmatch("[^\n]+") do
    local lower = cmd:lower()
    if lower:find("^curing priority ") and not lower:find("^curing priority defence")
      and lower ~= "curing priority list" then
      return cmd
    end
  end
end

-- ===== the option =====

do
  local g = new_game()
  local option = g.svo.config_dict.serverprios
  check("the option exists", type(option) == "table")
  eq(option.check("auto"), true, "auto is a value")
  eq(option.check("custom"), true, "custom is a value")
  eq(option.check("other"), nil, "nothing else is")
  eq(g.sk.customserverprios(), false, "auto is the mode until custom is chosen")
  eq(type(g.svo.serverprios.normal), "table", "the table has the normal set")
  eq(type(g.svo.serverprios.slowcuring), "table", "and the slowcuring set")

  g.svo.conf.serverprios = "custom"
  eq(g.sk.customserverprios(), true, "custom with serverside on")
  g.svo.conf.serverside = false
  eq(g.sk.customserverprios(), false, "custom with serverside off does nothing")
end

-- ===== auto mode is as it was =====

do
  local g = new_game()
  g.sent()
  g.lines(LIST_PLAIN)
  eq(g.count("normal"), 0, "auto: a list read doesn't fill the table")
  g.svo.setignore("paralysis", true)
  -- a full sync, as serverside going on runs it
  g.sk.priosbeforechange = g.sk.getblankbeforestateprios()
  g.sk.priochangecache = { special = {} }
  g.sk.priochangetimer = true
  g.sk.updateserversideprios()
  local sent = g.sent()
  check("auto: the sync still sends 26 for an ignored affliction", sets(sent, "paralysis", 26), sent)
end

-- ===== the switch to custom =====

do
  local g = new_game()
  local svo, sk = g.svo, g.sk
  g.sent()

  g.mode("custom")
  local sent = g.sent(true)
  eq(sent, "\ncuringset switch slowcuring\ncuring priority list\ncuringset switch normal\ncuring priority list\n",
    "the switch asks for both lists, the set in use last")

  -- svof handles impale itself by default, so the 26 the list has for it is
  -- svof's, and paralysis at 2 is the player's
  check("this test's premise: svof cures impale itself", not svo.serverignore.impale)
  check("and leaves paralysis to the server", svo.serverignore.paralysis == true)

  g.answer(LIST_SLOW, LIST_PLAIN)
  eq(g.count("normal"), 131, "the normal set's numbers are taken")
  eq(g.count("slowcuring"), 131, "and the slowcuring set's")
  eq(svo.serverprios.normal.paralysis, 2, "a number the game has is the player's")
  eq(svo.serverprios.normal.icebound, 1, "so is one for an affliction svof has no action for")
  eq(svo.serverprios.normal.impaled, sk.autoserverprios("normal").impale,
    "an affliction svof keeps at 26 gets auto's number, for when the server cures it again")
  check("which is not 26", svo.serverprios.normal.impaled ~= 26)
  check("the switch says what it took", g.echoed("Took your serverside priorities from the game: 131 in the normal"))
  eq(sk.serverread.asked, nil, "svof stops waiting for lists")

  -- the captured list has daeggerimpale at 2, and svof cures it itself
  sent = g.sent()
  check("an affliction svof cures that the list had a number for goes to 26", sets(sent, "daeggerimpale", 26), sent)
  check("in the slowcuring set too",
    sent:find("curingset switch slowcuring\ncuring priority[^\n]* daeggerimpale 26[^\n]*\ncuringset switch normal") ~= nil, sent)
  check("nothing the game already has right is sent", not sets(sent, "impaled", 26) and not sent:find(" paralysis "), sent)
  eq(svo.serverprios.normal.daeggerimpale, 2, "and the table keeps the list's number for it")

  -- ===== the sync sends no affliction numbers =====

  sk.priosbeforechange = sk.getblankbeforestateprios()
  sk.priochangecache = { special = {} }
  sk.priochangetimer = true
  sk.updateserversideprios()
  sent = g.sent()
  eq(any_affliction(sent), nil, "a full sync sends no affliction number in custom mode")
  check("and still sends defence numbers", sent:find("curing priority defence ", 1, true) ~= nil, sent)

  -- ===== a change made in game =====

  g.line("You have set the 'asthma' affliction to the 9 priority.")
  eq(svo.serverprios.normal.asthma, 9, "a confirmed change is the player's new number")
  g.line("You have set the 'unweavingmind(2)' affliction to the 6 priority.")
  eq(svo.serverprios.normal["unweavingmind(2)"], 6, "so is a stack entry")
  eq(svo.serverprios.slowcuring.asthma, 4, "the other set is left alone")
  eq(any_affliction(g.sent()), nil, "and svof sends nothing back")

  g.line("You have set the 'impaled' affliction to the 3 priority.")
  eq(svo.serverprios.normal.impaled, 3, "a number for an affliction svof cures is kept for later")
  sent = g.sent()
  check("and the game's goes back to 26", sets(sent, "impaled", 26), sent)
  g.line("You have set the 'impaled' affliction to the 26 priority.")
  eq(svo.serverprios.normal.impaled, 3, "svof's own 26 isn't taken as the player's number")
  eq(any_affliction(g.sent()), nil, "and isn't answered")

  -- ===== an ignore going on and coming off =====

  svo.setignore("paralysis", true)
  svo.signals["svo ignore changed"]:emit("paralysis")
  sent = g.sent()
  check("an ignored affliction goes to 26", sets(sent, "paralysis", 26), sent)
  check("in both sets", select(2, sent:gsub(" paralysis 26", "")) == 2, sent)
  g.line("You have set the 'paralysis' affliction to the 26 priority.")
  eq(svo.serverprios.normal.paralysis, 2, "and the table keeps the player's number")

  -- a list the player asks for while it is ignored
  g.lines((LIST_PLAIN:gsub("2:  paralysis, ", "2:  ", 1):gsub("26: blindness", "26: paralysis, blindness", 1)))
  eq(svo.serverprios.normal.paralysis, 2, "a list read meanwhile leaves the player's number")
  eq(svo.serverprios.normal.asthma, 4, "and takes the game's for the rest")
  g.sent()

  svo.unsetignore("paralysis")
  svo.signals["svo ignore changed"]:emit("paralysis")
  sent = g.sent()
  check("coming off ignore, it gets the player's number back", sets(sent, "paralysis", 2), sent)
  check("and nothing else is sent", select(2, sent:gsub("curing priority", "")) == 2, sent)

  -- ===== a reset in game =====

  g.line(RESET)
  sent = g.sent(true)
  check("a reset makes svof ask for the lists again", sent:find("curing priority list", 1, true) ~= nil, sent)
  g.answer(LIST_SLOW, LIST_DEFAULTS)
  eq(svo.serverprios.normal.latched, 1, "the table takes the game's defaults")
  eq(svo.serverprios.normal.paralysis, 1, "for every entry")
  eq(svo.serverprios.normal["unweavingmind(2)"], nil, "and loses the stack entry the reset cleared")
  eq(svo.serverprios.slowcuring.asthma, 4, "the set that wasn't reset keeps its numbers")
  sent = g.sent()
  check("svof puts back at 26 what it cures itself", sets(sent, "impaled", 26) and sets(sent, "daeggerimpale", 26), sent)
  check("and says so", g.echoed("Your serverside priorities were reset"))
  eq(svo.serverprios.normal.impaled, 2, "the table has the default for it, not 26")

  -- ===== a class change =====

  g.line("You have set the 'unweavingbody(2)' affliction to the 7 priority.")
  g.sent()
  sk.resetserversideprios()
  sent = g.sent()
  check("a class change doesn't reset the affliction priorities", not sent:find("curing priority reset", 1, true), sent)
  check("and still resets the defence list", sent:find("curing priority defence list reset", 1, true) ~= nil, sent)
  sk.resyncserversideprios()
  sent = g.sent()
  check("after it, the table goes out again", sets(sent, "paralysis", 1) and sets(sent, "unweavingbody2", 7), sent)
  check("with 26 for what svof cures", sets(sent, "impaled", 26) and not sets(sent, "impaled", 2), sent)

  -- ===== back to auto =====

  g.mode("auto")
  sent = g.sent()
  check("auto resets the set in use", sent:find("curing PRIORITY RESET", 1, true) ~= nil, sent)
  check("and sends its own numbers again", any_affliction((sent:gsub("curing PRIORITY RESET\n", ""))) ~= nil, sent)
  check("it says the stack priorities of the reset set are gone", g.echoed("The stack priorities you set are gone from the normal set"))
  eq(svo.serverprios.normal["unweavingbody(2)"], 7, "the table keeps them")

  -- ===== and to custom again =====

  g.mode("custom")
  g.sent(true)
  g.answer(LIST_SLOW, LIST_PLAIN)
  eq(svo.serverprios.normal.paralysis, 2, "custom starts from what the game has now")
  eq(svo.serverprios.normal["unweavingbody(2)"], 7, "and keeps the stack entry the game lost")
  sent = g.sent()
  check("which it sends again", sets(sent, "unweavingbody2", 7), sent)

  -- ===== serverside going on in custom mode =====

  svo.signals["svo config changed"]:emit("serverside")
  sent = g.sent()
  check("serverside on doesn't reset the priorities", not sent:find("PRIORITY RESET", 1, true), sent)
  check("it sends the player's numbers", sets(sent, "paralysis", 2) and sets(sent, "icebound", 1), sent)
  check("and 26 for what svof cures", sets(sent, "impaled", 26), sent)
end

-- ===== custom chosen with serverside off =====

do
  local g = new_game()
  local svo = g.svo
  svo.conf.serverside = false
  g.mode("custom")
  eq(any_affliction(g.sent()), nil, "nothing is sent while serverside is off")
  check("svof says it starts with serverside", g.echoed("once serverside is on"))

  svo.conf.serverside = true
  svo.signals["svo config changed"]:emit("serverside")
  local sent = g.sent()
  check("serverside on asks for the lists, having no numbers yet", sent:find("curing priority list", 1, true) ~= nil, sent)
  check("and doesn't reset", not sent:find("PRIORITY RESET", 1, true), sent)
end

-- ===== the game never lists =====

do
  local g = new_game()
  g.mode("custom")
  g.settle()
  eq(g.sk.serverread.asked, nil, "svof stops waiting for a list that never comes")
  check("and says so", g.echoed("The game didn't list your serverside priorities"))
  eq(g.count("normal"), 0, "with no numbers taken")
end

if #failures == 0 then
  print(("ALL PASS (%d checks)"):format(checks))
else
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(("%d of %d checks failed"):format(#failures, checks))
  os.exit(1)
end
