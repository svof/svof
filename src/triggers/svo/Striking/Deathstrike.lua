svo.givewarning({
	initialmsg = string.format("%s started Deathstrike! Hinder %s or leave the room in 10s!", multimatches[2][2], multimatches[2][2]),
	prefixwarning = multimatches[2][2].." deathstriking you",
	startin = 1,
	duration = 2
})

svo.startedfighting("blademaster", multimatches[2][2])