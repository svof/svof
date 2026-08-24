if not temp_name_list then return end

temp_name_list[1].xp_rank = tonumber(matches[2])

-- 200 is a safe amount to set it at, as the number will vary
if tonumber(matches[2]) < 240 then temp_name_list[1].dragon = 1 end