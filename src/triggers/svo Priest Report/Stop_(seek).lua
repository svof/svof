setTriggerStayOpen("Seek", 0)

-- someone asked directly for a seek
if svo.locating.person then
  if not svo.locating.ents then
    send(string.format("tell %s %s (%s) is at %s - alone", svo.locating.person, svo.locating.name, (svo.locating.hp == 0 and "dead" or svo.locating.hp.."hp, "..svo.locating.mp.."mp"), svo.locating.location))
  else
    send(string.format("tell %s %s (%s) is at %s - with %s (%d people total)", svo.locating.person, svo.locating.name, (svo.locating.hp == 0 and "dead" or svo.locating.hp.."hp, "..svo.locating.mp.."mp"), svo.locating.location,
      svo.concatand(svo.locating.ents),
      #svo.locating.ents+1))
  end
  svo.locating = nil
  return
end

-- manual seek, don't know where to report? Use cc
if not svo.locating.clan then
  if not svo.locating.ents then
    svo.cc("%s (%s) is at %s - alone", svo.locating.name, (svo.locating.hp == 0 and "dead" or svo.locating.hp.."hp, "..svo.locating.mp.."mp"), svo.locating.location)
  else
    svo.cc("%s (%s) is at %s - with %s (%d people total)", svo.locating.name, (svo.locating.hp == 0 and "dead" or svo.locating.hp.."hp, "..svo.locating.mp.."mp"), svo.locating.location,
      svo.concatand(svo.locating.ents),
      #svo.locating.ents+1)
  end
  svo.locating = nil
  return
end

local function getchannel()
  if svo.locating.clan == "party" then
    return "pt"
  elseif svo.locating.clan == "art" then
    return "art"
  else
    return ("clan "..svo.locating.clan.." tell")
  end
end

-- someone asked over clan/party for a seek
if not svo.locating.ents then
  send(string.format("%s %s (%s) is at %s - alone",
    getchannel(), svo.locating.name, (svo.locating.hp == 0 and "dead" or svo.locating.hp.."hp, "..svo.locating.mp.."mp"), svo.locating.location))

else
  send(string.format(
    "%s %s (%s) is at %s - with %s (%d people total)",
    getchannel(), svo.locating.name, (svo.locating.hp == 0 and "dead" or svo.locating.hp.."hp, "..svo.locating.mp.."mp"), svo.locating.location,
    (svo.concatand and svo.concatand(svo.locating.ents) or table.concat(svo.locating.ents, ", ")),
    #svo.locating.ents+1
  ))
end

svo.locating = nil