svo.givewarning({
	initialmsg = string.format("%s started Tzantza!", matches[2]),
	prefixwarning = matches[2].." started Tzantza",
	startin = 1,
	duration = 2
})

svo.startedfighting("shaman", matches[2])