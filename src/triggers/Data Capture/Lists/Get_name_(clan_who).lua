local match = getColorWildcard(14)

if match then
	local title = line:gsub(" %(off channel%)", "")

	temp_name_list[#temp_name_list + 1] = {
		name = match[1],
		title = title
	}

	-- if we know a class, add it in
	local class = ndb.getclass(match[1])
	local dragon
	if ndb.isdragon then dragon = ndb.isdragon(ndb.findname(line)) end

	if class and class ~= "" then
		class = class:title()
		echo((" "):rep(70-#line))
		cecho("<a_darkwhite>("..class..")")
		ndb.temp_classes_list[class] = (ndb.temp_classes_list[class] or 0) + 1
		if dragon then cecho(" <a_darkwhite>(Dragon)") temp_dragon = temp_dragon +1 end
	elseif dragon then echo((" "):rep(70-#line)) cecho("<a_darkwhite>(Dragon)") temp_dragon = temp_dragon +1 
	end
end