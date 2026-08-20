if not svo.qwhoareas or not next(svo.qwhoareas) then svo.echof("Check qwho first - we don't have any wholist data.") return end

local function cleanAreaName(area)
  return mmp.cleanAreaName and mmp.cleanAreaName(area) or area
end

for area, areadata in pairs(svo.qwhoareas) do
  local people = {}
  if area:lower():find(matches[2]:lower()) then
    for _, room in pairs(areadata) do
      people = table.n_union(people, room)
    end
    table.sort(people)

    svo.cc("%s %s in %s - %s", #people, (#people == 1 and 'person' or 'people'), cleanAreaName(area), svo.concatand(people))
  end
end