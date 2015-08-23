-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

install.ids = install.ids or {}

-- same name as conf
-- function to say have/don't have
local installdata = {
#if not skills.tekura then
  parry = {
    gmcp = {group = "weaponry", name = "parrying"},
  },
#else
  parry = {
    gmcp = {group = "tekura", name = "guarding"},
  },
#end
  thirdeye = {
    gmcp = {group = "vision", name = "thirdeye"},
  },
  deathsight = {
    gmcp = {group = "vision", name = "deathsight"},
  },
  focus = {
    gmcp = {group = "survival", name = "focusing"},
  },
  efficiency = {
    gmcp = {group = "survival", name = "efficiency"}
  },
  restore = {
    gmcp = {group = "survival", name = "restoration"},
  },
  breath = {
    gmcp = {group = "survival", name = "breathing"},
  },
  pipes = {
    command = "ii pipe",
    item = true,
    other = {
      pattern = [[^You are wielding:$]],
      script = [[
        svo.deleteAllP()
        svo.pipetrig = tempRegexTrigger([=[^ +pipe(\d+)]=],
          [=[
            tempTimer(0.02, [==[
              local r = svo.pipe_assignid(]==]..matches[2]..[==[)
              killTrigger(svo.pipetrig)
              if r then send("empty "..r, false) svo.echof("Set the %s pipe id to %d.", r, ]==]..matches[2]..[==[) end
            ]==])
          ]=])
      ]]
    }
  },
  insomnia = {
    gmcp = {group = "survival", name = "insomnia"},
  },
  clot = {
    gmcp = {group = "survival", name = "clotting"},
  },
#if skills.venom then
  shrugging = {
    gmcp = {group = "venom", name = "shrugging"}
  },
#end
#if skills.voicecraft then
  dwinnu = {
    gmcp = {group = "voicecraft", name = "dwinnu"},
  },
#end
#if skills.chivalry or skills.shindo or skills.kaido then
  fitness = {
#if skills.chivalry then
    command = "ab chivalry fitness",
    gmcp = {group = "chivalry", name = "fitness"},
#elseif skills.kaido then
    command = "ab kaido fitness",
    gmcp = {group = "kaido", name = "fitness"},
#elseif skills.shindo then
    command = "ab striking fitness",
    gmcp = {group = "striking", name = "fitness"},
#end
  },
#end
#if skills.chivalry then
  rage = {
    gmcp = {group = "chivalry", name = "rage"},
  },
#end
#if skills.shindo then
  shindodeaf = {
    gmcp = {group = "shindo", name = "deaf"},
  },
  shindoblind = {
    gmcp = {group = "shindo", name = "blind"},
  },
#end
#if skills.weaponmastery then
  recoverfooting = {
    gmcp = {group = "weaponmastery", name = "recover"},
  },
#end
}

function installclear(what)
  if type(install.ids[what]) == "table" then

    for _, id in pairs(install.ids[what]) do
      killTrigger(id)
      install.ids[what][_] = nil
    end
    install.ids[what] = nil

  else
    install.ids[what] = nil
  end

  if installtimer then killTimer(installtimer) end
  tempTimer(5+getNetworkLatency(), function ()
    if next(install.ids) then
      for thing, _ in pairs(install.ids) do
        if config_dict[thing] and config_dict[thing].type == "boolean" then
          config.set(thing, false, true)
        end

        installclear(thing)
      end
    end

    installtimer = nil

    if not next(install.ids) and not install.installing_system then
      echo"\n"
      echof("auto-configuration done. :) question time!")
      echo"\n"
      install.ask_install_questions()
    end
  end)
end

function installstart(fresh)
  if fresh and not sk.installwarning then
    echof("Are you really sure you want to wipe everything (all remove all non-default defence modes, clear basic+combat defup/keepup to blank, remove all configuration options)? If yes, do vinstall fresh again.")
    if selectString("really", 1) ~= -1 then setUnderline(true) resetFormat() end
    sk.installwarning = true
    return
  elseif fresh and sk.installwarning then
    local s, m = os.remove(getMudletHomeDir() .. "/svo")
    if not s then echof("Couldn't remove svo folder because of: %s", m) end

    defdefup = {
      basic = {},
      combat = {},
    }

    defkeepup = {
      basic = {},
      combat = {},
    }

    echof("Vacuumed everything up!")
    sk.installwarning = nil
  end

  for _, skill in pairs(install.ids) do
    if type(skill) == "table" then
      for _, id in pairs(skill) do
        installclear(id)
      end
    end
  end

  install.ids = {}
  local ids = install.ids

    for skill, skilldata in pairs(installdata) do
      if skilldata.gmcp then
        sendGMCP("Char.Skills.Get "..yajl.to_string(skilldata.gmcp))
        ids[skill] = true
      end
    end

    sendGMCP("Char.Skills.Get "..yajl.to_string{group = "survival"})
    sendGMCP("Char.Items.Inv")
#if skills.metamorphosis then
    sendGMCP("Char.Skills.Get "..yajl.to_string{group = "metamorphosis"})
#end
    signals.gmcpcharskillsinfo:unblock(install.checkskillgmcp)
    signals.gmcpcharitemslist:unblock(install.checkinvgmcp)
    signals.gmcpcharskillslist:unblock(install.checkskilllist)


  if sys.enabledgmcp then
    echof("Starting auto-configuration - going to detect which skills and pipes you've got. Please wait 5 seconds for the questions to start.")
    printCmdLine("Please wait, doing auto-configuration...")
    echo"\n"
  else
    echof("Please enable GMCP in Mudlet settings and restart before installing.")

    signals.gmcpcharskillsinfo:block(install.checkskillgmcp)
    signals.gmcpcharitemslist:block(install.checkinvgmcp)
    signals.gmcpcharskillslist:block(install.checkskilllist)

    for _, skill in pairs(install.ids) do
      if type(skill) == "table" then
        for _, id in pairs(skill) do
          installclear(id)
        end
      end
    end

    install.ids = {}

    return
  end

  send("config screenwidth 0", true)
  -- some newbies don't have the full prompt, just a -, which does not have the required info for the system
  -- for priests, make the balance show on the prompt - as healing others of blind/deaf takes no balance, while other other similar-looking lines do
  -- anyone else can see the class balance
  send(sys.ingamecustomprompt, false)

  -- defaults/reset
  for name, tbl in config_dict:iter() do
    if tbl.installstart then tbl.installstart(); raiseEvent("svo config changed", name) end
  end
  pipes.elm.id, pipes.skullcap.id, pipes.valerian.id = 0,0,0

  if sys.enabledgmcp then
    local city = gmcp.Char.Status.city:match("^(%w+)")
    if city then config.set("org", city, true) end

    if gmcp.Char.Status.level and tonumber(gmcp.Char.Status.level:match("^(%d+)")) >= 99 then
      config.set("dragonflex", true, true)
      config.set("dragonheal", true, true)
    else
      config.set("dragonflex", false, true)
      config.set("dragonheal", false, true)
    end
  end
end

-- logic: set relevant conf's to nil, go through a table of specific ones - if one is nil, ask the relevant question for it. inside alias to toggle it, call install again.

install.ask_install_questions = function ()
  if install.installing_system then return end

  install.installing_system = true
  install.check_install_step()
end

install.check_install_step = function()
  for name, tbl in config_dict:iter() do
    if conf[name] == nil and tbl.installcheck then
      echo "\n"
      tbl.installcheck()
      conf_printinstallhint(name)

      if printCmdLine then
        printCmdLine("vconfig "..name.." ")
      end

      return
    end
  end

  install.installing_system = false
  signals.gmcpcharskillsinfo:block(install.checkskillgmcp)
  signals.gmcpcharitemslist:block(install.checkinvgmcp)
  signals.gmcpcharskillslist:block(install.checkskilllist)
  echo"\n"
  echof("All done installing! Congrats.")
  signals.saveconfig:emit()

  decho(getDefaultColor().."If you'd like, you can also optionally setup the ")
  echoLink("parry", 'svo.sp.setup()', 'parry')
  decho(getDefaultColor().." system and the ")
  echoLink("herb precache", 'svo.showprecache()', 'herb precache')
  decho(getDefaultColor().." system. You can adjust the ")
  echoLink("echo colours", 'svo.config.showcolours()', 'echo colours')
  decho(getDefaultColor().." as well!")
  echo "\n"
  echof("I'd recommend that you at least glimpse through my docs as well so you sort of know what are you doing :)")

  if not conf.customprompt and not conf.setdefaultprompt then
    conf.setdefaultprompt = true
    setdefaultprompt()
    echo"\n" echof("I've setup a custom prompt for you that mimics the normal Achaean one, but also displays which afflictions have you got. See http://doc.svo.vadisystems.com/#setting-a-custom-prompt on how to customize it if you'd like, or if you don't like it, do 'vconfig customprompt off' to disable it.")
  end

  tempTimer(math.random(1,2), function ()
    echo"\n"
    echof("Oh, and one last thing - QQ, restart Mudlet and login again, so all changes can take effect properly.")
  end)
end

function install.checkskillgmcp()
  local t = _G.gmcp.Char.Skills.Info
  if not t then return end

  if t.skill == "clotting" then t.skill = "clot" end
  if t.skill == "parrying" then t.skill = "parry" end

  if conf[t.skill] == nil and (t.info == "" or t.info:find("You have not yet learned this ability")) then
    conf[t.skill] = false
    echof("Don't have %s, so <250,0,0>won't%s be using it whenever possible.", t.skill, getDefaultColor())
    raiseEvent("svo config changed", t.skill)
  elseif conf[t.skill] == nil then
    conf[t.skill] = true
    echof("Have %s, so <0,250,0>will%s be using it whenever possible.", t.skill, getDefaultColor())
    raiseEvent("svo config changed", t.skill)
  end

  installclear(t.skill)
end
signals.gmcpcharskillsinfo:connect(install.checkskillgmcp)
signals.gmcpcharskillsinfo:block(install.checkskillgmcp)

function install.checkinvgmcp()
  local t = _G.gmcp.Char.Items.List
  if not t.location == "inv" then return end

  -- feh! Easier to hardcode it for such a miniscule amount of items.
  -- If list enlarges, fix appopriately.
  for _, it in pairs(t.items) do
    if string.find(it.name, "%f[%a]pipe%f[%A]") then
      local r = pipe_assignid(it.id)
      if r then echof("Set the %s pipe id to %d.", r, it.id) end
    end
  end

end
signals.gmcpcharitemslist:connect(install.checkinvgmcp)
signals.gmcpcharitemslist:block(install.checkinvgmcp)


function install.checkskilllist()
  local t = _G.gmcp.Char.Skills.List
  if t.group == "survival" then
    for _, k in ipairs{{"focus", "focusing"}, {"restore", "restoration"}, {"insomnia", "insomnia"}, {"clot", "clotting"}, {"breath", "breathing"}, {"efficiency", "efficiency"}} do
      if contains(t.list, k[2]:title()) then
        config.set(k[1], true, true)
        installclear(k[1])
      end
    end

#if skills.metamorphosis then
  elseif t.group == "metamorphosis" then
    for _, k in ipairs{"truemorph", "hydra", "wyvern", "affinity", "icewyrm", "gorilla", "eagle", "jaguar", "wolverine", "transmorph", "elephant", "nightingale", "bonding", "bear", "basilisk", "sloth", "gopher", "condor", "hyena", "owl", "cheetah", "jackdaw", "turtle", "wolf", "wildcat", "powers", "squirrel"} do
    if contains(t.list, k:title()) then
      config.set("morphskill", k, true)
      break
    end
  end

  installclear("morphskill")
#end
  end
end
signals.gmcpcharskillslist:connect(install.checkskilllist)
signals.gmcpcharskillslist:block(install.checkskilllist)
