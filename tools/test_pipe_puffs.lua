--[[
Pipe puff counts, through tools/svof_world.lua and the real loaders.

  * Serverside refills pipes itself (the user, 2026-10-31), and svof counted
    a fill line only with its own fill in flight, so a pipe the server kept
    full read 0. A fill line under serverside with nothing in flight now
    refills the emptier of that herb's pipes, holding what the line names.
  * A puff came off the herb's first pipe whatever it held. It now comes
    off the first while it has any, then the second, and the label names
    what that pipe holds.
  * Filling the second pipe wrote the first one's contents and read the
    first one's puffs.

  lua tools/test_pipe_puffs.lua
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

local function set_pipe(svo, herb, t)
  local pipe = svo.pipes[herb]
  for k, v in pairs(t) do pipe[k] = v end
  return pipe
end

local FILLS = {
  skullcap = { "You fill your pipe with a skullcap flower.", "skullcap", "You fill your pipe with a pinch of ground malachite.", "malachite" },
  elm = { "You fill your pipe with slippery elm.", "elm", "You fill your pipe with a pinch of ground cinnabar.", "cinnabar" },
  valerian = { "You fill your pipe with a valerian leaf.", "valerian", "You fill your pipe with a pinch of realgar crystals.", "realgar" },
}

for herb, f in pairs(FILLS) do
  for i = 1, 3, 2 do
    local line, contents = f[i], f[i + 1]
    local w = world.new()
    local svo = w.svo
    svo.conf.serverside = true
    local pipe = set_pipe(svo, herb, { id = 101, puffs = 0, filledwith = 'x', maxpuffs = 10 })
    w.env.line = line
    svo.valid['fill' .. herb]()
    eq(pipe.puffs, 10, herb .. ": the server's fill refills the pipe (" .. line .. ")")
    eq(pipe.filledwith, contents, herb .. ": holding what the line names")
  end
end

do -- two pipes of one herb: the emptier
  local w = world.new()
  local svo = w.svo
  svo.conf.serverside = true
  local pipe = set_pipe(svo, 'skullcap', { id = 101, id2 = 102, puffs = 4, puffs2 = 0, filledwith = 'skullcap', filledwith2 = 'x' })
  w.env.line = FILLS.skullcap[3]
  svo.valid.fillskullcap()
  eq(pipe.puffs2, 10, "with two pipes, the emptier is refilled")
  eq(pipe.filledwith2, "malachite", "with what the line names")
  eq(pipe.puffs, 4, "and the other is left alone")
end

do -- a fill with both pipes level, from the live run: svo.pipe_refilled gave
   -- a fill of the second to the first, which then read as holding realgar
  local w = world.new()
  local svo = w.svo
  svo.conf.serverside = true
  local pipe = set_pipe(svo, 'valerian', { id = 535340, id2 = 688072, puffs = 10, puffs2 = 10,
    filledwith = 'valerian', filledwith2 = 'realgar', maxpuffs = 10, maxpuffs2 = 10 })
  w.env.line = FILLS.valerian[3]
  svo.valid.fillvalerian()
  eq(pipe.filledwith, "valerian", "level pipes: the first keeps its contents")
  eq(pipe.filledwith2, "realgar", "level pipes: the second holds what it did")
end

do -- the server names the pipe, whatever the counts say
  local w = world.new()
  local svo = w.svo
  svo.conf.serverside = true
  local pipe = set_pipe(svo, 'valerian', { id = 101, id2 = 102, puffs = 0, puffs2 = 7,
    filledwith = 'valerian', filledwith2 = 'valerian', maxpuffs = 10, maxpuffs2 = 10 })
  svo.pipe_filling("102")
  w.env.line = FILLS.valerian[3]
  svo.valid.fillvalerian()
  eq(pipe.puffs2, 10, "named pipe: the second is filled, though the first is emptier")
  eq(pipe.filledwith2, "realgar", "named pipe: holding what the line names")
  eq(pipe.puffs, 0, "named pipe: the first is left alone")
  eq(pipe.filledwith, "valerian", "named pipe: and keeps its contents")

  -- the name is for that fill only
  pipe.puffs, pipe.puffs2 = 0, 7
  w.env.line = FILLS.valerian[1]
  svo.valid.fillvalerian()
  eq(pipe.puffs, 10, "named pipe: the next fill goes by the counts again")
  eq(pipe.puffs2, 7, "named pipe: and leaves the second")
end

do -- a pipe svof doesn't track: nothing it counts changes
  local w = world.new()
  local svo = w.svo
  svo.conf.serverside = true
  local pipe = set_pipe(svo, 'elm', { id = 101, id2 = 102, puffs = 2, puffs2 = 3, filledwith = 'elm', filledwith2 = 'elm' })
  svo.pipe_filling("999")
  w.env.line = FILLS.elm[1]
  svo.valid.fillelm()
  eq(pipe.puffs, 2, "untracked pipe: the first is left alone")
  eq(pipe.puffs2, 3, "untracked pipe: the second is left alone")
end

do -- a name with no fill after it is gone by the prompt
  local w = world.new()
  local svo = w.svo
  svo.conf.serverside = true
  local pipe = set_pipe(svo, 'elm', { id = 101, id2 = 102, puffs = 0, puffs2 = 3, filledwith = 'elm', filledwith2 = 'elm' })
  svo.pipe_filling("102")
  w.prompt()
  w.env.line = FILLS.elm[1]
  svo.valid.fillelm()
  eq(pipe.puffs, 10, "stale name: the prompt clears it, so the emptier is filled")
  eq(pipe.puffs2, 3, "stale name: and the named pipe is left alone")
end

do -- the trigger that reads the server's line
  local dir = "src/triggers/svo (aliases, triggers)/svo/General/Server-side commands/"
  local f = assert(io.open(dir .. "triggers.json", "r"))
  local json = f:read("*a")
  f:close()
  eq(json:find('PUT [A-Z ]+ IN (', 1, true) ~= nil, true, "the trigger's pattern is there")
  f = assert(io.open(dir .. "Server_pipe_fill.lua", "r"))
  local script = f:read("*a")
  f:close()
  eq(script, "svo.pipe_filling(matches[2])", "and passes the pipe's number")
end

-- the player's own smokes and tap-outs, from the live run: svof held 9 puffs
-- after 9 smokes had emptied the pipe, and 10 on a tapped-out one
-- The Smoke trigger is multiline and ends in a one-line spacer, so Mudlet runs
-- its script and its children on the line after the drag line, with the drag
-- line as its first match (review of #906)
local PROMPT = "4926h, 4926m, 21200e, 22106w  exckdb---"
local function smoke_trigger(w, drag)
  w.env.line = PROMPT
  w.env.multimatches = { { drag }, {} }
  w.svo.pipe_smoke_line()
end
local function smoke(w, drag, ...)
  w.env.lastCommands = { ... }
  smoke_trigger(w, drag)
  w.svo.valid.smoke1()
  w.svo.valid.smoke2()
end
local DRAG = "You take a long drag of valerian off your pipe."
local function two_valerian(svo, t)
  local base = { id = 101, id2 = 102, puffs = 5, puffs2 = 5, filledwith = 'valerian', filledwith2 = 'realgar' }
  for k, v in pairs(t or {}) do base[k] = v end
  return set_pipe(svo, 'valerian', base)
end

do -- by ID: that pipe, in either place
  local w = world.new()
  local pipe = two_valerian(w.svo, { filledwith2 = 'valerian' })
  smoke(w, DRAG, "smoke 101")
  eq(pipe.puffs, 4, "own smoke: the pipe it named")
  eq(pipe.puffs2, 5, "own smoke: and not the other")
  smoke(w, DRAG, "smoke 102")
  eq(pipe.puffs2, 4, "own smoke: the second, when that's what it named")
  eq(pipe.puffs, 4, "own smoke: leaving the first")
  for _ = 1, 6 do smoke(w, DRAG, "smoke 101") end
  eq(pipe.puffs, 0, "own smoke: stops at 0")
end

do -- by name: what the line says was smoked
  local w = world.new()
  local pipe = two_valerian(w.svo)
  smoke(w, "You take a long drag of realgar off your pipe.", "smoke realgar")
  eq(pipe.puffs2, 4, "by name: the pipe holding what the line names")
  eq(pipe.puffs, 5, "by name: not the other")
  smoke(w, DRAG)
  eq(pipe.puffs, 4, "with nothing sent: still the line's")
end

do -- an older SMOKE <id> of the same herb's other pipe doesn't decide either,
   -- when the pipes hold different things and the line names one
  local w = world.new()
  local pipe = two_valerian(w.svo)
  smoke(w, DRAG, "look", "kill rat", "smoke 102")
  eq(pipe.puffs, 4, "stale ID of the herb's other pipe: the pipe holding what the line names")
  eq(pipe.puffs2, 5, "stale ID of the herb's other pipe: not the pipe it named")
end

do -- an older SMOKE <id> of another herb doesn't decide
  local GURGLE = "Your draw is accompanied by a deep gurgling sound before a series of shining bubbles erupt from the bowl of your pipe."
  local w = world.new()
  local pipe = two_valerian(w.svo)
  local elm = set_pipe(w.svo, 'elm', { id = 201, puffs = 7, filledwith = 'elm' })
  smoke(w, "You take a long drag of slippery elm off your pipe.", "smoke 101")
  eq(elm.puffs, 6, "stale ID: the line's herb is charged")
  eq(pipe.puffs, 5, "stale ID: not the pipe it named")
  -- nor which of the line's herb's pipes it charges
  smoke(w, "You take a long drag of slippery elm off your pipe.", "smoke 102")
  eq(elm.puffs, 5, "stale ID of a second pipe: still the line's herb's first")
  eq(pipe.puffs2, 5, "stale ID of a second pipe: not the pipe it named")
  -- the line names no herb, so the command does
  smoke(w, GURGLE, "smoke 201")
  eq(elm.puffs, 4, "a line with no herb: the pipe the command named")
  smoke(w, GURGLE, "smoke 999")
  eq(elm.puffs, 4, "a line with no herb and an unknown pipe: nothing")
  -- a pipe svof doesn't track, though the line names a herb it does
  smoke(w, "You take a long drag of slippery elm off your pipe.", "smoke 999")
  eq(elm.puffs, 4, "a line with a herb and an unknown pipe: nothing")
  eq(pipe.puffs + pipe.puffs2, 10, "a line with a herb and an unknown pipe: nor any other pipe")
end

do -- the drag line comes from the trigger's match, not the line it runs on
  local w = world.new()
  local elm = set_pipe(w.svo, 'elm', { id = 201, puffs = 7, filledwith = 'elm' })
  smoke(w, "You take a long drag of slippery elm off your pipe.", "smoke elm")
  eq(elm.puffs, 6, "by name with nothing else to go on: the line's herb")
  w.env.multimatches = {}
  w.env.line = "You take a long drag of slippery elm off your pipe."
  w.svo.pipe_smoke_line()
  w.svo.valid.smoke1()
  w.svo.valid.smoke2()
  eq(elm.puffs, 6, "with no match to read, nothing is counted")
end

do -- counted once
  local w = world.new()
  local svo = w.svo
  local pipe = two_valerian(svo)
  smoke(w, DRAG, "smoke 101")
  svo.valid.smoke1()
  svo.valid.smoke2()
  eq(pipe.puffs, 4, "the children running again count nothing more")

  -- a cure answered it, so its action counts it, not this
  w.env.lastCommands = { "smoke 101" }
  smoke_trigger(w, DRAG)
  svo.smoke_cure = true
  svo.valid.smoke2()
  eq(pipe.puffs, 4, "a cure answered it: nothing here")

  svo.conf.arena = true
  smoke(w, DRAG, "smoke 101")
  eq(pipe.puffs, 4, "the arena counts nothing")
end

do -- a smoke of svof's in flight isn't the player's
  local w = world.new()
  local svo = w.svo
  local pipe = set_pipe(svo, 'elm', { id = 201, puffs = 7, filledwith = 'elm' })
  svo.doaction(svo.dict.aeon.smoke)
  eq(svo.actions.aeon_smoke ~= nil, true, "svof's smoke is in flight")
  smoke(w, "You take a long drag of slippery elm off your pipe.", "smoke 201")
  eq(pipe.puffs, 7, "svof's own smoke doesn't count here")
end

do -- tap-outs
  local w = world.new()
  local svo = w.svo
  local pipe = two_valerian(svo)
  w.env.lastCommands = { "empty 102" }
  svo.valid.pipe_emptied()
  eq(pipe.puffs2, 0, "tap-out: the pipe EMPTY named")
  eq(pipe.puffs, 5, "tap-out: not the other")
  w.env.lastCommands = { "look", "empty 101" }
  svo.valid.pipe_emptied()
  eq(pipe.puffs, 0, "tap-out: the first, when that's what it named")

  pipe.puffs, pipe.puffs2 = 5, 5
  w.env.lastCommands = { "empty 999" }
  svo.valid.pipe_emptied()
  eq(pipe.puffs + pipe.puffs2, 10, "tap-out of an untracked pipe: nothing")
  w.env.lastCommands = { "empty pipe", "empty 101" }
  svo.valid.pipe_emptied()
  eq(pipe.puffs, 5, "the latest EMPTY names no pipe, so an older one doesn't decide")
  w.env.lastCommands = { "smoke 101" }
  svo.valid.pipe_emptied()
  eq(pipe.puffs, 5, "no EMPTY sent: nothing")
end

do -- a fill after a tap-out goes in the empty pipe, whatever the other holds
  local w = world.new()
  local svo = w.svo
  svo.conf.serverside = true
  local pipe = two_valerian(svo, { puffs = 10, puffs2 = 0, filledwith2 = 'realgar' })
  w.env.line = FILLS.valerian[1]
  svo.valid.fillvalerian()
  eq(pipe.puffs2, 10, "own fill: the empty pipe")
  eq(pipe.filledwith2, "valerian", "own fill: holding what the line names")
  eq(pipe.puffs, 10, "own fill: the other is as it was")
end

do -- the Smoke trigger keeps its line for its children
  local f = assert(io.open("src/triggers/svo (aliases, triggers)/svo/General/Smoke.lua", "r"))
  local script = f:read("*a")
  f:close()
  eq(script:find("svo.pipe_smoke_line()", 1, true) ~= nil, true, "the Smoke trigger keeps its line")
end

do -- not serverside, and nothing of svof's in flight: not a fill of svof's
  local w = world.new()
  local svo = w.svo
  svo.conf.serverside = false
  local pipe = set_pipe(svo, 'elm', { id = 101, puffs = 2 })
  w.env.line = FILLS.elm[1]
  svo.valid.fillelm()
  eq(pipe.puffs, 2, "without serverside, a fill line with nothing in flight changes nothing")
end

do -- a puff off the first pipe while it has any
  local w = world.new()
  local svo = w.svo
  local pipe = set_pipe(svo, 'skullcap', { id = 101, id2 = 102, puffs = 3, puffs2 = 5, filledwith = 'skullcap', filledwith2 = 'malachite' })
  w.echoes = {}
  svo.sk.skullcap_smokepuff()
  eq(pipe.puffs, 2, "a puff comes off the first pipe while it has any")
  eq(pipe.puffs2, 5, "and leaves the second")
  eq(table.concat(w.echoes), " (2 skullcap left)", "and says what's left in it")
end

do -- then the second
  local w = world.new()
  local svo = w.svo
  local pipe = set_pipe(svo, 'skullcap', { id = 101, id2 = 102, puffs = 0, puffs2 = 5, filledwith = 'skullcap', filledwith2 = 'malachite' })
  w.echoes = {}
  svo.sk.skullcap_smokepuff()
  eq(pipe.puffs2, 4, "with the first empty, a puff comes off the second")
  eq(table.concat(w.echoes), " (4 malachite left)", "and the label names what the second holds")
end

do -- one pipe, and arena
  local w = world.new()
  local svo = w.svo
  local pipe = set_pipe(svo, 'valerian', { id = 101, id2 = 0, puffs = 0 })
  svo.sk.valerian_smokepuff()
  eq(pipe.puffs, 0, "one pipe at 0 stays at 0")
  svo.conf.arena = true
  pipe.puffs = 3
  svo.sk.valerian_smokepuff()
  eq(pipe.puffs, 3, "and the arena counts nothing")
end

do -- filling the second pipe
  local w = world.new()
  local svo = w.svo
  svo.conf.curemethod = 'conconly'
  svo.rift.invcontents.skullcap, svo.rift.riftcontents.skullcap = 5, 5
  local pipe = set_pipe(svo, 'skullcap', { id = 101, id2 = 102, puffs = 3, puffs2 = 0, filledwith = 'malachite', filledwith2 = 'x' })
  w.sent = {}
  svo.sk.asyncfill('skullcap', 102)
  eq(pipe.filledwith2, 'skullcap', "filling the second pipe names what it holds")
  eq(pipe.filledwith, 'malachite', "and leaves the first one's")
  eq(table.concat(w.sent, "; "), "outr skullcap; put skullcap in 102", "and doesn't empty it for the first one's puffs")
  pipe.filledwith2 = 'x'
  w.sent = {}
  svo.sk.syncfill('skullcap', 102)
  eq(pipe.filledwith2, 'skullcap', "and so does a fill in slow curing")
  eq(table.concat(w.sent, "; "), "put skullcap in 102", "without emptying it")
end

print(string.format("%d checks, %d failures", checks, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
print("ALL PASS")
