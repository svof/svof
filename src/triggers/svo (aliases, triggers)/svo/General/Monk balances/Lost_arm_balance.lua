if svo.affl.crippledleftarm or svo.affl.mangledleftarm or svo.affl.mutilatedleftarm then
  svo.bals.rightarm = false
  raiseEvent("svo lost balance", "rightarm")
elseif svo.bals.leftarm then
  svo.bals.leftarm = false
  raiseEvent("svo lost balance", "leftarm")
else
  svo.bals.rightarm = false
  raiseEvent("svo lost balance", "rightarm")
end