function mindnetPrio(_, module)
  if module ~= "svo (mindnet)" then return true end
  tempTimer(0, [[setModulePriority("]]..module..[[", 0)]])
end

registerAnonymousEventHandler("sysInstall", "mindnetPrio", true)

svo = svo or {}; svo.loader = svo.loader or {}
svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (mindnet)"] = 1