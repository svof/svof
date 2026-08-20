svo.me.lastradiancer = multimatches[2][2]
tempTimer(30, [[svo.me.lastradiancer = nil]])

svo.givewarning({
	initialmsg = multimatches[2][2].." radiancing you (2/7)",
	prefixwarning = multimatches[2][2].." radiancing",
	duration = 2
})

svo.startedfighting("monk", multimatches[2][2])