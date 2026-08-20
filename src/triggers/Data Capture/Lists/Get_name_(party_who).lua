resetFormat()

local match = ndb.findname(line)
if match then
	temp_name_list[#temp_name_list + 1] = {
		name = ndb.findname(line),
		title = line
	}

	-- if we know a class, add it in
	local class = ndb.getclass(ndb.findname(line))
	local dragon
	if ndb.isdragon then dragon = ndb.isdragon(ndb.findname(line)) end

	if class and class ~= "" then
		echo((" "):rep(60-#line))
		cecho("<a_darkwhite>("..class:title()..")")
		ndb.temp_classes_list[class] = (ndb.temp_classes_list[class] or 0) + 1
		if dragon then cecho(" <a_darkwhite>(Dragon)") temp_dragon = temp_dragon +1 end
	elseif dragon then echo((" "):rep(60-#line)) cecho("<a_darkwhite>(Dragon)") temp_dragon = temp_dragon +1 
	end
end