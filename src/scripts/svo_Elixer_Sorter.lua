function elistPrio(_, module)
  if module ~= "svo (elistsorter)" then return true end
  tempTimer(0, [[setModulePriority("]]..module..[[", 0)]])
end

registerAnonymousEventHandler("sysInstall", "elistPrio", true)

svo = svo or {}; svo.loader = svo.loader or {}
svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (elistsorter)"] = 1.1