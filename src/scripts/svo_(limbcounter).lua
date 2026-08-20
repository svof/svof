function limbcounterPrio(_, module)
  if module ~= "svo (limbcounter)" then return true end
  tempTimer(0, [[setModulePriority("]]..module..[[", 0)]])
end

svo = svo or {}; svo.loader = svo.loader or {}
registerAnonymousEventHandler("sysInstall", "limbcounterPrio", true)