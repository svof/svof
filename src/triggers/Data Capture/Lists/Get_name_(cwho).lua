resetFormat()
local match = getColorWildcard(14)

if match then
  local matches = multimatches[1]
  local isdragon
  if (matches[4] and matches[4]:lower():find("dragon")) then matches[4] = nil; isdragon = true end

  temp_name_list[#temp_name_list + 1] = {
    name = match[1],
    class = (matches[4] and matches[4]:lower()),
    city_rank = tonumber(matches[3]),
    city = gmcp.Char.Status.city:match("^(%w+)")
  }

  if isdragon then temp_name_list[#temp_name_list].dragon = 1 end

	-- if we know a class, add it in
	local class = ndb.getclass(match[1])
	local dragon
	if ndb.isdragon then dragon = ndb.isdragon(match[1]) end

	if class and class ~= "" then
		ndb.temp_classes_list[class] = (ndb.temp_classes_list[class] or 0) + 1
	if matches[4] and dragon  then cecho(" <a_darkwhite>(Dragon)") temp_dragon = temp_dragon +1 elseif dragon then cecho(" <a_darkwhite>("..class:title()..")") temp_dragon = temp_dragon +1 
	end end
end