function enchanterPrio(_, module)
  if module ~= "svo (enchanter)" then return true end
  tempTimer(0, [[setModulePriority("]]..module..[[", 0)]])
end

registerAnonymousEventHandler("sysInstall", "enchanterPrio", true)
svo = svo or {}; svo.loader = svo.loader or {}
svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (enchanter)"] = 1