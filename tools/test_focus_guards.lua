--[[
Logic-level regression test for the focus guards in
`src/scripts/svo (curing skeleton, controllers, action system)/Curing_skeleton.lua`,
`src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua`
and `src/scripts/svo (custom prompt, serverside)/Serverside.lua`.

Same approach as tools/test_latched.lua: the code under test is extracted
from the real source files by anchor text and run in a stub environment, so it
is what ships rather than a reimplementation.

What it pins:

  * svo.focus_would_hurt: cadmus, fulminated and guilt each block a focus
    unless the player chose to risk it with focuswithcadmus,
    focuswithfulminated or focuswithguilt.
  * check_focus asks it, rather than spelling the tests out a second time.
  * the impatience probe, checkimpatience.misc, which sends a bare focus of
    its own: it waits while a focus would hurt. It used to check only focus
    balance and conf.focus, so it could focus while fulminated (paralysis) or
    guilt (a mental affliction) were held with both options off.
  * svo.setupserverside, run at every login: it sends the game the
    focus-with switches, so a player who already had serverside on when the
    options arrived does not keep whatever the game had.
  * svo.lostbal_focus: with whispering madness, after a focus that cured
    one of the ability file's 13 afflictions, or an unknown one, focus
    balance isn't taken as back sooner than 4 seconds plus the network
    latency, the latency capped at 3 seconds.

It proves nothing about Mudlet integration, the game, or real combat.

Run: lua tools/test_focus_guards.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local SKEL = "src/scripts/svo (curing skeleton, controllers, action system)/Curing_skeleton.lua"
local DICT = "src/scripts/svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua"
local SERVER = "src/scripts/svo (custom prompt, serverside)/Serverside.lua"

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return (data:gsub("\r\n", "\n"))
end

local function extract(source, path, start_anchor, end_anchor, keep_end)
  local s = source:find(start_anchor, 1, true)
  if not s then error("start anchor not found in " .. path .. ": " .. start_anchor) end
  local e = source:find(end_anchor, s + #start_anchor, true)
  if not e then error("end anchor not found in " .. path .. ": " .. end_anchor) end
  return source:sub(s, keep_end and (e + #end_anchor - 1) or (e - 1))
end

local skel = read_file(SKEL)
local helper_src = extract(skel, SKEL, "function svo.focus_would_hurt()", "\nend\n", true)
local check_focus_src = extract(skel, SKEL, "svo.check_focus = function(sync_mode)", "\nend\n", true)
local probe_src = extract(read_file(DICT), DICT, "    checkimpatience = {", "    checkasthma = {")
local setup_src = extract(read_file(SERVER), SERVER, "function svo.setupserverside()", "\nend\n", true)
print(string.format("extracted %d, %d, %d and %d bytes of the real helper, check_focus, probe and setupserverside",
  #helper_src, #check_focus_src, #probe_src, #setup_src))

-- Mudlet runs Lua 5.1, where only loadstring() takes a source string and the
-- environment is applied separately via setfenv. Branch on setfenv rather than
-- on a version string so this runs under either.
local function run(code, name, env)
  local chunk, err
  if setfenv then
    chunk, err = loadstring(code, name)
    if chunk then setfenv(chunk, env) end
  else
    chunk, err = load(code, name, "t", env)
  end
  if not chunk then error("could not load " .. name .. ": " .. tostring(err)) end
  return chunk()
end

local checks, failures = 0, 0
local function check(desc, got, want)
  checks = checks + 1
  if got ~= want then
    failures = failures + 1
    print(string.format("FAIL %s: got %s, want %s", desc, tostring(got), tostring(want)))
  end
end

-- One stub world: affs and conf are what the code under test reads.
local function world()
  local w = { affs = {}, conf = { focus = true }, sent = {}, focuswith = 0 }
  local svo = { affsp = {}, sk = {} }
  w.env = {
    svo = svo, affs = w.affs, conf = w.conf, sk = svo.sk,
    bals = { focus = true }, stats = { currentwillpower = 1000 },
    next = next, pairs = pairs,
  }
  run(helper_src, "focus_would_hurt", w.env)
  w.probe = run("return {\n" .. probe_src .. "\n}", "checkimpatience", w.env).checkimpatience.misc
  w.svo = svo
  return w
end

-- the helper: each affliction blocks, unless its option is on
for _, case in ipairs({
  {'cadmus', 'focuswithcadmus'},
  {'fulminated', 'focuswithfulminated'},
  {'guilt', 'focuswithguilt'},
}) do
  local aff, option = case[1], case[2]
  local w = world()
  check("nothing held: focus does not hurt", w.svo.focus_would_hurt(), false)
  w.affs[aff] = true
  check(aff .. " held, " .. option .. " off: focus hurts", w.svo.focus_would_hurt(), true)
  w.conf[option] = true
  check(aff .. " held, " .. option .. " on: focus does not hurt", w.svo.focus_would_hurt(), false)
end

do -- an unrelated affliction does not block
  local w = world()
  w.affs.stupidity = true
  check("stupidity alone: focus does not hurt", w.svo.focus_would_hurt(), false)
end

-- check_focus asks the helper rather than testing the afflictions itself
check("check_focus calls svo.focus_would_hurt", check_focus_src:find("svo.focus_would_hurt()", 1, true) ~= nil, true)
-- (its loop still reads affs.cadmus: with focuswithcadmus on, it focuses only
-- for the afflictions cadmus allows, a separate rule)
for _, case in ipairs({{'cadmus', 'focuswithcadmus'}, {'fulminated', 'focuswithfulminated'}, {'guilt', 'focuswithguilt'}}) do
  local by_hand = "(affs." .. case[1] .. " and not conf." .. case[2] .. ")"
  check("check_focus does not test " .. by_hand .. " by hand",
    check_focus_src:find(by_hand, 1, true) == nil, true)
end

-- the impatience probe
do
  local w = world()
  w.svo.affsp.impatience = true
  check("probe: suspected impatience, nothing held: probe", w.probe.isadvisable(), true)
  for _, case in ipairs({
    {'fulminated', 'focuswithfulminated'},
    {'guilt', 'focuswithguilt'},
    {'cadmus', 'focuswithcadmus'},
  }) do
    local aff, option = case[1], case[2]
    w.affs[aff] = true
    check("probe: " .. aff .. " held, " .. option .. " off: waits", w.probe.isadvisable(), false)
    w.conf[option] = true
    check("probe: " .. aff .. " held, " .. option .. " on: probes", w.probe.isadvisable(), true)
    w.affs[aff], w.conf[option] = nil, nil
  end
  w.svo.affsp.impatience = nil
  check("probe: no suspected impatience: no probe", w.probe.isadvisable(), false)
end

-- setupserverside at login
do
  local function login(serverside)
    local w = world()
    w.conf.serverside = serverside
    w.svo.sendc = function(c) w.sent[#w.sent + 1] = c end
    w.svo.getping = function() return 0.1 end
    w.svo.sk.sendfocuswith = function(only) w.focuswith = w.focuswith + 1 w.only = only end
    w.env.tempTimer = function() return 1 end
    w.env.killTimer = function() end
    run(setup_src, "setupserverside", w.env)
    w.svo.setupserverside()
    return w
  end
  local w = login(true)
  check("login with serverside: both focus-with switches sent once", w.focuswith, 1)
  check("login with serverside: sent for both, not one", w.only, nil)
  check("login with serverside: curing sets still created", w.sent[1], "curingset new normal")
  w = login(false)
  check("login without serverside: nothing sent", w.focuswith, 0)
end

-- The wait before svof takes focus balance as back without the game's
-- line. Whispering madness slows focusing its afflictions to about 4
-- seconds, and the line can come later under lag
do
  local lostbal_src = extract(skel, SKEL, "svo.madness_slows_focus = {", "\nend\n", true)
  local function wait(held, latency, cured)
    local w = world()
    local timeout
    for _, aff in ipairs(held) do w.affs[aff] = true end
    w.conf.ai_resetfocusbal = 5
    w.env.sk.focustick = 0
    w.env.svo.startbalancewatch = function() end
    w.env.tempTimer = function(t) timeout = t end
    w.env.raiseEvent = function() end
    w.env.getNetworkLatency = function() return latency end
    w.env.math = math
    run(lostbal_src, "lostbal_focus", w.env)
    w.env.svo.lostbal_focus(cured)
    return timeout
  end
  check("focus balance: back after 5s", wait({}, 2, 'stupidity'), 5)
  check("focus balance: madness with little lag keeps the 5s", wait({ 'madness' }, 0.3, 'stupidity'), 5)
  check("focus balance: madness under 2s of lag waits 4s and the lag", wait({ 'madness' }, 2, 'stupidity'), 6)
  check("focus balance: rixil's longer wait stays", wait({ 'madness', 'rixil' }, 0.3, 'stupidity'), 8)
  -- only the ability file's 13 are slowed, vertigo included in AFFLICTION
  -- SHOW's WhisperingMadness but not in the ability file
  check("focus balance: madness, dizziness cured: no madness wait", wait({ 'madness' }, 2, 'dizziness'), 5)
  check("focus balance: madness, vertigo cured: no madness wait", wait({ 'madness' }, 2, 'vertigo'), 5)
  check("focus balance: madness, cure unknown: madness wait", wait({ 'madness' }, 2), 6)
  -- one lag spike can't stall focus more than 3s past the 4
  check("focus balance: madness, a 9.9s reading counts as 3s", wait({ 'madness' }, 9.9, 'paranoia'), 7)
end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then print("FAILED") os.exit(1) end
print("ALL PASS")
