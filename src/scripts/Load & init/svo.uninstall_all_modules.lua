-- Svof ships as a single package now, so uninstalling is Mudlet's job and
-- there is nothing to tear down module by module. This only has to notice that
-- the system has gone and stop the loader from thinking it is still up, so a
-- later reinstall in the same session starts from a clean state.

function svo.uninstall_all_modules(_, name)
  if name and name ~= "svof" then return end

  svo.systemloaded = nil

  -- stop anything still scheduled from acting on a system that is going away
  if svo.signals and svo.signals.saveconfig then
    pcall(function() svo.signals.saveconfig:emit() end)
  end
end
