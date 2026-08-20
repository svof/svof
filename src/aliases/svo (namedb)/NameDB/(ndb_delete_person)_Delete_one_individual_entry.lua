if matches[2] == "all" then return end -- handled by another alias
if matches[2] == "unranked" then return end -- handled by another alias

local name = matches[2]:title()

local exists = db:fetch(ndb.db.people, db:eq(ndb.db.people.name, name))

if not (exists and next(exists)) then svo.echof("%s doesn't exist in the database already.", name) svo.showprompt() return end

db:delete(ndb.db.people, db:eq(ndb.db.people.name, name))

raiseEvent("NameDB name deleted", name)

svo.echof("Deleted %s's entry from NameDB.", name)
svo.showprompt()