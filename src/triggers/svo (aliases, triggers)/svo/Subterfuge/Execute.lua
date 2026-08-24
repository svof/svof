svo.givewarning({
	initialmsg = string.format("%s started Execute on you! STAND to stop it!", multimatches[2][2]),
	prefixwarning = multimatches[2][2].." execute you",
	startin = 1,
	duration = 2
})

svo.startedfighting("serpent", multimatches[2][2])