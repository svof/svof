local temp_name_list = temp_name_list or {}

temp_name_list[#temp_name_list + 1] = {
  name = multimatches[2][2],
  class = ndb.isvalidclass(multimatches[2][3]) and multimatches[2][3]:lower() or "",
  city = ndb.isvalidcity(multimatches[2][4]) and multimatches[2][4]:title() or ""
}

db:merge_unique(ndb.db.people, temp_name_list)

raiseEvent("NameDB got new data")