if svo.conf.medprone then
  if svo.ignore.prone and (not svo.conf.aillusion or stats.currentmana == stats.maxmana) then
    svo.ignore.prone = nil
    echo'\n' svo.echof("Took prone off ignore, since you're done meditating.")
  end
end

if svo.conf.unmed then
  svo.defs.keepup("meditate", false)
end