-- the temple flick gives a mangled head, not the game's concussion (the user,
-- 2026-10-31). The trigger keeps the name it had when svof called that
-- seriousconcussion
if svo.conf.aillusion and not (svo.enabledskills.vodun or svo.enabledskills.puppetry) then
  svo.ignore_illusion("Ignored a mangled head - we don't seem to be fighting a Shaman or a Jester (tn shaman or tn jester if you are)")
else
  svo.valid.simplemangledhead()
end