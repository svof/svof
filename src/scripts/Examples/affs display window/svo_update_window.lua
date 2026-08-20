-- delete the line below and enable vconfig eventaffs plus this script for this demo to work!
if true or not Geyser then return end

local affslabel

local main = Geyser.Container:new({x=0,y=0,width="100%",height="100%",name="affslabelcontainer"})

affslabel = Geyser.Label:new({  name = "affslabel",
                               x = "87%", y = "80%",
                               width = "11%", height = "17%"},
                               main)
-- this sets the colour of the whole label to greenish
affslabel:setColor(100,155,0,127)

local function highlight(name)
	if not svo.ignore[name] then return name else
	return string.format([[<span style="color:yellowgreen">%s</span>]], name) end
end

function svo_update_window()
local s = {}
	if not affslabel then return end

	for name, namet in pairs(svo.affl) do
		if name ~= "deaf" and name ~= "blind" then
			if type(namet) == "table" and namet.count then
				s[#s+1] = string.format("%s (%d)", highlight(name), namet.count)
			else
				s[#s+1] = highlight(name)
			end
		end
	end
	affslabel:echo([[<span style="color:white">]].. table.concat(s, "<br>") .."</span>")
end