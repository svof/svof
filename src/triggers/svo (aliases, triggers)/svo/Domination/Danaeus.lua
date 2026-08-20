local aff = multimatches[2][2]
if table.contains(svo.danaeusaffs, aff) then
  (svo.valid["proper_"..aff] or svo.valid["simple"..aff])()
end