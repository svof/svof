function offererPrio(_, module)
  if module ~= "svo (offering)" then return true end
  tempTimer(0, [[setModulePriority("]]..module..[[", 1)]])
end

registerAnonymousEventHandler("sysInstall", "offererPrio", true)

svo = svo or {}
svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (offering)"] = 1