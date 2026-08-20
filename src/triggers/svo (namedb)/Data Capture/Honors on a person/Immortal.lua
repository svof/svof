if ndb.honorsid then killTimer(ndb.honorsid) ndb.honorsid = nil end

disableTrigger("Honors")

if ndb.gaghonours then svo.deleteLineP() end

local temp_name_list = {}
temp_name_list[1] = {name = ndb.honorsname, immortal = 1}
db:merge_unique(ndb.db.people, temp_name_list)

local gaghonours = ndb.gaghonours
ndb.gaghonours = nil

raiseEvent("NameDB finished honors", ndb.honorsname, (gaghonours and "quiet" or "manual"))