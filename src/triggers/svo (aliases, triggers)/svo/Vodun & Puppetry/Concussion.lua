if svo.conf.aillusion and not (svo.enabledskills.vodun or svo.enabledskills.puppetry) then
  svo.ignore_illusion("Ignored concussion - we don't seem to be fighting a Shaman or a Jester (tn shaman or tn jester if you are)")
else
  svo.valid.simpleseriousconcussion()
end