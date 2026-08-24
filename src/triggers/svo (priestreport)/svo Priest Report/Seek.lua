svo.locating.location = multimatches[2][2]
svo.locating.hp = tonumber(multimatches[2][3])
svo.locating.mp = tonumber(multimatches[2][4])

if mmp and svo.locating.name then
  mmp.pdb[svo.locating.name] = svo.locating.location
  mmp.pdb_lastupdate[svo.locating.name] = true
  raiseEvent("mmapper updated pdb")
end