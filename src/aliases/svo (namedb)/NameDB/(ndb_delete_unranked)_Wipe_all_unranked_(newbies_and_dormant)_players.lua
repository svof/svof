local howmany = #db:fetch(ndb.db.people, db:eq(ndb.db.people.xp_rank, -2))

if not ndb.deleteunranked then
  svo.echof("Are you really sure you want to wipe the database of all unranked people? This will affect newbies and dormant players and get rid of %s entries.", howmany)
  svo.showprompt()
  ndb.deleteunranked = true
  return
end


ndb.deleteunranked = nil
db:delete(ndb.db.people, db:eq(ndb.db.people.xp_rank, -2))

-- clear highlights
ndb.loadhighlights()

svo.echof("Wiped %s unranked players from NameDB.", howmany)
svo.showprompt()