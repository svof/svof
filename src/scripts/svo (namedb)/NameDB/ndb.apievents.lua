-- What sends names to the Achaea API lookups in ndb.downloaded_file: logging
-- in, which starts the poll of who is online, and the people the game shows
-- you - in your room, talking on a channel, or on a list NameDB reads.
function ndb.apievents(event, arg)
  if not (svo and svo.conf and ndb.api and ndb.lookup) then return end
  local api = ndb.api

  if event == "gmcp.Char.Name" then
    api.online = true
    api.stopped, api.errors = nil, 0
    -- let the login settle before the first fetch
    tempTimer(5, function() api.poll() end)

  elseif event == "sysDisconnectionEvent" then
    api.online = nil

  elseif event == "gmcp.Room.Players" then
    local players = gmcp.Room and gmcp.Room.Players
    if type(players) ~= "table" then return end
    for _, player in ipairs(players) do
      if type(player) == "table" then ndb.lookup(player.name) end
    end

  elseif event == "gmcp.Room.AddPlayer" then
    local player = gmcp.Room and gmcp.Room.AddPlayer
    if type(player) == "table" then ndb.lookup(player.name) end

  elseif event == "gmcp.Comm.Channel.Text" then
    local text = gmcp.Comm and gmcp.Comm.Channel and gmcp.Comm.Channel.Text
    if type(text) == "table" then ndb.lookup(text.talker) end

  elseif event == "NameDB saw list name" then
    ndb.lookup(arg)
  end
end
