bdayTable = bdayTable or {}
bdayTable[#bdayTable+1] = matches[2]

svo.prompttrigger("namedb capture birtdhdays", function()
	local temp_name_list = {}

	for i,j in ipairs(bdayTable) do
		temp_name_list[#temp_name_list + 1] = {
			name = j
		}
	end

	db:merge_unique(ndb.db.people, temp_name_list)

	raiseEvent("NameDB got new data")
	bdayTable = nil
end)