-- svo
for i = 1, #matches, 2 do
  selectString(matches[i], 1)
  setFgColor(150,151,150)

  selectString(matches[i+1], 1)
  fg("white")
  deselect()
  resetFormat()
end