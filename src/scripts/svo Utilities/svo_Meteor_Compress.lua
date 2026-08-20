function svo.updatemeteors()
  deleteLine()
  svo.prompttrigger("compress meteors", svo.showmeteors)
end

local function concatmap(tbl)
  local t = {}
  for k,v in pairs(tbl) do
    t[#t+1] = v.." on "..k
  end
  return svo.concatand(t)
end

function svo.showmeteors()
  local t = {}
  if svo.meteors.justlaunched then
    t[#t+1] = string.format("%d launched", svo.meteors.justlaunched)
  end
  if svo.meteors.justlaunchedmine then
    t[#t+1] = "plus your meteor"
  end
  if svo.meteors.headingin then
    t[#t+1] = string.format("%d heading to you", svo.meteors.headingin)
  end
  if svo.meteors.headingout then
    t[#t+1] = string.format("%d going elsewhere", svo.meteors.headingout)
  end
  if svo.meteors.brokeshield then
    t[#t+1] = svo.meteors.brokeshield.. " broke your shield"
  end
  if svo.meteors.hityou then
    t[#t+1] = string.format("%s hit you", svo.concatand(svo.meteors.hityou))
  end
  if svo.meteors.brokeshieldother then
    t[#t+1] = string.format("shield broke on: %s", concatmap(svo.meteors.brokeshieldother))
  end
  if svo.meteors.hitanother then
    t[#t+1] = string.format("meteors hit: %s", concatmap(svo.meteors.hitanother))
  end
  if svo.meteors.fellelsewhere then
    t[#t+1] = string.format("%d hit no-one", svo.meteors.fellelsewhere)
  end

  svo.echof("<255,0,0>meteors%s: %s", svo.getDefaultColor(), svo.concatand(t))
  svo.meteors = nil
end