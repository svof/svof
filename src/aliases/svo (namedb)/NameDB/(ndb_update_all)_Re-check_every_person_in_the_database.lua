local alldata = db:fetch(ndb.db.people)

if not svo.conf.autocheck or not svo.conf.usehonors then
	svo.echof("Both vconfig usehonors and vconfig autocheck must be set to yes to update all entries.")
	return 
end
if #alldata >= 100 and not ndb.updateall then
  svo.echof("Are you really sure you want to re-check everybody in the database? You've got %d names - this'll take a while. If yes, do this again.", #alldata)
  svo.showprompt()
  ndb.updateall = true
  return
end

ndb.updateall = nil
ndb.fixed_set(ndb.db.people.xp_rank, -1)

svo.echof("Re-checking all %d known people in NameDB.", #alldata)
raiseEvent("NameDB got new data")