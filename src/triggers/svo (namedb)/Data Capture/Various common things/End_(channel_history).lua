setTriggerStayOpen("Channel history", 0)

db:merge_unique(ndb.db.people, ndb.temp_name_list)

ndb.temp_name_list = nil

raiseEvent("NameDB got new data")