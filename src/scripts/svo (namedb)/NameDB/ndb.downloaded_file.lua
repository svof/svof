-- Looking people up on the Achaea API, api.achaea.com.
--
-- Credit to Veldrin for the original lookup and parser this replaces. Making
-- the API NameDB's main source, using the list of who is online to decide who
-- to look up, and keeping HONORS for what the API can't say, follow the
-- Legacy system's NameDB (https://github.com/Legacy-System/Legacy). The code
-- here is svof's own.
--
-- A lookup fills in what the API knows: full title, level, class, city,
-- house, and whether someone is a god. An in-game HONORS, when vconfig
-- usehonors is on, runs later and adds what only HONORS shows. A lookup never
-- writes xp_rank: xp_rank -1 is how the honors queue knows someone was never
-- honored in game.

ndb.api = ndb.api or {}
local api = ndb.api

api.maxinflight = 4          -- Qt opens at most 6 connections to one host anyway
api.timeout = 20             -- seconds before a request that never finished is given up
api.fresh = 24 * 60 * 60     -- a name looked up in the last day isn't asked about again
api.hourlycap = 300          -- a guard against a bug re-queuing names, far above normal play
api.maxerrors = 5            -- failures in a row before lookups stop until the next login
api.polldelay = 10 * 60      -- how often the list of who is online is fetched

api.queue = api.queue or {}             -- names waiting, in order
api.queued = api.queued or {}           -- name = true while waiting or in flight
api.inflight = api.inflight or {}       -- local file = {key =, timer =}
api.seen = api.seen or {}               -- names asked about this session, for the honors queue
api.hiddencity = api.hiddencity or {}   -- names whose city the API hides
api.notfound = api.notfound or {}       -- name = time the API said there's no such character
api.errors = api.errors or 0
api.hour = api.hour or {start = 0, count = 0}

local ONLINE = "\0online"

local function apidir()
  return getMudletHomeDir() .. "/svo/namedb/api"
end

local function normalise(path)
  return (path:gsub("\\", "/"))
end

-- An Achaean name: one capitalised word of three letters or more.
function ndb.isvalidname(name)
  return type(name) == "string" and name:find("^%u%l%l+$") ~= nil
end

-- What one reply from api.achaea.com/characters/<name>.json says about
-- someone, as a NameDB record. Only the fields the reply settles are set, so
-- merging the record leaves the rest of the row alone. The second value is
-- true when the API hides their city.
function ndb.api_record(name, t)
  local function field(key)
    local value = t[key]
    if value == nil then return "" end
    return tostring(value)
  end

  local record = {name = name, api_checked = os.time()}
  local fullname, level, class = field("fullname"), field("level"), field("class")
  local city, house = field("city"):lower(), field("house")

  if fullname ~= "" then record.title = fullname end

  -- Gods have no level, class or city. The Guides are mortal on paper, with
  -- a level and no class, and are counted with the gods - as an HONORS on
  -- them counts them, since it gives them the gods' birth line. A reply never
  -- takes divinity away: that is HONORS' call.
  if level == "" or (class == "" and fullname == name .. ", the Guide") then
    record.immortal = 1
    return record, false
  end

  local lvl = tonumber(level)
  if lvl then
    record.level = lvl
    record.dragon = lvl > 98 and 1 or 0
  end

  if class ~= "" then record.class = class:lower() end

  local hidden = false
  if city == "(hidden)" then
    -- keep the city NameDB has: QWC colours or an HONORS may know it
    hidden = true
  elseif city == "" or city == "(none)" then
    record.city = "rogue"
  elseif city == "underworld" then
    record.city = "Undead"
  else
    record.city = city:title()
  end

  if house == "(hidden)" then
    -- keep the house NameDB has
  elseif house == "" or house == "(none)" then
    record.guild = ""
  else
    record.guild = house:title()
  end

  return record, hidden
end

local function inflightcount()
  local n = 0
  for _ in pairs(api.inflight) do n = n + 1 end
  return n
end

local function take(file)
  local key = normalise(file)
  local entry = api.inflight[key]
  if not entry then return end
  api.inflight[key] = nil
  if entry.timer then killTimer(entry.timer) end
  return entry
end

local function readfile(file)
  local f = io.open(file, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

-- Holds requests back for a while; pump() carries on afterwards.
function api.wait(seconds)
  if api.resume then return end
  api.resume = tempTimer(math.max(1, seconds), function()
    api.resume, api.capped = nil, nil
    api.pump()
  end)
end

local function requeue(key)
  if key == ONLINE then return end
  table.insert(api.queue, 1, key)
  api.queued[key] = true
end

function api.request(key, file, url)
  if not lfs.attributes(apidir()) then lfs.mkdir(apidir()) end

  api.hour.count = api.hour.count + 1
  local entry = {key = key}
  local slot = normalise(file)
  api.inflight[slot] = entry
  entry.timer = tempTimer(api.timeout, function()
    if api.inflight[slot] ~= entry then return end
    api.inflight[slot] = nil
    api.failed(key, "no reply in " .. api.timeout .. "s")
  end)

  local ok, err = pcall(downloadFile, file, url)
  if not ok then
    take(file)
    api.failed(key, err)
  end
end

-- A request that failed for a reason other than "no such character". The
-- first failure holds every request back; the ones already in flight during
-- that pause are put back without counting, so one outage counts once.
function api.failed(key, why)
  if api.resume then
    requeue(key)
    return
  end

  api.errors = api.errors + 1
  if api.errors >= api.maxerrors then
    api.stopped = true
    api.queue, api.queued = {}, {}
    svo.echof("NameDB couldn't reach the Achaea API %d times in a row (last: %s), so it won't look names up again until you next log in.", api.errors, tostring(why))
    return
  end

  requeue(key)
  api.wait(math.min(600, math.floor(30 * 2 ^ (api.errors - 1))))
end

function api.pump()
  if api.stopped or api.resume or not svo.conf.ndbapi then return end

  while api.queue[1] and inflightcount() < api.maxinflight do
    local now = os.time()
    if now - api.hour.start >= 3600 then
      api.hour.start, api.hour.count = now, 0
    end
    if api.hour.count >= api.hourlycap then
      if not api.capped then
        api.capped = true
        svo.echof("NameDB has made %d Achaea API lookups this hour, so it's waiting for the hour to pass before making more.", api.hourlycap)
      end
      api.wait(api.hour.start + 3600 - now)
      return
    end

    local name = table.remove(api.queue, 1)
    api.request(name, apidir() .. "/" .. name .. ".json", "http://api.achaea.com/characters/" .. name .. ".json")
  end
end

local function fresh(name)
  local notfound = api.notfound[name]
  if notfound and os.time() - notfound < api.fresh then return true end

  local person = ndb.getname(name)
  local checked = person and tonumber(person.api_checked) or 0
  return checked > 0 and os.time() - checked < api.fresh
end

-- Asks the API about someone, unless they were asked about in the last day.
-- force asks again anyway, ahead of everyone waiting.
function ndb.lookup(name, force)
  if not (svo.conf and svo.conf.ndbapi) or api.stopped or not ndb.getname then return end
  if type(name) ~= "string" then return end

  name = name:lower():title()
  if not ndb.isvalidname(name) or name == svo.me.name then return end

  api.seen[name] = true
  if api.queued[name] then return end
  if not force and fresh(name) then return end

  api.queued[name] = true
  if force then
    table.insert(api.queue, 1, name)
  else
    api.queue[#api.queue + 1] = name
  end
  api.pump()
end

-- kept for scripts that called the old lookup
function ndb.getinfo(person)
  ndb.lookup(person, true)
end

function api.notfoundname(name)
  api.queued[name] = nil
  api.notfound[name] = os.time()
  if ndb.exists(name) then
    ndb.fixed_set(ndb.db.people.api_checked, os.time(), db:eq(ndb.db.people.name, name))
  end
end

function api.gotcharacter(name, t)
  api.queued[name] = nil
  if t.error or type(t.name) ~= "string" then
    api.notfoundname(name)
    return
  end

  local record, hidden = ndb.api_record(name, t)
  api.hiddencity[name] = hidden or nil
  db:merge_unique(ndb.db.people, {record})
  raiseEvent("NameDB got API data", name)
end

function api.gotonline(t)
  if type(t.characters) ~= "table" then return end

  for _, character in ipairs(t.characters) do
    if type(character) == "table" then ndb.lookup(character.name) end
  end

  -- the people just seen are the honors queue now
  if svo.conf.usehonors and svo.conf.autocheck then ndb.updatebyhonors() end
end

-- Fetches who is online and looks up the ones NameDB doesn't know or hasn't
-- checked today. Runs at login and every api.polldelay seconds after.
function api.poll()
  if api.polltimer then killTimer(api.polltimer) end
  api.polltimer = tempTimer(api.polldelay, api.poll)

  if not (svo.conf and svo.conf.ndbapi) or not api.online or api.stopped or api.resume then return end

  local file = apidir() .. "/online.json"
  if api.inflight[normalise(file)] then return end
  api.request(ONLINE, file, "http://api.achaea.com/characters.json")
end

local function downloaderror(...)
  local args, n = {...}, select("#", ...)
  local file
  for i = 1, n do
    if type(args[i]) == "string" and api.inflight[normalise(args[i])] then
      file = args[i]
      break
    end
  end
  if not file then return end -- not ours: other packages download too

  local entry = take(file)
  os.remove(file)

  local message = {}
  for i = 1, n do
    if args[i] ~= file and type(args[i]) == "string" then message[#message + 1] = args[i] end
  end
  message = table.concat(message, " ")

  -- the API answers a name it doesn't know with a 403, "Character not found"
  if entry.key ~= ONLINE and (message:find("Forbidden", 1, true) or message:find("403", 1, true)
    or message:lower():find("not found", 1, true)) then
    api.errors = 0
    api.notfoundname(entry.key)
    api.pump()
    return
  end

  api.failed(entry.key, message ~= "" and message or "download error")
end

function ndb.downloaded_file(event, ...)
  if event == "sysDownloadError" then return downloaderror(...) end

  local filename = ...
  if type(filename) ~= "string" then return end
  local entry = take(filename)
  if not entry then return end -- not ours: other packages download too

  local s = readfile(filename)
  os.remove(filename)

  local ok, t = pcall(yajl.to_value, s or "")
  if not ok or type(t) ~= "table" then
    api.failed(entry.key, "a reply that isn't JSON")
    return
  end

  api.errors = 0
  if entry.key == ONLINE then
    api.gotonline(t)
  else
    api.gotcharacter(entry.key, t)
  end
  api.pump()
end

-- Installed or reloaded while logged in: no login event is coming to start
-- the poll, so start it here.
if gmcp and gmcp.Char and gmcp.Char.Name and not api.polltimer then
  api.online = true
  tempTimer(5, function() api.poll() end)
end
