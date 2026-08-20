svo.givewarning({
	initialmsg = string.format("%s is eliminating you!", multimatches[2][2]),
	prefixwarning = multimatches[2][2].." eliminating you",
	startin = 1,
	duration = 2
})

svo.startedfighting("apostate", multimatches[2][2])