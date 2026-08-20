if not temp_name_list then return end

if ndb.isvalidhouse(matches[2]) then
  temp_name_list[1].guild = matches[2]
end