svo = svo or {}; svo.loader = svo.loader or {}
svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (burncounter)"] = 1

function burnPrio(_, module)
  if module ~= "svo (burncounter)" then return true end
  tempTimer(0, [[setModulePriority("]]..module..[[", 0)]])
end

registerAnonymousEventHandler("sysInstall", "burnPrio", true)

-- burncounters prompt tag is defined here
-- feel free to tinker with it, but move it out into a script of its own,
-- so your changes don't get erased on an update!
-- Also remember modules are always loaded last, so you need to put it in a module 
-- in order to have it overwrite this prompttag, and to have it only fire after svo loads.

tempTimer(
  0,
  function()
    function svo.bl_prompttag()
      if
        svo.defc.dragonform or not svo.lasthit or not svo.bl_list or not svo.bl_list[svo.lasthit]
      then
        return ""
      end
      local t = svo.bl_list[svo.lasthit]
      return
        string.format(
          "%s%s", (t.level == 0 and '' or t.level), (t.dehydrate == 0 and '' or " (dehydrated)")
        )
    end

    svo.adddefinition("@bl", "svo.bl_prompttag()")
  end
)