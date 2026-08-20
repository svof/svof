svo.givewarning({
	initialmsg = string.format("%s is still devouring you!", multimatches[2][2]),
	prefixwarning = multimatches[2][2].." devouring you",
	duration = 2
})

svo.startedfighting("dragon", multimatches[2][2])