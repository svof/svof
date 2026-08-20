local temp_name_list = { {name = matches[2], xp_rank = -1} }

db:merge_unique(ndb.db.people, temp_name_list)

raiseEvent("NameDB got new data")