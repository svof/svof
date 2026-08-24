if matches[3]:lower() == "dragon" then matches[3] = nil end

temp_name_list[#temp_name_list + 1] = {
  name = matches[2],
  class = (matches[3] and matches[3]:lower()),
  guild = ndb.findfromtable(gmcp.Char.Status.house, ndb.valid.houses)
}