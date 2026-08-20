-- The module priority this group used to set on install has no meaning in a
-- single package: load order comes from where these items sit in the tree.

svo = svo or {}; svo.loader = svo.loader or {}

-- burncounters prompt tag is defined here
-- feel free to tinker with it, but move it out into a script of its own,
-- so your changes don't get erased on an update!
-- Also remember modules are always loaded last, so you need to put it in a module 
-- in order to have it overwrite this prompttag, and to have it only fire after svo loads.

-- svo.adddefinition only exists once the core has loaded, so register on the
-- system-loaded event rather than racing it with a zero-delay timer.
local function bl_setup()
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

if svo.systemloaded then
  bl_setup()
else
  registerAnonymousEventHandler("svo system loaded", bl_setup)
end
