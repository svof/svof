function svo_show_classes()
  if not next(svo.enabledclasses) then svo.echof("No class tricks are enabled.") return end

  local l = svo.keystolist(svo.enabledclasses)
  table.sort(l)
  svo.echof("Enabled tricks for: %s", svo.concatand(l))
end