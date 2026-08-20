if not ndb.deleteall then
  svo.echof("Are you really sure you want to wipe the database completely clean? Nothing will be saved, and this is irreversible. If yes, do this again.")
  svo.showprompt()
  ndb.deleteall = true
  return
end

ndb.deleteall = nil
db:delete(ndb.db.people, true)

-- clear highlights
ndb.loadhighlights()

svo.echof("Database completely wiped.")
svo.showprompt()