if not svo.qwhoareas or not next(svo.qwhoareas) then svo.echof("Check qwho first - we don't have any wholist data.") return end

local person = matches[2]:title()

local function locate(person)
  for area, areadata in pairs(svo.qwhoareas) do
    for room, people in pairs(areadata) do
      for i = 1, #people do
        if people[i]:starts(person) then
          return area, room, people[i]
        end
      end
    end
  end
end

local area, room, fullname = locate(person)

if not area then svo.echof("Don't have %s in the list - perhaps they're gemmed, or check qwho again?", person) return end

local people = svo.qwhoareas[area][room]
table.sort(people)

local function cleanAreaName(area)
  return mmp.cleanAreaName and mmp.cleanAreaName(area) or area
end

if #people == 1 then
  local text = string.format("%s is alone at %s in %s", people[1], room, cleanAreaName(area))
  svo.cc(text)
  svo.echof(text)
else
  local text = string.format("%d %s total with %s at %s in %s - %s", #people, (#people == 1 and 'person' or 'people'), fullname, room, cleanAreaName(area) or '?', svo.concatand(people))
  svo.cc(text)
  svo.echof(text)
end