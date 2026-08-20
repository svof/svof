if matches[2] == "off" then
  if svo.me.class == "Priest" then
    svo.doadd("angel trace off", false, false)
    svo.tracing = nil
  elseif svo.me.class == "Apostate" then
    svo.doadd("demon trace off", false, false)
    svo.tracing = nil
  end
else
  svo.tracing = matches[2]:title()
  svo.tracingarea = matches[3]
  if svo.me.class == "Priest" then
    svo.doadd("angel trace "..svo.tracing)
  elseif svo.me.class == "Apostate" then
    svo.doadd("demon trace "..svo.tracing)
  end
  svo.echof("Tracing and reporting %s%s", svo.tracing, (svo.tracingarea and " only when they're in "..svo.tracingarea:title() or ''))
end