if type(svo.displacerooms) == 'table' then
  local room = table.remove(svo.displacerooms, 1)

  svo.givewarning({
    initialmsg = string.format(multimatches[2][2].." cancelled/stopped displacing you, '"..room.."' safe to move back into")
  })
else
  svo.givewarning({
    initialmsg = string.format(multimatches[2][2].." cancelled/stopped displacing you")
  })
end

svo.startedfighting("alchemist", multimatches[2][2])