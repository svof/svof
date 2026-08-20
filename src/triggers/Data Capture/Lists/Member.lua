if matches[2] == "Total" then return end

local class = line:sub(47):match("^(%w+)")
if class and class:lower() == "dragon" then class = nil end

temp_name_list[#temp_name_list + 1] = {
  name = matches[2],
  class = class,
  order = gmcp.Char.Status.order:match("(%w+)")
}