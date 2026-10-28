-- Step 0: svof's own data for the afflictions it knows, against the game's
-- AFFLICTION SHOW record (the 2026-10-21 capture). Run from C:\work\svof-affs.
-- Prints one line per difference, by kind, and a summary.
local world = dofile("tools/svof_world.lua")
local w = world.new()
local svo = w.svo
local cap = dofile("C:/work/svof/claude-notes/reference/affliction_show.lua")

-- the place svof applies a salve to, by running its onstart with apply stubbed
local function salve_place(entry)
  local place
  local real = svo.apply
  svo.apply = function(_, where) place = where end
  pcall(entry.salve.onstart)
  svo.apply = real
  return place and place:match("to (%a+)") or nil
end

local tree = {}
for _, n in ipairs(svo.empty.treecurables or {}) do tree[n] = true end

local out, counts = {}, {}
local function say(kind, n, s, msg)
  counts[kind] = (counts[kind] or 0) + 1
  out[#out + 1] = string.format("%-10s %-22s %s", kind, n .. (s ~= n and (" (" .. s .. ")") or ""), msg)
end

local names = {}
for n in pairs(cap) do names[#names + 1] = n end
table.sort(names)
local known = 0
for _, n in ipairs(names) do
  local r = cap[n]
  local mapped = svo.dict.sstosvoa[n]
  local s = type(mapped) == 'string' and mapped or (svo.dict[n] and n) or nil
  local entry = s and svo.dict[s]
  if type(entry) == 'table' and entry.aff then
    known = known + 1
    -- the game's cures, every route
    local game = { herb = {}, smoke = {}, purgative = {}, salve = {}, other = {} }
    local timecure = false
    for _, route in ipairs(r["Cure(s)"] or {}) do
      for _, c in ipairs(svo.affcures(route) or {}) do
        if c.kind == 'time' then timecure = true
        elseif c.kind == 'game' then game.other[#game.other + 1] = c[1]
        else game[c.kind][#game[c.kind] + 1] = c end
      end
    end
    local function list(t) return t and table.concat(t, "/") or "none" end
    -- herbs
    local svherb = entry.herb and entry.herb.eatcure
    local gherb = game.herb[1]
    if gherb and not svherb then say("herb", n, s, "game: eat " .. gherb[1] .. "; svof: no herb cure")
    elseif svherb and not gherb then say("herb", n, s, "svof: eat " .. list(svherb) .. "; game: no herb cure")
    elseif gherb and svherb[1] ~= gherb[1] then say("herb", n, s, "game: eat " .. gherb[1] .. "; svof: eat " .. list(svherb)) end
    -- smoke
    local svsmoke = entry.smoke and entry.smoke.smokecure
    local gsmoke = game.smoke[1]
    if gsmoke and not svsmoke then say("smoke", n, s, "game: smoke " .. gsmoke[1] .. "; svof: no smoke cure")
    elseif svsmoke and not gsmoke then say("smoke", n, s, "svof: smoke " .. list(svsmoke) .. "; game: no smoke cure")
    elseif gsmoke and svsmoke[1] ~= gsmoke[1] then say("smoke", n, s, "game: smoke " .. gsmoke[1] .. "; svof: smoke " .. list(svsmoke)) end
    -- cure elixirs
    local svp = entry.purgative and entry.purgative.sipcure
    local gp = game.purgative[1]
    if gp and not svp then say("elixir", n, s, "game: sip " .. gp[1] .. "; svof: no elixir cure")
    elseif svp and not gp then say("elixir", n, s, "svof: sip " .. list(svp) .. "; game: no elixir cure")
    elseif gp and svp[1] ~= gp[1] then say("elixir", n, s, "game: sip " .. gp[1] .. "; svof: sip " .. list(svp)) end
    -- salves, and where
    local svs = entry.salve and entry.salve.applycure
    local gs = game.salve[1]
    if gs and not svs then say("salve", n, s, "game: apply " .. gs[1] .. (gs.place and (" to " .. gs.place) or "") .. "; svof: no salve cure")
    elseif svs and not gs then say("salve", n, s, "svof: apply " .. list(svs) .. "; game: no salve cure")
    elseif gs then
      local place = salve_place(entry)
      if svs[1] ~= gs[1] then say("salve", n, s, "game: apply " .. gs[1] .. "; svof: apply " .. list(svs)) end
      if (gs.place or place) and gs.place ~= place then
        say("place", n, s, "game: to " .. tostring(gs.place) .. "; svof: to " .. tostring(place))
      end
    end
    -- the game's other cures (focus, writhe, sip health...), against svof's other balances
    local others = {}
    for _, b in ipairs({ "focus", "sip", "physical", "misc", "waitingfor" }) do if entry[b] then others[#others + 1] = b end end
    local gfocus = false
    for _, o in ipairs(game.other) do if o == "focus mind" or o == "focus" then gfocus = true end end
    if gfocus and not entry.focus then say("focus", n, s, "game: focus; svof: no focus cure")
    elseif entry.focus and not gfocus then say("focus", n, s, "svof: focus; game: no focus cure") end
    local rest = {}
    for _, o in ipairs(game.other) do if o ~= "focus mind" and o ~= "focus" then rest[#rest + 1] = o end end
    if #rest > 0 then say("other", n, s, "game: " .. table.concat(rest, ", ") .. "; svof balances: " .. table.concat(others, ",")) end
    -- time
    local dtime = r["Default time"] and r["Default time"][1]
    if timecure then
      local wait = entry.waitingfor and entry.waitingfor.customwait
      say("time", n, s, "game: Time" .. (dtime and (", " .. dtime) or ", no default") .. "; svof: "
        .. (wait and ("waitingfor " .. tostring(wait) .. "s") or "no waitingfor"))
    end
    -- random cures
    local norandom = r["NoRandomCure"] and r["NoRandomCure"][1] == "Yes"
    if norandom and tree[s] then say("random", n, s, "game: no random cure; svof: tree cures it")
    elseif not norandom and not tree[s] then say("random", n, s, "game: random cures take it; svof: not tree-curable") end
  end
end

for _, l in ipairs(out) do print(l) end
print(string.format("\n%d of %d afflictions svof knows", known, #names))
local kinds = {}
for k in pairs(counts) do kinds[#kinds + 1] = k end
table.sort(kinds)
for _, k in ipairs(kinds) do print(string.format("  %-8s %d", k, counts[k])) end
