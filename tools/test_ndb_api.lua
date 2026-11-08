--[[
Logic-level test for NameDB's Achaea API lookups:
`src/scripts/svo (namedb)/NameDB/ndb.downloaded_file.lua` (the queue, the
parser, the download handlers and the online poll) and `ndb.apievents.lua`
(what feeds names to it), plus ndb.updatebyhonors and ndb.honors_next from
`ndb_main_code.lua`, which make HONORS the second step after the API.

The two API files run whole, and the two honours functions are extracted by
anchor text, all in a stub Mudlet: downloadFile records requests, the test
answers them through ndb.downloaded_file, tempTimer timers fire when the test
says so, and the database is a table. So it is what ships, and it proves
nothing about Mudlet's download events, the game or the API itself. The
replies are shaped like real ones from api.achaea.com (2026-11-07), with
invented names.

Run: lua tools/test_ndb_api.lua
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
]]

local DIR = "src/scripts/svo (namedb)/NameDB/"

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then error("cannot open " .. path .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  return (data:gsub("\r\n", "\n"))
end

local function extract(source, start_anchor, path)
  local s = source:find(start_anchor, 1, true)
  local e = s and source:find("\nend\n", s, true)
  if not (s and e) then error(start_anchor .. " not found in " .. path .. " - update this test's anchor") end
  return source:sub(s, e + 4)
end

local apisrc = read_file(DIR .. "ndb.downloaded_file.lua")
local eventsrc = read_file(DIR .. "ndb.apievents.lua")
local mainsrc = read_file(DIR .. "ndb_main_code.lua")
local honorsblock = extract(mainsrc, "function ndb.updatebyhonors()", DIR .. "ndb_main_code.lua")
  .. extract(mainsrc, "function ndb.honors_next(argument)", DIR .. "ndb_main_code.lua")

-- Mudlet's own string:title
function string.title(self) return (self:gsub("^%l", string.upper, 1)) end

-- A small JSON reader, enough for the API's replies.
local function json_decode(s)
  local pos = 1
  local function ws() pos = s:find("[^ \t\r\n]", pos) or #s + 1 end
  local value
  local function str()
    local out = {}
    pos = pos + 1
    while true do
      local c = s:sub(pos, pos)
      if c == "" then error("unterminated string") end
      if c == '"' then pos = pos + 1 break end
      if c == "\\" then
        local e = s:sub(pos + 1, pos + 1)
        out[#out + 1] = ({n = "\n", t = "\t", r = "\r", b = "\b", f = "\f"})[e] or e
        pos = pos + 2
      else
        out[#out + 1] = c
        pos = pos + 1
      end
    end
    return table.concat(out)
  end
  function value()
    ws()
    local c = s:sub(pos, pos)
    if c == "{" then
      local t = {}
      pos = pos + 1
      ws()
      if s:sub(pos, pos) == "}" then pos = pos + 1 return t end
      while true do
        ws()
        local k = str()
        ws()
        if s:sub(pos, pos) ~= ":" then error("expected : at " .. pos) end
        pos = pos + 1
        t[k] = value()
        ws()
        local d = s:sub(pos, pos)
        pos = pos + 1
        if d == "}" then return t end
        if d ~= "," then error("expected , or } at " .. pos) end
      end
    elseif c == "[" then
      local t = {}
      pos = pos + 1
      ws()
      if s:sub(pos, pos) == "]" then pos = pos + 1 return t end
      while true do
        t[#t + 1] = value()
        ws()
        local d = s:sub(pos, pos)
        pos = pos + 1
        if d == "]" then return t end
        if d ~= "," then error("expected , or ] at " .. pos) end
      end
    elseif c == '"' then
      return str()
    elseif s:find("^true", pos) then pos = pos + 4 return true
    elseif s:find("^false", pos) then pos = pos + 5 return false
    elseif s:find("^null", pos) then pos = pos + 4 return nil
    else
      local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
      if not num or num == "" then error("bad JSON at " .. pos) end
      pos = pos + #num
      return tonumber(num)
    end
  end
  local v = value()
  ws()
  if pos <= #s then error("trailing JSON at " .. pos) end
  return v
end

local checks, failures = 0, {}
local function ok(cond, label)
  checks = checks + 1
  if not cond then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual))
  end
end

-- Replies shaped like the API's, names invented.
local function reply(fields)
  local base = {name = "", fullname = "", city = "", house = "", level = "", class = "",
    mob_kills = "", player_kills = "", xp_rank = "", explorer_rank = ""}
  for k, v in pairs(fields) do base[k] = v end
  local order = {"name", "fullname", "city", "house", "level", "class", "mob_kills", "player_kills", "xp_rank", "explorer_rank"}
  local parts = {}
  for _, k in ipairs(order) do parts[#parts + 1] = string.format('"%s":"%s"', k, base[k]) end
  return "{" .. table.concat(parts, ",") .. "}"
end
local GOD = reply({name = "Testgod", fullname = "Testgod, the Unmaker"})
local GUIDE = reply({name = "Testguide", fullname = "Testguide, the Guide", city = "(none)", house = "(none)",
  level = "94", mob_kills = "457", player_kills = "0", xp_rank = "0", explorer_rank = "1161"})
local function mortal(name, extra)
  local f = {name = name, fullname = "Sir " .. name .. ", Tester", city = "eleusis", house = "savants",
    level = "157", class = "serpent", mob_kills = "1086k", player_kills = "4389", xp_rank = "12", explorer_rank = "93"}
  for k, v in pairs(extra or {}) do f[k] = v end
  return reply(f)
end

-- One fresh stub world, with the real files loaded into it.
local function world()
  local w = {now = 1000000, timers = {}, nexttimer = 0, requests = {}, files = {}, events = {},
    echoes = {}, people = {}, honored = {}}

  local function load_into(src, name, env)
    local chunk, err
    if setfenv then
      chunk, err = loadstring(src, name)
      if chunk then setfenv(chunk, env) end
    else
      chunk, err = load(src, name, "t", env)
    end
    if not chunk then error("could not load " .. name .. ": " .. tostring(err)) end
    chunk()
  end

  local people = w.people
  local dbstub = {}
  function dbstub:eq(field, value) return {field = field, value = value} end
  function dbstub:merge_unique(_, list)
    for _, rec in ipairs(list) do
      local row = people[rec.name]
      if not row then
        row = {name = rec.name, city = "rogue", immortal = 0, xp_rank = -1, api_checked = 0}
        people[rec.name] = row
      end
      for k, v in pairs(rec) do row[k] = v end
    end
  end
  function dbstub:fetch() -- every non-immortal with xp_rank -1, which is all updatebyhonors asks for
    local rows = {}
    for _, row in pairs(people) do
      if row.immortal ~= 1 and row.xp_rank == -1 then rows[#rows + 1] = row end
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    return rows
  end
  function dbstub:AND() end
  function dbstub:not_eq() end
  function dbstub:delete() end

  local svo = {conf = {ndbapi = true}, me = {name = "Myself"}, bals = {equilibrium = true}}
  function svo.echof(fmt, ...) w.echoes[#w.echoes + 1] = string.format(fmt, ...) end
  function svo.echofn(fmt, ...) w.echoes[#w.echoes + 1] = string.format(fmt, ...) end
  function svo.oneconcat(t) local k = {} for n in pairs(t) do k[#k + 1] = n end table.sort(k) return table.concat(k, ", ") end
  svo.getDefaultColorNums = {0, 0, 0}

  local ndb = {db = {people = {api_checked = "api_checked", name = "name", immortal = "immortal", xp_rank = "xp_rank"}}}
  function ndb.getname(name) return people[name] end
  function ndb.exists(name) return people[name] ~= nil end
  function ndb.fixed_set(field, value, query) if people[query.value] then people[query.value][field] = value end end
  function ndb.honors(name) w.honored[#w.honored + 1] = name end
  function ndb.showhonorswindow() end

  local gmcp = {}
  local env = {
    ndb = ndb, svo = svo, gmcp = gmcp, db = dbstub,
    getMudletHomeDir = function() return "C:/home" end,
    lfs = {attributes = function() return true end, mkdir = function() end},
    tempTimer = function(seconds, fn)
      w.nexttimer = w.nexttimer + 1
      w.timers[w.nexttimer] = {at = w.now + seconds, fn = fn, seconds = seconds}
      return w.nexttimer
    end,
    killTimer = function(id) w.timers[id] = nil end,
    downloadFile = function(file, url) w.requests[#w.requests + 1] = {file = file, url = url} end,
    raiseEvent = function(...) w.events[#w.events + 1] = table.concat({...}, "|") end,
    yajl = {to_value = json_decode},
    io = {open = function(file)
      local content = w.files[file]
      if not content then return nil end
      return {read = function() return content end, close = function() end}
    end},
    os = {time = function() return w.now end, remove = function(file) w.files[file] = nil end},
    echo = function() end, setFgColor = function() end, setUnderline = function() end, echoLink = function() end,
    seconds2human = function(s) return 0, 0, s end,
    table = setmetatable({size = function(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end},
      {__index = table}),
    unpack = unpack or table.unpack,
  }
  setmetatable(env, {__index = _G})
  load_into(apisrc, "ndb.downloaded_file", env)
  load_into(eventsrc, "ndb.apievents", env)
  load_into(honorsblock, "honors functions", env)

  w.ndb, w.svo, w.gmcp, w.api = ndb, svo, gmcp, ndb.api

  -- the requests not answered yet, as names (or "online")
  function w.pending()
    local out = {}
    for slot, entry in pairs(ndb.api.inflight) do
      out[#out + 1] = slot:match("/([%w]+)%.json$")
    end
    table.sort(out)
    return table.concat(out, ",")
  end
  function w.file(name) return "C:/home/svo/namedb/api/" .. name .. ".json" end
  function w.answer(name, body)
    w.files[w.file(name)] = body
    ndb.downloaded_file("sysDownloadDone", w.file(name))
  end
  function w.fail(name, message)
    ndb.downloaded_file("sysDownloadError", message, w.file(name))
  end
  -- fires the timer that holds lookups back, if any
  function w.resume()
    local id = ndb.api.resume
    if not id or not w.timers[id] then return false end
    local t = w.timers[id]
    w.timers[id] = nil
    w.now = t.at
    t.fn()
    return true
  end
  function w.requested(url_part)
    local n = 0
    for _, r in ipairs(w.requests) do if r.url:find(url_part, 1, true) then n = n + 1 end end
    return n
  end
  return w
end

-- 1. The parser on each kind of reply.
do
  local w = world()
  local rec = w.ndb.api_record("Testgod", json_decode(GOD))
  eq(rec.immortal, 1, "a god (empty level) is immortal")
  eq(rec.title, "Testgod, the Unmaker", "and keeps the full title")
  eq(rec.city, nil, "and gets no city from a reply that has none")

  rec = w.ndb.api_record("Testguide", json_decode(GUIDE))
  eq(rec.immortal, 1, "a Guide (no class, \"<name>, the Guide\") is immortal")

  local hidden
  rec, hidden = w.ndb.api_record("Testmortal", json_decode(mortal("Testmortal")))
  eq(rec.immortal, nil, "a mortal's reply leaves immortal alone")
  eq(rec.city, "Eleusis", "city is title-cased")
  eq(rec.guild, "Savants", "house is title-cased")
  eq(rec.class, "serpent", "class is kept lower-case")
  eq(rec.level, 157, "level is a number")
  eq(rec.dragon, 1, "a level over 98 is a dragon")
  eq(rec.xp_rank, nil, "xp_rank is never written: it marks who HONORS hasn't seen")
  eq(rec.api_checked, w.now, "the lookup time is recorded")
  eq(hidden, false, "a city given isn't hidden")

  rec = w.ndb.api_record("Testmortal", json_decode(mortal("Testmortal", {level = "60"})))
  eq(rec.dragon, 0, "a level under 99 isn't a dragon")

  rec, hidden = w.ndb.api_record("Testmortal", json_decode(mortal("Testmortal", {city = "(hidden)", house = "(hidden)"})))
  eq(rec.city, nil, "a hidden city leaves the known city alone")
  eq(rec.guild, nil, "a hidden house leaves the known house alone")
  eq(hidden, true, "and is reported as hidden")

  rec = w.ndb.api_record("Testmortal", json_decode(mortal("Testmortal", {city = "(none)", house = "(none)"})))
  eq(rec.city, "rogue", "no city is a rogue")
  eq(rec.guild, "", "no house clears the house")

  rec = w.ndb.api_record("Testmortal", json_decode(mortal("Testmortal", {city = "underworld"})))
  eq(rec.city, "Undead", "the underworld is the Undead")

  rec = w.ndb.api_record("Testmortal", json_decode(mortal("Testmortal", {fullname = "Testmortal, the Guide"})))
  eq(rec.immortal, nil, "a player titled the Guide, with a class, stays mortal")
end

-- 2. The queue: four in flight, the rest wait, one answer starts the next.
do
  local w = world()
  local names = {"Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot"}
  for _, n in ipairs(names) do w.ndb.lookup(n) end
  eq(#w.requests, 4, "six lookups send four requests at once")
  eq(w.pending(), "Alpha,Bravo,Charlie,Delta", "the first four, in order")
  w.answer("Alpha", mortal("Alpha"))
  eq(#w.requests, 5, "an answer starts the next")
  eq(w.pending(), "Bravo,Charlie,Delta,Echo", "which is the fifth")
  eq(w.people.Alpha and w.people.Alpha.city, "Eleusis", "the answer is merged into the database")
  eq(w.people.Alpha.xp_rank, -1, "and leaves xp_rank at -1 for HONORS")
  ok(w.events[#w.events] == "NameDB got API data|Alpha", "and raises NameDB got API data with the name")
  for _, n in ipairs({"Bravo", "Charlie", "Delta", "Echo"}) do w.answer(n, mortal(n)) end
  w.answer("Foxtrot", mortal("Foxtrot"))
  eq(#w.requests, 6, "every name is asked about exactly once")
  eq(w.pending(), "", "and nothing is left in flight")
end

-- 3. Asking twice, freshness, force, and names that aren't names.
do
  local w = world()
  w.ndb.lookup("Alpha")
  w.ndb.lookup("alpha")
  eq(#w.requests, 1, "a name waiting or in flight isn't asked about twice, whatever its case")
  w.answer("Alpha", mortal("Alpha"))
  w.ndb.lookup("Alpha")
  eq(#w.requests, 1, "a name looked up today isn't asked about again")
  w.ndb.lookup("Alpha", true)
  eq(#w.requests, 2, "unless forced")
  w.answer("Alpha", mortal("Alpha"))
  w.now = w.now + 25 * 60 * 60
  w.ndb.lookup("Alpha")
  eq(#w.requests, 3, "and a day later it is asked about again")
  w.answer("Alpha", mortal("Alpha"))

  for _, bad in ipairs({"Al", "Two words", "x1", "", "Myself", "Aine, the Sheriff"}) do w.ndb.lookup(bad) end
  w.ndb.lookup(nil)
  w.ndb.lookup({})
  eq(#w.requests, 3, "short names, several words, non-letters, nothing and yourself aren't asked about")

  w.svo.conf.ndbapi = false
  w.ndb.lookup("Bravo")
  eq(#w.requests, 3, "with vconfig ndbapi off nothing is asked")
end

-- 4. "Character not found" is an answer, not an outage.
do
  local w = world()
  w.people.Gone = {name = "Gone", city = "rogue", immortal = 0, xp_rank = -1, api_checked = 0}
  w.ndb.lookup("Gone")
  w.ndb.lookup("Nobody")
  w.fail("Gone", "Error transferring http://api.achaea.com/characters/Gone.json - server replied: Forbidden")
  w.fail("Nobody", "Error transferring http://api.achaea.com/characters/Nobody.json - server replied: Forbidden")
  eq(w.api.errors, 0, "a 403 doesn't count as an error")
  eq(w.api.resume, nil, "and doesn't hold lookups back")
  eq(w.people.Gone.api_checked, w.now, "a known name is marked as checked")
  eq(w.people.Nobody, nil, "an unknown one isn't added to the database")
  w.ndb.lookup("Gone")
  w.ndb.lookup("Nobody")
  eq(#w.requests, 2, "neither is asked about again the same day")
end

-- 5. Outages back off, count once per pause, and stop after five.
do
  local w = world()
  for _, n in ipairs({"Alpha", "Bravo", "Charlie", "Delta", "Echo"}) do w.ndb.lookup(n) end
  w.fail("Alpha", "Connection refused")
  eq(w.api.errors, 1, "a failure counts")
  ok(w.api.resume ~= nil, "and holds lookups back")
  eq(w.timers[w.api.resume] and w.timers[w.api.resume].seconds, 30, "for 30 seconds the first time")
  w.fail("Bravo", "Connection refused")
  w.fail("Charlie", "Connection refused")
  eq(w.api.errors, 1, "failures during the pause don't count again")
  w.ndb.lookup("Foxtrot")
  eq(#w.requests, 4, "nothing new is sent during the pause")

  local waits = {30}
  for round = 2, 4 do
    w.resume()
    local victim = w.pending():match("^(%w+)")
    w.fail(victim, "Connection refused")
    waits[#waits + 1] = w.timers[w.api.resume] and w.timers[w.api.resume].seconds
  end
  eq(table.concat(waits, ","), "30,60,120,240", "each pause doubles")
  w.resume()
  w.fail(w.pending():match("^(%w+)"), "Connection refused")
  eq(w.api.stopped, true, "the fifth failure in a row stops lookups")
  ok(#w.echoes == 1 and w.echoes[1]:find("5 times in a row", 1, true), "and says so once")
  local before = #w.requests
  w.ndb.lookup("Golf")
  eq(#w.requests, before, "so new lookups are ignored")

  w.ndb.apievents("gmcp.Char.Name")
  eq(w.api.stopped, nil, "logging in again lets lookups start over")
  eq(w.api.errors, 0, "with the error count cleared")
end

-- 6. A request that never finishes is given up, and a success clears the count.
do
  local w = world()
  w.ndb.lookup("Alpha")
  local entry = w.api.inflight[w.file("Alpha")]
  ok(entry and w.timers[entry.timer], "each request has a timeout")
  local t = w.timers[entry.timer]
  w.timers[entry.timer] = nil
  t.fn()
  eq(w.pending(), "", "a timeout frees the slot")
  eq(w.api.errors, 1, "and counts as a failure")
  w.resume()
  eq(w.pending(), "Alpha", "the name is asked about again after the pause")
  w.answer("Alpha", mortal("Alpha"))
  eq(w.api.errors, 0, "a good answer clears the error count")

  w.ndb.lookup("Bravo")
  w.answer("Bravo", "<!DOCTYPE html><html>Internal error</html>")
  eq(w.api.errors, 1, "a reply that isn't JSON counts as a failure")
end

-- 7. Downloads that aren't NameDB's are left alone.
do
  local w = world()
  w.ndb.lookup("Alpha")
  w.files["C:/home/other.mpackage"] = "zip"
  w.ndb.downloaded_file("sysDownloadDone", "C:/home/other.mpackage")
  w.ndb.downloaded_file("sysDownloadError", "Not Found", "C:/home/other.mpackage")
  eq(w.files["C:/home/other.mpackage"], "zip", "another package's file isn't read or removed")
  eq(w.pending(), "Alpha", "and NameDB's own request is untouched")
  eq(w.api.errors, 0, "and nothing counts as an error")
  w.files["C:\\home\\svo\\namedb\\api\\Alpha.json"] = mortal("Alpha")
  w.ndb.downloaded_file("sysDownloadDone", "C:\\home\\svo\\namedb\\api\\Alpha.json")
  eq(w.pending(), "", "a path with backslashes still matches its request")
  eq(w.people.Alpha and w.people.Alpha.city, "Eleusis", "and its reply is read")
end

-- 8. The hourly ceiling.
do
  local w = world()
  w.api.hourlycap = 3
  for _, n in ipairs({"Alpha", "Bravo", "Charlie", "Delta"}) do w.ndb.lookup(n) end
  eq(#w.requests, 3, "no more than the ceiling is sent in an hour")
  ok(w.echoes[1] and w.echoes[1]:find("this hour", 1, true), "and NameDB says it's waiting")
  for _, n in ipairs({"Alpha", "Bravo", "Charlie"}) do w.answer(n, mortal(n)) end
  eq(#w.requests, 3, "answers don't get round it")
  w.resume()
  eq(#w.requests, 4, "the next hour carries on")
  eq(#w.echoes, 1, "and the message was given once")
end

-- 9. Login starts the poll of who is online; the poll looks up who isn't fresh.
do
  local w = world()
  w.ndb.apievents("gmcp.Char.Name")
  local start
  for id, t in pairs(w.timers) do if t.seconds == 5 then start = id end end
  ok(start, "login waits a moment before the first poll")
  local t = w.timers[start]
  w.timers[start] = nil
  t.fn()
  eq(w.requested("characters.json"), 1, "then fetches who is online")
  local repeats = 0
  for _, tm in pairs(w.timers) do if tm.seconds == 600 then repeats = repeats + 1 end end
  eq(repeats, 1, "and schedules the next poll in ten minutes")

  w.people.Fresh = {name = "Fresh", city = "Eleusis", immortal = 0, xp_rank = -1, api_checked = w.now}
  w.answer("online", '{"count":3,"characters":[{"uri":"https://api.achaea.com/characters/alpha.json","name":"Alpha"},'
    .. '{"uri":"https://api.achaea.com/characters/fresh.json","name":"Fresh"},'
    .. '{"uri":"https://api.achaea.com/characters/bravo.json","name":"Bravo"}]}')
  eq(w.pending(), "Alpha,Bravo", "everyone online who wasn't checked today is looked up")
  ok(w.api.seen.Fresh, "and the fresh one still counts as seen this session")

  w.api.poll()
  eq(w.requested("characters.json"), 2, "the next poll asks again")
  w.api.poll()
  eq(w.requested("characters.json"), 2, "but not while the last one is still in flight")
  w.answer("online", '{"count":0,"characters":[]}')
  w.ndb.apievents("sysDisconnectionEvent")
  w.api.poll()
  eq(w.requested("characters.json"), 2, "and not while disconnected")
end

-- 10. The people the game shows you.
do
  local w = world()
  w.gmcp.Room = {Players = {{name = "Alpha", fullname = "Alpha the Tester"}, {name = "Myself", fullname = "Me"}}}
  w.ndb.apievents("gmcp.Room.Players")
  w.gmcp.Room.AddPlayer = {name = "Bravo", fullname = "Bravo the Tester"}
  w.ndb.apievents("gmcp.Room.AddPlayer")
  w.gmcp.Comm = {Channel = {Text = {channel = "ct", talker = "Charlie", text = "hi"}}}
  w.ndb.apievents("gmcp.Comm.Channel.Text")
  w.ndb.apievents("NameDB saw list name", "Delta")
  eq(w.pending(), "Alpha,Bravo,Charlie,Delta", "room, arrivals, channel talkers and list names are looked up")
  w.gmcp.Room.Players = "garbage"
  w.ndb.apievents("gmcp.Room.Players")
  w.gmcp.Comm.Channel.Text = nil
  w.ndb.apievents("gmcp.Comm.Channel.Text")
  eq(#w.requests, 4, "and malformed GMCP is ignored")
end

-- 11. A reply never takes divinity away.
do
  local w = world()
  w.people.Joan = {name = "Joan", city = "rogue", immortal = 1, xp_rank = -1, api_checked = 0}
  w.ndb.lookup("Joan")
  w.answer("Joan", mortal("Joan"))
  eq(w.people.Joan.immortal, 1, "someone HONORS marked immortal stays immortal")
  w.ndb.lookup("Testgod")
  w.answer("Testgod", GOD)
  eq(w.people.Testgod.immortal, 1, "a god the API reports is added as immortal")
end

-- 12. HONORS after the API: the people seen this session, hidden cities first.
do
  local w = world()
  w.svo.conf.usehonors, w.svo.conf.autocheck = true, false
  for _, n in ipairs({"Alpha", "Bravo", "Charlie"}) do
    w.people[n] = {name = n, city = "rogue", immortal = 0, xp_rank = -1, api_checked = 0}
  end
  w.api.seen.Bravo, w.api.seen.Charlie = true, true
  w.ndb.updatebyhonors()
  eq(w.svo.oneconcat(w.ndb.honorslist), "Bravo, Charlie", "with the API on, HONORS is kept to the people seen")

  w.ndb.honorseveryone = true
  w.ndb.updatebyhonors()
  eq(w.svo.oneconcat(w.ndb.honorslist), "Alpha, Bravo, Charlie", "ndb update all gets everyone")
  w.ndb.honorseveryone = nil

  w.svo.conf.ndbapi = false
  w.ndb.updatebyhonors()
  eq(w.svo.oneconcat(w.ndb.honorslist), "Alpha, Bravo, Charlie", "with the API off, as before: everyone")
  w.svo.conf.ndbapi = true

  w.svo.conf.autocheck = true
  w.ndb.honorslist = {Bravo = true, Charlie = true}
  w.api.hiddencity.Charlie = true
  w.ndb.honors_next()
  eq(w.honored[1], "Charlie", "someone whose city the API hides is honored first")
  w.ndb.honors_next()
  eq(w.honored[2], "Bravo", "then the rest")
end

if #failures == 0 then
  print(string.format("ALL PASS (%d checks)", checks))
  os.exit(0)
else
  print(string.format("%d of %d checks FAILED:", #failures, checks))
  for _, f in ipairs(failures) do print("  " .. f) end
  os.exit(1)
end
