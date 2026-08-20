if svo.conf.aillusion and not (svo.enabledskills.vodun or svo.enabledskills.puppetry) then
  svo.ignore_illusion("Mildtrauma ignored - we don't seem to be fighting a Shaman or a Jester")
else
  svo.valid.simplemildtrauma()
end