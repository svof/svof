function fishdistPrio(_, module)
  if module ~= "svo (fishdist)" then return true end
  tempTimer(0, [[setModulePriority("]]..module..[[", 0)]])
end

registerAnonymousEventHandler("sysInstall", "fishdistPrio",true)

svo = svo or {}; svo.loader = svo.loader or {}
svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (fishdist)"] = 1