svo.givewarning({
	initialmsg = string.format("An alchemist started displacing you! Move rooms, or make the alchemist do something. 9s before getting moved"),
	prefixwarning = "getting displaced",
	startin = 1,
	duration = 2
})

local currentroom = gmcp.Room.Info.name

svo.displacerooms = svo.displacerooms or {}
svo.displacerooms[#svo.displacerooms+1] = currentroom

--[[tempTimer(9+1, function()
  local i = table.index_of(svo.displacerooms, currentroom)
  if i then
    table.remove(svo.displacerooms, i)
    svo.echof(currentroom.." should be safe to move back into now.")
  end
end)]]