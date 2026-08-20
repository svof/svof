svo.loader.fishdist = function()
  svo.adddefinition("@fishdist", "svo.telldistance()")
  -- returns the value of the 'baited' 'no line out' or the distance
  function svo.telldistance()
    if fdistance == "baited" then return "<light_sky_blue>baited" elseif fdistance == "lineout" then return "<dark_green>Line out, no bait!" elseif fdistance then return "<slate_blue>"..fdistance.." feet out" else return "<medium_sea_green>no line out" end
  end

  if type(svo.conf.fishhighlight) ~= 'nil' then
    if svo.conf.fishhighlight then enableTrigger"svo Fishing Distance by Trilliana" else
    disableTrigger"svo Fishing Distance by Trilliana" end
  end

  svo.config.setoption("fishhighlight",
  {
   vconfig2string = true,
    type = "boolean",
    onenabled = function ()
      enableTrigger"svo Fishing Distance by Trilliana"
      svo.echof("<0,250,0>Will%s show highlights for fishing.", svo.getDefaultColor())

      if not string.find(svo.conf.customprompt, "@fishdist", 1, true) then
        svo.config.set("customprompt", svo.conf.customprompt .." @fishdist", false)
        svo.echof("Added the fishing distance to your custom prompt as well.")
      end
    end,
    ondisabled = function ()
      disableTrigger"svo Fishing Distance by Trilliana"

      if string.find(svo.conf.customprompt, "@fishdist", 1, true) then
        svo.config.set("customprompt", svo.conf.customprompt:gsub(" @fishdist", ""), false)
        svo.echof("Removed the fishing distance tag from your custom prompt.")
      end

      svo.echof("<250,0,0>Won't%s show highlights for fishing.", svo.getDefaultColor())
    end,
    onshow = function (defaultcolour)
      fg("gold")
      echoLink("fishing dist:", "", "svo Fishing Distance by Trilliana", true)
      fg(defaultcolour)
      echo(" Fishing highlights are ")
      fg("a_cyan") echoLink(svo.conf.fishhighlight and "enabled" or "disabled", "svo.config.set('fishhighlight', "..(svo.conf.fishhighlight and "false" or "true")..", true)", "Click to "..(svo.conf.fishhighlight and "disable" or "enable").." fishing highlight triggers", true) fg(defaultcolour)
      echo(".\n")
  end})
end