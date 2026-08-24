-- Act on lost/gained affs
-- can be used, for example, to stop an instakill if you've gotten hindered - unpause system, unpause offense, etc.
-- must have vconfig eventaffs on
function svo_example_affs(eventname, data)
	svo.echof("Event: %s, data: %s", eventname, data)
--	tempTimer(0, function() svo.echof("Event: %s, data: %s", eventname, data) end)
end