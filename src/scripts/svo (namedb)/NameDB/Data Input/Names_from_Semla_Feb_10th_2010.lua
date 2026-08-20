if true then return end

--

local temp_name_list = {}

for key,value in pairs(citizens:split("|")) do
	temp_name_list[key] = {name = value, xp_rank = -1}
end

db:merge_unique(ndb.db.people, temp_name_list)

raiseEvent("NameDB got new data")