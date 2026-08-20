function priestReportPrio(_, module)
  if module ~= "svo (priestreport)" then return true end
  tempTimer(0, [[setModulePriority("]]..module..[[", 0)]])
end

registerAnonymousEventHandler("sysInstall", "priestReportPrio", true)

svo = svo or {}; svo.loader = svo.loader or {}
svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (priestreport)"] = 1