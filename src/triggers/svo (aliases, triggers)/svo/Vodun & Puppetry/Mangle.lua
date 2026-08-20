if svo.conf.aillusion and not (svo.enabledskills.vodun or svo.enabledskills.puppetry) then
  svo.ignore_illusion("Ignored mangle - we don't seem to be fighting a Shaman or a Jester")
else
  svo.valid["simplemutilated"..multimatches[2][2]..multimatches[2][3]]()
end