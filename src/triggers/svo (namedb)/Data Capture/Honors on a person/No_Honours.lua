if ndb.honorsid then killTimer(ndb.honorsid) ndb.honorsid = nil else return end

disableTrigger("Honors")

if ndb.gaghonours then svo.deleteLineP() end

echo("\n")
svo.echof(ndb.honorsname .. " doesn't exist anymore, deleted them.")
local deletedname = ndb.honorsname

db:delete(ndb.db.people, db:eq(ndb.db.people.name, ndb.honorsname))
svo.debugf("deleted %s", ndb.honorsname)

local gaghonours = ndb.gaghonours
ndb.gaghonours = nil

raiseEvent("NameDB finished honors", "", (gaghonours and "quiet" or "manual"))

raiseEvent("NameDB name deleted", deletedname)