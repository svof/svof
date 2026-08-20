if not temp_name_list then return end

temp_name_list[1].birth_day = tonumber(matches[3])
temp_name_list[1].birth_month = ndb.valid.months[matches[4]]
temp_name_list[1].birth_year = tonumber(matches[5])
temp_name_list[1].birth_hidden = 0