-- Svof consists of multiples Mudlet modules which need to be loaded in the correct order
-- (since a module can require functions already defined in another module)
-- this loader will load them in the correct order by calling the svo.loader.* function 
-- each file defines


-- Loads the system independent of the order of xmls/modules got installed within Mudlet
-- also used when the system needs to be reloaded with a new class
function svo_init_system()
  if svo.systemloaded then return end

  -- list of required Svof subsystems that need to be loaded before we can
	-- load everything else that starts on the 'svo.signals.systemstart' event
  local required_subsystems = {
    'setup',
    'misc',
    'empty',
    'dict',
    'sk',
    'controllers',
    'action',
    'pipes',
    'rift',
    'diag',
    'valid_simple',
    'valid_main',
    'config',
    'install',
    'aliases',
    'defences',
    'prio',
    'parry',
    'funnies',
    'dor',
    'customprompt',
    'serverside',
    --'peopletracker',
  }
	
  -- addons that make use of the loader mechanism to load after the system is loaded
	local addons = {
	  'limbcounter',
		'priestreporter',
    'inker',
    --new ones
    'mindnet',
    'burncounter',
    'elistsorter',
    'enchanter',
    'refiller',
    'peopletracker',
    'fishdist',
    
	}
	
	-- Penlight is not loaded yet	
	if not package.loaded['pl.tablex'] then return end
		
	local tablex = require('pl.tablex')
	local loaded_subsystems = tablex.keys(svo.loader)
	
	-- check if any of the required modules are missing
	if not table.is_empty(table.n_complement(required_subsystems, loaded_subsystems)) then
	  return
	end
	
	-- ensure Mudlet is new enough for the system to work without issues
	if not mudletOlderThan or mudletOlderThan(3,20) then
	  cecho("<SkyBlue:firebrick>Can't load Svof: your Mudlet is too old for the system to run well.\nPlease update to latest to enjoy it!\n")
		return
	end
	
  --clears all signals in case of a reload (e.g. classchange)
  svo.signals = nil
  
	for _, subsystem in ipairs(required_subsystems) do
	  svo.loader[subsystem]()
	end

  svo.signals.systemstart:emit()
  svo.systemloaded = true
  raiseEvent("svo system loaded")
	
	-- if we're already logged in when the system is installed, initialise a few other things
	if gmcp and gmcp.Char and gmcp.Char.Name then
	  svo.signals.gmcpcharname:emit()
	end
	
  svo.echofn("Loaded & ready to go, version %s (", tostring(svo.version))
  echoLink("homepage", 'openUrl"http://svof.github.io/svof"', "Svof homepage")
  decho(svo.getDefaultColor()..")\n")
	
	-- load any addons that wait for the system to load,
	-- plus ensure only the class-specific limbcounter is present
	for _, addon in ipairs(addons) do
	  if svo.loader[addon] then svo.loader[addon]() end
	end
	
	-- setup prompt stats on a reload
	if force_init then sendSocket("\n") end
end