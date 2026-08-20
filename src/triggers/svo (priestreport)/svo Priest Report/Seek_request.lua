if svo.defc.dragonform then return end

local clans = {
	["The Dawnguard"] = "dg",
	["Eleusian Rangers"] = "er",
	["Cyrene City Guard"] = "ccg",
	["Party"] = "party",
	["Army"] = "art",
}

if not clans[matches[2]] then echo"\n" svo.echof("This clans short name isn't known - please add it to the 'Seek request' trigger. Can't report the seek back otherwise!") return end

svo.locating = {clan = clans[matches[2]], name = matches[3]}
svo.doaddfree("angel seek "..svo.locating.name)