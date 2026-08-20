local aff = multimatches[2][2]
if table.contains(svo.nemesisaffs, aff) then
  (svo.valid["proper_"..aff] or svo.valid["simple"..aff])()
end