svo.givewarning({
	initialmsg = string.format("%s started Doom for you! Leave or hinder within %d seconds", svo.doomer, svo.affl.aeon and 7 or 10),
	prefixwarning = svo.doomer.." dooms you",
	startin = 0,
	duration = 2
})
svo.doomer = nil