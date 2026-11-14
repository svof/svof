if matches[3] and matches[3] ~= "" then
  svo.sk.serverprios_refusecleargaps()
  return
end

svo.prio.cleargaps(matches[2], true)