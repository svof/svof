svo.echof("Added %s to the do queue %s times%s", matches[3], matches[2], (not svo.me.dopaused and '' or ", but do queue is paused (dop)"))
for i = 1, tonumber(matches[2]) do
  svo.doadd(matches[3], false)
end