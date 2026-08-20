if not target or not matches[2]:lower():find(target:lower(), 1, true) then return end

svo.rt_name = matches[2]
svo.rt_razed = true
tempTimer(2, [[svo.rt_razed = nil]])

selectCurrentLine()
setFgColor(0, 170, 255)
resetFormat()
deselect()