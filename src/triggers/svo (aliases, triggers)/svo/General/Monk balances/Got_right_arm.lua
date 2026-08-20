svo.bals.rightarm = true
raiseEvent("svo got balance", "rightarm")
if svo.regain_both_arms then svo.bals.leftarm = true raiseEvent("svo got balance", "leftarm"); svo.regain_both_arms = nil end

svo.gotarmbalance()