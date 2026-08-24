svo.defs.keepup("meditate", matches[2], nil, true)

if not svo.conf.medprone then return end

if svo.defkeepup[svo.defs.mode].meditate then
  svo.ignore.prone = true
  echo'\n' svo.echof("Added prone to ignore as well, so you can sit while meditating.")
else
  svo.ignore.prone = nil
  svo.echof("Took prone off ignore.")
  sendSocket"\n"
end