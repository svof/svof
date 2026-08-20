svo.givewarning({
	initialmsg = string.format("%s still deathstriking you! Hinder %s or leave the room in 5s!", multimatches[2][2], multimatches[2][2]),
	prefixwarning = multimatches[2][2].." deathstriking you still",
	startin = 1,
	duration = 2
})

svo.startedfighting("blademaster", multimatches[2][2])