svo.forestwolf = svo.forestwolf or {}
svo.forestwolf[#svo.forestwolf+1] = multimatches[2][2]

deleteLine()
svo.prompttrigger("forest wolf", function()
  svo.echof("<223,0,255>forest defs%s (wolf) hit %s.", svo.getDefaultColor(), svo.concatand(svo.forestwolf))
  svo.forestwolf = nil
end)