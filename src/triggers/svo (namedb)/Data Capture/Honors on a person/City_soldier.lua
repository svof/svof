if not temp_name_list then return end

temp_name_list[1].city_soldier = -2
-- "He is an Insurgent of the Wilds(1) in the army of Eleusis."
temp_name_list[1].army_rank = tonumber(matches[1]:match("%((%d+)%) in the army of")) or temp_name_list[1].army_rank