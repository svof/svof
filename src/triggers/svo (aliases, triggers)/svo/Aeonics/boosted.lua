svo.givewarning({
	initialmsg = string.format("%s started BOOSTED Doom for you! Leave within %d seconds", matches[2], svo.affl.aeon and 5 or 7),
	prefixwarning = matches[2].." dooms you (BOOSTED)",
	startin = 1,
	duration = 2
})
svo.doomer = nil