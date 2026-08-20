-- separate trigger not to reset the stopwatch often
if svo.bals.prayer ~= nil then
  svo.valid.usedprayerbalance()
end