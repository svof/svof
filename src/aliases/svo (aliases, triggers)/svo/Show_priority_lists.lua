if matches[2] == "serveraffs" then
	svo.sk.serverprios_show(matches[3])
elseif matches[2] == "serverdefs" then
	svo.echof("Svof doesn't show serverside defence numbers yet. CURING PRIORITY DEFENCE LIST shows the game's.")
elseif matches[3] and matches[3] ~= "" then
	svo.echof("Only vp serveraffs takes slowcuring after it. For Svof's own slowcuring list, use vp slowcuring.")
elseif matches[2] == "slowcuring" then
	svo.printordersync()
else
	svo.printorder(matches[2])
end