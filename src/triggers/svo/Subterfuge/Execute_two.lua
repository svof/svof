svo.givewarning_multi({
	initialmsg = string.format("%s is still executing you! STAND to stop it!", multimatches[2][2]),
	prefixwarning = multimatches[2][2].." still executing you",
	duration = 2
})

svo.startedfighting("serpent", multimatches[2][2])