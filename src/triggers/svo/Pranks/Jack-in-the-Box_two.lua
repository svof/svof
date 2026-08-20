if matches[2] ~= svo.me.name then return end

svo.givewarning({
	initialmsg = string.format("Jack-in-the-Box about to %s you!!", ((math.random(2) == 1) and "nom" or "eat")),
	prefixwarning = matches[2].." Jack-in-the-Box you",
	startin = 1,
	duration = 2
})