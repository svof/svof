svo.loader.priestreporter = function()
  if not (svo.me.class == "Priest" or svo.me.class == "Apostate") then return end
  
  if type(svo.conf.autoseek) ~= 'nil' then
    if svo.conf.autoseek then enableTrigger"Seek request" else
    disableTrigger"Seek request" end
  end

  svo.config.setoption("autoseek",
  {
   vconfig2string = true,
    type = "boolean",
    onenabled = function ()
      enableTrigger"Seek request"
      svo.echof("<0,250,0>Will%s seek on seek requests.", svo.getDefaultColor())
    end,
    ondisabled = function () disableTrigger"Seek request" svo.echof("<250,0,0>Won't%s automatically seek on requests.", svo.getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg("gold")
      echoLink("pr:", "", "svo Priest Report", true)
      fg(defaultcolour)
      echo(" Responding to seek requests is ")
      fg("a_cyan") echoLink(svo.conf.autoseek and "on" or "off", "svo.config.set('autoseek', "..(svo.conf.autoseek and "false" or "true")..", true)", "Click to "..(svo.conf.autoseek and "disable" or "enable").." responses to seek requests", true) fg(defaultcolour)
      fg(defaultcolour) echo(", better tracing ")
      fg("a_cyan") echoLink(svo.conf.bettertrace and "on" or "off", "svo.config.set('bettertrace', "..(svo.conf.bettertrace and "false" or "true")..", true)", "Click to "..(svo.conf.bettertrace and "disable" or "enable").." a better trace reporting style", true) fg(defaultcolour)
      fg(defaultcolour)
      if not svo.conf.bettertrace then
        echo(".\n")
      else
        echo(", reporting every ")
        fg("a_cyan") echoLink(svo.conf.reportdelay, "printCmdLine('vconfig reportdelay ')", "Click to adjust the max number of seconds a trace announce will be delayed for someone speedwalking", true) fg(defaultcolour)
        echo("s.\n")
      end
  end})

  svo.me.locatelist = svo.me.locatelist or {}

  svo.config.setoption("locatelist", {
    type = "string",
    check = function(what)
      if what:find("^%w+$") then return true end
    end,
    onset = function ()
      local name = string.title(svo.conf.locatelist)
      -- we want nil, not false so 'or' doesn't help
      if svo.me.locatelist[name] then svo.me.locatelist[name] = nil else svo.me.locatelist[name] = true end

      if svo.me.locatelist[name] then
        svo.echof("Added <0,255,0>%s%s to the locatelist list - will respond to their locate tells.", name, svo.getDefaultColor())
      else
		svo.echof("Removed %s from the locatelist list.", name)
      end
    end
  })


  svo.config.setoption("bettertrace",
  {
    vconfig2string = true,
    type = "boolean",
    onenabled = function ()
      svo.echof("<0,250,0>Will%s use improved trace output (less spammy and more helpful).", svo.getDefaultColor())
    end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use improved trace output (will use old room-by-room instead).", svo.getDefaultColor()) end,
  })

  svo.config.setoption("reportdelay",
  {
    type = "number",
    min = 1,
    max = 100000,
    onset = function ()
      svo.echof("Will report movement every %d seconds max for someone speedwalking.", svo.conf.reportdelay)
    end,
  })

local conf = svo.conf

-- initialise to something so there's a value
local oldroom = ""
conf.reportdelay = 2
conf.bettertrace = true

local function announce_between_two_rooms(roomname1, roomname2)
  -- get the area the room the person ended up in, if possible
  local exactarealastroom
  if mmp.getexactarea then
    exactarealastroom = mmp.getexactarea(roomname2)
    if exactarealastroom then exactarealastroom = mmp.cleanAreaName(exactarealastroom) end
  end

  -- if moved between just two rooms: get lists of IDs for both of them
  local rid1, rid2 = mmp.searchRoomExact(roomname1), mmp.searchRoomExact(roomname2)

  -- if we have more than one ID for either - just announce where we ended up
  if not (table.size(rid1) == 1 and table.size(rid2) == 1) then
    svo.cc("%s moved one room to %s%s", svo.tracing, roomname2, (exactarealastroom and " in "..exactarealastroom))
  -- if exactly one ID for start and end, then work out the directory
  else
    rid1 = next(rid1)
    rid2 = next(rid2)
    local found
    for exit, roomid in pairs(getRoomExits(rid1)) do
      if roomid == rid2 then
        svo.cc("%s moved %s to %s%s", svo.tracing, exit, roomname2, (exactarealastroom and " in "..exactarealastroom)); found = true; break
      end
    end
    if not found then svo.cc("%s moved one room to %s%s", svo.tracing, roomname2, (exactarealastroom and " in "..exactarealastroom)) end
  end
end

svo.trace = function()
  svo.recently_announced = nil

  if svo.rooms_to_announce and #svo.rooms_to_announce == 2 then
    announce_between_two_rooms(svo.rooms_to_announce[1], svo.rooms_to_announce[2])

  -- if they've moved a bunch of rooms
  elseif svo.rooms_to_announce and #svo.rooms_to_announce > 2 then
    -- get the area the room the person ended up in, if possible
    local exactarealastroom
    if mmp.getexactarea then
      exactarealastroom = mmp.getexactarea(svo.rooms_to_announce[#svo.rooms_to_announce])
      if exactarealastroom then exactarealastroom = mmp.cleanAreaName(exactarealastroom) end
    end

    svo.cc("%s moved %d room%s to %s%s", svo.tracing, #svo.rooms_to_announce-1, (svo.rooms_to_announce == 2 and "" or 's'), svo.rooms_to_announce[#svo.rooms_to_announce], (exactarealastroom and " in "..exactarealastroom))
  -- else just one room in the table - then it is the same room, so ignore
  end
  svo.rooms_to_announce = nil
end

function svo.priestapo_trace(name, newroom)
  if svo.defc.dragonform then return end

  if not (svo.tracing and name == svo.tracing) then return end

  local exactarea
  if mmp.getexactarea then exactarea = mmp.getexactarea(newroom) end

  local function oldannounce()
    if exactarea then
      svo.cc("%s entered %s in %s", name, newroom, mmp.cleanAreaName(exactarea))
    else
      svo.cc("%s entered %s", name, newroom)
    end
  end

  if not conf.bettertrace then
    oldannounce()
  else
    if not svo.recently_announced then
      announce_between_two_rooms(oldroom, newroom)

      -- keep track for slow movement
      oldroom = newroom
      -- separately keep track for speedwalking
      svo.rooms_to_announce = { newroom }

      svo.recently_announced = tempTimer(conf.reportdelay, svo.trace)
    else
      svo.rooms_to_announce = svo.rooms_to_announce or {}
      svo.rooms_to_announce[#svo.rooms_to_announce+1] = newroom
    end
  end
end

end -- end of svo priest reporter loader

if svo.systemloaded then svo.loader.priestreporter() end