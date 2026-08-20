local data = string.split(line, ", ")

-- fix last name that ends with a dot
data[#data] = string.sub(data[#data], 1, #data[#data] - 1)

-- fix the 'and Name' from qw2
if data[#data]:starts("and ") then
  data[#data] = data[#data]:match("and (%w+)")
end

local city_colours = {
  ["0,255,0"] = "Eleusis",
  ["0,128,128"] = "Cyrene",
  ["255,0,0"] = "Mhaldor",
  ["128,128,0"] = "Hashan",
  ["128,0,128"] = "Ashtan",
  ["255,255,255"] = "Targossas",
  ["128,0,0"] = "Undead"
}

temp_name_list = {}

local selectString, getFgColor, format = selectString, getFgColor, string.format


-- see if we can glean off city affiliation off qwc colours
for _, name in ipairs(data) do
  temp_name_list[#temp_name_list + 1] = {name = name}

  if selectString(name,1) >= 0 then
    local r,g,b = getFgColor()
    local rgb = format("%d,%d,%d", r,g,b)
    if city_colours[rgb] then
      temp_name_list[#temp_name_list].city = city_colours[rgb]
    else
      temp_name_list[#temp_name_list].city = "rogue"
    end
    setFgColor(192,192,192)
    deselect()
  end

end
