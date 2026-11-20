--[[
Logic-level test of the game's curing settings under vconfig serverprios
custom.

In auto mode svof sends the game its own vconfig values. In custom mode the
rows of CURING STATUS are the player's: svof reads them, sets its own options
to match and says what changed, and sends a setting only when the player
changes it through vconfig. Defence Upkeep, Sipping and Affliction Curing
don't move svof's own keepup, sipping and curing: svof warns instead.

This covers:
- the switch to custom asking for the status and CURING FOCUS and sending no
  setting, and svof's options following what comes back
- svof's toggles sending nothing before the status is known
- a setting changed in game, by its reply line
- a setting changed through vconfig: one command, whose reply isn't taken as
  the player's edit, and a reply that never comes stops waiting
- the values svof put there itself being left alone
- the three exceptions and the settings svof relies on: warned about, once
- vconfig keepup sending nothing in custom mode
- the switch back to auto sending svof's settings
- auto mode following nothing

The reply lines are the game's, captured 2026-11-15. Every pattern of the
"Curing setting lines" trigger is read from triggers.json and each line here
has to fire it. It runs the real loaders through tools/svof_world.lua and
proves what svof sends and keeps, not what the game does with it. CURING
FOCUS shows a guilt or fulminated switch only while it is off (the owner's
capture, 2026-11-15).

Run: lua tools/test_server_settings.lua
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

local DASHES = ("-"):rep(78)

-- the status of tools/test_server_status.lua, with any rows replaced
local STATUS
do
  local f = assert(io.open("tools/test_server_status.lua", "r"))
  local src = f:read("*a"):gsub("\r\n", "\n")
  f:close()
  local rows = assert(src:match('local STATUS = "Curing Status:\\n" %.%. DASHES %.%. %[%[\n(.-)%]%]'), "STATUS not found")
  STATUS = "Curing Status:\n" .. DASHES .. "\n" .. rows .. DASHES
end
local function status_with(changes)
  local text = STATUS
  for label, value in pairs(changes or {}) do
    local n
    text, n = text:gsub("(\n" .. label:gsub("%p", "%%%0") .. ":%s+)[^\n]+", function(lead) return lead .. value end, 1)
    assert(n == 1, "no row " .. label)
  end
  return text
end

local FOCUS = [[
Automatic usage of focusing is currently enabled.
You will prioritise herbs over focusing.
You will not focus while afflicted by guilt.
You will not focus while afflicted by fulminated.]]

-- ===== the triggers, as the package has them =====

local DIR = "src/triggers/svo (aliases, triggers)/svo/General/Server-side commands/"
local function readfile(path)
  local f = assert(io.open(path, "r"))
  local s = f:read("*a")
  f:close()
  return s
end
local function patterns_of(name)
  local json = readfile(DIR .. "triggers.json")
  local from = assert(json:find('"name": "' .. name .. '"', 1, true), "no trigger " .. name)
  local to = json:find("%]", from)
  local patterns = {}
  for pattern, kind in json:sub(from, to):gmatch('"pattern": "(.-)",%s*"type": "(%w+)"') do
    patterns[#patterns + 1] = { pattern = (pattern:gsub("\\\\", "\\")), kind = kind }
  end
  return patterns
end
local SETTING = { patterns = patterns_of("Curing setting lines"), script = readfile(DIR .. "Curing_setting_lines.lua") }
local PRIORITY = { patterns = patterns_of("Curing priority lines"), script = readfile(DIR .. "Curing_priority_lines.lua") }

local function fires(trigger, text)
  for _, p in ipairs(trigger.patterns) do
    if (p.kind == "startOfLine" and text:sub(1, #p.pattern) == p.pattern)
      or (p.kind == "exactMatch" and text == p.pattern)
      or (p.kind == "regex" and world.rex_stub.match(text, p.pattern)) then
      return true
    end
  end
  return false
end

-- ===== one svof, with serverside on =====

local function new_game(mode)
  local w = world.new({ class = "Magi" })
  local svo = w.svo
  local g = { w = w, svo = svo, sk = svo.sk, conf = svo.conf, read = svo.sk.serverread, mark = 0, echomark = 0 }
  svo.conf.serverside = true
  -- svof sets its default prompt some seconds after loading, which needs
  -- Lua 5.1 once it is logged in: let that pass first
  for _ = 1, 30 do w.advance(1) end
  svo.conf.paused = false
  svo.sk.logged_in = true
  g.mark = #w.sent

  function g.line(text, isprompt)
    w.env.line = text
    w.env.isPrompt = function() return isprompt or false end
    local readers = {}
    for _, t in ipairs(w.triggers) do
      if not t.killed and t.kind == "regex" and t.pattern == "^" then readers[#readers + 1] = t end
    end
    if not isprompt then
      if fires(PRIORITY, text) then w.run(PRIORITY.script, "trigger") end
      if fires(SETTING, text) then w.run(SETTING.script, "trigger") end
    end
    for _, t in ipairs(readers) do
      if not t.killed then w.run(t.code, "reader") end
    end
  end
  function g.lines(text) for l in (text .. "\n"):gmatch("(.-)\n") do g.line(l) end end
  function g.prompt() g.line("1000h, 1000m cexkdb-", true) end
  -- a reply line, which has to be one the trigger fires on
  function g.reply(text)
    check("the trigger fires on: " .. text, fires(SETTING, text))
    g.line(text)
  end
  function g.settle() for _ = 1, 30 do w.advance(1) end end
  -- the setting commands sent since the last call
  function g.sent(now)
    if now then w.advance(0) else g.settle() end
    local out = {}
    for i = g.mark + 1, #w.sent do
      -- svof sends several commands as one, joined in one of three ways
      local joined = w.sent[i]:gsub("^setalias multicmd ", ""):gsub("^9multicmd {(.*)}$", "%1"):gsub("}{", "\n"):gsub("/", "\n")
      if svo.conf.commandseparator and svo.conf.commandseparator ~= "" then
        joined = joined:gsub(svo.conf.commandseparator:gsub("%p", "%%%0"), "\n")
      end
      for c in (joined .. "\n"):gmatch("(.-)\n") do
        local priority = c:match("^curing priority (.*)$")
        if c:find("^curing ") and (not priority or priority == "health" or priority == "mana") then
          out[#out + 1] = c
        end
      end
    end
    g.mark = #w.sent
    return table.concat(out, ", ")
  end
  function g.echoed(text)
    local found = 0
    for i = g.echomark + 1, #w.echoes do
      if w.echoes[i]:find(text, 1, true) then found = found + 1 end
    end
    return found
  end
  function g.echoes_seen() g.echomark = #w.echoes end
  function g.mode(to)
    svo.conf.serverprios = to
    svo.sk.serverpriosmode()
  end
  -- what the config changed event's handlers do
  function g.changed(option) svo.signals["svo config changed"]:emit(option) end

  if mode then g.mode(mode) end
  return g
end

-- ===== the switch to custom =====

do
  local g = new_game()
  local conf = g.conf
  conf.siphealth, conf.sipmana, conf.mosshealth, conf.mossmana = 80, 70, 60, 50
  conf.moss, conf.focus, conf.clot, conf.insomnia = true, false, true, false
  conf.bleedamount, conf.healthaffsabove, conf.manause = 100, 50, 20
  conf.curemethod, conf.keepup = 'prefertrans', true
  conf.focuswithguilt, conf.focuswithfulminated = true, true
  g.svo.serverignore.healhealth, g.svo.serverignore.healmana = true, true
  g.sent()

  g.mode("custom")
  eq(g.sent(true), "curing status, curing focus", "the switch asks for the status and the focus switches, and sets nothing")
  eq(g.read.status, nil, "the status isn't known until it arrives")

  -- the toggles that run at every prompt wait for it
  g.sk.togglefocusserver()
  g.sk.toggleclotserver()
  g.sk.toggleinsomniaserver()
  eq(g.sent(true), "", "svof's toggles send nothing before the status is known")

  g.lines(STATUS)
  g.lines(FOCUS)
  g.prompt()
  eq(g.sent(), "", "reading the status sends nothing")

  eq(conf.siphealth, 90, "siphealth follows the game")
  eq(conf.sipmana, 80, "sipmana follows")
  eq(conf.mosshealth, 90, "mosshealth follows")
  eq(conf.mossmana, 70, "mossmana follows")
  eq(conf.focus, true, "focus follows")
  eq(conf.clot, true, "clot was the same already")
  eq(conf.insomnia, true, "insomnia follows")
  eq(conf.bleedamount, 60, "bleedamount follows Clot at")
  eq(conf.healthaffsabove, 70, "healthaffsabove follows")
  eq(conf.manause, 35, "manause follows Will use mana above")
  eq(conf.curemethod, 'preferconc', "curemethod follows the method and fallback together")
  eq(conf.focuswithguilt, false, "focuswithguilt follows CURING FOCUS")
  eq(conf.focuswithfulminated, false, "focuswithfulminated follows")
  eq(conf.keepup, true, "keepup stays svof's own")
  eq(g.echoed("Svof's settings now follow the game's"), 3, "svof says what changed, for the status and for each focus switch")
  check("naming the option, its value and what it was",
    g.echoed("siphealth 90 (was 80)") == 1 and g.echoed("focus on (was off)") == 1, table.concat(g.w.echoes, " | "))
  eq(g.echoed("the game didn't"), 0, "no warning for a status with everything on")

  -- the toggles agree with the game now
  g.sk.togglefocusserver()
  g.sk.toggleclotserver()
  g.sk.toggleinsomniaserver()
  eq(g.sent(), "", "and svof's toggles have nothing to send")

  -- the same status again changes nothing and says nothing
  g.echoes_seen()
  g.lines(STATUS)
  eq(g.echoed("Svof's settings now follow"), 0, "the same status again says nothing")

  -- ===== a setting changed in game =====

  g.reply("Health curing threshold set to 85%.")
  eq(conf.siphealth, 85, "siphealth set in game")
  eq(g.read.status.siphealth, 85, "and svof's record of the game has it")
  g.reply("Mana curing threshold set to 75%.")
  eq(conf.sipmana, 75, "sipmana set in game")
  g.reply("Moss health curing threshold set to 85%.")
  eq(conf.mosshealth, 85, "mosshealth set in game")
  g.reply("Moss mana curing threshold set to 65%.")
  eq(conf.mossmana, 65, "mossmana set in game")
  g.reply("Will clot above 55 bleeding.")
  eq(conf.bleedamount, 55, "clotat set in game")
  g.reply("You will now use mana if above 30% of your maximum mana reserves.")
  eq(conf.manause, 30, "manathreshold set in game")
  g.reply("Will cure health based afflictions above 65%.")
  eq(conf.healthaffsabove, 65, "healthaffsabove set in game")
  g.reply("You will now not use the insomnia ability.")
  eq(conf.insomnia, false, "insomnia off in game")
  g.reply("You will now use the insomnia ability.")
  eq(conf.insomnia, true, "and on")
  g.reply("Automatic usage of focusing disabled.")
  eq(conf.focus, false, "focus off in game")
  g.reply("Automatic usage of focusing activated.")
  eq(conf.focus, true, "and on")
  g.reply("You will no longer attempt to clot your wounds.")
  eq(conf.clot, false, "clot off in game")
  g.reply("You will now attempt to clot your wounds.")
  eq(conf.clot, true, "and on")
  g.reply("You will now use transmutation cures.")
  eq(conf.curemethod, 'prefertrans', "the method changed in game, with the fallback the status had")
  g.reply("You will no longer use alternative curing methods if your selected curing type is not available.")
  eq(conf.curemethod, 'transonly', "the fallback off in game")
  g.reply("You will now use concoction-based cures.")
  eq(conf.curemethod, 'conconly', "concoctions with no fallback")
  g.reply("You will now use alternative curing methods if your selected curing type is not available.")
  eq(conf.curemethod, 'preferconc', "and with it")
  g.reply("You will now focus while afflicted by guilt.")
  eq(conf.focuswithguilt, true, "focus with guilt on in game")
  g.reply("You will no longer focus while afflicted by fulminated.")
  eq(conf.focuswithfulminated, false, "focus with fulminated off in game")
  g.reply("You will no longer focus while afflicted by guilt.")
  eq(conf.focuswithguilt, false, "and guilt off")

  -- CURING FOCUS has no line for a switch that is on
  g.echoes_seen()
  g.reply("Automatic usage of focusing is currently enabled.")
  g.reply("You will prioritise focus over herbs.")
  eq(conf.focuswithguilt, false, "a switch isn't taken as on before the reply has ended")
  g.prompt()
  eq(conf.focuswithguilt, true, "CURING FOCUS with no guilt line: the switch is on")
  eq(conf.focuswithfulminated, true, "and with no fulminated line")
  eq(g.read.status.focusoverherbs, true, "Focus over herbs is recorded from it")
  eq(g.echoed("focuswithguilt on (was off)"), 1, "svof says so")
  eq(g.read.focusreader, nil, "and stops reading at the prompt")

  g.reply("Automatic usage of focusing is currently enabled.")
  g.reply("You will prioritise herbs over focusing.")
  g.reply("You will not focus while afflicted by fulminated.")
  g.prompt()
  eq(conf.focuswithguilt, true, "one line: guilt stays on")
  eq(conf.focuswithfulminated, false, "and fulminated is off")

  -- a reply cut short says nothing about the switches
  g.reply("Automatic usage of focusing is currently disabled.")
  g.prompt()
  eq(conf.focuswithguilt, true, "a reply with only its first line leaves guilt alone")
  eq(conf.focuswithfulminated, false, "and fulminated")
  eq(conf.focus, false, "though focus follows it")
  g.reply("Automatic usage of focusing activated.")
  g.reply("You will no longer focus while afflicted by guilt.")

  g.reply("Curing will now prioritise mana over health.")
  eq(g.read.status.healthmana, "Mana", "Health/Mana Priority is recorded")
  eq(g.sk.priochangecache.special.healthormana, "mana", "and svof's cache of it follows")
  g.svo.dict.healhealth.sip.onprioswitch()
  eq(g.sent(), "", "svof's sip order doesn't send the game its own Health/Mana Priority")

  -- settings svof has no option for are only recorded
  for line, want in pairs({
    ["Automatic usage of the tree tattoo activated."] = { 'tree', true },
    ["Automatic usage of the tree tattoo disabled."] = { 'tree', false },
    ["You will now prioritise focus over herbs."] = { 'focusoverherbs', true },
    ["You will now prioritise herbs over focus."] = { 'focusoverherbs', false },
    ["Will clot down to 5 bleeding."] = { 'clotto', 5 },
    ["Will clot down to the default value of 0 bleeding."] = { 'clotto', 0 },
    ["You will now use corrupted clotting if above 65% of your maximum health reserves."] = { 'clothealth', 65 },
    ["You will now use kaido transmute when you can."] = { 'kaidotransmute', true },
    ["You will no longer use kaido transmute."] = { 'kaidotransmute', false },
  }) do
    g.reply(line)
    eq(g.read.status[want[1]], want[2], "recorded: " .. line)
  end
  eq(g.sent(), "", "nothing was sent for any change made in game")

  -- ===== a setting changed through vconfig =====

  g.echoes_seen()
  conf.manause = 40
  g.changed('manause')
  eq(g.sent(true), "curing manathreshold 40", "a vconfig change sends its one command")
  conf.manause = 45 -- the player's next change, before the game answers the first
  g.reply("You will now use mana if above 40% of your maximum mana reserves.")
  eq(conf.manause, 45, "the reply to svof's own command isn't taken as the player's edit")
  eq(g.read.status.manathreshold, 40, "and svof's record of the game has what was sent")
  eq(g.echoed("Svof's settings now follow"), 0, "and nothing is said")
  g.reply("You will now use mana if above 30% of your maximum mana reserves.")
  eq(conf.manause, 30, "the same line again is the player's edit in game")

  conf.bleedamount = 70
  g.changed('bleedamount')
  eq(g.sent(), "curing clotat 70", "another vconfig change")
  g.reply("Will clot above 50 bleeding.")
  eq(conf.bleedamount, 50, "a command the game never answered stops waiting")

  conf.bleedamount = 80
  g.changed('bleedamount')
  g.sent(true)
  g.reply("Will clot above 45 bleeding.")
  eq(conf.bleedamount, 45, "a reply with another value is the player's edit, while svof's command waits")
  g.reply("Will clot above 80 bleeding.")
  eq(g.read.status.clotat, 80, "and svof's own reply is still known for what it is")
  eq(conf.bleedamount, 45, "leaving the option alone")
  g.settle()

  -- ===== the values svof put there itself =====

  g.svo.serverignore.healhealth = false
  g.changed('siphealth')
  g.sent(true)
  conf.siphealth = 85
  g.reply("Health curing threshold set to 0%.")
  eq(conf.siphealth, 85, "svof's own siphealth 0, for health it sips itself, isn't followed")
  g.lines(status_with({ ["Sip health at"] = "0%" }))
  eq(conf.siphealth, 85, "nor a status showing it")
  g.svo.serverignore.healhealth = true

  conf.moss = false
  g.lines(status_with({ ["Sip health at"] = "85%", ["Eat moss below health"] = "0%", ["Eat moss below mana"] = "0%" }))
  eq(conf.mosshealth, 90, "moss at 0 with vconfig moss off isn't followed")
  eq(conf.mossmana, 70, "for mana either")
  conf.moss = true

  g.svo.affs.cadmus = { p = g.svo.dict.cadmus.aff }
  conf.focuswithcadmus = false
  g.sk.togglefocusserver()
  eq(g.sent(true), "curing focus off", "svof turns focus off under cadmus, as in auto mode")
  g.reply("Automatic usage of focusing disabled.")
  eq(conf.focus, true, "and vconfig focus stays on")
  g.lines(status_with({ ["Use focus"] = "No" }))
  eq(conf.focus, true, "with a status showing it off, too")
  g.svo.affs.cadmus = nil
  g.sk.togglefocusserver()
  eq(g.sent(true), "curing focus on", "and back on after cadmus")
  g.reply("Automatic usage of focusing activated.")
  g.settle()
end

-- ===== the three exceptions, and what svof relies on =====

do
  local g = new_game()
  g.conf.keepup = true
  g.svo.serverignore.healhealth, g.svo.serverignore.healmana = true, true
  g.mode("custom")
  g.sent()
  g.lines(status_with({ ["Defence Upkeep"] = "No", ["Sipping"] = "No", ["Affliction Curing"] = "No",
    ["Enabled"] = "No", ["Reporting commands"] = "No", ["Batch actions"] = "No" }))

  eq(g.conf.keepup, true, "Defence Upkeep off in game leaves svof's keepup on")
  eq(g.echoed("Defence Upkeep is off in the game"), 1, "and svof warns about the defences left to the server")
  eq(g.echoed("Sipping is off in the game"), 1, "Sipping off is warned about")
  eq(g.echoed("Affliction Curing is off in the game"), 1, "Affliction Curing off is warned about")
  eq(g.echoed("so the server cures nothing"), 1, "Enabled off is warned about")
  eq(g.echoed("Command reporting is off in the game"), 1, "Reporting off is warned about")
  eq(g.echoed("Batch actions is off in the game"), 1, "Batch off is warned about")
  eq(g.sent(), "", "and svof turns none of them on")

  g.echoes_seen()
  g.lines(status_with({ ["Defence Upkeep"] = "No", ["Sipping"] = "No", ["Affliction Curing"] = "No",
    ["Enabled"] = "No", ["Reporting commands"] = "No", ["Batch actions"] = "No" }))
  eq(g.echoed("is off in the game"), 0, "each warning is given once")

  g.reply("Automatic defence handling activated.")
  g.reply("Automatic defence handling disabled.")
  eq(g.echoed("Defence Upkeep is off in the game"), 1, "and again after the setting came back and went")
  g.reply("Automatic defence handling activated.")
  g.reply("Automatic sipping of healing elixirs activated.")
  g.reply("Automatic affliction curing activated.")
  g.reply("Command reporting activated.")
  g.reply("You will now attempt to cure multiple things at once.")
  g.reply("Curing activated.")
  g.echoes_seen()

  -- vconfig keepup is svof's own
  g.conf.keepup = false
  g.changed('keepup')
  eq(g.sent(), "", "vconfig keepup off sends the game nothing in custom mode")
  eq(g.echoed("Defence Upkeep is on in the game while Svof's keepup is off"), 1, "and svof says the server still keeps its own up")
  g.conf.keepup = true
  g.changed('keepup')
  eq(g.sent(), "", "nor does keepup on")

  -- the other replies
  g.reply("Automatic sipping of healing elixirs disabled.")
  g.reply("Automatic affliction curing disabled.")
  g.reply("Command reporting disabled.")
  g.reply("You will now cure one thing at a time.")
  g.reply("Curing disabled.")
  eq(g.read.status.enabled, false, "Curing disabled is recorded")
  eq(g.echoed("so the server cures nothing"), 1, "and warned about, with svof not paused")

  -- pausing svof still sends its own command, whose reply isn't a surprise
  g.reply("Curing activated.")
  g.echoes_seen()
  g.conf.paused = true
  g.changed('paused')
  eq(g.sent(true), "curing off", "pausing svof still turns the game's curing off")
  g.reply("Curing disabled.")
  eq(g.echoed("so the server cures nothing"), 0, "with no warning, as svof is paused")
  g.conf.paused = false
  g.changed('paused')
  g.reply("Curing activated.")
  g.sent()

  -- svof sipping health itself while the game sips it too
  g.svo.serverignore.healhealth = false
  g.lines(status_with({}))
  eq(g.echoed("Svof sips health itself and the game is set to sip it too"), 1, "double sipping is warned about")
  g.svo.serverignore.healhealth = true

  -- ===== back to auto =====

  g.sent()
  g.conf.manause = 35
  g.mode("auto")
  local sent = g.sent()
  for _, command in ipairs({ "curing defences on", "curing manathreshold 35", "curing clotat ", "curing siphealth ",
    "curing mosshealth ", "curing focus withoutguilt", "curing transmutation off", "curing fallback on" }) do
    check("the switch back to auto sends " .. command, sent:find(command, 1, true) ~= nil, sent)
  end
end

-- ===== the status never arriving =====

do
  local g = new_game("custom")
  g.sent()
  g.settle()
  eq(g.echoed("The game didn't show its curing status"), 1, "svof says when the status never came")
  g.sk.togglefocusserver()
  g.sk.toggleclotserver()
  g.sk.toggleinsomniaserver()
  eq(g.sent(), "", "and its toggles go on waiting")
end

-- ===== a status cut short =====

do
  -- the header, its dashes and a few rows, without the closing dashes
  local CUT = {}
  for l in (STATUS .. "\n"):gmatch("(.-)\n") do
    if #CUT < 6 then CUT[#CUT + 1] = l end
  end
  local cut = table.concat(CUT, "\n")
  local function cadmus(g)
    g.conf.focus, g.conf.focuswithcadmus = true, false
    g.svo.affs.cadmus = { p = g.svo.dict.cadmus.aff }
  end

  -- cut short once, whole on the re-ask
  local g = new_game("custom")
  cadmus(g)
  g.lines(cut); g.prompt()
  eq(g.sent(true), "curing status, curing focus, curing status", "a status cut short is asked for once more, the status only")
  eq(g.read.status, nil, "a cut status sets nothing")
  g.lines(STATUS); g.prompt()
  check("the re-asked status is read", g.read.status ~= nil)
  g.sk.togglefocusserver()
  eq(g.sent(), "curing focus off", "and svof's toggles work")
  eq(g.echoed("The game didn't show its curing status"), 0, "with no warning, not even after 15 seconds")

  -- cut short twice
  g = new_game("custom")
  g.lines(cut); g.prompt()
  g.lines(cut); g.prompt()
  eq(g.sent(true), "curing status, curing focus, curing status", "cut short twice: exactly one re-ask is sent")
  eq(g.echoed("The game didn't show its curing status"), 1, "and the warning is printed")
  g.settle()
  eq(g.echoed("The game didn't show its curing status"), 1, "once")
  eq(g.sent(), "", "and nothing else is asked")
  eq(g.read.status, nil, "the status stays unknown")

  -- cut short once, the re-ask never answered
  g = new_game("custom")
  g.lines(cut); g.prompt()
  g.sent(true)
  eq(g.echoed("The game didn't show its curing status"), 0, "no warning while the re-ask is awaited")
  g.settle()
  eq(g.echoed("The game didn't show its curing status"), 1, "the re-ask never answered warns once after 15 seconds")

  -- one the player typed
  g = new_game("custom")
  g.lines(STATUS); g.prompt()
  g.sent()
  g.lines(cut); g.prompt()
  eq(g.sent(), "", "a cut status the player typed sends no re-ask")
  check("and leaves the status it had", g.read.status ~= nil)
  eq(g.echoed("The game didn't show its curing status"), 0, "and warns of nothing")
end

-- ===== login, and serverside going on, in custom mode =====

do
  local g = new_game("custom")
  g.lines(STATUS)
  g.sent()
  g.sk.serverprios_login()
  local sent = g.sent(true)
  check("login asks for the status", sent:find("curing status, curing focus", 1, true) ~= nil, sent)
  eq(g.read.status, nil, "and the last session's status is forgotten until it arrives")

  g.svo.setupserverside()
  sent = g.sent()
  check("login sends no focus switch", not sent:find("curing focus with", 1, true), sent)

  g.conf.serverside = false
  g.svo.tntf_set('serverside', 'on', true)
  g.changed('serverside')
  g.w.advance(0)
  sent = g.sent()
  check("serverside going on asks for the status", sent:find("curing status", 1, true) ~= nil, sent)
  for _, command in ipairs({ "curing afflictions on", "curing sipping on", "curing defences on", "curing batch on",
    "curing reporting on", "curing siphealth", "curing clotat", "curing manathreshold", "curing focus with" }) do
    check("and doesn't send " .. command, not sent:find(command, 1, true), sent)
  end
end

-- ===== auto mode =====

do
  local g = new_game()
  g.conf.siphealth = 80
  g.sent()
  g.lines(STATUS)
  g.reply("Health curing threshold set to 85%.")
  eq(g.conf.siphealth, 80, "auto mode follows nothing")
  eq(g.echoed("Svof's settings now follow"), 0, "and says nothing")
  eq(g.echoed("in the game"), 0, "and warns about nothing")
  g.conf.keepup = false
  g.changed('keepup')
  eq(g.sent(), "curing defences off", "and vconfig keepup still sends the game its switch")

  g.conf.serverside = false
  g.svo.tntf_set('serverside', 'on', true)
  g.changed('serverside')
  g.w.advance(0)
  local sent = g.sent()
  for _, command in ipairs({ "curing afflictions on", "curing sipping on", "curing batch on", "curing reporting on",
    "curing manathreshold", "curing focus withoutguilt" }) do
    check("auto mode still sends " .. command .. " when serverside goes on", sent:find(command, 1, true) ~= nil, sent)
  end
end

if #failures == 0 then
  print(("ALL PASS (%d checks)"):format(checks))
  os.exit(0)
else
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(("%d of %d checks failed"):format(#failures, checks))
  os.exit(1)
end
