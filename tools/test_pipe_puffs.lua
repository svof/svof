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
