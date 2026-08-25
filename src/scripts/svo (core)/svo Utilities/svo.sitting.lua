-- handles getting up after a manual sit
function svo.sitting(_, aff)
  if aff ~= "prone" then return end

  if svo.ignore.prone and svo.ignore.prone.because and svo.ignore.prone.because == "you sat down" then
    svo.ignore.prone = nil
    raiseEvent("svo ignore changed", "prone")
  end
end