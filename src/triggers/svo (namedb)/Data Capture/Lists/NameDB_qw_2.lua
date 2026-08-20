local function commit()
  db:merge_unique(ndb.db.people, temp_name_list)

  for _, person in pairs(temp_name_list) do
    raiseEvent("NameDB saw list name", person.name)
  end

  raiseEvent("NameDB got new data")
end

-- ignore yourself gemmed offplane
if multimatches[1][1] == "None." then
  disableTrigger("NameDB qw")
  disableTrigger("NameDB qw 2")
  ndb.checkingqwi = nil
  commit()
  return
end



--[[
for _,name in ipairs(data) do
  -- check for guides, but ignore Gods, who show as (God)
  if name:find("(", 1, true) then
    local secondname
    name, secondname = name:match("(%w+)%((%w+)%)")
    if name and secondname then
      temp_name_list[#temp_name_list + 1] = {
        name = secondname
      }
 
      temp_name_list[#temp_name_list + 1] = {
        name = name
      } 
    end
  else
    -- add a plain name
    temp_name_list[#temp_name_list + 1] = {
      name = name
    }
  end
end
]]

-- re-honors if asked for
if ndb.qwtype and ndb.qwtype == "update" then
  for _, name in pairs(temp_name_list) do
    name.xp_rank = -1
  end

-- or organize by cities
elseif ndb.qwtype and ndb.qwtype == "organize cities" then
  local cities = {}

  local getcity = ndb.getcity
  for _, person in pairs(temp_name_list) do
    local city = getcity(person.name)

    city = city or "unknown"
    if city == "" then city = "rogue" end

    if ndb.isimmortal(person.name) then city = "Immortal" end
    
    cities[city] = cities[city] or {}
    cities[city][#cities[city]+1] = person.name
  end

  echo'\n\n'
  svo.echof("qw, sorted by members and count:")

  local sortbycount, longestcityname = {}, 0
  for city, members in pairs(cities) do
    sortbycount[city] = #members
    if #city > longestcityname then longestcityname = #city end
  end

  local sortbycount = {}; for city in pairs(cities) do sortbycount[#sortbycount+1] = {city, #cities[city]} end
  table.sort(sortbycount, function(a, b)
    return a[2] > b[2]
  end)

  for _, org in ipairs(sortbycount) do
    local city, members = org[1], cities[org[1]]
    table.sort(members)
    cecho(string.format("  <royal_blue>%-"..longestcityname.."s<a_grey> <DarkSlateGrey>(<blaze_orange>%d<DarkSlateGrey>): <a_grey>%s\n", city, #members, svo.concatand(members)))
  end

-- or report to cc
elseif ndb.qwtype and ndb.qwtype:starts("report members of ") then
  local org = ndb.qwtype:match("^report members of (%w+)"):lower()

  local citizens = {}
  for _, city in ipairs(ndb.valid.cities) do
    if city:lower():starts(org) then
      org = city

      for _, person in pairs(temp_name_list) do
        local persons_city = ndb.getcity(person.name)
        if persons_city == city then citizens[#citizens+1] = person.name end
      end

      break
    end
  end

  if not citizens[1] then echo'\n' svo.echof("No citizens of %s seem to be on.", org) return end

  table.sort(citizens)

  svo.cc("%s %s visible: %s", #citizens, ndb.getpluralcity(org, #citizens), svo.concatand(citizens))
elseif ndb.qwtype == "show marks" then
  local marks = {}
  for _, person in pairs(temp_name_list) do
    local mark = ndb.ismark(person.name)

    if mark then
      marks[mark] = marks[mark] or {}
      marks[mark][#marks[mark]+1] = person.name
    end
  end

  echo'\n\n'
  svo.echof("Marks:")
  if not next(marks) then svo.echof("(none found)") end
  for cat, people in pairs(marks) do
    table.sort(people)
    cecho(string.format("  %s: %s\n", cat:title(), svo.concatandf(people, ndb.getcolorn)))
  end

elseif ndb.qwtype == "show infamous" then
  local infamous = {}
  for _, person in pairs(temp_name_list) do
    local infamy = ndb.isinfamous(person.name)

    if infamy and infamy >= 1 then
      infamous[infamy] = infamous[infamy] or {}
      infamous[infamy][#infamous[infamy]+1] = person.name
    end
  end

  echo'\n\n'
  svo.echof("Infamous:")
  if not next(infamous) then svo.echof("(none found)") end
  for cat, people in pairs(infamous) do
    table.sort(people)
    cecho(string.format("  %s: %s\n", ndb.valid.shortinfamous[cat], svo.concatandf(people, ndb.getcolorn)))
  end
end

commit()
disableTrigger("NameDB qw")
disableTrigger("NameDB qw 2")