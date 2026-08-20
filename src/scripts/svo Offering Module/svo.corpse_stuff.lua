function svo.corpse_stuff()
  local List = gmcp.Char.Items.List
  if not svo.off_preaction or
     not ((List.location == "inv" and svo.off_preaction ~= "get") or
          (List.location == "room" and svo.off_preaction == "get")) then
    return
  end -- end early if we won't be handling this anyhow.
  local preaction = svo.off_preaction
  local action = svo.off_action
  if List.location == "room" and preaction == "get" then
    for k,v in pairs(List.items) do
      if v.attrib and v.attrib:find("d") then
        svo.doaddfree("get " .. v.id)
      elseif v.name:find("the corpse of") then
        svo.doaddfree("get " .. v.id)
      end
    end
  else
    local t = List.items
    local havekris, haveselfish
    if svo.defkeepup[svo.defs.mode].selfishness then
      svo.defs.keepup("selfishness", false)
      haveselfish = true
    end
    if svo.off_preaction == "offer" then 
      -- see if we got a kris, if we need it
      for _, item in pairs(t) do
        if item.name and item.name == "a sacrificial kris" then
          svo.doaddfree("unwield right$wield kris")
          havekris = true
          break
        end
      end
      -- now do business
      svo.doaddfree("offer corpses")
    else
      for _, item in pairs(t) do
        if item.name and string.find(item.name, "the corpse of", 1, true) then
          if svo.off_preaction == "defile" then
            svo.doadd("offer "..item.id.." to defile")
          elseif svo.off_preaction == "sanctify" then
            svo.doadd("offer "..item.id.." to sanctify")
          elseif svo.off_preaction == "give" then
            svo.doaddfree("give "..item.id.." to "..svo.off_action)
				  elseif svo.off_preaction == "put" then
				  	svo.doaddfree("put "..item.id.." in "..svo.off_action)
				  elseif svo.off_preaction == "drop" then
					  svo.doaddfree("drop "..item.id)
          end
        end
      end
    end
    if havekris then
      svo.doaddfree("unwield kris")
    end

    if haveselfish then
      svo.doadd("vkeep selfishness on")
    end
  end
  svo.doadd(function() disableTrigger("Shrine full/gone") end)
  svo.off_preaction = nil
end