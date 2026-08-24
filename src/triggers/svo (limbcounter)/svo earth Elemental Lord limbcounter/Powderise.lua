if svo.lc_shaping == 4 then
	svo.lc_hit(matches[3], matches[2], 2)
elseif svo.lc_shaping <= 3 then
	svo.lc_hit(matches[3], matches[2], 1)
end

svo.lc_shaping = string.match(gmcp.Char.Vitals.charstats[3], "%d+")
svo.lc_shaping = tonumber(svo.lc_shaping)