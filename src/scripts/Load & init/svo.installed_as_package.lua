function svo.installed_as_package(_, installedpackage)
  if not (installedpackage == "svo (install me in module manager)"
	  or installedpackage == "Svof - dont install me as package") then return end
	
	if svo_installed_as_package then killTimer(svo_installed_as_package) end
	svo_installed_as_package = tempTimer(0, function() cecho(
[[<indian_red>Svof needs to be installed as a module, not a package -
please uninstall it and instead install using the <orange_red>Module Manager<indian_red>!
]])
  svo_installed_as_package = nil
  end)
end