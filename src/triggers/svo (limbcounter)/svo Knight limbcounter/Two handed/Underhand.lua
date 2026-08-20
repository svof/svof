if svo.lc_checkdamage then
	svo.lc_hit(multimatches[2][2], "torso", .5)
elseif not svo.lc_checkdamage then
	svo.lc_hit(multimatches[2][2], "torso", 1)
end