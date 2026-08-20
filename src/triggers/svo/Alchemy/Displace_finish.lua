if type(svo.displacerooms) == 'table' then
  local room = table.remove(svo.displacerooms, 1)
end

svo.givewarning({
	initialmsg = string.format("%s displaced you", multimatches[2][2]),
	prefixwarning = multimatches[2][2].. " displaced you (4/4)",
	startin = 0,
	duration = 1
})