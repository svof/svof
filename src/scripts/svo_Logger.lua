function loggerPrio(_, module)
  if module ~= "svo (logger)" then return true end
  tempTimer(0, [[setModulePriority("]]..module..[[", 1)]])
end

registerAnonymousEventHandler("sysInstall", "loggerPrio", true)
svo = svo or {}
svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (logger)"] = 1