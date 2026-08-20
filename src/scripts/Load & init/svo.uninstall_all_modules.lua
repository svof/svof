-------------------------------------------------
--         Put your Lua functions here.        --
--                                             --
-- Note that you can also use external Scripts --
-------------------------------------------------
function svo.uninstall_all_modules(event,modulename)
  if event and (modulename ~= "svo (install me in module manager)") then return true end

  for ourmodule,_ in pairs(svo.modules_version) do
    if not event or (ourmodule ~= "svo (install me in module manager)") then
      disableModuleSync(ourmodule) -- need to disable module before uninstalling first due to a bug in Mudlet module sync
      tempTimer(0, function()
  	  uninstallModule(ourmodule)
      end)
    end
  end
	svo.systemloaded = nil
end