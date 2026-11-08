-- Only an HONORS NameDB started says whose this line is. ndb.honorsname is
-- never cleared, so without this an HONORS sent any other way marked the last
-- person NameDB honored as a god.
if not ndb.honorsid then return end
killTimer(ndb.honorsid) ndb.honorsid = nil

disableTrigger("Honors")

if ndb.gaghonours then svo.deleteLineP() end

local temp_name_list = {}
temp_name_list[1] = {name = ndb.honorsname, immortal = 1}
db:merge_unique(ndb.db.people, temp_name_list)

local gaghonours = ndb.gaghonours
ndb.gaghonours = nil

raiseEvent("NameDB finished honors", ndb.honorsname, (gaghonours and "quiet" or "manual"))