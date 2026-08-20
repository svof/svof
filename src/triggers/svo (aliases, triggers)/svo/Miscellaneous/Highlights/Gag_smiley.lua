deleteLine()
if not svo.warnedsmileys then
  svo.warnedsmileys = true
  tempTimer(0.5, function() svo.echof("just saved you from seeing a giant-ass smiley."); svo.warnedsmileys = nil end)
end