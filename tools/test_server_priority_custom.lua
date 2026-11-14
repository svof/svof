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
- svof's own sends, confirmed late or crossed by the player's edit, never
  taken as the player's numbers, and sends never confirmed stop waiting
- the check at login against a game that keeps what svof sends, and both
  answers to the differences it shows
- the game's lovers going to inlove and not to lust, which shares its name,
  and blindness sent as blind
- pva, avs and pvd as swaps of the server's numbers, in the order they went
  on, kept across a login, and never taken as the player's numbers
- autoslick putting asthma first in the server's numbers, and giving its
  number back
- vignore <aff> <count>: its refusals, one stack at 26 apart from the whole
  ignore, the stack entry svof makes following the plain one, the game's
  stack limit, and the switch to auto
- the warnings: nothing cures it, a number kept for something svof keeps at
  26, and an affliction left to the server that the game's list lacks, each
  once for each change
- the game's names from gamename or GMCP's, with none for svof's own
  afflictions, such as paradox
- vset, vswap and vswapslow with server at the end, which go into the table
  once the game confirms them, their refusals, vp serveraffs, the ss aff
  column of vp, export and import, and the reminder the plain forms give
- defences: the switch taking the game's numbers into the mode in use, the
  sync sending the player's numbers, edits in game and from vset, keepup
  deciding what is on the list, defence modes, vp serverdefs, the login
  check, and export and import

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
      if not t.killed and t.kind == "regex" and t.pattern == "^"
        and (t.code:find("serverlist_line", 1, true) or t.code:find("serverdeflist_line", 1, true)) then
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

  -- the game's lovers is the lover's curse, svof's inlove. svof's lovers
  -- action is lust, which has the same name and no priority in the game
  local toserver, toaction = g.sk.serverprionames()
  eq(toaction.lovers, "inlove", "the game's lovers is inlove, the lover's curse")
  eq(toserver.lovers, nil, "and lust, svof's lovers action, has no server priority")
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
  eq(sent, "\ncuringset switch slowcuring\ncuring priority list\ncuringset switch normal\ncuring priority list\n"
    .. "curing priority defence list\n",
    "the switch asks for both lists, the set in use last, and then for the defence list")

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

-- ===== a game that keeps what svof sends =====

-- the numbers the game has, starting from what svof read, with every
-- affliction number svof sent since put in, in order and in the curingset in
-- use. It stands in for the game at login
local function new_model(sets)
  local model = { sets = {}, active = "normal" }
  for set, entries in pairs(sets) do
    model.sets[set] = {}
    for entry, number in pairs(entries) do model.sets[set][entry] = number end
  end
  local listnames = { blind = "blindness", deaf = "deafness" }
  function model.apply(sent)
    for cmd in sent:gmatch("[^\n]+") do
      local set = cmd:match("^curingset switch (%w+)$")
      if set then model.active = set end
      local rest = cmd:match("^curing priority (.*)$")
      if rest and not rest:find("^defence") and rest ~= "list" and not rest:lower():find("^reset") then
        for name, number in rest:gmatch("(%S+) (%d+)") do
          local plain, stack = name:match("^(.-)(%d+)$")
          local entry = plain and (plain .. "(" .. stack .. ")") or (listnames[name] or name)
          model.sets[model.active][entry] = tonumber(number)
        end
      end
    end
  end
  function model.list(set)
    local levels = {}
    for entry, number in pairs(model.sets[set]) do
      levels[number] = levels[number] or {}
      table.insert(levels[number], entry)
    end
    local out = { "Your affliction curing priorities for the priority set " .. set .. ":" }
    for n = 1, 26 do
      table.sort(levels[n] or {})
      out[#out + 1] = (n .. ":  " .. table.concat(levels[n] or {}, ", ")):gsub("%s+$", "")
    end
    out[#out + 1] = "Affs with priority 26 are ignored."
    return table.concat(out, "\n")
  end
  return model
end

-- a custom-mode svof that has read the captured lists, and a game that keeps
-- what svof sends from then on
local function new_custom()
  local g = new_game()
  g.sent()
  g.mode("custom")
  g.sent(true)
  g.answer(LIST_SLOW, LIST_PLAIN)
  g.model = new_model(g.sk.serverread.sets)
  g.model.apply(g.sent())
  -- the game's answer to what svof sent, in the normal set
  function g.confirm(name, number)
    g.line(("You have set the '%s' affliction to the %d priority."):format(name, number))
  end
  function g.login()
    g.svo.logging_in = true
    g.svo.signals.changecuring:emit()
    g.svo.logging_in = false
    g.svo.signals.changecuring:emit()
  end
  function g.linked(code)
    for _, l in ipairs(g.w.links) do
      if l:find(code, 1, true) then return true end
    end
    return false
  end
  return g
end

-- ===== svof's own sends aren't the player's edits =====

do
  local g = new_custom()
  local svo = g.svo
  local p = svo.serverprios.normal.paralysis
  eq(p, 2, "this test's premise: paralysis is the player's 2")

  -- an ignore that comes off before the game answers it
  svo.setignore("paralysis", true)
  svo.signals["svo ignore changed"]:emit("paralysis")
  svo.unsetignore("paralysis")
  svo.signals["svo ignore changed"]:emit("paralysis")
  local sent = g.sent()
  check("an ignore on and off at once sends both", sent:find(" paralysis 26 paralysis 2", 1, true) ~= nil, sent)
  g.confirm("paralysis", 26)
  eq(svo.serverprios.normal.paralysis, 2, "svof's 26, confirmed after the ignore came off, isn't the player's")
  g.confirm("paralysis", 2)
  eq(svo.serverprios.normal.paralysis, 2, "and svof's own 2 changes nothing")
  eq(any_affliction(g.sent()), nil, "neither confirmation is answered")

  -- an ignore that comes off and goes on again before the game answers
  svo.setignore("paralysis", true)
  svo.signals["svo ignore changed"]:emit("paralysis")
  g.sent()
  g.confirm("paralysis", 26)
  svo.unsetignore("paralysis")
  svo.signals["svo ignore changed"]:emit("paralysis")
  svo.setignore("paralysis", true)
  svo.signals["svo ignore changed"]:emit("paralysis")
  g.sent()
  g.confirm("paralysis", 2)
  eq(any_affliction(g.sent()), nil, "svof's own 2, with its 26 still on the way, isn't answered with 26")
  g.confirm("paralysis", 26)
  eq(svo.serverprios.normal.paralysis, 2, "the table keeps the player's number")
  eq(any_affliction(g.sent()), nil, "and nothing more is sent")

  -- the player's edit lands between svof's send and its confirmation
  svo.unsetignore("paralysis")
  svo.signals["svo ignore changed"]:emit("paralysis")
  sent = g.sent()
  check("coming off ignore sends the player's number", sets(sent, "paralysis", 2), sent)
  g.confirm("paralysis", 7)
  eq(svo.serverprios.normal.paralysis, 7, "the player's edit is taken")
  eq(any_affliction(g.sent()), nil, "and not answered while svof's send is on its way")
  g.confirm("paralysis", 2)
  eq(svo.serverprios.normal.paralysis, 7, "svof's own send landing after it doesn't undo it")
  sent = g.sent()
  check("and the game gets the player's number back", sets(sent, "paralysis", 7), sent)
  g.confirm("paralysis", 7)
  eq(any_affliction(g.sent()), nil, "which settles it")
end

do
  -- the game takes blind and confirms it as blindness
  local g = new_custom()
  g.svo.serverprios.normal.blindness = 5
  g.sk.serverprios_send()
  local sent = g.sent()
  check("blindness is sent as blind", sets(sent, "blind", 5) and not sent:find(" blindness ", 1, true), sent)
  g.confirm("blindness", 5)
  eq(any_affliction(g.sent()), nil, "and its confirmation as blindness is svof's own")
end

do
  -- sends that are never confirmed stop waiting
  for _, late in ipairs({ false, true }) do
    local g = new_custom()
    local svo = g.svo
    svo.setignore("asthma", true)
    svo.signals["svo ignore changed"]:emit("asthma")
    svo.unsetignore("asthma")
    svo.signals["svo ignore changed"]:emit("asthma")
    g.sent()
    if late then g.w.advance(61) end
    g.confirm("asthma", 26)
    if late then
      eq(svo.serverprios.normal.asthma, 26, "a minute on, a 26 svof doesn't keep is the player's")
    else
      eq(svo.serverprios.normal.asthma, 4, "within a minute, the 26 svof sent is svof's")
    end
  end
end

-- ===== the check at login =====

do
  local g = new_custom()
  local svo, sk = g.svo, g.sk
  g.confirm("unweavingmind(2)", 6)
  g.model.apply(g.sent())
  g.model.sets.normal["unweavingmind(2)"] = 6

  g.login()
  local sent = g.sent(true)
  check("login asks for both lists", select(2, sent:gsub("curing priority list", "")) == 2, sent)
  g.answer(g.model.list("slowcuring"), g.model.list("normal"))
  eq(sk.serverread.asked, nil, "svof stops waiting")
  check("lists that match say nothing", not g.echoed("aren't the ones Svof has"))
  eq(any_affliction(g.sent()), nil, "and send nothing")

  -- changed from another client while svof was away
  g.model.sets.normal.paralysis = 5
  g.model.sets.normal["unweavingmind(2)"] = nil
  g.model.sets.slowcuring.daeggerimpale = 3
  g.model.sets.normal.newaff = 4
  g.login()
  g.sent(true)
  g.answer(g.model.list("slowcuring"), g.model.list("normal"))
  check("differences are shown", g.echoed("aren't the ones Svof has"))
  check("a changed number", g.echoed("normal set: paralysis is 5 in the game and 2 in Svof."))
  check("a stack entry the game lost", g.echoed("normal set: unweavingmind(2) is missing in the game and 6 in Svof."))
  check("an affliction svof cures that the game would cure too",
    g.echoed("slowcuring set: daeggerimpale is 3 in the game and 26 in Svof."))
  check("an entry svof doesn't have", g.echoed("normal set: newaff is 4 in the game and missing in Svof."))
  check("svof's own 26 isn't a difference", not g.echoed("impaled is"))
  check("one link keeps the game's", g.linked("svo.sk.serverprios_keepgame()"))
  check("one sends svof's", g.linked("svo.sk.serverprios_keepsvof()"))
  eq(svo.serverprios.normal.paralysis, 2, "nothing changes until one is chosen")
  eq(any_affliction(g.sent()), nil, "and nothing is sent")

  sk.serverprios_keepsvof()
  sent = g.sent()
  check("sending svof's sends the changed number", sets(sent, "paralysis", 2), sent)
  check("the lost stack entry", sets(sent, "unweavingmind2", 6), sent)
  check("and 26 for what svof cures", sets(sent, "daeggerimpale", 26), sent)
  check("but not what already matches", not sent:find(" icebound ", 1, true), sent)
  eq(svo.serverprios.normal.newaff, 4, "an entry only the game had goes into the table")
  g.model.apply(sent)

  g.login()
  g.sent(true)
  g.w.echoes = {}
  g.answer(g.model.list("slowcuring"), g.model.list("normal"))
  check("after that, the next login matches", not g.echoed("aren't the ones Svof has"))
end

do
  local g = new_custom()
  local svo, sk = g.svo, g.sk
  g.model.sets.normal.paralysis = 5
  g.model.sets.normal.daeggerimpale = 3
  g.login()
  g.sent(true)
  g.answer(g.model.list("slowcuring"), g.model.list("normal"))
  sk.serverprios_keepgame()
  eq(svo.serverprios.normal.paralysis, 5, "keeping the game's takes its number")
  eq(svo.serverprios.normal.daeggerimpale, 3, "for an affliction svof cures, too, kept for later")
  local sent = g.sent()
  check("which goes back to 26 in the game", sets(sent, "daeggerimpale", 26), sent)
  check("and nothing else is sent", not sent:find(" paralysis ", 1, true), sent)
end

do
  -- custom chosen with serverside off has no numbers to compare
  local g = new_game()
  g.svo.conf.serverside = false
  g.mode("custom")
  g.svo.conf.serverside = true
  g.sent()
  g.svo.logging_in = true
  g.svo.signals.changecuring:emit()
  g.svo.logging_in = false
  g.svo.signals.changecuring:emit()
  g.sent(true)
  g.answer(LIST_SLOW, LIST_PLAIN)
  eq(g.count("normal"), 131, "login with no numbers yet takes the game's")
  check("as the switch to custom does", g.echoed("Took your serverside priorities from the game"))
end

do
  -- in auto mode, login asks for nothing
  local g = new_game()
  g.sent()
  g.svo.logging_in = true
  g.svo.signals.changecuring:emit()
  g.svo.logging_in = false
  g.svo.signals.changecuring:emit()
  local sent = g.sent(true)
  check("auto: login asks for no list", not sent:find("curing priority list", 1, true), sent)
end

-- ===== tactical swaps: pva, avs, pvd =====

do
  local g = new_game()
  g.sent()
  g.sk.serverprios_toggle("pva")
  eq(any_affliction(g.sent()), nil, "auto: pva sends no server number of its own")
  eq(g.svo.serverprios.toggles, nil, "and isn't kept")
end

do
  local g = new_custom()
  local svo, sk = g.svo, g.sk
  -- a list read replaces the table, so it is looked up each time
  local function N() return svo.serverprios.normal end
  eq(N().paralysis .. " " .. N().asthma .. " " .. N().darkshade, "2 4 25", "this test's premise: paralysis 2, asthma 4, darkshade 25")

  sk.serverprios_toggle("pva")
  local sent = g.sent()
  check("pva swaps the server's numbers of paralysis and asthma", sets(sent, "paralysis", 4) and sets(sent, "asthma", 2), sent)
  check("in both sets", select(2, sent:gsub(" paralysis 4", "")) == 2, sent)
  eq(table.concat(svo.serverprios.toggles, " "), "pva", "and keeps it on, to survive a restart")
  eq(N().paralysis, 2, "the table keeps the player's numbers")
  g.model.apply(sent)
  g.confirm("paralysis", 4)
  g.confirm("asthma", 2)
  eq(N().paralysis .. " " .. N().asthma, "2 4", "svof's own swap, confirmed, isn't the player's")
  eq(any_affliction(g.sent()), nil, "and isn't answered")

  -- a list the player asks for while the swap is on
  g.lines(g.model.list("normal"))
  eq(N().paralysis .. " " .. N().asthma, "2 4", "a list read meanwhile leaves the player's numbers")

  -- the login check expects the swap
  g.login()
  g.sent(true)
  g.answer(g.model.list("slowcuring"), g.model.list("normal"))
  check("the login check expects the swaps that are on", not g.echoed("aren't the ones Svof has"))

  -- a later swap moves what the earlier one left
  sk.serverprios_toggle("pvd")
  sent = g.sent()
  check("pvd after pva swaps paralysis's new number with darkshade's",
    sets(sent, "paralysis", 25) and sets(sent, "darkshade", 4) and not sent:find(" asthma ", 1, true), sent)
  eq(table.concat(svo.serverprios.toggles, " "), "pva pvd", "in the order they went on")
  g.model.apply(sent)

  -- the player's edit of a swapped entry is the player's number
  g.confirm("asthma", 9)
  eq(N().asthma, 9, "an edit of a swapped entry goes into the table")
  check("svof says where it keeps it", g.echoed("asthma's serverside number is 9, and Svof keeps it at 2"))
  sent = g.sent()
  check("and the game keeps the swap, with the new number on the other side",
    sets(sent, "asthma", 2) and sets(sent, "darkshade", 9), sent)
  g.model.apply(sent)

  sk.serverprios_toggle("pva")
  sent = g.sent()
  check("pva off gives paralysis darkshade's number, as pvd alone does",
    sets(sent, "paralysis", 25) == false and sets(sent, "asthma", 9) and sets(sent, "darkshade", 2), sent)
  eq(table.concat(svo.serverprios.toggles, " "), "pvd", "and leaves pvd on")
  g.model.apply(sent)
  sk.serverprios_toggle("pvd")
  sent = g.sent()
  check("with both off, each has its own number", sets(sent, "paralysis", 2) and sets(sent, "darkshade", 25), sent)
  eq(#svo.serverprios.toggles, 0, "and nothing stays on")
end

do
  -- swaps that are on, kept at a restart: the game has them, and the table
  -- doesn't take them as the player's
  local g = new_custom()
  local svo, sk = g.svo, g.sk
  sk.serverprios_toggle("avs")
  g.model.apply(g.sent())
  g.model.sets.normal.prone = 5
  g.login()
  g.sent(true)
  g.answer(g.model.list("slowcuring"), g.model.list("normal"))
  check("only the real difference is shown", g.echoed("prone is 5") and not g.echoed("slickness is"))
  sk.serverprios_keepgame()
  eq(svo.serverprios.normal.slickness .. " " .. svo.serverprios.normal.impatience, "3 7",
    "keeping the game's doesn't take the swapped numbers as the player's")
  eq(svo.serverprios.normal.prone, 5, "and takes the player's change")
  eq(any_affliction(g.sent()), nil, "with nothing to send")
end

-- ===== autoslick in server numbers =====

do
  local g = new_custom()
  local svo, sk = g.svo, g.sk
  svo.conf.autoslick = true
  local function N() return svo.serverprios.normal end
  check("this test's premise: paralysis is before asthma", N().paralysis < N().asthma)

  svo.affl.slickness, svo.affl.asthma = {}, {}
  sk.serverprios_autoslick()
  eq(any_affliction(g.sent()), nil, "asthma and slickness alone don't need it")

  svo.affl.anorexia = {}
  sk.serverprios_autoslick()
  local sent = g.sent()
  check("with a third, asthma goes first", sets(sent, "asthma", 1), sent)
  check("and what was first makes room", sets(sent, "aeon", 2) and sets(sent, "icebound", 2), sent)
  check("in both sets", select(2, sent:gsub(" asthma 1", "")) == 2, sent)
  check("svof says so", g.echoed("the server cures asthma first"))
  g.model.apply(sent)
  g.confirm("asthma", 1)
  g.confirm("aeon", 2)
  eq(N().asthma .. " " .. N().aeon, "4 1", "svof's own numbers aren't the player's")

  sk.serverprios_autoslick()
  eq(any_affliction(g.sent()), nil, "nothing more while it holds")

  svo.affl.slickness = nil
  sk.serverprios_autoslick()
  sent = g.sent()
  check("without slickness, asthma gets its number back", sets(sent, "asthma", 4) and sets(sent, "aeon", 1), sent)
  check("and svof says so", g.echoed("Gave asthma its serverside number back"))

  -- vconfig autoslick off while it holds
  svo.affl.slickness = {}
  sk.serverprios_autoslick()
  g.sent()
  svo.conf.autoslick = false
  svo.signals["svo config changed"]:emit("autoslick")
  sent = g.sent()
  check("turning autoslick off gives the number back", sets(sent, "asthma", 4), sent)
end

do
  -- asthma already before paralysis and impatience
  local g = new_custom()
  local svo, sk = g.svo, g.sk
  svo.conf.autoslick = true
  -- in both sets, since autoslick goes by each set's own numbers
  g.confirm("asthma", 1)
  g.line(SWITCH_SLOW)
  g.confirm("asthma", 1)
  g.line(SWITCH_NORMAL)
  g.sent()
  svo.affl.slickness, svo.affl.asthma, svo.affl.anorexia = {}, {}, {}
  sk.serverprios_autoslick()
  -- asthma ties with aeon at 1, but paralysis and impatience are after it
  eq(any_affliction(g.sent()), nil, "asthma before paralysis and impatience needs nothing")
  eq(next(sk.serverslick), nil, "and autoslick stays off")
end

-- ===== one stack ignored: vignore <aff> <count> =====

-- runs the vignore alias as Mudlet would, with what its pattern matched
local VIGNORE
do
  local f = assert(io.open("src/aliases/svo (aliases, triggers)/svo/Ignore things/Toggle_ignore_things.lua", "r"))
  VIGNORE = f:read("*a")
  f:close()
  local j = assert(io.open("src/aliases/svo (aliases, triggers)/svo/Ignore things/aliases.json", "r"))
  local json = j:read("*a")
  j:close()
  check("vignore's pattern takes a count", json:find('"regex": "^vignore (\\\\w+)(?: (\\\\d+))?$"', 1, true) ~= nil)
end
local function vignore(g, aff, count)
  g.w.env.matches = { "vignore " .. aff .. (count and (" " .. count) or ""), aff, count and tostring(count) or nil }
  g.w.run(VIGNORE, "vignore")
end

do
  local g = new_game()
  g.sent()
  vignore(g, "unweavingmind", 2)
  eq(any_affliction(g.sent()), nil, "auto: a stack can't be ignored")
  check("and svof says only custom mode does it", g.echoed("Only serverside can ignore one stack"))
end

do
  local g = new_custom()
  local svo, sk = g.svo, g.sk
  local function N() return svo.serverprios.normal end
  check("this test's premise: the server cures unweavingmind", svo.serverignore.unweavingmind == true)
  eq(N()["unweavingmind(2)"], nil, "and the game has no number for its stack 2")

  vignore(g, "paralysis", 2)
  check("an affliction svof doesn't count is refused", g.echoed("Svof doesn't count stacks of paralysis"))
  vignore(g, "unweavingmind", 1)
  check("stack 1 is refused, being the plain entry", g.echoed("Stack 1 is unweavingmind's plain entry"))
  svo.serverignore.unweavingmind = false
  vignore(g, "unweavingmind", 2)
  check("one svof cures itself is refused", g.echoed("Svof cures unweavingmind itself"))
  svo.serverignore.unweavingmind = true
  eq(any_affliction(g.sent()), nil, "and none of those sends anything")

  vignore(g, "unweavingmind", 2)
  local sent = g.sent()
  check("vignore with a count puts that stack at 26", sets(sent, "unweavingmind2", 26), sent)
  check("in both sets", select(2, sent:gsub(" unweavingmind2 26", "")) == 2, sent)
  check("and leaves the plain entry", not sent:find(" unweavingmind ", 1, true), sent)
  eq(svo.ignore.unweavingmind, nil, "it isn't an ignore of the whole affliction")
  g.model.apply(sent)
  g.confirm("unweavingmind(2)", 26)
  eq(N()["unweavingmind(2)"], nil, "svof's 26 isn't the player's number")

  svo.show_ignore()
  check("vshow ignore lists it", g.echoed("unweavingmind (stack 2)"))
  check("with a link to remove it", g.linked('svo.sk.serverprios_stackignore("unweavingmind", 2)'))

  -- the plain entry changes while the stack is ignored
  g.confirm("unweavingmind", 9)
  g.model.sets.normal.unweavingmind = 9
  eq(N().unweavingmind, 9, "an edit of the plain entry is the player's")
  eq(any_affliction(g.sent()), nil, "and the ignored stack stays at 26")

  -- the whole affliction ignored as well, and then not
  svo.setignore("unweavingmind", true)
  svo.signals["svo ignore changed"]:emit("unweavingmind")
  sent = g.sent()
  check("a whole ignore puts the plain entry at 26 too", sets(sent, "unweavingmind", 26), sent)
  g.model.apply(sent)
  g.confirm("unweavingmind", 26)
  svo.unsetignore("unweavingmind")
  svo.signals["svo ignore changed"]:emit("unweavingmind")
  sent = g.sent()
  check("off again, the plain entry gets its number", sets(sent, "unweavingmind", 9), sent)
  check("and the stack ignore holds", not sent:find("unweavingmind2", 1, true), sent)
  g.model.apply(sent)
  g.confirm("unweavingmind", 9)

  -- the login check expects the ignored stack
  g.login()
  g.sent(true)
  g.answer(g.model.list("slowcuring"), g.model.list("normal"))
  check("the login check expects an ignored stack", not g.echoed("aren't the ones Svof has"))

  vignore(g, "unweavingmind", 2)
  sent = g.sent()
  check("vignore again gives the stack the plain entry's number", sets(sent, "unweavingmind2", 9), sent)
  check("and says so", g.echoed("The server cures unweavingmind at 2 stacks again"))
  g.model.apply(sent)
  g.confirm("unweavingmind(2)", 9)
  eq(N()["unweavingmind(2)"], nil, "the entry svof made still isn't the player's")

  g.confirm("unweavingmind", 11)
  g.model.sets.normal.unweavingmind = 11
  sent = g.sent()
  check("the entry svof made follows the plain one", sets(sent, "unweavingmind2", 11), sent)
  g.model.apply(sent)

  -- a list read doesn't take the entry svof made as the player's
  g.lines(g.model.list("normal"))
  eq(N()["unweavingmind(2)"], nil, "a list read leaves the entry svof made out of the table")
  g.w.echoes = {}
  g.login()
  g.sent(true)
  g.answer(g.model.list("slowcuring"), g.model.list("normal"))
  check("and the login check still matches", not g.echoed("aren't the ones Svof has"))
end

do
  -- a stack the player gave a number, and the game's limit
  local g = new_custom()
  local svo = g.svo
  g.confirm("unweavingmind(2)", 6)
  g.sent()
  vignore(g, "unweavingmind", 2)
  local sent = g.sent()
  check("a stack with the player's number goes to 26", sets(sent, "unweavingmind2", 26), sent)
  vignore(g, "unweavingmind", 2)
  sent = g.sent()
  check("and gets the player's number back", sets(sent, "unweavingmind2", 6), sent)

  vignore(g, "unweavingmind", 9)
  g.sent()
  g.line("The unweavingmind affliction can only have up to 5 stacks.")
  eq(svo.serverprios.stackignore, nil, "a stack past the game's limit stops being ignored")
  check("and svof says why", g.echoed("can only have up to 5 stacks, so Svof stopped ignoring stack 9"))
  vignore(g, "unweavingmind", 7)
  check("then a stack past it is refused", g.echoed("unweavingmind can only have up to 5 stacks."))
  eq(svo.serverprios.stackignore, nil, "without being ignored")

  -- the switch to auto
  vignore(g, "unweavingmind", 3)
  g.sent()
  g.mode("auto")
  sent = g.sent()
  eq(svo.serverprios.stackignore, nil, "auto mode drops the stack ignores")
  check("and gives the set that isn't reset the plain entry's number",
    sent:find("curingset switch slowcuring\ncuring priority[^\n]* unweavingmind3 25", 1) ~= nil, sent)
  check("and says the server cures every stack again", g.echoed("the server cures every stack again"))
end

-- ===== warnings =====

local function echoes(g, text)
  local n = 0
  for _, e in ipairs(g.w.echoes) do
    if e:find(text, 1, true) then n = n + 1 end
  end
  return n
end

do
  local g = new_custom()
  local svo, sk = g.svo, g.sk

  -- the game's names: gamename, else the one GMCP reports. svof's own
  -- afflictions have neither, and no priority in the game
  local toserver = sk.serverprionames()
  eq(toserver.sleep, "sleeping", "sleep goes by its GMCP name, sleeping, which the game lists")
  eq(toserver.galed, "airfisted", "and galed by airfisted")
  eq(toserver.blindaff, "blindness", "a gamename comes first")
  eq(toserver.paradox, nil, "paradox, not an affliction in the game, has no server name")
  eq(toserver.insomnia, nil, "nor does insomnia, which GMCP doesn't report as svof's")
  eq(toserver.hoisted, nil, "nor hoisted")
  check("so the switch finds no name the list lacks", not g.echoed("priority list doesn't have"))

  -- nothing cures it
  check("this test's premise: the server cures paralysis", svo.serverignore.paralysis == true)
  -- the captured list has latched, blindness and deafness at 26, which svof
  -- leaves to the server in this setup
  check("the switch warns for a 26 the server is meant to cure",
    g.echoed("latched is at 26 in the normal and slowcuring sets, so nothing cures it"))
  local n0 = echoes(g, "so nothing cures it")
  check("but not for paralysis, which has a number", not g.echoed("paralysis is at 26"))
  g.confirm("paralysis", 26)
  check("26 on an affliction the server cures warns that nothing cures it",
    g.echoed("paralysis is at 26 in the normal set, so nothing cures it"))
  check("with a link to give it a number", g.linked('svo.sk.serverprios_givenumber("paralysis")'))
  check("and one to let svof cure it", g.linked('svo.unsetserverignore("paralysis")'))
  eq(any_affliction(g.sent()), nil, "the warning changes no number by itself")
  g.confirm("paralysis", 26)
  eq(echoes(g, "so nothing cures it"), n0 + 1, "and says it once for each change")

  sk.serverprios_givenumber("paralysis")
  local sent = g.sent()
  local auto = sk.autoserverprios("normal").paralysis
  eq(svo.serverprios.normal.paralysis, auto, "the link gives it auto mode's number")
  check("and sends it", sets(sent, "paralysis", auto), sent)
  g.confirm("paralysis", auto)
  g.confirm("paralysis", 26)
  eq(echoes(g, "so nothing cures it"), n0 + 2, "26 again is a new change, and warns again")

  svo.serverignore.paralysis = false
  svo.signals["svo serverignore changed"]:emit("paralysis")
  g.sent()
  svo.serverignore.paralysis = true
  svo.signals["svo serverignore changed"]:emit("paralysis")
  g.sent()
  eq(echoes(g, "so nothing cures it"), n0 + 3, "so is the server curing it again after svof did")

  -- svof keeps it at 26, and the player gave it a number
  g.confirm("impaled", 3)
  check("a number for an affliction svof cures says it's kept",
    g.echoed("Svof cures impale itself, so the server keeps impaled at 26. Your 3 is saved"))
  check("with a link to let serverside cure it", g.linked('svo.setserverignore("impale")'))
  svo.setignore("asthma", true)
  svo.signals["svo ignore changed"]:emit("asthma")
  g.sent()
  g.confirm("asthma", 26)
  g.confirm("asthma", 5)
  check("and for one svof ignores", g.echoed("asthma is ignored, so the server keeps asthma at 26. Your 5 is saved"))
  check("with a link to stop ignoring it", g.linked('svo.toggle_ignore("asthma")'))
  eq(echoes(g, "so nothing cures it"), n0 + 3, "an ignored affliction at 26 isn't one nothing cures")

  -- a reset list has neither blindness nor deafness, and the game still has them
  g.line(RESET)
  g.sent(true)
  g.answer(LIST_SLOW, LIST_DEFAULTS)
  local lacking = false
  for _, e in ipairs(g.w.echoes) do
    if e:find("priority list doesn't have", 1, true) and e:find("blindness", 1, true) then lacking = true end
  end
  check("blindness missing from a reset list isn't a name svof has wrong", not lacking)
end

do
  -- an affliction left to the server that the game's list doesn't have
  local g = new_game()
  g.svo.serverignore.galed = true
  g.sent()
  g.mode("custom")
  g.sent(true)
  g.answer(LIST_SLOW, LIST_PLAIN)
  check("one left to the server that the list lacks is named, with its game name",
    g.echoed("Svof leaves galed (airfisted) to serverside, but the game's priority list doesn't have it"))
  check("with how to have svof cure it", g.echoed("To have Svof cure it instead, use vshow serverside."))
  g.svo.logging_in = true
  g.svo.signals.changecuring:emit()
  g.svo.logging_in = false
  g.svo.signals.changecuring:emit()
  g.sent(true)
  g.answer(LIST_SLOW, LIST_PLAIN)
  eq(echoes(g, "priority list doesn't have"), 1, "and says so once a session")
end

-- ===== svof's list commands with server at the end =====

local ALIASES = "src/aliases/svo (aliases, triggers)/svo/"
local function readfile(path)
  local f = assert(io.open(path, "r"))
  local s = f:read("*a")
  f:close()
  return s
end
local ALIAS = {
  vset = readfile(ALIASES .. "Set_an_affliction_priority.lua"),
  vswap = readfile(ALIASES .. "Swap_affliction_priorities.lua"),
  vswapslow = readfile(ALIASES .. "Swap_slow_mode_affliction_priorities.lua"),
  vcleargaps = readfile(ALIASES .. "Clear_all_gaps_in_a_prio_mode.lua"),
  vp = readfile(ALIASES .. "Show_priority_lists.lua"),
}
do
  local json = readfile(ALIASES .. "aliases.json")
  for _, pattern in ipairs({
    '"^vset (\\\\w+)(?: (\\\\w+))? (\\\\d+)( server)?$"',
    '"^vswapslow (\\\\w+) (\\\\w+)( server)?$"',
    '"^vcleargaps (\\\\w+)( server)?$"',
    '"^(?:vshowprios|vp) (\\\\w+)(?: (slowcuring))?$"',
    '"^vimportprio(?: (\\\\w+))?( server)?$"',
  }) do
    check("the alias pattern " .. pattern .. " takes server", json:find(pattern, 1, true) ~= nil)
  end
end
-- runs an alias with what its pattern matched, nil for a group that didn't
local function alias(g, name, ...)
  g.w.env.matches = { name, ... }
  g.w.run(ALIAS[name], name)
end

do
  local g = new_game()
  g.sent()
  alias(g, "vset", "paralysis", nil, "3", " server")
  eq(any_affliction(g.sent()), nil, "auto: vset server sends nothing")
  check("and says custom mode does it", g.echoed("To set them yourself, use vconfig serverprios custom"))
  g.sk.serverprios_show("normal")
  check("auto: vp serveraffs shows the numbers auto mode works out",
    g.echoed("The serverside affliction priorities Svof works out from its own lists, normal set:"))
end

do
  local g = new_custom()
  local svo, sk = g.svo, g.sk
  local function N() return svo.serverprios.normal end

  alias(g, "vset", "paralysis", nil, "3", " server")
  local sent = g.sent()
  check("vset server sends the number", sets(sent, "paralysis", 3), sent)
  check("to the normal set alone", select(2, sent:gsub(" paralysis 3", "")) == 1
    and not sent:find("switch slowcuring\ncuring priority paralysis", 1, true), sent)
  eq(N().paralysis, 2, "and the table waits for the game to take it")
  g.confirm("paralysis", 3)
  eq(N().paralysis, 3, "the game's confirmation puts it in the table")
  check("and svof says so", g.echoed("paralysis is 3 in the normal set."))
  eq(any_affliction(g.sent()), nil, "with nothing sent back")

  alias(g, "vset", "paralysis", "slowcuring", "7", " server")
  sent = g.sent()
  check("vset slowcuring server goes to the slowcuring set",
    sent:find("curingset switch slowcuring\ncuring priority paralysis 7", 1, true) ~= nil, sent)

  alias(g, "vset", "blindaff", nil, "5", " server")
  sent = g.sent()
  check("svof's name for an affliction works, sent as the game takes it", sets(sent, "blind", 5), sent)

  alias(g, "vset", "unweavingmind2", nil, "6", " server")
  sent = g.sent()
  check("a stack entry goes as name and count", sets(sent, "unweavingmind2", 6), sent)
  g.confirm("unweavingmind(2)", 6)
  eq(N()["unweavingmind(2)"], 6, "and is the player's once confirmed")

  alias(g, "vset", "paralysis2", nil, "5", " server")
  check("a stack of one svof doesn't count is refused", g.echoed("Svof doesn't count stacks of paralysis"))
  alias(g, "vset", "hoisted", nil, "3", " server")
  check("so is a name the game's list lacks", g.echoed("the game's priority list has no hoisted"))
  alias(g, "vset", "paralysis", nil, "27", " server")
  check("and a number past 26", g.echoed("the game's numbers go from 1 to 26"))
  alias(g, "vset", "paralysis", "herb", "3", " server")
  check("and a balance in place of slowcuring", g.echoed("To set a serverside priority, use vset <name> <number> server"))
  eq(any_affliction(g.sent()), nil, "none of those sends anything")

  alias(g, "vset", "impale", nil, "4", " server")
  eq(N().impaled, 4, "a number for something svof keeps at 26 goes into the table at once")
  check("and says the server keeps 26", g.echoed("impaled is 4 in the normal set, and the server keeps it at 26 for now."))
  eq(any_affliction(g.sent()), nil, "sending nothing")

  -- the plain forms still edit svof's own lists, and say how to edit the server's
  alias(g, "vset", "paralysis", "herb", "3", nil)
  check("vset without server reminds how to edit the server's list", g.echoed("put server at the end"))
  alias(g, "vset", "asthma", "herb", "4", nil)
  eq(echoes(g, "put server at the end"), 1, "once a session")
  alias(g, "vset", "paralysis", nil, "3", nil)
  check("vset with no balance and no server asks which balance", g.echoed("Which balance?"))

  alias(g, "vcleargaps", "herb", " server")
  check("vcleargaps server is refused", g.echoed("Svof doesn't clear gaps on the server"))
end

do
  local g = new_custom()
  local svo, sk = g.svo, g.sk
  local function N() return svo.serverprios.normal end

  alias(g, "vswap", "paralysis", "asthma", "server", nil)
  local sent = g.sent()
  check("vswap server swaps the two numbers", sets(sent, "paralysis", 4) and sets(sent, "asthma", 2), sent)
  g.confirm("paralysis", 4)
  g.confirm("asthma", 2)
  eq(N().paralysis .. " " .. N().asthma, "4 2", "and both are the player's once confirmed")
  check("which isn't pva: the table holds them", svo.serverprios.toggles == nil or #svo.serverprios.toggles == 0)

  alias(g, "vswapslow", "paralysis", "asthma", " server")
  sent = g.sent()
  check("vswapslow server swaps them in the slowcuring set",
    sent:find("curingset switch slowcuring\ncuring priority[^\n]* paralysis 4", 1) ~= nil, sent)

  -- vp serveraffs
  g.w.echoes, g.w.links = {}, {}
  alias(g, "vp", "serveraffs", nil)
  check("vp serveraffs shows the set", g.echoed("Your serverside affliction priorities, normal set:"))
  check("grouped by the game's number", g.echoed("   2: "))
  -- the name and its mark are echoed one after the other
  local marked = false
  for i, e in ipairs(g.w.echoes) do
    if e == "impaled" and g.w.echoes[i + 1] == " (svof cures it, yours " .. N().impaled .. ")" then marked = true end
  end
  check("with why the game's number isn't the player's", marked)
  check("and arrows that set the player's number", g.linked('svo.sk.serverprios_vset("paralysis", nil, 3)')
    and g.linked('svo.sk.serverprios_vset("paralysis", nil, 5)'))
  g.w.echoes, g.w.links = {}, {}
  alias(g, "vp", "serveraffs", "slowcuring")
  check("vp serveraffs slowcuring shows that set", g.echoed("Your serverside affliction priorities, slowcuring set:"))
  check("with arrows for it", g.linked('svo.sk.serverprios_vset("paralysis", "slowcuring",'))

  -- the ss aff column of vp
  eq(sk.serverprios_number("paralysis", "normal"), 4, "the ss aff column has the player's number")
  g.w.echoes = {}
  -- svof's intlen uses math.log10, which Mudlet's Lua 5.1 has and 5.2+ dropped
  local math_ = g.w.env.math
  if not math_.log10 then
    g.w.env.math = setmetatable({ log10 = function(x) return math.log(x, 10) end }, { __index = math_ })
  end
  svo.printorder("herb")
  local shown = false
  for _, e in ipairs(g.w.echoes) do
    if e:find("ss aff%s+4%) paralysis") then shown = true end
  end
  check("and vp herb shows it", shown)

  -- export and import
  svo.serverprios.toggles = { "pva" }
  local text = sk.serverprios_exporttext("mine")
  local loaded = assert(sk.serverprios_importtext(text))
  local same = true
  for _, set in ipairs({ "normal", "slowcuring" }) do
    for entry, number in pairs(svo.serverprios[set]) do
      if loaded[set][entry] ~= number then same = false end
    end
    for entry, number in pairs(loaded[set]) do
      if svo.serverprios[set][entry] ~= number then same = false end
    end
  end
  check("an export reads back to the same numbers", same)
  eq(table.concat(loaded.toggles, " "), "pva", "and the same swaps")
  svo.serverprios.toggles = {}
  g.sent()

  loaded.normal.prone = 9
  loaded.toggles = {}
  sk.serverprios_takeexport(loaded)
  sent = g.sent()
  eq(N().prone, 9, "an import is the player's")
  check("and sends what differs", sets(sent, "prone", 9), sent)
  check("but not what matches", not sent:find(" icebound ", 1, true), sent)

  local bad = sk.serverprios_importtext("normal = { paralysis = 30 }\nslowcuring = {}")
  eq(bad, nil, "an export with a number past 26 is refused")
  eq(sk.serverprios_importtext("normal = {}"), nil, "and one without both sets")
end

-- ===== defences =====

do
  local g = new_game()
  local svo, sk = g.svo, g.sk
  -- cloak on keepup, kept up by the server
  svo.defkeepup.basic.cloak, svo.defkeepup.combat.cloak = true, true
  svo.serverignore.cloak = true
  -- another defence, off keepup
  local other
  local names = {}
  for action, entry in pairs(svo.dict) do
    for _, data in pairs(type(entry) == "table" and entry or {}) do
      if type(data) == "table" and data.def and not data.undeffable and action ~= "cloak" and not entry.gamename then
        names[#names + 1] = action
        break
      end
    end
  end
  table.sort(names)
  other = names[1]
  check("this test's premise: a defence off keepup", other ~= nil and not svo.defkeepup.basic[other])
  local function deflist(entries)
    g.line("Your defence priorities for curing set normal:")
    for name, number in pairs(entries) do g.line(("%-18s: %d"):format(name, number)) end
    g.line("", true)
  end
  local function M() return svo.serverprios.defences and svo.serverprios.defences[svo.defs.mode] or {} end

  g.sent()
  g.mode("custom")
  g.sent(true)
  g.answer(LIST_SLOW, LIST_PLAIN)
  deflist({ cloak = 3 })
  eq(M().cloak, 3, "the switch takes the game's defence numbers into the mode in use")
  check("and says so", g.echoed("Took your serverside defence numbers for basic mode from the game: 1 defences"))
  g.sent()

  sk.serverdefs_sendall()
  local sent = g.sent()
  check("the sync sends a defence the player's number", sent:find("curing priority defence cloak 3", 1, true) ~= nil, sent)
  g.line("You have set the 'cloak' defence to the 3 priority.")
  eq(M().cloak, 3, "and its confirmation is svof's own")
  sk.serverdefs_sendall()
  eq(g.sent():find("defence cloak", 1, true), nil, "with nothing sent again")

  -- an edit in game
  g.line("You have set the 'cloak' defence to the 7 priority.")
  eq(M().cloak, 7, "an edit in game is the player's number in the mode in use")
  check("svof says so", g.echoed("cloak is 7 in basic mode."))
  sent = g.sent()
  check("and the other curingset gets the same number",
    sent:find("curingset switch slowcuring\ncuring priority defence cloak 7", 1, true) ~= nil, sent)
  check("but not the one that has it", select(2, sent:gsub("defence cloak 7", "")) == 1, sent)

  -- vset from svof
  sk.serverprios_vset("cloak", nil, "6")
  eq(M().cloak, 6, "vset <defence> <number> server sets the mode's number, as for an affliction")
  check("and names the mode", g.echoed("cloak is 6 in basic mode."))
  sent = g.sent()
  check("and sends it", sent:find("defence cloak 6", 1, true) ~= nil, sent)
  sk.serverprios_vset("cloak", "defences", "4")
  eq(M().cloak, 4, "vset <defence> defences <number> server does too")
  sk.serverprios_vset("cloak", "defence", "5")
  eq(M().cloak, 5, "and so does defence, singular")
  sent = g.sent()
  check("and sends it", sent:find("curing priority defence[^\n]* cloak 5", 1) ~= nil, sent)

  -- a name that is an affliction too sets the affliction, and says how to set the defence
  sk.serverprios_vset("blindness", nil, "4")
  sent = g.sent()
  check("blindness, a defence and an affliction, sets the affliction",
    sent:find("curing priority blind 4", 1, true) ~= nil and not sent:find("defence blind", 1, true), sent)
  check("and says how to set the defence", g.echoed("blindness is a defence too. To set the defence's number, use vset blindness defence 4 server."))
  g.w.echoes = {}
  sk.serverprios_vset("blindness", "affliction", "6")
  sent = g.sent()
  check("affliction before the number sets the affliction", sent:find("curing priority blind 6", 1, true) ~= nil, sent)
  check("without the note", not g.echoed("is a defence too"))
  sk.serverprios_vset("blindness", "afflictions", "7")
  sent = g.sent()
  check("and so does afflictions", sent:find("curing priority blind 7", 1, true) ~= nil, sent)

  -- a defence named like an affliction only the game's list has goes to the
  -- affliction: svof's names for afflictions don't cover those
  svo.dict.icebound = { gamename = nil, misc = { def = true } }
  check("this test's premise: icebound is on the game's list and has no svof name",
    svo.serverprios.normal.icebound ~= nil and sk.serverprionames().icebound == nil)
  sk.serverprios_vset("icebound", nil, "3")
  sent = g.sent()
  check("a name on the game's list is an affliction, whatever else svof calls it",
    sent:find("curing priority icebound 3", 1, true) ~= nil and not sent:find("defence icebound", 1, true), sent)
  svo.dict.icebound = nil
  sk.serverprios_vset("blind", nil, "4")
  sent = g.sent()
  check("blind, the defence's own name, sets the defence", sent:find("defence blind 4", 1, true) ~= nil
    or g.echoed("blind is 4 in basic mode"), sent)
  sk.serverprios_vset("cloak", "defences", "30")
  check("a number past 25 is refused", g.echoed("use a number from 1 to 25"))
  sk.serverprios_vset("notadefence", "defences", "3")
  check("and a name that isn't a defence", g.echoed("notadefence isn't a defence Svof knows"))

  -- an edit of a defence off keepup
  g.line(("You have set the '%s' defence to the 4 priority."):format(other))
  eq(M()[other], 4, "an edit of a defence off keepup is kept")
  sent = g.sent()
  check("but keepup decides: svof takes it back off", sent:find("defence " .. other .. " reset", 1, true) ~= nil, sent)
  check("and says how to keep it up", g.echoed("isn't on your keepup there, so Svof took it back off"))

  -- taken off in game
  g.line("You have set the 'cloak' defence to the 0 priority.")
  sent = g.sent()
  check("a defence on keepup taken off in game goes back on", sent:find("defence cloak 5", 1, true) ~= nil, sent)
  check("and svof says why", g.echoed("cloak is on your keepup in basic mode, so Svof put it back"))
  eq(M().cloak, 5, "keeping the player's number")

  -- another defence mode
  svo.defs.mode = "combat"
  svo.signals["svo switched defence mode"]:emit("combat")
  sent = g.sent()
  local auto = sk.serverdefs_expected().cloak
  check("a mode with no numbers of its own has Svof's order", auto ~= 5 and sent:find("defence cloak " .. auto, 1, true) ~= nil, sent)
  svo.defs.mode = "basic"
  svo.signals["svo switched defence mode"]:emit("basic")
  sent = g.sent()
  check("and switching back sends the player's number", sent:find("defence cloak 5", 1, true) ~= nil, sent)

  -- the mode commands
  svo.copy_defmode("basic", "copied")
  eq(svo.serverprios.defences.copied and svo.serverprios.defences.copied.cloak, 5, "vcopy defmode copies the numbers")
  svo.rename_defmode("copied", "renamed")
  eq(svo.serverprios.defences.renamed and svo.serverprios.defences.renamed.cloak, 5, "vrename defmode moves them")
  eq(svo.serverprios.defences.copied, nil, "from the old name")
  svo.delete_defmode("renamed")
  eq(svo.serverprios.defences.renamed, nil, "vdelete defmode drops them")

  -- vp serverdefs
  g.w.echoes = {}
  sk.serverdefs_show()
  check("vp serverdefs shows the mode's numbers", g.echoed("Your serverside defence numbers in basic mode"))
  check("with each defence at its number", g.echoed("   5: cloak"))
  check("and the ones off keepup", g.echoed("Off your keepup, so not on the server's list: " .. other .. " (4)"))

  -- the check at login
  svo.logging_in = true
  svo.signals.changecuring:emit()
  svo.logging_in = false
  svo.signals.changecuring:emit()
  sent = g.sent(true)
  check("login asks for the defence list too", sent:find("curing priority defence list", 1, true) ~= nil, sent)
  g.answer(LIST_SLOW, LIST_PLAIN)
  g.w.echoes = {}
  deflist({ cloak = 9 })
  check("a defence number changed elsewhere is shown", g.echoed("cloak is 9 in the game and 5 in Svof."))
  sk.serverdefs_keepgame("normal")
  eq(M().cloak, 9, "keeping the game's takes its number")

  -- export and import carry every mode's numbers
  local loaded = assert(sk.serverprios_importtext(sk.serverprios_exporttext("mine")))
  eq(loaded.defences.basic.cloak, 9, "an export holds the defence numbers")
  loaded.defences.nosuchmode = { cloak = 2 }
  local skipped = sk.serverprios_takeexport(loaded)
  eq(table.concat(skipped, " "), "nosuchmode", "an import leaves out a mode the player doesn't have")
  eq(svo.serverprios.defences.nosuchmode, nil, "without making it")
end

do
  -- auto mode keeps svof's numbers
  local g = new_game()
  g.svo.defkeepup.basic.cloak, g.svo.serverignore.cloak = true, true
  g.sent()
  g.line("You have set the 'cloak' defence to the 7 priority.")
  eq(g.svo.serverprios.defences, nil, "auto: an edit in game isn't kept")
  g.sk.serverprios_vset("cloak", "defences", "5")
  check("and vset defences server is refused", g.echoed("in auto mode, Svof works out the server's numbers"))
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
