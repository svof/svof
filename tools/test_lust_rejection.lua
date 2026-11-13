--[[
Logic-level test of svof's use of the game's CURING REJECTION for lust.

The game's serverside curing rejects every lust it sees except from names
on its whitelist, keeps its switch, whitelist and assumed list across
logins, and only sees a lust when you aren't blacked out (Announce #5524).
That's svof's whitelist mode (vconfig autoreject white), with the lust list
as the whitelist. When serverside has lust (vshow server), svof now:

- turns the game's rejection on in whitelist mode, and off otherwise, so
  in blacklist mode, with autoreject off, or with svof handling lust;
- reads the game's whitelist once a login with WHITELIST SHOW, then adds
  and removes names until it matches the lust list, before turning
  rejection on, as the game asks;
- keeps rejecting itself in blacklist mode, which the game can't do;
- takes a lust off when the game's REJECT gets the reply, which svof
  ignored with anti-illusion on, since svof hadn't sent the REJECT;
- tells the game with ASSUME about a lust it sees in blackout.

This runs the real loaders through tools/svof_world.lua for a Magi and
feeds the game's replies as lines. The replies are the ones captured in
game on 2026-11-13, a whitelist of several names included ("A, B, and
C."). It proves what svof sends and how it reads the replies, not what
the game does with the commands.

Run: lua tools/test_lust_rejection.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local world = dofile("tools/svof_world.lua")

local checks, failures = 0, {}
local function check(desc, ok, detail)
  checks = checks + 1
  if not ok then failures[#failures + 1] = desc .. (detail and (": " .. detail) or "") end
end

-- long enough for svof's sends to go out, and short of the 10 seconds it
-- listens for the game's replies after its last command
local function settle(w)
  for _ = 1, 4 do w.advance(1) end
end

-- svof's sends, as single commands: it batches some into its serverside
-- aliases, "setalias multicmd a/b" and "9multicmd {a}{b}"
local function commands(w, from)
  local out = {}
  for i = from or 1, #w.sent do
    local s = w.sent[i]
    local batch = s:match("^setalias multicmd (.*)$")
    if batch then
      for c in batch:gmatch("[^/]+") do out[#out + 1] = c end
    elseif s:match("^9multicmd ") then
      for c in s:gmatch("{([^}]*)}") do out[#out + 1] = c end
    else
      out[#out + 1] = s
    end
  end
  return out
end

-- the CURING REJECTION commands among them, without the prefix
local function rejections(w, from)
  local out = {}
  for _, c in ipairs(commands(w, from)) do
    local r = c:match("^curing rejection (.*)$")
    if r then out[#out + 1] = r end
  end
  return out
end

local function same(got, want)
  if #got ~= #want then return false end
  for i = 1, #want do if got[i] ~= want[i] then return false end end
  return true
end

local function show(t) return "{" .. table.concat(t, " | ") .. "}" end

-- a Magi on serverside, with svof's own events dispatched to its signals
local function serverside_on(lustlist)
  local w = world.new({ class = "Magi" })
  local recorded = w.env.raiseEvent
  w.env.raiseEvent = function(name, ...)
    recorded(name, ...)
    w.svo.events(name, ...)
  end
  for _, name in ipairs(lustlist or {}) do w.svo.me.lustlist[name] = true end
  w.svo.conf.serverside = true
  w.svo.signals["svo config changed"]:emit("serverside")
  settle(w)
  return w
end

local NOBODY = "You have no people that you will not automatically reject the lust of."

-- ===== svof has lust: the game's rejection goes off =====

do
  local w = serverside_on({ "Alex" })
  check("svof has lust by default", w.svo.serverignore.lovers == false, tostring(w.svo.serverignore.lovers))
  check("serverrejects is false", w.svo.serverrejects() == false)
  check("turning serverside on sends rejection off, and nothing else",
    same(rejections(w), { "off" }), show(rejections(w)))
end

-- ===== serverside has lust: whitelist first, then on =====

do
  local w = serverside_on({ "Alex", "Dana" })
  local from = #w.sent + 1
  w.svo.setserverignore("lovers")
  settle(w)
  check("handing lust to serverside asks for the whitelist first",
    same(rejections(w, from), { "whitelist show" }), show(rejections(w, from)))

  from = #w.sent + 1
  check("the empty whitelist reply is read", w.line(NOBODY) == 1)
  settle(w)
  check("it then adds the lust list and turns rejection on, in that order",
    same(rejections(w, from), { "whitelist add Alex", "whitelist add Dana", "on" }), show(rejections(w, from)))
  check("serverrejects is true", w.svo.serverrejects() == true)

  for _, l in ipairs({ "You add Alex to your rejection whitelist.", "You add Dana to your rejection whitelist.",
    "You will now automatically reject the lust of your enemies." }) do
    check("reply is caught: " .. l, w.line(l) == 1)
  end

  -- a lust list change sends only the difference
  from = #w.sent + 1
  w.svo.me.lustlist.Dana = nil
  w.svo.me.lustlist.Quinn = true
  w.svo.signals["svo config changed"]:emit("lustlist")
  settle(w)
  check("a lust list change adds and removes only the differences",
    same(rejections(w, from), { "whitelist add Quinn", "whitelist remove Dana" }), show(rejections(w, from)))

  -- the game refuses a name it doesn't know
  local echoes = #w.echoes
  check("the refusal is caught", w.line("Add who to your rejection whitelist?") == 1)
  local said = table.concat(w.echoes, "", echoes + 1)
  check("a refused name is reported", said:find("doesn't know Quinn", 1, true) ~= nil, said)
  check("a refused name is dropped from svof's copy of the whitelist", w.svo.sk.rejection.whitelist and
    w.svo.sk.rejection.whitelist.quinn == nil)

  -- listening stops a while after the last command
  for _ = 1, 15 do w.advance(1) end
  check("the replies aren't caught later", w.line("You will now automatically reject the lust of your enemies.") == 0)

  -- nothing changed: nothing is sent
  from = #w.sent + 1
  w.svo.signals["svo config changed"]:emit("lustlist")
  settle(w)
  check("a sync with nothing to change sends nothing", #rejections(w, from) == 0, show(rejections(w, from)))

  -- blacklist mode: the game can't, so off, and svof rejects
  from = #w.sent + 1
  w.svo.conf.autoreject = "black"
  w.svo.signals["svo config changed"]:emit("autoreject")
  settle(w)
  check("blacklist mode turns rejection off", same(rejections(w, from), { "off" }), show(rejections(w, from)))
  check("in blacklist mode svof rejects itself", w.svo.dict.lovers.physical.servercannot() == true)

  -- back to whitelist mode
  from = #w.sent + 1
  w.svo.conf.autoreject = "white"
  w.svo.signals["svo config changed"]:emit("autoreject")
  settle(w)
  check("whitelist mode turns it on again", same(rejections(w, from), { "on" }), show(rejections(w, from)))
  check("in whitelist mode svof leaves it to serverside", w.svo.dict.lovers.physical.servercannot() == false)

  -- autoreject off ignores lust
  from = #w.sent + 1
  w.svo.ignore.lovers = true
  w.svo.signals["svo config changed"]:emit("autoreject")
  settle(w)
  check("autoreject off turns rejection off", same(rejections(w, from), { "off" }), show(rejections(w, from)))
  w.svo.ignore.lovers = nil

  -- a new login reads the whitelist again
  w.svo.signals["svo config changed"]:emit("autoreject")
  settle(w)
  from = #w.sent + 1
  w.svo.setupserverside()
  settle(w)
  local got = rejections(w, from)
  check("a login reads the whitelist again", got[#got] == "whitelist show", show(got))
  from = #w.sent + 1
  w.line("You will not automatically reject the lust of: Alex and Quinn.")
  settle(w)
  check("a login sets the switch once the whitelist is read",
    same(rejections(w, from), { "on" }), show(rejections(w, from)))
end

-- ===== reading a whitelist with names =====

-- the game's form, with a serial comma, and the same without one
for _, form in ipairs({ "Alex, Quinn, and Sam", "Alex, Quinn and Sam" }) do
  local w = serverside_on({ "Alex", "Dana" })
  w.svo.setserverignore("lovers")
  settle(w)
  local from = #w.sent + 1
  w.line("You will not automatically reject the lust of: " .. form .. ".")
  settle(w)
  check("whitelist '" .. form .. "': adds what's missing, removes what isn't on the lust list",
    same(rejections(w, from), { "whitelist add Dana", "whitelist remove Quinn", "whitelist remove Sam", "on" }),
    show(rejections(w, from)))
end

-- ===== the curing loop: serverside rejects, unless it can't =====

local function lusted(w, name)
  w.svo.valid.simplelovers(name)
  w.prompt()
end

local function svof_picks(w)
  local p = w.svo.check_balanceful_acts(true)
  return p and p.action_name or "nothing"
end

do
  local w = serverside_on({})
  w.svo.setserverignore("lovers")
  settle(w)
  w.line(NOBODY)
  settle(w)
  lusted(w, "Alex")
  check("a lust is tracked", w.svo.affs.lovers ~= nil and w.svo.dict.lovers.map.Alex == true)
  check("svof leaves the REJECT to serverside in whitelist mode", svof_picks(w) ~= "lovers", svof_picks(w))
  w.svo.conf.autoreject = "black"
  w.svo.me.lustlist.Alex = true
  check("svof sends the REJECT itself in blacklist mode", svof_picks(w) == "lovers", svof_picks(w))
end

-- ===== serverside's REJECT takes the lust off =====

local function server_rejects(w, name, reply)
  w.svo.curingcommand("REJECT " .. name:upper())
  if reply == "friendship" then
    w.env.multimatches = { { "You reject the friendship of" }, { "You reject the friendship of " .. name .. ".", name } }
    w.svo.valid.cured_lovers()
  else
    w.env.matches = { "Why would you reject " .. name .. "?", name }
    w.svo.valid.cured_lovers_nobody()
  end
  w.prompt()
end

do
  local w = serverside_on({})
  w.svo.setserverignore("lovers")
  settle(w)
  w.svo.conf.aillusion = true
  lusted(w, "Alex")
  lusted(w, "Dana")
  server_rejects(w, "Alex", "friendship")
  check("serverside's REJECT takes that name off", w.svo.dict.lovers.map.Alex == nil)
  check("and leaves the other", w.svo.dict.lovers.map.Dana == true and w.svo.affs.lovers ~= nil)
  server_rejects(w, "Dana", "nobody")
  check("a failed serverside REJECT takes that name off too", w.svo.dict.lovers.map.Dana == nil)
  check("with nobody left, lust is gone", w.svo.affs.lovers == nil)

  -- the reply without a serverside REJECT is still refused with anti-illusion on
  lusted(w, "Alex")
  w.env.multimatches = { { "You reject the friendship of" }, { "You reject the friendship of Alex.", "Alex" } }
  w.svo.valid.cured_lovers()
  w.prompt()
  check("the reply alone, with anti-illusion on, changes nothing", w.svo.dict.lovers.map.Alex == true)
end

-- ===== a lust seen in blackout is passed on =====

do
  local w = serverside_on({})
  w.svo.setserverignore("lovers")
  settle(w)
  w.line(NOBODY)
  settle(w)
  local from = #w.sent + 1
  lusted(w, "Alex")
  settle(w)
  check("outside blackout, serverside sees it itself", #rejections(w, from) == 0, show(rejections(w, from)))
  w.svo.addaffdict(w.svo.dict.blackout)
  from = #w.sent + 1
  lusted(w, "Dana")
  settle(w)
  check("in blackout, svof tells serverside", same(rejections(w, from), { "assume Dana" }), show(rejections(w, from)))
end

do
  local w = serverside_on({})
  w.svo.addaffdict(w.svo.dict.blackout)
  local from = #w.sent + 1
  lusted(w, "Dana")
  settle(w)
  check("in blackout, with svof handling lust, nothing is assumed", #rejections(w, from) == 0, show(rejections(w, from)))
end

-- ===== serverside off: nothing at all =====

do
  local w = world.new({ class = "Magi" })
  w.svo.me.lustlist.Alex = true
  w.svo.serverignore.lovers = true
  w.svo.signals["svo config changed"]:emit("lustlist")
  settle(w)
  check("serverside off: no CURING REJECTION command", #rejections(w) == 0, show(rejections(w)))
end

if #failures == 0 then
  print(("ALL PASS (%d checks)"):format(checks))
else
  for _, f in ipairs(failures) do print("FAIL: " .. f) end
  print(("%d of %d checks failed"):format(#failures, checks))
  os.exit(1)
end
