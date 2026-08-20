setTriggerStayOpen("Clan Position Name",0)
setTriggerStayOpen("Clan Position Start",0)

clanNames = string.split(clanNames, ",? ")
local clan_name_list = {}
local added = {}
for k,v in pairs(clanNames) do 
  if not added[v] then
     clan_name_list[#clan_name_list+1] = {name = v}
  end
  added[v] = true
end
db:merge_unique(ndb.db.people, clan_name_list)
raiseEvent("NameDB got new data")
clanNames = nil