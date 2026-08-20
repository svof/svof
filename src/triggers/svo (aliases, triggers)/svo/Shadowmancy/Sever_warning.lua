svo.startedfighting("depthswalker", matches[2])
svo.givewarning({
	initialmsg = string.format("%s is severing you!", matches[2]),
	prefixwarning = matches[2].." severs you",
	startin = 1,
	duration = 2
})