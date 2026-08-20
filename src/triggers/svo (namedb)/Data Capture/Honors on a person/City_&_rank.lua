if not temp_name_list then return end
if string.find(matches[3],"underworld") then
  temp_name_list[1].city = "Undead"
  temp_name_list[1].class = "undead"
  temp_name_list[1].city_rank = matches[2]
  return
end
temp_name_list[1].city_rank = ndb.getrankincity(matches[3], matches[2])
temp_name_list[1].city = matches[3]