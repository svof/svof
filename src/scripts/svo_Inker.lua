function inkerPrio(_, module)
  if module ~= "svo (inker)" then return true end
  tempTimer(0, [[setModulePriority("]]..module..[[", 0)]])
end

registerAnonymousEventHandler("sysInstall", "inkerPrio",true)
svo = svo or {}; svo.loader = svo.loader or {}
svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (inker)"] = 2.0