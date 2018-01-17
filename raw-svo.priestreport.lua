-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

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

function svo.angel_trace(name, newroom)
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
