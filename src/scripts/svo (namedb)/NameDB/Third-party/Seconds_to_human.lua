-- credit: http://www.gammon.com.au/forum/?id=12494&reply=6#reply6
function seconds2human(input)
  local seconds = input
  local hours = math.floor(seconds/3600) -- only returns whole numbers
  seconds = seconds%3600 -- returns remainder of previous division
  local minutes = math.floor(seconds/60) -- only whole numbers again
  seconds = seconds%60 -- final remainder

  return hours, minutes, seconds
end