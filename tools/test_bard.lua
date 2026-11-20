--[[
Logic-level test of Bard after the class's rework.

Achaea replaced Swashbuckling, Voicecraft and Harmonics with Bladedance,
Composition and Sagas. This runs the real loaders through tools/svof_world.lua
as a Bard and checks:

  * the skillsets, and that nothing of what the rework removed is left
  * tune's command, which leaves wielding a rapier to the player
  * the dances and tempos: their commands and lines, one at a time, defup
    switching to the one chosen, and keepup leaving a picked one alone, defup's
    included
  * the tempo triggers, run from their real scripts, and a tempo going when
    GMCP's one tempo or DEF no longer has one
  * circling, encircling and aria: tracked from GMCP, their lines and DEF, with
    nothing to choose in defup or keepup
  * the five earworm and crescendo triggers, moved and otherwise untouched

It proves nothing about what the game prints: those lines came from the game's
DEFENCE SHOW, a Bard's captures and the trigger scripts of another player's
reworked Bard.

Run: lua tools/test_bard.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(got, want, what)
  checks = checks + 1
  if got ~= want then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", what, tostring(want), tostring(got))
  end
end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local function has(list, item)
  for _, v in ipairs(list) do
    if v == item then return true end
  end
  return false
end

local TRIGGERS = "src/triggers/svo (aliases, triggers)/svo/"
local DANCES = { "harrying", "hawkstep", "wavedance" }
local TEMPOS = { "adagio", "moderato", "allegro", "vivace" }

-- a Bard with defup's or keepup's choices set, with svof running
local function bard(opts)
  local w = world.new({ class = "Bard", paused = false })
  for k, v in pairs(opts or {}) do w.svo.conf[k] = v end
  return w
end

local function sent(w, command)
  for _, c in ipairs(w.sent) do
    if c == command then return true end
  end
  return false
end

-- svof looks for what it wants to do
local function gnomes(w)
  w.svo.make_gnomes_work()
  w.run_timers()
end

-- a line of the game's, then the prompt that settles it
local function game(w, line)
  w.line(line)
  w.prompt()
end

-- ===== The skillsets =====
do
  local w = world.new({ class = "Bard" })
  local svo = w.svo
  -- a Bard has Sagas or Woe, never both: Woe in Cyrene, Sagas anywhere else
  for _, skill in ipairs({ "bladedance", "composition", "sagas" }) do
    eq(svo.haveskillset(skill), true, "a Bard outside Cyrene has " .. skill)
  end
  eq(svo.haveskillset("woe"), false, "a Bard outside Cyrene has no woe")
  eq(svo.havevoicebalance(), true, "and has the voice balance")
  eq(svo.me.skills.sagas, true, "me.skills agrees: sagas")
  eq(svo.me.skills.woe, nil, "me.skills agrees: no woe")
  eq(has(svo.knownskills.bard, "woe"), false, "knownskills has no woe for them")

  -- the city is read after this file loads, so systemstart and a city change
  -- both work the skills out again
  svo.conf.org = "Cyrene"
  svo.signals.orgchanged:emit()
  for _, skill in ipairs({ "bladedance", "composition", "woe" }) do
    eq(svo.haveskillset(skill), true, "a Cyrene Bard has " .. skill)
  end
  eq(svo.haveskillset("sagas"), false, "a Cyrene Bard has no sagas")
  eq(svo.havevoicebalance(), true, "and has the voice balance")
  eq(svo.me.skills.woe, true, "me.skills agrees: woe")
  eq(svo.me.skills.sagas, nil, "me.skills agrees: no sagas")
  eq(has(svo.knownskills.bard, "sagas"), false, "knownskills has no sagas for them")
  svo.conf.org = "Ashtan"
  svo.signals.orgchanged:emit()
  eq(svo.haveskillset("sagas"), true, "moving away from Cyrene gives sagas back")
  eq(svo.haveskillset("woe"), false, "and takes woe off")
  svo.conf.org = "Cyrene"
  svo.signals.systemstart:emit()
  eq(svo.haveskillset("woe"), true, "systemstart reads the city a loaded config set")
  eq(svo.haveskillset("sagas"), false, "and not sagas")
  svo.conf.org = nil
  svo.refreshskills()
  eq(svo.haveskillset("sagas"), true, "no city set: sagas")

  -- an enemy Bard can have either
  eq(has(svo.classes.bard.skills, "sagas"), true, "the enemy Bard list has sagas")
  eq(has(svo.classes.bard.skills, "woe"), true, "and woe")
  eq(world.new({ class = "Monk" }).svo.havevoicebalance(), false, "a Monk has no voice balance")
  for _, skill in ipairs({ "swashbuckling", "voicecraft", "harmonics" }) do
    eq(svo.haveskillset(skill), false, "a Bard no longer has " .. skill)
  end
  eq(svo.bals.voice, true, "Sagas keeps voice balance")

  for _, name in ipairs({ "lay", "songbird", "drunkensailor", "heartsfury", "arrowcatch", "dwinnu", "anthem",
      "harmonius", "contradanse", "paxmusicalis", "gigue", "bagatelle", "partita", "berceuse", "continuo", "wassail",
      "canticle", "reel", "hallelujah" }) do
    eq(svo.defs_data[name], nil, "a Bard has no " .. name .. " record")
    eq(svo.dict[name], nil, "a Bard has no " .. name .. " entry")
  end
  eq(svo.dict.sstosvod.lay, nil, "GMCP's lay goes nowhere")
  eq(svo.dict.sstosvod.lament, false, "deSangre's Lament is still one svof leaves alone")

  for _, name in ipairs({ "balancing", "acrobatics", "dodging", "grip", "tune" }) do
    eq(svo.defs_data[name].type, "bladedance", name .. " is under Bladedance")
  end
end

do -- other classes keep what's theirs
  local w = world.new({ class = "Jester" })
  eq(w.svo.defs_data.arrowcatch and w.svo.defs_data.arrowcatch.type, "pranks", "a Jester keeps arrowcatch")
  eq(w.svo.dict.sstosvod.arrowcatching, "arrowcatch", "and its GMCP name")
  w = world.new({ class = "Monk" })
  for _, name in ipairs({ "harrying", "hawkstep", "adagio", "circling", "encircling", "aria" }) do
    eq(w.svo.defs_data[name], nil, "a Monk has no " .. name)
  end
  w.gmcp_defence_add("circling")
  eq(w.svo.defc.circling, nil, "GMCP's circling means nothing to a Monk")
end

do -- the writhes no longer look for dwinnu, as anyone
  for _, class in ipairs({ "Bard", "Monk" }) do
    local w = world.new({ class = class })
    w.svo.affs.webbed = { p = {} }
    w.svo.affs.roped = { p = {} }
    local ok_web, err_web = pcall(w.svo.dict.webbed.misc.isadvisable)
    local ok_rope, err_rope = pcall(w.svo.dict.roped.misc.isadvisable)
    eq(ok_web, true, class .. ": webbed's writhe works out with no dwinnu: " .. tostring(err_web))
    eq(ok_rope, true, class .. ": roped's writhe works out with no dwinnu: " .. tostring(err_rope))
  end
end

-- ===== tune =====
do
  local w = bard({ keepup = true })
  local svo = w.svo
  local tune = svo.dict.tune.physical
  eq(tune.action, "blade tune", "tune's command")
  eq(tune.undeffable, true, "svof raises tune itself")
  svo.defkeepup.basic.tune = true
  gnomes(w)
  eq(sent(w, "blade tune"), true, "keepup sends blade tune")
  for _, c in ipairs(w.sent) do
    eq(c:find("wield", 1, true), nil, "and wields nothing, which is the player's choice: " .. c)
  end
  w.gmcp_defence_add("tune")
  eq(svo.defc.tune, true, "GMCP's tune sets it")
  eq(svo.bals.voice, true, "and spends no voice balance")
end

do -- a saved setting from when the server raised tune doesn't stop svof raising it now
  local w = bard({ serverside = true, keepup = true })
  w.svo.serverignore.tune = true
  w.svo.defkeepup.basic.tune = true
  gnomes(w)
  eq(sent(w, "blade tune"), true, "serverside: tune is svof's whatever serverignore saved")
end

-- ===== The dances =====
local ON = {
  harrying = "You begin the spiral steps of your blade-wrought song, weapon and body in perfect symmetry.",
  hawkstep = "Your step moves in the exacting precision of a staccato bladesong, the flawless footwork rapidly accelerating in tune with the unheard beat as your surroundings blur.",
  wavedance = "You begin the unrelenting dance of the waves, feet carrying you ever forward and yet never quite at the full extent of motion.",
}
local ALREADY = {
  harrying = "You are already dancing the harrying.",
  hawkstep = "You are already dancing the hawkstep.",
  wavedance = "You are already dancing like the unrelenting waves.",
}
local SWITCH = {
  harrying = "Spiral steps bleed into a perfect staccato as for the briefest moment you transition into the deadly harrying.",
  hawkstep = "Spiral steps bleed into a perfect staccato as for the briefest moment you move in a harrying hawkstep.",
  wavedance = "Spiral steps bleed into a perfect staccato as for the briefest moment you move as the crashing waves.",
}
local CEASE = "You cease your peerless dancing, returning to explosive stillness."

for _, dance in ipairs(DANCES) do
  local w = world.new({ class = "Bard" })
  local svo = w.svo
  local act = svo.dict[dance].physical
  eq(act.action, "dance " .. dance, dance .. ": its command")
  eq(act.undeffable, true, dance .. ": svof raises it itself")

  -- whoever sent the command
  game(w, ON[dance])
  eq(svo.defc[dance], true, dance .. ": its starting line sets it")
  game(w, CEASE)
  eq(svo.defc[dance], false, dance .. ": ceasing takes it off")
  game(w, ALREADY[dance])
  eq(svo.defc[dance], true, dance .. ": being told it's already up sets it")

  -- each of the others replaced by this one
  for _, other in ipairs(DANCES) do
    if other ~= dance then
      w = world.new({ class = "Bard" })
      svo = w.svo
      game(w, ON[other])
      game(w, SWITCH[dance])
      eq(svo.defc[dance], true, dance .. ": switching from " .. other .. " sets it")
      eq(svo.defc[other], false, dance .. ": and takes " .. other .. " off")
    end
  end
end

do -- GMCP knows two of the three
  local w = world.new({ class = "Bard" })
  w.gmcp_defence_add("hawkstep")
  eq(w.svo.defc.hawkstep, true, "GMCP's hawkstep sets it")
  w.gmcp_defence_remove("hawkstep")
  eq(w.svo.defc.hawkstep, false, "and its removal takes it off")
  w.gmcp_defence_add("wavedance")
  eq(w.svo.defc.wavedance, true, "GMCP's wavedance sets it")
  eq(w.svo.dict.sstosvod.harrying, nil, "the game's list has no harrying")
  eq(w.svo.dict.sstosvod.tempo, false, "and its one tempo is none of svof's four by itself")
end

do -- DEF: a dance's line sets it and takes the old one off, and a dance DEF
   -- doesn't print isn't lost
  local function def(w, line)
    local svo = w.svo
    svo.doaction(svo.dict.defcheck.physical)
    svo.defs.defstart()
    if line then w.line(line) end
    svo.defs.defline()
    w.prompt()
  end
  local w = world.new({ class = "Bard" })
  local svo = w.svo
  svo.defences.got("harrying")
  def(w, "You have the grace of a striking hawk.")
  eq(svo.defc.hawkstep, true, "DEF's hawkstep line sets it")
  eq(svo.defc.harrying, false, "and takes harrying off, as only one is up")

  w = world.new({ class = "Bard" })
  svo = w.svo
  svo.defences.got("harrying")
  def(w)
  eq(svo.defc.harrying, true, "a DEF with no dance line leaves harrying, which DEF has no line for")
end

-- A missed switch line, as in blackout, left two dances up, and neither DEF
-- nor GMCP corrected it (review of #908)
do
  local w = world.new({ class = "Bard" })
  w.svo.defences.got("harrying")
  w.gmcp_defence_add("hawkstep")
  eq(w.svo.defc.hawkstep, true, "GMCP adds a dance")
  eq(w.svo.defc.harrying, false, "and takes the old one off")

  w = world.new({ class = "Bard" })
  w.svo.defences.got("harrying")
  w.gmcp_defence_list({ "hawkstep" })
  eq(w.svo.defc.hawkstep, true, "a GMCP list names a dance")
  eq(w.svo.defc.harrying, false, "and takes the old one off too")

  -- so defup's choice goes up again
  w = bard()
  local svo = w.svo
  svo.sys.deffing = true
  svo.defdefup.basic.harrying = true
  svo.defences.got("harrying")
  w.gmcp_defence_add("hawkstep")
  gnomes(w)
  eq(sent(w, "dance harrying"), true, "defup sends its own dance again")
end

-- ===== Choosing one =====
do
  for _, list in ipairs({ DANCES, TEMPOS }) do
    local w = world.new({ class = "Bard" })
    local svo = w.svo
    for _, name in ipairs(list) do
      svo.defs.keepup(name, true, "basic")
      svo.defs.defup(name, true, "basic")
      for _, other in ipairs(list) do
        eq(svo.defkeepup.basic[other], other == name, "keepup holds only " .. name .. ", checking " .. other)
        eq(svo.defdefup.basic[other], other == name, "defup holds only " .. name .. ", checking " .. other)
      end
    end
  end
end

do -- keepup leaves one the player's offence picked alone
  local w = bard({ keepup = true })
  local svo = w.svo
  svo.defkeepup.basic.hawkstep = true
  svo.defences.got("wavedance")
  svo.defences.got("allegro")
  svo.defkeepup.basic.adagio = true
  gnomes(w)
  eq(sent(w, "dance hawkstep"), false, "keepup doesn't replace a dance that's up")
  eq(sent(w, "tempo adagio"), false, "or a tempo that's up")

  svo.defences.lost("wavedance")
  gnomes(w)
  eq(sent(w, "dance hawkstep"), true, "and raises its own with none up")
end

do -- defup switches to the one chosen
  local w = bard()
  local svo = w.svo
  svo.sys.deffing = true
  svo.defdefup.basic.hawkstep = true
  svo.defences.got("wavedance")
  gnomes(w)
  eq(sent(w, "dance hawkstep"), true, "defup replaces a dance that's up")
  eq(svo.dict.hawkstep.physical.isadvisable(), false, "and doesn't want it again while it's in flight")

  w = bard()
  svo = w.svo
  svo.sys.deffing = true
  svo.defdefup.basic.adagio = true
  svo.defdefup.basic.allegro = false
  svo.doaction(svo.dict.vivace.physical)
  eq(svo.dict.adagio.physical.isadvisable(), false, "but not while another of them is in flight")
end

do -- defup and keepup choosing different dances: defup's wins until defup is
   -- done, and keepup then leaves it alone. Both were wanted, each one's
   -- completion took the other off, and defup never finished (review of #908)
  local w = bard({ keepup = true })
  local svo = w.svo
  svo.defdefup.basic.hawkstep = true
  svo.defdefup.basic.balancing = true
  svo.defkeepup.basic.wavedance = true
  svo.sys.deffing = true
  svo.showprompt = function() end
  local danced = {}
  for _ = 1, 8 do
    w.sent = {}
    gnomes(w)
    for _, dance in ipairs(DANCES) do
      if sent(w, "dance " .. dance) then
        danced[#danced + 1] = dance
        local up = svo.defc.harrying or svo.defc.hawkstep or svo.defc.wavedance
        game(w, up and SWITCH[dance] or ON[dance])
      end
    end
    if sent(w, "balancing on") then game(w, "You move onto the balls of your feet and begin to concentrate on balance.") end
    -- as the prompt does while deffing
    svo.defupfinish()
    if not svo.sys.deffing then break end
  end
  eq(table.concat(danced, " "), "hawkstep", "defup and keepup apart: defup dances its own, once")
  eq(svo.defc.hawkstep, true, "defup and keepup apart: and it's up")
  eq(svo.defc.balancing, true, "defup and keepup apart: defup goes on to the rest")
  eq(svo.sys.deffing, false, "defup and keepup apart: and finishes")
  w.sent = {}
  gnomes(w)
  eq(sent(w, "dance wavedance"), false, "defup and keepup apart: keepup then leaves defup's dance alone")

  -- with nothing of the group in defup, a dance that's up stays while deffing too
  w = bard({ keepup = true })
  svo = w.svo
  svo.defdefup.basic.balancing = true
  svo.defkeepup.basic.wavedance = true
  svo.defences.got("hawkstep")
  svo.sys.deffing = true
  gnomes(w)
  eq(sent(w, "dance wavedance"), false, "defup with no dance: keepup leaves one that's up alone")
end

do -- with paralysis or prone, none of them
  local w = bard({ keepup = true })
  w.svo.defkeepup.basic.harrying = true
  w.svo.affs.paralysis = { p = {} }
  eq(w.svo.dict.harrying.physical.isadvisable(), false, "paralysed, no dance")
end

do -- the commands svof adopts when someone else types them
  local w = world.new({ class = "Bard" })
  eq(w.svo.sys.input_to_actions["dance hawkstep"] ~= nil, true, "svof knows dance hawkstep as its own")
  eq(w.svo.sys.input_to_actions["tempo adagio"] ~= nil, true, "and tempo adagio")
end

-- ===== The tempos, through their real trigger scripts =====
local function tempo_trigger(w, name, match)
  w.env.matches = { "whole line", match }
  w.run(read(TRIGGERS .. "Bladedance/" .. name .. ".lua"), name)
  w.prompt()
end

for _, tempo in ipairs(TEMPOS) do
  local w = world.new({ class = "Bard" })
  local svo = w.svo
  eq(svo.dict[tempo].physical.action, "tempo " .. tempo, tempo .. ": its command")

  tempo_trigger(w, "Tempo_set", tempo)
  eq(svo.defc[tempo], true, tempo .. ": setting it sets it")
  for _, other in ipairs(TEMPOS) do
    if other ~= tempo then
      tempo_trigger(w, "Tempo_shown", other)
      eq(svo.defc[other], true, tempo .. ": DEF naming " .. other .. " sets that")
      eq(svo.defc[tempo], false, tempo .. ": and takes this one off")
      tempo_trigger(w, "Tempo_set", tempo)
    end
  end
  w = world.new({ class = "Bard" })
  tempo_trigger(w, "Tempo_set", tempo:upper())
  eq(w.svo.defc[tempo], true, tempo .. ": whatever case the game prints")
end

do -- "already" names no tempo: it's the one svof sent, and no other
  local w = world.new({ class = "Bard" })
  local svo = w.svo
  svo.doaction(svo.dict.allegro.physical)
  tempo_trigger(w, "Tempo_already")
  eq(svo.defc.allegro, true, "already: the tempo in flight is up")
  eq(svo.defc.adagio, nil, "already: and no other")

  w = world.new({ class = "Bard" })
  tempo_trigger(w, "Tempo_already")
  for _, tempo in ipairs(TEMPOS) do
    eq(w.svo.defc[tempo], nil, "already: with none in flight, no " .. tempo)
  end

  w = world.new({ class = "Bard" })
  tempo_trigger(w, "Tempo_set", "nosuchtempo")
  for _, tempo in ipairs(TEMPOS) do
    eq(w.svo.defc[tempo], nil, "a name that isn't a tempo sets no " .. tempo)
  end
  tempo_trigger(w, "Tempo_shown", "hawkstep")
  eq(w.svo.defc.hawkstep, nil, "and a dance's name in that place doesn't set the dance")
end

do -- a tempo has no line of its own going, so GMCP's one tempo and DEF say
   -- when none is up. Nothing took one off, and keepup never raised it again
   -- (review of #908)
  local w = world.new({ class = "Bard" })
  local svo = w.svo
  tempo_trigger(w, "Tempo_set", "vivace")
  w.gmcp_defence_remove("tempo")
  eq(svo.defc.vivace, false, "GMCP's tempo going takes the tempo off")
  w.gmcp_defence_add("tempo")
  for _, tempo in ipairs(TEMPOS) do
    eq(svo.defc[tempo] == true, false, "GMCP's tempo coming doesn't say which, so no " .. tempo)
  end
  tempo_trigger(w, "Tempo_set", "adagio")
  w.gmcp_defence_remove("hawkstep")
  eq(svo.defc.adagio, true, "another defence going leaves the tempo")
  w.gmcp_defence_list({ "tempo", "hawkstep" })
  eq(svo.defc.adagio, true, "a GMCP list with tempo leaves it")
  w.gmcp_defence_list({ "hawkstep" })
  eq(svo.defc.adagio, false, "a GMCP list without tempo takes it off")

  -- DEF, with and without the tempo's line
  local function def(shown)
    svo.doaction(svo.dict.defcheck.physical)
    svo.defs.defstart()
    if shown then
      w.env.matches = { "whole line", shown }
      w.run(read(TRIGGERS .. "Bladedance/Tempo_shown.lua"), "Tempo_shown")
    end
    svo.defs.defline()
    w.prompt()
    -- DEF's own display, which clears what this DEF listed
    svo.showprompt = function() end
    w.run_timers()
  end
  w = world.new({ class = "Bard" })
  svo = w.svo
  tempo_trigger(w, "Tempo_set", "vivace")
  def()
  eq(svo.defc.vivace, false, "DEF naming no tempo takes the tempo off")
  tempo_trigger(w, "Tempo_set", "vivace")
  def("vivace")
  eq(svo.defc.vivace, true, "DEF naming it keeps it")
  def("adagio")
  eq(svo.defc.adagio, true, "DEF naming another sets that")
  eq(svo.defc.vivace, false, "and takes this one off")

  -- so keepup raises it again
  w = bard({ keepup = true })
  svo = w.svo
  svo.defkeepup.basic.vivace = true
  tempo_trigger(w, "Tempo_set", "vivace")
  w.gmcp_defence_remove("tempo")
  w.sent = {}
  gnomes(w)
  eq(sent(w, "tempo vivace"), true, "keepup raises a tempo GMCP took off")
end

do -- another class seeing these lines
  local w = world.new({ class = "Monk" })
  w.env.matches = { "whole line", "adagio" }
  local ok, err = pcall(w.run, read(TRIGGERS .. "Bladedance/Tempo_set.lua"), "Tempo_set")
  eq(ok, true, "a Monk seeing a tempo line gets no error: " .. tostring(err))
  ok, err = pcall(w.run, read(TRIGGERS .. "Bladedance/Tempo_already.lua"), "Tempo_already")
  eq(ok, true, "nor the already line: " .. tostring(err))
end

-- ===== Tracked, with nothing to choose =====
local TRACKED = {
  { name = "circling", gate = "bladedance", def = "You are demonstrating peerless footwork.",
    off = "Your foe has escaped your deadly footwork." },
  { name = "encircling", gate = "bladedance", def = "You are attacking in synchrony with an ally.",
    off = "You are no longer encircling with your ally." },
  { name = "aria", gate = "composition", def = "Your health is enhanced by the beauties of an Aria.",
    off = "The heavenly strains of the Aria slowly fall silent." },
}

for _, t in ipairs(TRACKED) do
  local name = t.name
  local w = world.new({ class = "Bard" })
  local svo = w.svo
  eq(svo.defs_data[name].nodef, true, name .. ": has no place in the lists")
  eq(svo.defs_data[name].type, nil, name .. ": nor in a skillset's")
  eq(svo.dict[name], nil, name .. ": svof has no command for it")
  eq(svo.defkeepup.basic[name], nil, name .. ": no keepup slot")
  eq(svo.defdefup.basic[name], nil, name .. ": no defup slot")

  w.gmcp_defence_add(name)
  eq(svo.defc[name], true, name .. ": GMCP sets it")
  local got = false
  for _, e in ipairs(w.events) do
    if e.name == "svo got def" and e.args[1] == name then got = true end
  end
  eq(got, true, name .. ": and a script hears it")
  w.gmcp_defence_remove(name)
  eq(svo.defc[name], false, name .. ": GMCP takes it off")

  svo.defences.got(name)
  game(w, t.off)
  eq(svo.defc[name], false, name .. ": its fading line takes it off")

  -- DEF keeps one it lists and takes off one it doesn't
  w = world.new({ class = "Bard" })
  svo = w.svo
  svo.defences.got(name)
  svo.doaction(svo.dict.defcheck.physical)
  svo.defs.defstart()
  w.line(t.def)
  svo.defs.defline()
  w.prompt()
  eq(svo.defc[name], true, name .. ": DEF listing it keeps it")

  w = world.new({ class = "Bard" })
  svo = w.svo
  svo.defences.got(name)
  svo.doaction(svo.dict.defcheck.physical)
  svo.defs.defstart()
  svo.defs.defline()
  w.prompt()
  eq(svo.defc[name], false, name .. ": DEF not listing it takes it off")

  -- the two choosing commands refuse it
  w = world.new({ class = "Bard" })
  svo = w.svo
  pcall(svo.defs.keepup, name, true, "basic")
  pcall(svo.defs.defup, name, true, "basic")
  eq(svo.defkeepup.basic[name], nil, name .. ": keepup won't take it")
  eq(svo.defdefup.basic[name], nil, name .. ": defup won't take it")
end

-- ===== The triggers =====
do
  local function names(path)
    local out, seen = {}, {}
    for name in read(path):gmatch('"name":%s*"([^"]+)"') do
      out[#out + 1] = name
      seen[name] = true
    end
    return seen, out
  end

  local root = names(TRIGGERS .. "triggers.json")
  eq(root.Bladedance, true, "the Bladedance group is there")
  eq(root.Composition, true, "the Composition group is there")
  eq(root.Swashbuckling, nil, "Swashbuckling is gone")
  eq(root.Voicecraft, nil, "Voicecraft is gone")
  eq(root.Harmonics, nil, "Harmonics is gone")

  local blade, list = names(TRIGGERS .. "Bladedance/triggers.json")
  eq(#list, 5, "Bladedance holds five triggers")
  for _, name in ipairs({ "Earworm hum", "Crescendo hum", "Tempo set", "Tempo shown", "Tempo already" }) do
    eq(blade[name], true, "Bladedance has " .. name)
  end
  local composition, list2 = names(TRIGGERS .. "Composition/triggers.json")
  eq(#list2, 3, "Composition holds three triggers")
  for _, name in ipairs({ "Crescendo begins", "Crescendo draws closer", "Crescendo peaks" }) do
    eq(composition[name], true, "Composition has " .. name)
  end

  -- earworm and crescendo still do what they did
  local w = world.new({ class = "Bard" })
  eq(read(TRIGGERS .. "Bladedance/Earworm_hum.lua"):find("svo.valid.simpleearworm()", 1, true) ~= nil, true,
    "the earworm hum still gives earworm")
  eq(read(TRIGGERS .. "Bladedance/Crescendo_hum.lua"):find("svo.valid.simplecrescendo()", 1, true) ~= nil, true,
    "the crescendo hum still gives crescendo")
  for _, file in ipairs({ "Crescendo_begins", "Crescendo_draws_closer", "Crescendo_peaks" }) do
    eq(read(TRIGGERS .. "Composition/" .. file .. ".lua"):find("svo.valid.simplecrescendo()", 1, true) ~= nil, true,
      file .. " still gives crescendo")
  end
  eq(type(w.svo.valid.simpleearworm), "function", "and the handlers they call exist")
  eq(type(w.svo.valid.simplecrescendo), "function", "both of them")
end

-- ===== Voice balance, from GMCP =====
-- "Voice: No" is assumed, not captured: the game's one seen value is "Yes"
do
  -- creating a world raises got balance for the balances it resets
  local function fresh(class)
    local w = world.new({ class = class })
    w.events = {}
    return w
  end
  local function count(w, name)
    local n = 0
    for _, e in ipairs(w.events) do
      if e.name == name and e.args[1] == "voice" then n = n + 1 end
    end
    return n
  end

  local w = fresh("Bard")
  local svo = w.svo
  w.gmcp_vitals({ "Bleed: 0", "Rage: 0", "Voice: Yes" })
  eq(svo.bals.voice, true, "voice: Yes with the balance up changes nothing")
  eq(count(w, "svo lost balance"), 0, "voice: Yes with the balance up raises no lost balance")
  eq(count(w, "svo got balance"), 0, "voice: Yes with the balance up raises no got balance")
  eq(svo.sk.voice_gmcp, true, "voice: GMCP's Yes is kept")

  w.gmcp_vitals({ "Bleed: 0", "Rage: 0", "Voice: No" })
  eq(svo.bals.voice, false, "voice: No takes the balance down")
  eq(count(w, "svo lost balance"), 1, "voice: No raises lost balance once")
  eq(svo.sk.voice_gmcp, false, "voice: GMCP's No is kept")
  w.gmcp_vitals({ "Bleed: 0", "Rage: 0", "Voice: No" })
  eq(svo.bals.voice, false, "voice: a second No leaves it down")
  eq(count(w, "svo lost balance"), 1, "voice: and raises nothing")

  -- the fallback timer's guess stays down while GMCP says No
  w.advance(11)
  eq(svo.bals.voice, false, "voice: the fallback timer doesn't restore it while GMCP says No")
  eq(count(w, "svo got balance"), 0, "voice: and raises no got balance")
  w.advance(100)
  eq(svo.bals.voice, false, "voice: a long recovery stays down")
  w.gmcp_vitals({ "Voice: No" })
  eq(count(w, "svo lost balance"), 1, "voice: and Vitals through it raise no lost/got pair")

  -- in blackout GMCP says nothing, so the guess stands
  svo.affs.blackout = { p = {} }
  svo.bals.voice = true
  svo.lostbal_voice()
  eq(count(w, "svo lost balance"), 2, "voice: lost again")
  w.advance(11)
  eq(svo.bals.voice, true, "voice: in blackout the fallback timer restores it")
  svo.affs.blackout = nil

  -- and GMCP's Yes brings it back, once
  svo.bals.voice = true
  w.events = {}
  w.gmcp_vitals({ "Voice: No" })
  w.gmcp_vitals({ "Voice: Yes" })
  eq(svo.bals.voice, true, "voice: Yes brings it back")
  eq(count(w, "svo got balance"), 1, "voice: Yes raises got balance once")
  w.gmcp_vitals({ "Voice: Yes" })
  eq(count(w, "svo got balance"), 1, "voice: a second Yes raises nothing")
  eq(count(w, "svo lost balance"), 1, "voice: and the lost balance stays one")
  w.advance(100)
  eq(count(w, "svo got balance"), 1, "voice: the old fallback timer adds nothing")

  -- the text path and GMCP for one use
  w = fresh("Bard")
  svo = w.svo
  svo.lostbal_voice()
  w.gmcp_vitals({ "Voice: No" })
  eq(count(w, "svo lost balance"), 1, "voice: the text path then GMCP raise one lost balance")
  svo.valid.gotvoicebalance()
  w.prompt()
  w.gmcp_vitals({ "Voice: Yes" })
  eq(svo.bals.voice, true, "voice: got voice then Yes leaves it up")
  eq(count(w, "svo got balance"), 1, "voice: and raises one got balance")

  -- values it doesn't know
  w = fresh("Bard")
  svo = w.svo
  w.gmcp_vitals({ "Voice: Maybe" })
  eq(svo.bals.voice, true, "voice: an unknown value leaves it up")
  eq(svo.sk.voice_gmcp, nil, "voice: and GMCP has said nothing")
  w.gmcp_vitals({ "Voice: No" })
  w.gmcp_vitals({ "Voice: Maybe" })
  eq(svo.bals.voice, false, "voice: an unknown value leaves it down")
  eq(svo.sk.voice_gmcp, false, "voice: and keeps what GMCP last said")
  eq(count(w, "svo got balance"), 0, "voice: and raises nothing")
  w.gmcp_vitals({ "Bleed: 0", "Rage: 0" })
  eq(svo.bals.voice, false, "voice: charstats with no Voice leave it down")
  eq(count(w, "svo lost balance"), 1, "voice: and raise nothing")
  w = fresh("Bard")
  w.gmcp_vitals({ "Bleed: 0", "Rage: 0" })
  eq(w.svo.bals.voice, true, "voice: charstats with no Voice leave it up")
  eq(count(w, "svo lost balance"), 0, "voice: and raise nothing")

  -- GMCP not said anything: the fallback timer restores it
  w = fresh("Bard")
  svo = w.svo
  svo.lostbal_voice()
  w.advance(11)
  eq(svo.bals.voice, true, "voice: with GMCP silent the fallback timer restores it")
  eq(count(w, "svo got balance"), 1, "voice: and raises got balance once")

  -- a class without Sagas connects nothing
  w = fresh("Monk")
  local before = w.svo.bals.voice
  w.gmcp_vitals({ "Voice: No" })
  eq(w.svo.bals.voice, before, "voice: a Monk's balance is untouched by Voice: No")
  eq(w.svo.sk.voice_gmcp, nil, "voice: and a Monk records nothing")
  eq(count(w, "svo lost balance"), 0, "voice: and raises nothing")
end

-- Sagas and Woe use one balance: the gates and GMCP work for both, and the two
-- recovery paths that aren't at the recovery line record the time without
-- printing it
for _, case in ipairs({ { org = "Ashtan", skill = "sagas" }, { org = "Cyrene", skill = "woe" } }) do
  local label = case.skill .. " Bard"
  local function fresh()
    local w = world.new({ class = "Bard" })
    w.svo.conf.org = case.org
    w.svo.signals.orgchanged:emit()
    w.events = {}
    w.svo.stats.lastvoice = nil
    w.env.stopStopWatch = function() return 7 end
    w.svo.conf.showbaltimes = true
    w.echotimes = 0
    w.svo.echotime = function() w.echotimes = w.echotimes + 1 end
    return w
  end
  local function got(w)
    local n = 0
    for _, e in ipairs(w.events) do
      if e.name == "svo got balance" and e.args[1] == "voice" then n = n + 1 end
    end
    return n
  end

  local w = fresh()
  local svo = w.svo
  eq(svo.haveskillset(case.skill), true, label .. ": has " .. case.skill)
  -- the gates
  eq(type(svo.valid.usedvoicebalance), "function", label .. ": the used voice handler exists")
  eq(type(svo.valid.gotvoicebalance), "function", label .. ": the got voice handler exists")
  eq(type(svo.cpp.compute_voicebal), "function", label .. ": the prompt computes voice")
  eq(svo.cp.definitions["@voicebal"], "svo.cpp.compute_voicebal()", label .. ": the prompt tag shows it")
  svo.bals.voice = nil
  svo.reset.bals()
  eq(svo.bals.voice, true, label .. ": a balance reset sets voice")
  w.events = {}

  -- GMCP
  w.gmcp_vitals({ "Voice: No" })
  eq(svo.bals.voice, false, label .. ": GMCP's No takes the balance down")
  w.gmcp_vitals({ "Voice: Yes" })
  eq(svo.bals.voice, true, label .. ": GMCP's Yes brings it back")
  eq(got(w), 1, label .. ": and raises one got balance")
  eq(svo.stats.lastvoice, 7, label .. ": and records the time")
  eq(w.echotimes, 0, label .. ": GMCP's path prints no time")

  -- the fallback timer
  w = fresh()
  svo = w.svo
  svo.lostbal_voice()
  w.advance(11)
  eq(svo.bals.voice, true, label .. ": the timer restores voice")
  eq(got(w), 1, label .. ": and raises one got balance")
  eq(svo.stats.lastvoice, 7, label .. ": the timer path records the time")
  eq(w.echotimes, 0, label .. ": the timer path prints no time")

  -- the text path still prints the time, where it's at the line
  w = fresh()
  svo = w.svo
  svo.lostbal_voice()
  svo.endbalancewatch("voice")
  eq(w.echotimes, 1, label .. ": endbalancewatch with no flag still prints")
  svo.endbalancewatch("voice", nil, true)
  eq(w.echotimes, 1, label .. ": and with the flag doesn't")
end

do -- no voice balance, no voice gates
  local w = world.new({ class = "Monk" })
  eq(w.svo.valid.usedvoicebalance, nil, "a Monk has no used voice handler")
  eq(w.svo.cpp.compute_voicebal, nil, "or prompt voice")
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL: " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
