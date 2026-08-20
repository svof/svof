-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.


svo.loader.inker = function()
  local firstload = not svo.inkerLoaded    
  local tattoos = {
      firefly = {{1,'yewllowink'},},
      moss = {{1,'blueink'},{1,'redink'},{1,'yellowink'},},
      feather = {{2,'blueink'},{1,'redink'},},
      shield = {{1,'greenink'},{2,'redink'},},
      mindseye = {{2,'blueink'},{1,'greenink'},},
      hammer = {{1,'purpleink'},{2,'redink'},},
      cloak = {{3,'blueink'},},
      bell = {{3,'blueink'},{2,'redink'},},
      crystal = {{1,'greenink'},{1,'purpleink'},{1,'yellowink'},},
      moon = {{1,'blueink'},{1,'redink'},{1,'yellowink'},},
      starburst = {{1,'blueink'},{1,'goldink'},{1,'greenink'},{1,'purpleink'},{1,'redink'},{1,'yellowink'},},
      boar = {{1,'purpleink'},{2,'redink'},},
      web = {{1,'greenink'},{1,'yellowink'},},
      tentacle = {{2,'greenink'},{1,'purpleink'},},
      hourglass = {{1,'blueink'},{2,'yellowink'},},
      brazier = {{2,'redink'},{2,'yellowink'},},
      prism = {{1,'blueink'},{1,'greenink'},{1,'purpleink'},{1,'redink'},{1,'yellowink'},},
      tree = {{5,'greenink'},},
      megalith = {{2,'goldink'},},
      ox = {{1,'goldink'},{1,'redink'},{1,'yellowink'},{1,'blueink'},},
      chameleon = {{1,'goldink'},{1,'purpleink'},{1,'yellowink'},},
      talon = {{20,'blackink'},},
      }
  local tattoo_order = {'firefly','moss','feather','shield','mindseye','hammer','cloak','bell',
     'crystal','moon','starburst','boar','web','tentacle','hourglass','brazier','prism','tree',
     'megalith','ox','chameleon','talon',} -- this is the order they are in in the AB file
  local places = {'head', 'torso', 'left arm', 'right arm', 'left leg', 'right leg', 'back'}

  function svo.ti_printTable() -- function to print above table nicely.
    for k,v in pairs(tattoo_order) do 
      echo(string.format("\n    %s = {", v))
      for x,y in pairs(tattoos[v]) do echo(string.format("{%s,'%s'},",y[1],y[2])) end
      echo("},")
    end
  end
  
  svo.ti_inking = false
  
  
  function svo.ti_ink(tattoos, place, person)
   
    if not person then
      if svo.isPlace(place) then
        person = "me"
      else
        person = place
        place = nil
      end
    end

    local tattoosorder = string.split(tattoos, ",")
    
    for i = 1, #tattoosorder do tattoosorder[i] = string.trim(tattoosorder[i]) end
    svo.ti_inking = 
    {
      on = person, 
      tattoos = tattoosorder, 
      part = place or 'open place',
      tattoo_counter = 1,
    }
   
    svo.echof(
      "Going to ink %s on %s of %s.",
      svo.concatand(svo.ti_inking.tattoos),
      svo.ti_inking.part,
      svo.ti_inking.on
    )
    svo.showprompt() echo"\n"
    svo.app('on')
    
    svo.ti_inknext()
  end
  function svo.isPlace(word)
    for _, limb in pairs(places) do
     if word:lower() == limb then return true end
    end
  end
  
  local function doneinking()
      local touchables = {'moss', 'moon', 'boar', 'megalith', 'ox',}
      local needtotouch = {}
      for i = 1, svo.ti_inking.tattoo_counter do
        if table.contains(touchables, svo.ti_inking.tattoos[i]) then needtotouch[#needtotouch+1] = svo.ti_inking.tattoos[i] end
      end
      if #needtotouch > 0 then
        if svo.ti_inking.on ~= 'me' and svo.ti_inking.on ~= 'stencil' then
          if svo.conf.telltouch then send(string.format("tell %s you should now touch your %s tattoo%s", svo.ti_inking.on, svo.concatand(needtotouch), (#needtotouch == 1 and "" or 's'))) end
        elseif svo.ti_inking.on == 'me' then
          for k,v in pairs(needtotouch) do 
            svo.doadd("touch " .. v ,false)
          end
        end
      end
      echo'\n'
      if #svo.ti_inking.tattoos > 0 then
        svo.echof("Finished inking " .. svo.concatand(svo.ti_inking.tattoos) .. " tattoo(s).")
      else
        svo.echof("No tattoos were inked!")
      end
      svo.ti_inking = nil
      svo.app('off')
      svo.showprompt()
  end
  

  function svo.ti_finishedinking(stencil)
    if not svo.ti_inking then return end
    svo.ti_inking.tattoo_counter = svo.ti_inking.tattoo_counter + 1
    if not svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter] then
      doneinking()
    else
      echo("\n")
      svo.echof("Inking the next tattoo...")
      svo.ti_inknext(stencil)
    end   
  end
  
  function svo.ti_cancelinking()
    if not svo.ti_inking then return end
    for i=svo.ti_inking.tattoo_counter,#svo.ti_inking.tattoos do -- remove tattoos we didn't ink from here to the end
      table.remove(svo.ti_inking.tattoos,svo.ti_inking.tattoo_counter) -- so we won't try to touch them
    end
    if reink then killTimer(reink) reink = nil end
    if svo.ti_inking.on == "stencil" then send("clearqueue all",false) end
    doneinking()
  end
  
  function svo.ti_inknext(stencil)
    if not tattoos[svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter]] then -- We don't have any info about this tattoo
      svo.echof("Don't know anything about a %s tattoo.", svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter])
      svo.showprompt()
      if not svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter + 1] then --no more tattoos, done
        doneinking()
        return
      else
        svo.ti_inking.tattoo_counter = svo.ti_inking.tattoo_counter + 1 --skip this tattoo
        svo.ti_inknext(stencil)
        return
      end
    end
    if not stencil then
      if svo.ti_inking.part == "open place" then
        svo.sendc(string.format("ink %s on %s", svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter], svo.ti_inking.on))
      else
        svo.sendc(string.format("ink %s on %s of %s", svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter], svo.ti_inking.part, svo.ti_inking.on))
      end
    else
      svo.sendc(string.format("queue add eqbal ink %s on %s", svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter], svo.ti_inking.on))
    end
  end
  
  function svo.ti_interrupted()
    if not svo.ti_inking then return end
    if not svo.conf.autoreink then 
      echo"\n" svo.echofn("Not reinking interrupted tattoos...")
      fg('green') echoLink(" (ENABLE) ", "svo.config.set('autoreink', true, true)", "Click to start auto reinking interrupted tattoos", true)
      svo.ti_cancelinking() 
    end
    if svo.ti_inking.on == 'me' then
      echo"\n" svo.echofn("Be still! Going to ink again in a few... ")
      cechoLink("<red>(CANCEL)","svo.ti_cancelinking()","Cancel inking",true)
    else
      send(string.format("tell %s Be still while I ink you!", svo.ti_inking.on))
      echo'\n' cechoLink("<red>(CANCEL)","svo.ti_cancelinking()","Cancel inking",true)
    end
    reink = tempTimer(5, function() svo.ti_inknext() reink = nil end)
  end
  
  function svo.ti_cantink(why)
    echo("\n") svo.echof("Lacking the %s for the %s tattoo...", why, svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter])
    if not svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter + 1] or why == "space" then
      for i=svo.ti_inking.tattoo_counter,#svo.ti_inking.tattoos do -- remove tattoos we didn't ink from here to the end
        table.remove(svo.ti_inking.tattoos,svo.ti_inking.tattoo_counter) -- so we won't try to touch them
      end
      doneinking()
    else
      table.remove(svo.ti_inking.tattoos,svo.ti_inking.tattoo_counter) -- remove just this tattoo, we didn't do it
      svo.ti_inknext()
    end
  end
  
  svo.config.setoption('telltouch',
  {
    type = 'boolean',
    vconfig2string = true,
    onshow = function (defaultcolour)
      fg('gold')
      echoLink("ti:", "", "svo Tattoo Inker", true)
      -- <Tell/Don't tell> people to touch inked tattoos
      if svo.conf.telltouch then
        fg('a_cyan') echoLink(" Will tell", "svo.config.set('telltouch', false, true)", "Click to stop telling people to touch their newly-inked tattoos", true)
      else
        fg('a_cyan') echoLink(" Won't tell", "svo.config.set('telltouch', true, true)", "Click to start telling people to touch their newly-inked tattoos", true)
      end
      fg(defaultcolour) echo(" people to touch inked tattoos")
      echo(".\n")
    end,
    onenabled = function ()
      svo.echof("<0,250,0>Will%s tell people to touch tattoos they need to after inking.", svo.getDefaultColor())
    end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s tell people to touch tattoos they need to after inking.", svo.getDefaultColor()) end
  })
  
    svo.config.setoption('autoreink',
  {
    type = 'boolean',
    vconfig2string = true,
    onshow = function (defaultcolour)
      fg('gold')
      echoLink("ti:", "", "svo Tattoo Inker", true)
      -- &lt;Reink/Don't reink&gt; interrupted tattoos
      if svo.conf.autoreink then
        fg('a_cyan') echoLink(" Will", "svo.config.set('autoreink', false, true)", "Click to stop auto reinking interrupted tattoos", true)
      else
        fg('a_cyan') echoLink(" Won't", "svo.config.set('autoreink', true, true)", "Click to start auto reinking interrupted tattoos", true)
      end
      fg(defaultcolour) echo(" reink interrupted tattoos")
      echo(".\n")
    end,
    onenabled = function ()
      svo.echof("&lt;0,250,0&gt;Will%s reink interrupted tattoos.", svo.getDefaultColor())
    end,
    ondisabled = function () svo.echof("&lt;250,0,0&gt;Won't%s reink interrupted tattoos.", svo.getDefaultColor()) end
  })
  
  svo.inkerLoaded = true 
  if firstload then
    svo.echof("Loaded svo Tattoo Inker, version %s.", tostring(svo.modules_version["svo (inker)"]))
  end
end -- end loader

if svo.systemloaded then svo.loader.inker() end