local match = getColorWildcard(14)

if match then
  if matches[2]:lower() == "dragon" then matches[2] = nil end

  temp_name_list[#temp_name_list + 1] = {
    name = match[1],
    class = ((matches[2] and ndb.isvalidclass(matches[2])) and matches[2]:lower() or ""),
    guild = ndb.findfromtable(gmcp.Char.Status.house, ndb.valid.houses)
  }
end