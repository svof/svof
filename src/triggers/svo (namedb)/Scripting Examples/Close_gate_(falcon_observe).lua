setTriggerStayOpen("Falcon observe", 0)

local function say(tbl, affiliation)
	if not next(tbl) then return end

	local temp = {}
	for i,j in pairs(tbl) do
		temp[#temp+1] = string.format("%s %d%%hp", i, j)
	end

	svo.cc("%s outside in area: %s", affiliation, svo.concatand(temp))
end


say(parse_enemies, "Enemies")
parse_enemies = nil