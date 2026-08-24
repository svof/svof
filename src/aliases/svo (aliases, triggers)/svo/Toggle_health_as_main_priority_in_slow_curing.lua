if not svo.inslowcuringmode() then
	svo.echof("We aren't in slow curing mode.")
	return
end

if not svo.sac_mainhealth then
	svo.sac_mainhealth = true
	svo.prio_makefirst("healhealth", "sip")
	svo.echof("Set health as main priority.")
else
	svo.sac_mainhealth = false
	svo.prio_undofirst()
	svo.echof("Removed health as main priority.")
end