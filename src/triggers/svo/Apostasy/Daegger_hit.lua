if not svo.hunt then return end

svo.givewarning_multi({
  initialmsg = tostring(svo.hunt).." used hunt - shield to stop it if on you!"
})
svo.startedfighting("apostate", svo.hunt)