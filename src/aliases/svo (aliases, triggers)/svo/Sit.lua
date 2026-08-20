svo.ignore.prone = {because = "you sat down"}
raiseEvent("svo ignore changed", "prone")

if svo.sittingdown then killTimer(svo.sittingdown) end
svo.sittingdown = tempTimer(1, function()
  if not svo.affl.prone then svo.ignore.prone = nil; raiseEvent("svo ignore changed", "prone") end
end)


send(command)