ndb = ndb or {}

function ndbPrio(_, module)
  if module ~= "svo (namedb)" then return true end
  tempTimer(0, [[setModulePriority("]]..module..[[", 1)]])
end

registerAnonymousEventHandler("sysInstall", "ndbPrio", true)

svo = svo or {}
svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (namedb)"] = 1