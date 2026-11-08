if not temp_name_list then return end

-- "He is a member of the Shaman class."
local class = matches[2]:lower()
if ndb.isvalidclass(class) then temp_name_list[1].class = class end
