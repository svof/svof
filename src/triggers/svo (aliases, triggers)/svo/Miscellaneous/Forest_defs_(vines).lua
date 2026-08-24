svo.forestvines = svo.forestvines or {}
svo.forestvines[#svo.forestvines+1] = matches[2] or "you"

deleteLine()
svo.prompttrigger("forest vines", function()
  svo.echof("<223,0,255>forest defs%s (vines) hit %s.", svo.getDefaultColor(), svo.concatand(svo.forestvines))
  svo.forestvines = nil
end)