-- handles unignoring sleeping after waking up
function svo.sleeping(_, aff)
  if aff ~= "sleep" then return end

  if svo.ignore.sleep and svo.ignore.sleep.because and svo.ignore.sleep.because == "you wanted to sleep" then
    svo.ignore.sleep = nil
  end
end