svo.valid.diag_bleeding(matches[2])

if tonumber(matches[2]) >= 500 then
  selectString(matches[2], 1)
  fg("red")
  bg("white")
  deselect()
  resetFormat()
end