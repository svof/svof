-- catches newbies who switch cities or suicide, contributed by Adet

local names = {}
local alldata = db:fetch(ndb.db.people, db:eq(ndb.db.people.xp_rank, -2))

if #alldata >= 100 and not ndb.updateunranked then
  svo.echof("Are you really sure you want to check all unranked people? You've got %d names - this'll take a while. If yes, do this again.", #alldata)
  svo.showprompt()
  ndb.updateunranked = true
  return
end
ndb.updateunranked = nil

for _, person in pairs(alldata) do
  table.insert(names, person.name)
end

local temp_name_list = {}
for i = 1, #names do 
  temp_name_list[#temp_name_list+1] = {name = names[i], xp_rank = -1}
end

db:merge_unique(ndb.db.people, temp_name_list)
raiseEvent("NameDB got new data")