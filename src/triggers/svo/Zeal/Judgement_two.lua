svo.givewarning({
	initialmsg = string.format("%s is still judging you!", multimatches[2][2]),
	prefixwarning = multimatches[2][2].." judging you",
	duration = 2
})

svo.startedfighting("priest", multimatches[2][2])