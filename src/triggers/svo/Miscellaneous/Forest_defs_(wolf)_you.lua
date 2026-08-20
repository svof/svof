svo.forestwolf = svo.forestwolf or {}
svo.forestwolf[#svo.forestwolf+1] = "you"

deleteLine()
svo.prompttrigger("forest wolf", function()
  svo.echof("<223,0,255>forest defs%s (wolf) hit %s.", svo.getDefaultColor(), svo.concatand(svo.forestwolf))
  svo.forestwolf = nil
end)