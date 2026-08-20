svo.rt_sname = multimatches[2][2]
svo.rt_flayed = true
tempTimer(2, [[if svo.rt_flayed then svo.rt_flayed = nil end]])

selectCurrentLine()
setFgColor(0, 170, 255)
resetFormat()
deselect()