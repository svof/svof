local person = multimatches[2][2]:trim()

if selectString(person, 1) > 0 then fg("red") setBold(true) deselect() resetFormat() end

svo.givewarning_multi({
	initialmsg = person.." has deliverance",
	prefixwarning = "deliverance in room",
	duration = 1
})