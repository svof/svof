if svo.lc_checkdamage == true then
	local start = (svo.lc_break_at - (svo.lc_break_at * .3))
	local hit = (svo.lc_break_at / start)
	hit = string.format("%2.1f", hit)
	hit = tonumber(hit)
	svo.lc_hit(multimatches[2][2], multimatches[2][3], hit)
	svo.lc_checkdamage = false
else
	svo.lc_hit(multimatches[2][2], multimatches[2][3], 1)
end