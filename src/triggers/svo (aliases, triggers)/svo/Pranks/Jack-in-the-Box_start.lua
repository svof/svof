if matches[3] ~= svo.me.name then return end

svo.givewarning({
	initialmsg = string.format("%s started Jack-in-the-Box for you!", matches[2]),
	prefixwarning = matches[2].." Jack-in-the-Box you",
	startin = 1,
	duration = 2
})