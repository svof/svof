local name = multimatches[2][2]

db:merge_unique(ndb.db.people, {{
  name = name,
  city = gmcp.Char.Status.city:match("^(%w+)"),
  city_rank = 1,
}})

raiseEvent("NameDB got new data")