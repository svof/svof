svo.givewarning_multi({
	initialmsg = string.format("%s started Reave on you!", matches[2]),
	prefixwarning = matches[2].." reaving you",
	startin = 1,
	duration = 2
})

svo.startedfighting("alchemist", matches[2])