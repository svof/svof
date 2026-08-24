local aff = multimatches[2][2]
if table.contains(svo.scragaffs, aff) then
  svo.valid["simple"..aff]()
end
svo.valid.bloodleech()