svo.givewarning({
	initialmsg = string.format("%s started funeralmass on %s!", matches[2], matches[3]),
	prefixwarning = matches[2].." fmass "..matches[3],
	startin = 1,
	duration = 2
})
svo.fmass = { bard = matches[2], victim = matches[3] }

tempTimer(10, [[svo.fmass = nil]])