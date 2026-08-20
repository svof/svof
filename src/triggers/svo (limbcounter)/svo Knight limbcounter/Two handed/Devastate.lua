if matches[2] == "legs" then
	svo.lc_list[matches[3]]["leftleg"] = svo.lc_break_at
	svo.lc_list[matches[3]]["rightleg"] = svo.lc_break_at
elseif matches[2] == "arms" then
	svo.lc_list[matches[3]]["leftarm"] = svo.lc_break_at
	svo.lc_list[matches[3]]["rightarm"] = svo.lc_break_at
end
svo.lc_checklimbcounter()