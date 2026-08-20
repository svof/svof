local name = matches[2]:title()
local category = matches[3]
local towhat = tonumber(matches[4]) or matches[4]

local temp_name_list = {}

if category == "city" then
  towhat = towhat:title()
  if not ndb.isvalidcity(towhat) then
    svo.echof("%s isn't a known city, sorry.\n  Available ones are: %s", towhat, svo.concatand(ndb.valid.cities))
    return
  end

elseif category == "class" then
  towhat = towhat:lower()
  if not ndb.isvalidclass(towhat) then
    svo.echof("%s isn't a known class, sorry.\n  Available ones are: %s", towhat, svo.concatand(ndb.valid.classes))
    return
  end

elseif category == "race" then
  towhat = towhat:lower()
  if not ndb.isvalidrace(towhat) then
    svo.echof("%s isn't a known race, sorry.\n  Available ones are: %s", towhat, svo.concatand(ndb.valid.races))
    return
  end

elseif category == "house" then category = "guild"
end

if category == "guild" or category == "order" then towhat = towhat:title() end
if category == "notes" then towhat = towhat:gsub([[\n]], "\n") end

if category == "cityenemy" or category == "houseenemy" or category == "orderenemy" or category == "immortal" or category == "dragon" then
  towhat = svo.toboolean(towhat) and 1 or 0
end

temp_name_list[#temp_name_list + 1] = {
  name = name,
  [category] = towhat
}

db:merge_unique(ndb.db.people, temp_name_list)

ndb.showwhois(name)

-- re-honors person if necessary
if category == "xp_rank" or category == "might" then
  raiseEvent"NameDB got new data"
end

raiseEvent("NameDB set name changed", name)

-- regenerate order vconfigs
if category == "order" then ndb.setuporders() end