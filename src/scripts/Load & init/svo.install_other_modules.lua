function svo.install_other_modules(_, installedmodule)
  if installedmodule ~= "svo (install me in module manager)" then return end
	
	local modules_list = svo.modules_list
	
	local current_module_name = 'svo (install me in module manager)'
	local basepath = getModulePath(current_module_name)
	-- -4 to account for the .xml ending
	basepath = basepath:sub(1, #basepath-#current_module_name-4)
	
	-- if Mudlet does not support enableModuleSync(), ask the person to do it manually
	local warn_manual_sync
	
	-- install missing modules & sync if Mudlet supports it
	for _, modulename in ipairs(modules_list) do
	  if not getModulePath(modulename) then
		  local modulepath = basepath..modulename..".xml"
			
			if io.exists(modulepath) then
  		  -- workaround for https://github.com/Mudlet/Mudlet/issues/1223
  			tempTimer(0, function()
				  installModule(basepath..modulename..".xml")
					if enableModuleSync then
					  enableModuleSync(modulename)
					else
					  if warn_manual_sync then killTimer(warn_manual_sync) end
					  warn_manual_sync = tempTimer(0, svo.ask_to_sync_manual)
					end
				end)
			end
		end
	end
	
	-- sync this module too
	if enableModuleSync then enableModuleSync('svo (install me in module manager)') end
end

function svo.ask_to_sync_manual()
	cecho("\n<dark_orchid>Installed all modules - now make sure to tick 'sync' in the Module Manager for everything Svof!")
end