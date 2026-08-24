svo.valid.bled()
svo.valid.simplecorrupted()

if tonumber(multimatches[2][2]) >= 500 then
  selectString(multimatches[2][2], 1)
  fg("red")
  bg("white")
  deselect()
  resetFormat()
end