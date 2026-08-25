function svo.classchange(override)
  local newclass = (override ~= "gmcp.Char.Status") and override or gmcp.Char.Status.class
	local temp_defs = {}
  
	-- if you're in an unrecognised class, use the None system
	if not svo.knownskills[newclass:lower()] then newclass = "None" end
		
	-- save general defences in temp table, so svo doesn't waste resources
	-- deffing what is already up	
  for k,v in pairs(svo.defc) do
    if v then
      if not svo.defs_data[k] then
        svo.defc[k] = nil
      else
        if svo.defs_data[k].type == "general" then
          temp_defs[k] = true
        end
      end
    end
  end
	
  if svo.me.class ~= newclass then
    svo.sk.gettingfullstats = false
    local oldclass = svo.me.class
    
    -- kill temporary defense triggers for old class
    for k,v in pairs(svo.defencetemptriggers) do
      killTrigger(v)
    end
    svo.defencetemptriggers = {}
    svo.me.class = newclass
    svo.signals.saveconfig:emit()
		
		-- reset all serverside prios so serverside doesn't spam class-specific defences
		-- it's a bug in the game that serverside still tries to put up defences you can't
    svo.sk.resetserversideprios()
		svo.dict = {}
    svo.systemloaded = false; svo_init_system()
    for defname,v in pairs(temp_defs) do
      svo.defences.got(defname)
    end

    svo.echof("Changed your Svof from %s over to %s.", oldclass, svo.me.class)
    
		-- if system is not paused after dragonforming, unpause serverside
    if not svo.conf.paused then
      svo.app("off")
    end
  end
end