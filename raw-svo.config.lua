-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local sys, defdefup, signals = svo.sys, svo.defdefup, svo.signals
local conf, sk, me, defs = svo.conf, svo.sk, svo.me, svo.defs
local defences, cnrl, rift = svo.defences, svo.cnrl, svo.rift
local pipes = svo.pipes

svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/config")

-- conf has actual values, config data for them

svo.wait_tbl = {
  [0] = {n = 0.7, m = "Systems lag tolerance level set to normal."},
  [1] = {n = 1.1, m = "The lag level was set to \"decent\" - make sure to set it to normal when it clears up."},
  [2] = {n = 1.9, m = "The lag level was set to \"severe\" - make sure to set it to normal when it clears up."},
  [3] = {n = 3.5, m = "The lag level was set to \"awfully terrible\" - make sure to set it to normal when it clears up. Don't even think about fighting in this lag."},
  [4] = {n = 3.5, m = "The lag level was set to \"you're on a mobile in the middle of nowhere\" - make sure to set it to normal when it clears up. Don't even think about fighting in this lag. Don't use this for bashing with dor either - use 3 instead. This is more useful for scripts that rely on do - enchanting and etc."}
}

svo.conf_printinstallhint = function (which)
  svo.assert(svo.config_dict[which] and svo.config_dict[which].type, which.." is missing a type")

  if svo.config_dict[which].type == "boolean" then
    svo.echof("Use %s to answer.", tostring(svo.green("vconfig "..which.." yep/nope")))
  elseif svo.config_dict[which].type == "string" then
    svo.echof("Use %s to answer.", tostring(svo.green("vconfig "..which.." (option)")))
  elseif svo.config_dict[which].type == "number" and svo.config_dict[which].percentage then
    svo.echof("Use %s to answer.", tostring(svo.green("vconfig "..which.." (percent)")))
  elseif svo.config_dict[which].type == "number" then
    svo.echof("Use %s to answer.", tostring(svo.green("vconfig "..which.." (number)")))
  end
end

local conf_installhint = function (which)
  svo.assert(svo.config_dict[which] and svo.config_dict[which].type, which.." is missing a type")

  if svo.config_dict[which].type == "boolean" then
    return "Use vconfig "..which.." yep/nope to answer."
  elseif svo.config_dict[which].type == "string" then
    return "Use vconfig "..which.." (option) to answer."
  elseif svo.config_dict[which].type == "number" and svo.config_dict[which].percentage then
    return "Use vconfig "..which.." (percent) to answer."
  elseif svo.config_dict[which].type == "number" then
    return "Use vconfig "..which.." (number) to answer."
  else return ""
  end
end

svo.config_dict = svo.pl.OrderedMap {
  {blockcommands = {
    vconfig2 = true,
    type = "boolean",
    onenabled = function ()
      svo.echof("<0,250,0>Will%s block your commands in slow curing mode (aeon/retardation) if the system is doing something.", svo.getDefaultColor())
      if not denyCurrentSend then svo.echof("Warning: your version of Mudlet doesn't support this, so blockcommands won't actually work. Update to 1.2.0+") end
    end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s block your commands in slow curing mode, but instead allow them to override what the system is doing.", svo.getDefaultColor())
    if not denyCurrentSend then svo.echof("Warning: your version of Mudlet doesn't support this, so blockcommands won't actually work.") end end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      if denyCurrentSend then
        echo "Override commands in slow-curing mode.\n" return
      else
        echo "Override commands in slow-curing mode (requires Mudlet 1.2.0+).\n" return end
    end,
    installstart = function () conf.blockcommands = true end,
  }},
  {autoslick = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Automatically prioritise slickness",
    onenabled = function () svo.echof("<0,250,0>Will%s automatically swap asthma herb priority in times of danger - when you have paralysis or impatience above asthma in prios, and you have asthma+slickness on you, getting hit with a herbstack.", svo.getDefaultColor()) end,
    ondisabled = function ()
      if svo.swapped_asthma then
        svo.prio_swap("asthma", "herb", svo.swapped_asthma)
        svo.swapped_asthma = nil
        svo.echof("Swapped asthma priority back down.")
      end

      svo.echof("<250,0,0>Won't%s automatically swap asthma herb priority in times of danger.", svo.getDefaultColor()) end,
    installstart = function () conf.autoslick = true end
  }},
  {focus = {
    type = "boolean",
    vconfig1 = "focus",
    onenabled = function () svo.echof("<0,250,0>Will%s use Focus to cure.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use Focus to cure.", svo.getDefaultColor()) end,
    installstart = function () conf.focus = nil end,
    installcheck = function () svo.echof("Can you make use of the Focus skill?") end
  }},
  {siprandom = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s sip by random vial IDs of a potion - note that this requires the elist sorter to know which vial IDs have which potions - and you'll need to check 'elist' after a vial runs out.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s make use of random vials - will be sipping the first available one by name.", svo.getDefaultColor()) end,
  }},
  {autoclasses = {
      type = "boolean",
      onenabled = function () svo.echof("<0,250,0>Will%s automatically enable the classes you seem to be fighting (used for class tricks).", svo.getDefaultColor()) end,
      ondisabled = function () svo.echof("<250,0,0>Won't%s automatically enable classes that you seem to be fighting (you can use tn/tf class instead).", svo.getDefaultColor()) end,

      vconfig2 = true,
      onshow = function (defaultcolour)
        fg(defaultcolour)
        if conf.autoclasses then
          echo "Will auto-enable classes.\n"
        else
          echo "Won't auto-enable classes.\n"
        end
      end,
    }},
  {havelifevision = {
    type = "boolean",
    onenabled = function () defences.enablelifevision() svo.echof("<0,250,0>Have%s Lifevision mask - added it to defup/keepup.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Don't%s have Lifevision mask - won't be adding it to defup/keepup.", svo.getDefaultColor()) end,
  }},
  {autoarena = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s automatically enable/disable arena mode as you enter into the arena.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s automatically enable/disable arena mode as you enter/leave the arena..", svo.getDefaultColor()) end,
  }},
  {haveshroud = {
    type = "boolean",
    onenabled = function () defences.enableshroud() svo.echof("<0,250,0>Have%s a Shroudcloak - added it to defup/keepup.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Don't%s have a Shroudcloak - won't be adding it to defup/keepup.", svo.getDefaultColor()) end,
  }},
  {focuswithcadmus = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use Focus while you have cadmus"
      if conf.focuswithcadmus then
        echo"    ("
        echoLink("adjust affs", "svo.config.set'cadmusaffs'", "View, enable and disable afflictions for which focus is allowed to be used while you've got cadmus")
        fg(defaultcolour) echo ")"
      end
      echo"\n"
      resetFormat()
    end,
    onenabled = function () svo.echof("<0,250,0>Will%s focus for mental afflictions when you've got cadmus (this'll give you a physical affliction when you do).", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s focus when you've got cadmus.", svo.getDefaultColor()) end,
  }},
  {cadmusaffs = {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      svo.echofn("Afflictions for which we will use focus even though we have ")
      underline(true)
      setFgColor(unpack(svo.getDefaultColorNums))
      echoLink("cadmus", '', "Cadmus will give you a physical affliction if you focus with it (and still cure the mental one)", true)
      underline(false)
      echo(":\n")

      local temp = svo.prio.getlist("focus")

      -- clear gaps so we can sort and display in 2 columns
      local t = {}
      for _, focusaff in ipairs(temp) do t[#t+1] = focusaff end

      table.sort(t) -- display alphabetically

      for i = 1, #t, 2 do
        local focusaff, nextaff = t[i], t[i+1]

        if me.cadmusaffs[focusaff] then
          dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[svo.me.cadmusaffs["]]..focusaff..[["] = false; svo.config.set'cadmusaffs']], "Click to stop focusing for "..focusaff.." when you have camus", true)
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %s", focusaff))
        else
          dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[svo.me.cadmusaffs["]]..focusaff..[["] = true; svo.config.set'cadmusaffs']], "Click to start focusing for "..focusaff.." when you have camus and are able to focus", true)
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %s", focusaff))
        end

        -- equal out the spacing on the second column
        echo((" "):rep(30-#focusaff))

        if nextaff and me.cadmusaffs[nextaff] then
          dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[svo.me.cadmusaffs["]]..nextaff..[["] = false; svo.config.set'cadmusaffs']], "Click to stop focusing for "..nextaff.." when you have camus", true)
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %s\n", nextaff))
        elseif nextaff then
          dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[svo.me.cadmusaffs["]]..nextaff..[["] = true; svo.config.set'cadmusaffs']], "Click to start focusing for "..nextaff.." when you have camus and are able to focus", true)
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %s\n", nextaff))
        end
      end

      _G.setUnderline = underline
      echo'\n'
    end
  }},
  {lyre = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Lyre mode",
    onenabled = function () defs.keepup("lyre", "on") svo.echof("Lyre mode <0,250,0>ON%s.", svo.getDefaultColor()) end,
    ondisabled = function () defs.keepup("lyre", "off") svo.app("off", true) svo.echof("Lyre mode <250,0,0>OFF%s.", svo.getDefaultColor()) end,
  }},
  {ninkharsag = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Experimental Nin'kharsag tracking",
    onenabled = function () svo.echof("Experimental Nin'kharsag tracking <0,250,0>enabled%s - will attempt to work out which affs Nin'kharsag hides, and diagnose otherwise.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("Experimental Nin'kharsag <250,0,0>disabled%s.", svo.getDefaultColor()) end,
  }},
  {shipmode = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Ship mode",
    onenabled = function () signals.newroom:connect(sk.check_shipmode) svo.echof("Ship mode <0,250,0>enabled%s - this will allow the system to work properly with the 2-3 line prompts.", svo.getDefaultColor()) end,
    ondisabled = function () signals.newroom:disconnect(sk.check_shipmode) svo.echof("Ship mode <250,0,0>disabled%s.", svo.getDefaultColor()) end,
  }},
  {lyrecmd = {
    type = "string",
    onset = function ()
      svo.dict.lyre.physical.action = conf.lyrecmd
      svo.echof("Will use the '%s' for the Lyre mode.", tostring(conf.lyrecmd))
    end
  }},
  {commandseparator = {
    type = "string",
    onset = function ()
      svo.echof("Will use <0,250,0>%s%s as the in-game command separator.", tostring(conf.commandseparator), svo.getDefaultColor())
    end
  }},
  {buckawns = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Have buckawns",
    onenabled = function () svo.echof("<0,250,0>Do%s have buckawns.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Don't%s have buckawns.", svo.getDefaultColor()) end,
    installstart = function () conf.buckawns = nil end,
    installcheck = function () svo.echof("Have you got the buckawns artifact?") end
  }},
  {burrowpause = {
    type = "boolean",
    onenabled = function () signals.gmcproominfo:connect(sk.check_burrow_pause) svo.echof("<0,250,0>Will%s auto-pause when we burrow.", svo.getDefaultColor()) end,
    ondisabled = function () signals.gmcproominfo:disconnect(sk.check_burrow_pause) svo.echof("<250,0,0>Won't%s auto-pause when we burrow.", svo.getDefaultColor()) end,
    installstart = function () conf.burrowpause = true end,
  }},
  {freevault = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Vaulting doesn't take balance",
    onenabled = function ()
      if conf.freevault and svo.dict.riding.physical.balanceful_act then
        svo.dict.riding.physical.balanceless_act = true
        svo.dict.riding.physical.balanceful_act = nil
        signals.dragonform:emit()
      elseif not conf.freevault and svo.dict.riding.physical.balanceless_act then
        svo.dict.riding.physical.balanceless_act = nil
        svo.dict.riding.physical.balanceful_act = true
        signals.dragonform:emit()
      end
      svo.echof("<0,250,0>Do%s have balanceless vaulting.", svo.getDefaultColor())
    end,
    ondisabled = function ()
      if conf.freevault and svo.dict.riding.physical.balanceful_act then
        svo.dict.riding.physical.balanceless_act = true
        svo.dict.riding.physical.balanceful_act = nil
        signals.dragonform:emit()
      elseif not conf.freevault and svo.dict.riding.physical.balanceless_act then
        svo.dict.riding.physical.balanceless_act = nil
        svo.dict.riding.physical.balanceful_act = true
        signals.dragonform:emit()
      end
      svo.echof("<250,0,0>Don't%s have balanceless vaulting.", svo.getDefaultColor())
    end,
  }},
  {deathsight = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Have deathsight",
    onenabled = function () svo.echof("<0,250,0>Do%s have deathsight.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Don't%s have deathsight.", svo.getDefaultColor()) end,
    installstart = function () conf.deathsight = nil end,
    installcheck = function () svo.echof("Have you got the deathsight skill?") end
  }},
  {tree = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use tree       ("
      echoLink("view scenarios", "svo.config.set'treefunc'", "View, enable and disable scenarios in which tree will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () svo.echof("<0,250,0>Will%s use of tree.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use of tree.", svo.getDefaultColor()) end,
    installstart = function () conf.tree = nil end,
    installcheck = function () svo.echof("Do you have a Tree tattoo?") end
  }},
  {treebalance = {
    type = "number",
    min = 0,
    max = 100000,
    onset = function ()
      if conf.treebalance == 0 then
        svo.echof("Will use the default settings for tree balance length.")
      else
        svo.echof("Set tree balance to be %ds - if it doesn't come back after that, I'll reset it.", conf.treebalance)
      end
    end,
    installstart = function () conf.treebalance = 0 end
  }},
  {restore = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use restore    ("
      echoLink("view scenarios", "svo.config.set'restorefunc'", "View, enable and disable scenarios in which restore will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () svo.echof("<0,250,0>Will%s use Restore to cure limbs when necessary.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use Restore to cure.", svo.getDefaultColor()) end,
    installstart = function () conf.restore = nil end,
    installcheck = function () svo.echof("Can you make use of the Restore skill?") end
  }},
  {dragonheal = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use dragonheal ("
      echoLink("view scenarios", "svo.config.set'dragonhealfunc'", "View, enable and disable scenarios in which dragonheal will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () svo.echof("<0,250,0>Will%s use dragonheal to cure when necessary.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use dragonheal to cure.", svo.getDefaultColor()) end,
    installstart = function () conf.dragonheal = nil end,
    installcheck = function () svo.echof("Can you make use of the Dragonheal?") end
  }},
  {breath = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Auto-enable breathing on Kai Choke",
    onenabled = function () svo.echof("<0,250,0>Will%s automatically enabling breathing against Kai Choke and to check for asthma.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use survival breathing.", svo.getDefaultColor()) end,
    installstart = function () conf.breath = nil end,
    installcheck = function () svo.echof("Can you make use of the survival breath skill?") end
  }},
  {ignoresinglebites = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Ignore single serpent bites",
    onenabled = function () svo.echof("<0,250,0>Will%s ignore all serpent bites that deliver only one affliction - most likely they'll be illusions, but may also be not against a smart Serpent who realizes that you're ignoring. So if you see them only biting, that's a warning sign that they're *really* biting, and you'd want to toggle this off & diagnose.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s ignore serpent bites that deliver only one affliction.", svo.getDefaultColor()) end
  }},
  {ignoresinglestabs = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Ignore single serpent doublestabs",
    onenabled = function () svo.echof("<0,250,0>Will%s ignore all serpent doublestabs that deliver only one affliction (most likely they'll be illusions, but may also be not).", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s ignore serpent doublestabs that deliver only one affliction.", svo.getDefaultColor()) end
  }},
  {efficiency = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Have survival efficiency",
    onenabled = function () svo.echof("<0,250,0>Have%s survival efficiency - tree tattoo balance will take shorter to come back.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Don't%s have efficiency - tree tattoo balance will take longer to come back.", svo.getDefaultColor()) end,
    installstart = function () conf.efficiency = nil end,
    installcheck = function () svo.echof("Do you have the survival efficiency skill?") end
  }},
  {clot = {
    type = "boolean",
    vconfig1 = "clot",
    onenabled = function () svo.echof("<0,250,0>Will%s use clot to control bleeding.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use clot for bleeding.", svo.getDefaultColor()) end,
    installstart = function () conf.clot = nil end,
    installcheck = function () svo.echof("Can you make use of the Clot skill?") end
  }},
  {insomnia = {
    type = "boolean",
    vconfig1 = "insomnia",
    onenabled = function () svo.echof("<0,250,0>Will%s use the Insomnia skill for insomnia.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use the Insomnia skill for insomnia, and will use cohosh instead.", svo.getDefaultColor()) end,
    installstart = function () conf.insomnia = nil end,
    installcheck = function () svo.echof("Can you make use of the Insomnia skill?") end
  }},
  {thirdeye = {
    type = "boolean",
    vconfig1 = "thirdeye",
    onenabled = function () svo.echof("<0,250,0>Will%s use the thirdeye skill for thirdeye instead of echinacea.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use the thirdeye skill for thirdeye, and will use echinacea instead.", svo.getDefaultColor()) end,
    installstart = function () conf.thirdeye = nil end,
    installcheck = function () svo.echof("Can you make use of the Thirdeye skill?") end
  }},
  {moss = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s make use of moss/potash to heal.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s make use of moss/potash to heal.", svo.getDefaultColor()) end,
    installstart = function ()
      conf.moss = nil end,
    installcheck = function ()
      svo.echof("Do you want to make use of moss/potash to heal?") end,
  }},
  {showchanges = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s show changes in health/mana on the prompt.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s show changes in health/mana on the prompt.", svo.getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Show h/m changes (in "..tostring(conf.changestype).." format).\n")
    end,
    installstart = function () conf.showchanges = nil end,
    installcheck = function () svo.echof("Do you want to show changes about your health/mana in the prompt?") end
  }},
  {changestype = {
    type = "string",
    check = function (what)
      if what == "full" or what == "short" or what == "fullpercent" or what == "shortpercent" then return true end
    end,
    onset = function ()
      svo.echof("Will use the %s health/mana loss echoes.", conf.changestype)
    end,
    installstart = function () conf.changestype = "shortpercent" end
  }},
  {log = {
    type = "string",
    check = function (what)
      if what == "off" or what == "file" or what == "echo" or what == "both" then return true end
    end,
    onset = function ()
      svo.updateloggingconfig()
      if conf.log == "off" then
        svo.echof("Logging disabled.")
      elseif conf.log == "file" then
        if Logger then
          svo.echof("Will log to the file in %s.", (getMudletHomeDir() .. "/log/svof.txt"))
        else
          svo.echof("Please install the Simple logger first (https://forums.mudlet.org/viewtopic.php?f=6&t=1424), then restart.")
          svo.conf.log = "off"
          svo.updateloggingconfig()
        end
      elseif conf.log == "echo" then
        svo.echof("Will log to your screen.")
      else
        svo.echof("Will log to both screen and file in %s.", (getMudletHomeDir() .. "/log/svof.txt"))
      end
    end,
    installstart = function () conf.log = "off" end
  }},
  {showbaltimes = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s show balance times for balance, equilibrium and herbs.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s show balance times.", svo.getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Show how long balances took.\n"
    end,
    installstart = function () conf.showbaltimes = true end,
    -- installcheck = function () svo.echof("Do you want to show how long your balances take?") end
  }},
  {showafftimes = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s show how long afflictions took to cure.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s show times for curing afflictions.", svo.getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Show how quickly afflictions are cured.\n"
    end,
    installstart = function () conf.showafftimes = true end,
  }},
  {doubledo = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s do actions twice under stupidity.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s do actions twice under stupidity.", svo.getDefaultColor()) end,
    onshow = "Double do actions in stupidity",
    vconfig2 = true
  }},
  {repeatcmd = {
    type = "number",
    min = 0,
    max = 100000,
    onset = function ()
      if conf.repeatcmd == 0 then svo.echof("Will not repeat commands.")
      elseif conf.repeatcmd == 1 then svo.echof("Will repeat each command one more time.")
      else svo.echof("Will repeat each command %d more times.", conf.repeatcmd)
    end end,
    installstart = function () conf.repeatcmd = 0 end
  }},
  {singleprompt = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      if conf.singleprompt then
        echo(string.format("Use a singleprompt%s", (conf.singlepromptblank and ' (with a blank line)' or '')))
      else
        echo("Not using a singleprompt")
      end
      echo'.\n'
      resetFormat()
    end,
    onenabled = function ()
      svo.echof("<0,250,0>Enabled%s the use of a single prompt.", svo.getDefaultColor())

      sk.enable_single_prompt()
    end,
    ondisabled = function ()
      svo.echof("<250,0,0>Disabled%s the use a single prompt.", svo.getDefaultColor())
      if svo.moveprompt then killTrigger(svo.moveprompt) end
      if svo.bottomprompt then svo.bottomprompt:hide(); svo.bottomprompt.reposition = function() end end
      setBorderBottom(0)
      svo.bottom_border = 0
    end
  }},
  {singlepromptsize = {
    type = "number",
    min = 0,
    max = 100,
    onset = function ()
      if svo.bottomprompt then
        svo.bottomprompt:setFontSize(conf.singlepromptsize)
        if conf.singleprompt then
          -- svo.config.set("singleprompt", "off", false)
          -- svo.config.set("singleprompt", "on", false)

          if svo.moveprompt then killTrigger(svo.moveprompt) end
          if svo.bottomprompt then svo.bottomprompt:hide(); svo.bottomprompt.reposition = function() end end
          setBorderBottom(0)
          svo.bottom_border = 0

          sk.enable_single_prompt()
          clearWindow("svo.bottomprompt")
        end
      end

      svo.echof("Will be displaying the font at size %d.", conf.singlepromptsize)
    end
  }},
  {singlepromptblank = {
    type = "boolean",
    onenabled = function ()
      svo.echof("<0,250,0>Enabled%s the single prompt to show a blank line for the prompt.", svo.getDefaultColor())
      svo.config.set("singlepromptkeep", false, false)
    end,
    ondisabled = function ()
      svo.echof("<250,0,0>Disabled%s the blank line, will be deleting the prompt instead.", svo.getDefaultColor())
    end
  }},
  {singlepromptkeep = {
    type = "boolean",
    onenabled = function ()
      svo.echof("<0,250,0>Enabled%s the single prompt to keep the prompt%s.", svo.getDefaultColor(), (conf.singleprompt and '' or ' (when vconfig singleprompt is on)'))
      svo.config.set("singlepromptblank", false, false)
    end,
    ondisabled = function ()
      svo.echof("<250,0,0>Disabled%s keeping the prompt, will be removing it.", svo.getDefaultColor())
    end
  }},
  {waitherbai = {
    type = "boolean",
    vconfig2 = true,
    onenabled = function () svo.echof("<0,250,0>Will%s pause eating of herbs while checking herb-cured illusions.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s pause eating of herbs while checking herb-cured illusions.", svo.getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour) echo ("Don't eat while checking herb-cured illusions.\n")
    end,
    installstart = function () conf.waitherbai = true end
  }},
  {waitparalysisai = {
    type = "boolean",
    vconfig2 = true,
    onenabled = function () svo.echof("<0,250,0>Will%s wait for balance/eq to confirm a suspect paralysis instead of accepting it - so if we get a suspect paralysis while off bal/eq, we'll cure other things and check the paralysis when we can.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s wait for balance/eq to confirm a possible paralysis - if we get one off bal/eq, we'll eat bloodroot asap. Otherwise if we have bal/eq, we'll check first.", svo.getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour) echo ("Wait for balance/eq to check suspicious paralysis.\n")
    end,
    installstart = function () conf.waitparalysisai = false end
  }},
  {commandecho = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s show commands the system is doing.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s show commands the system is doing.", svo.getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour) echo ("Show system commands ("..tostring(conf.commandechotype)..")\n")
    end,
    installstart = function () conf.commandecho = true end
  }},
  {commandechotype = {
    type = "string",
    check = function (what)
      if what == "plain" or what == "fancy" or what == "fancynewline" then return true end
    end,
    onset = function ()
      svo.echof("Will use the %s command echoes.", conf.commandechotype)
    end,
    installstart = function () conf.commandechotype = "fancy" end
  }},
  {curemethod = {
    type = "string",
    check = function (what)
      if table.contains({"conconly", "transonly", "preferconc", "prefertrans", "prefercustom"}, what) then return true end
    end,
    onset = function ()
      signals.curemethodchanged:emit()
      if conf.curemethod == "conconly" then
        svo.echof("Will only use the usual Concoctions herbs/potions/salve for curing.")
      elseif conf.curemethod == "transonly" then
        svo.echof("Will only use Transmutation minerals for curing.")
      elseif conf.curemethod == "preferconc" then
        svo.echof("Will use Concoctions and Transmutation cures as you have them, but prefer Concoctions cures.")
      elseif conf.curemethod == "prefertrans" then
        svo.echof("Will use Concoctions and Transmutation cures as you have them, but prefer Transmutation cures.")
      elseif conf.curemethod == "prefercustom" then
        svo.echof("Will use your preferred Concoctions or Transmutation cures, falling back to the alternatives if you run out. See 'vshow curelist' for the adjustment menu.")
      else
        svo.echof("Will use Concoctions and Transmutation cures as you have them.")
      end
    end,
    -- onshow: done in vshow
    installstart = function () conf.curemethod = nil end,
    installcheck = function () svo.echof("Would you like to use Concoctions or Transmutation cures?\n\n  You can answer with 'conconly' - which'll mean that you'd like to use Concoctions cures only, 'transonly' - which'll mean that you'd like to use Transmutation cures only, 'preferconc' - prefer Concoctions cures, but fall back to Transmutation cures should you run out, and lastly, 'prefertrans' - prefer Transmutation cures, but fall back to Concoctions should you run out.") end
  }},
  {customprompt = {
    type = "string",
    vconfig2 = true,
    onset = function ()
      if conf.customprompt == "none" or conf.customprompt == "off" or conf.customprompt == "of" then
        conf.customprompt = false
        svo.echof("Custom prompt disabled.")
      elseif conf.customprompt == "on" then
        if conf.oldcustomprompt ~= "off" and conf.oldcustomprompt ~= "of" then
          conf.customprompt = conf.oldcustomprompt
          svo.cp.makefunction()
          svo.echof("Custom prompt restored.")
          if svo.innews then
            svo.innews = false
            svo.echof("Disabled the news status and re-enabled the prompt.")
          end
        else
          svo.echof("You haven't set a custom prompt before, so we can't revert back to it. Set it with 'vconfig customprompt <prompt line>.")
          conf.customprompt = false
        end
      else
        svo.cp.makefunction()
        conf.oldcustomprompt = conf.customprompt
        svo.echof("Custom prompt enabled and set; will replace the standard one with yours now.")
      end
    end,
    installstart = function () conf.customprompt = nil; conf.setdefaultprompt = nil end
  }},
  {relight = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s auto-relight non-artifact pipes.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s auto-relight pipes.", svo.getDefaultColor()) end,
    installstart = function () conf.relight = true end,
    installcheck = function () svo.echof("Should we keep non-artifact pipes lit?") end
  }},
  {gagrelight = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s hide relighting of pipes.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s hide relighting pipes.", svo.getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo(string.format("Re-light pipes quietly%s.\n", not conf.relight and " (when relighting is on)" or ""))
    end,
    installstart = function () conf.gagrelight = true end,
    installcheck = function () svo.echof("Should we hide it when pipes are relit (it can get spammy)?") end
  }},
  {gagotherbreath = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s hide others breathing.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s hide others breathing.", svo.getDefaultColor()) end,
    onshow = "Completely gag others breathing",
    installstart = function () conf.gagotherbreath = true end
  }},
  {gagbreath = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s hide the breathing defence.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s hide the breathing defence.", svo.getDefaultColor()) end,
    onshow = "Completely gag breathing",
    installstart = function () conf.gagbreath = true end,
    -- installcheck = function () svo.echof("Should we hide it when you use the breathing defence?") end
  }},
  {gageqbal = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s hide the 'you're off eq/bal' messages.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s hide the 'you're off eq/bal' messages.", svo.getDefaultColor()) end,
    onshow = "Completely gag off eq/bal messages",
    installstart = function () conf.gageqbal = true end,
    installcheck = function () svo.echof("Should we hide the messages you get when you try and spam something off balance or equilibrium?") end
  }},
  {gagserverside = {
    type = "boolean",
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Gag Svof's use of serverside priorities/toggles.\n")
    end,
    onenabled = function () svo.echof("<0,250,0>Will%s hide info lines from the serverside curing system.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s hide info lines from the serverside curing system.", svo.getDefaultColor()) end,
    installstart = function () conf.gagserverside = true end,
  }},
  {gagservercuring = {
    type = "boolean",
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Gag serverside [CURING] messages.\n")
    end,
    onenabled = function () svo.echof("<0,250,0>Will%s hide serverside's [CURING] messages.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s hide serverside's [CURING] messages.", svo.getDefaultColor()) end,
    installstart = function () conf.gagservercuring = false end,
  }},
  {ccto = {
    type = "string",
    onset = function ()
      conf.ccto = conf.ccto:lower()
      if conf.ccto == "pt" or conf.ccto == "party" then
        svo.echof("Will report stuff to party.")
      elseif conf.ccto == "clt" then
        svo.echof("Will report stuff to the current selected clan.")
      elseif conf.ccto:find("^tell %w+") then
        svo.echof("Will report stuff to %s via tells.", conf.ccto:match("^tell (%w+)"):title())
      elseif conf.ccto == "ot" then
        svo.echof("Will report stuff to the Order channel.")
      elseif conf.ccto == "team" then
        svo.echof("Will report stuff to the team channel.")
      elseif conf.ccto == "army" then
        svo.echof("Will report stuff to the army channel.")
      elseif conf.ccto == "echo" then
        svo.echof("Will echo ccto stuff back to you, instead of announcing it anywhere.")
      else
        svo.echof("Will report stuff to the %s clan.", conf.ccto)
      end
    end,
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo(string.format("Reporting stuff to %s.\n", tostring(conf.ccto)))
    end,
    installstart = function ()
      conf.ccto = "pt" end
  }},
  {mosshealth = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxhealth:emit() svo.echof("Will eat moss/potash for health if it falls below %d%% (%dh).", conf.mosshealth, sys.mosshealth) end,
    installstart = function () conf.mosshealth = nil end,
    installcheck = function () svo.echof("At what %% of health do you want to start using moss/potash to heal, if enabled?") end
  }},
  {pagelength = {
    type = "number",
    vconfig2string = true,
    min = 1,
    max = 250,
    onset = function () svo.echof("Will reset your pagelength to %d after changing it.", conf.pagelength) end,
    installstart = function () conf.pagelength = 20 end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Default pagelength to reset to is ") fg("a_cyan")
      echoLink(tostring(conf.pagelength), 'printCmdLine"vconfig pagelength "',
      "Set the default pagelength to reset to after changing it",
       true)
      cecho("<a_grey> lines.\n")
    end,
  }},
  {herbstatsize = {
    type = "number",
    min = 1,
    max = 100,
    onset = function () rift.update_riftlabel(); svo.echof("Set the font size in the herbstat window to %d.", conf.herbstatsize) end,
    installstart = function () conf.herbstatsize = 9 end
  }},
  {mossmana = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxmana:emit() svo.echof("Will eat moss/potash for mana if it falls below %d%% (%dm).", conf.mossmana, sys.mossmana) end,
    installstart = function () conf.mossmana = nil end,
    installcheck = function () svo.echof("At what %% of mana do you want to start using moss/potash to heal, if enabled?") end
  }},
  {siphealth = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxhealth:emit() svo.echof("Will start sipping health if it falls below %d%% (%dh).", conf.siphealth, sys.siphealth) end,
    installstart = function () conf.siphealth = nil end,
    installcheck = function () svo.echof("At what %% of health do you want to start sipping health?") end
  }},
  {sipmana = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxmana:emit() svo.echof("Will start sipping mana if it falls below %d%% (%dm).", conf.sipmana, sys.sipmana) end,
    installstart = function () conf.sipmana = nil end,
    installcheck = function () svo.echof("At what %% of mana do you want to start sipping mana?") end
  }},
  {refillat = {
    type = "number",
    min = 0,
    max = 30,
    onset = function () svo.echof("Will start refilling pipes when they're at %d puffs.", conf.refillat) end,
    installstart = function () conf.refillat = 1 end
  }},
  {manause = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxmana:emit() svo.echof("Will use mana-draining skills if only above %d%% mana (%d).", conf.manause, sys.manause) end,
    installstart = function () conf.manause = 35 end,
    installcheck = function () svo.echof("Above which %% of mana is the system allowed to use mana skills? Like focus, insomnia, etc. If you got below this %%, it'll revert to normal cures.") end
  }},
  {lag = {
    type = "number",
    min = 0,
    max = 4,
    onset = function () cnrl.update_wait() svo.echof(svo.wait_tbl[conf.lag].m) end,
    installstart = function () conf.lag = 0 end
  }},
  {unknownfocus = {
    type = "number",
    min = 0,
    onset = function () svo.echof("Will diagnose after we have %d or more unknown, but focusable afflictions.", conf.unknownfocus) end,
    installstart = function ()
      if svo.haveskillset('healing') then
        conf.unknownfocus = 1
      else
        conf.unknownfocus = 2
      end
    end,
  }},
  {unknownany = {
    type = "number",
    min = 0,
    onset = function () svo.echof("Will diagnose after we have %d or more unknown affs.", conf.unknownany) end,
    installstart = function ()
      if svo.haveskillset('healing') then
        conf.unknownany = 1
      else
        conf.unknownany = 2
      end
    end,
  }},
  {bleedamount = {
    type = "number",
    vconfig2string = true,
    min = 0,
    onset = function () svo.echof("Will start clotting if bleeding for more than %d health.", conf.bleedamount) end,
    installstart = function () conf.bleedamount = 60 end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Will clot if bleeding for over ") fg("a_cyan")
      echoLink(tostring(conf.bleedamount), 'printCmdLine"vconfig bleedamount "', "Set the # of health bleeding above which the system will start clotting", true)
      fg(defaultcolour) echo(" health or ") fg("a_cyan")
      echoLink(tostring(conf.manableedamount), 'printCmdLine"vconfig manableedamount "', "Set the # of mana bleeding above which the system will start clotting", true)
      fg(defaultcolour) echo(" mana (and over ") fg("a_cyan")
      echoLink(tostring(conf.corruptedhealthmin).."%", 'printCmdLine"vconfig corruptedhealthmin "', "Set the % of health below which the system will not clot your mana bleeding (due tp Alchemist corruption, which makes bleeding lose mana and clotting it will use health)", true)
      fg(defaultcolour) echo(" health)\n")
    end,
  }},
  {manableedamount = {
    type = "number",
    vconfig2string = true,
    min = 0,
    onset = function () svo.echof("Will start clotting if bleeding for more than %d mana.", conf.manableedamount) end,
    installstart = function () conf.manableedamount = 60 end,
  }},
  {corruptedhealthmin = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxhealth:emit() svo.echof("Will not clot your mana bleeding if your health falls below %d%% (%dh).", conf.corruptedhealthmin, sys.corruptedhealthmin) end,
    installstart = function () conf.corruptedhealthmin = 70 end
  }},
  {valerianid = {
    type = "number",
    min = 0,
    installstart = function () conf.valerianid = nil; pipes.valerian.id = 0 end,
    installcheck = function () svo.echof("What pipe should we use for valerian? Answer with the ID, please.") end,
    onset = function ()
      pipes.valerian.id = tonumber(conf.valerianid)
      svo.echof("Set the valerian pipe id to %d.", pipes.valerian.id) end,
  }},
  {skullcapid = {
    type = "number",
    min = 0,
    installstart = function () conf.skullcapid = nil; pipes.skullcap.id = 0 end,
    installcheck = function () svo.echof("What pipe should we use for skullcap? Answer with the ID, please.") end,
    onset = function ()
      pipes.skullcap.id = tonumber(conf.skullcapid)
      svo.echof("Set the skullcap pipe id to %d.", pipes.skullcap.id) end,
  }},
  {treefunc = {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      svo.echof("Scenarios to use tree in:")
      local sortednames = svo.keystolist(svo.tree)
      table.sort(sortednames)
      local longestfname = svo.longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = svo.tree[fname]

        if not me.disabledtreefunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[svo.me.disabledtreefunc["]]..fname..[["] = true; svo.config.set'treefunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[svo.me.disabledtreefunc["]]..fname..[["] = false; svo.config.set'treefunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline

      svo.showprompt()
    end
  }},
  {restorefunc = {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      svo.echof("Scenarios to use restore in:")
      local sortednames = svo.keystolist(svo.restore)
      table.sort(sortednames)
      local longestfname = svo.longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = svo.restore[fname]

        if not me.disabledrestorefunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[svo.me.disabledrestorefunc["]]..fname..[["] = true; svo.config.set'restorefunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[svo.me.disabledrestorefunc["]]..fname..[["] = false; svo.config.set'restorefunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline
      svo.showprompt()
    end
  }},
  {dragonhealfunc = {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      svo.echof("Scenarios to use dragonheal in:")

      local sortednames = svo.keystolist(svo.dragonheal)
      table.sort(sortednames)
      local longestfname = svo.longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = svo.dragonheal[fname]
        if not me.disableddragonhealfunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[svo.me.disableddragonhealfunc["]]..fname..[["] = true; svo.config.set'dragonhealfunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[svo.me.disableddragonhealfunc["]]..fname..[["] = false; svo.config.set'dragonhealfunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline
    end
  }},
  {elmid = {
    type = "number",
    min = 0,
    installstart = function () conf.elmid = nil; pipes.elm.id = 0 end,
    installcheck = function () svo.echof("What pipe should we use for elm? Answer with the ID, please.") end,
    onset = function ()
      pipes.elm.id = tonumber(conf.elmid)
      svo.echof("Set the elm pipe id to %d.", pipes.elm.id) end,
  }},
  {eventaffs = {
    type = "boolean",
    -- vconfig2 = true,
    -- onshow = "Raise Mudlet events on each affliction",
    onenabled = function () svo.echof("<0,250,0>Will%s raise Mudlet events for gained/lost afflictions.", svo.getDefaultColor()) end,
    ondisabled = function () conf.eventaffs = true svo.echof("eventaffs are on by default now - and this option is depreciated; there's no point in turning it off.") end,
    installstart = function () conf.eventaffs = true end
  }},
  {gagclot = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Gag clotting",
    onenabled = function () svo.echof("<0,250,0>Will%s gag the clotting spam.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s gag the clotting spam.", svo.getDefaultColor()) end,
    installstart = function () conf.gagclot = true end,
  }},
  {autorewield = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      if next(gmcp) then
        echo "Rewield forced unwield.\n"
      else
        echo "Rewield forced unwield (requires GMCP)\n"
      end
    end,
    onenabled = function ()
      if sys.enabledgmcp then
        svo.echof("<0,250,0>Will%s automatically rewield items that we've been forced to unwield.", svo.getDefaultColor())
      else
        svo.echof("<0,250,0>Will%s automatically rewield items that we've been forced to unwield (requires GMCP being enabled).", svo.getDefaultColor())
      end
    end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s automatically rewield things.", svo.getDefaultColor()) end
  }},
  {preclot = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      if conf.preclot and conf.clot then
        echo "Will preclot bleeding.\n"
      elseif conf.preclot and not conf.clot then
        echo "Will do preclotting (when clotting is enabled).\n"
      else
        echo "Won't preclot bleeding.\n"
      end
    end,
    onenabled = function () svo.echof("<0,250,0>Will%s do preclotting (saves health at expense of willpower).", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s do preclotting (saves willpwer at expense of health).", svo.getDefaultColor()) end,
    installstart = function () conf.preclot = true end,
    installcheck = function () svo.echof("Should the system do preclotting? Doing so will save you from some bleeding damage, at the cost of more willpower.") end
  }},
  {org = {
    type = "string",
    check = function (what)
      if svo.contains({"Ashtan", "Hashan", "Mhaldor", "Targossas", "Cyrene", "Eleusis", "None", "Rogue"}, what:title()) then return true end
    end,
    onset = function ()
      if conf.org == "none" or conf.org == "rogue" then
        conf.org = "none"
        -- reset echotype so the org change can have effect on echoes
        conf.echotype = nil
        signals.orgchanged:emit()
        svo.echof("Will use the default plain echoes.")
      else
        conf.org = string.title(conf.org)
        -- reset echotype so the org change can have effect on echoes
        conf.echotype = nil

        -- if NameDB is present, set own city to be allied - in case you weren't a citizen of this city before and it was an enemy to you
        if ndb and ndb.conf and type(ndb.conf.citypolitics) == "table" then
          ndb.conf.citypolitics[conf.org] = "ally"
        end

        signals.orgchanged:emit()
        svo.echof("Will use %s-styled echoes.", conf.org)
      end

    end,
    installstart = function ()
      conf.org = nil end,
    installcheck = function ()
      svo.echof("What city do you live in? Select from: Ashtan, Hashan, Mhaldor, Targossas, Cyrene, Eleusis or none.") end
  }},
  {slowcurecolour = {
    type = "string",
    vconfig2string = true,
    check = function (what)
      if color_table[what] or what == "off" then return true end
    end,
    onset = function ()
      local r,g,b = unpack(color_table[conf.slowcurecolour])
      svo.echof("Will colour your actions in <%d,%d,%d>%s%s when in aeon or retardation.", r,g,b, conf.slowcurecolour, svo.getDefaultColor())
    end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Colouring aeon/retardation curing lines in ") fg(conf.slowcurecolour)
      echoLink(tostring(conf.slowcurecolour), 'printCmdLine"vconfig slowcurecolour "',
      "Set which colour you'd like curing lines to show as in aeon / retardation",
       true)
      cecho("<a_grey>.\n")
    end,
    installstart = function ()
      conf.slowcurecolour = "blue" end
  }},
  {hinderpausecolour = {
    type = "string",
    vconfig2string = true,
    check = function (what)
      if color_table[what] or what == "off" then return true end
    end,
    onset = function ()
      local r,g,b = unpack(color_table[conf.hinderpausecolour])
      svo.echof("Will colour hindering afflictions in <%d,%d,%d>%s%s when paused.", r,g,b, conf.hinderpausecolour, svo.getDefaultColor())
    end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Colouring hindering lines in ") fg(conf.hinderpausecolour)
      echoLink(tostring(conf.hinderpausecolour), 'printCmdLine"vconfig hinderpausecolour "',
      "Set which colour you'd like to see hindering lines in when paused",
       true)
      cecho("<a_grey> when paused.\n")
    end,
    installstart = function ()
      conf.hinderpausecolour = "orange" end
  }},
  {autoreject = {
    type = "string",
    check = function (what)
      if svo.contains({"black", "white", "off", "on"}, what:sub(1,5):lower()) then sk.oldautoreject = conf.autoreject return true end
    end,
    onset = function ()
      conf.autoreject = string.lower(conf.autoreject):sub(1,5)

      if conf.autoreject == "off" then
        svo.ignore.lovers = true
        conf.autoreject = sk.oldautoreject; sk.oldautoreject = nil
        svo.echof("Disabled autoreject completely (ie, will ignore curing lovers aff).")
      elseif conf.autoreject == "on" then
        svo.ignore.lovers = nil
        conf.autoreject = sk.oldautoreject; sk.oldautoreject = nil
        svo.echof("Enabled autoreject (won't ignore curing lovers anymore) - right now it's in %slist mode.", conf.autoreject)
      elseif conf.autoreject == "white" then
        local c = table.size(me.lustlist)
        svo.echof("Autoreject has been set to whitelist mode - that means we will be automatically rejecting everybody, except those on the lust list (%d %s).", c, (c == 1 and "person" or "people"))
      elseif conf.autoreject == "black" then
        local c = table.size(me.lustlist)
        svo.echof("Autoreject has been set to blacklist mode - that means we will only be rejecting people on the lust list (%d %s).", c, (c == 1 and "person" or "people"))
      else
        svo.echof("... how did you manage to set the option to '%s'?", tostring(conf.autoreject))
      end
    end,
    installstart = function ()
      conf.autoreject = "white" end
  }},
  {lustlist = {
    type = "string",
    check = function(what)
      if what:find("^%w+$") then return true end
    end,
    onset = function ()
      local name = string.title(conf.lustlist)
      if not me.lustlist[name] then me.lustlist[name] = true else me.lustlist[name] = nil end

      if me.lustlist[name] then
        if conf.autoreject == "black" then
          svo.echof("Added %s to the lust list (so we will be autorejecting them).", name)
        elseif conf.autoreject == "white" then
          svo.echof("Added %s to the lust list (so we won't be autorejecting them).", name)
        else
          svo.echof("Added %s to the lust list.", name)
        end
      else
        if conf.autoreject == "black" then
          svo.echof("Removed %s from the lust list (so we will not be autorejecting them now).", name)
        elseif conf.autoreject == "white" then
          svo.echof("Removed %s from the lust list (so we will be autorejecting them).", name)
        else
          svo.echof("Removed %s from the lust list.", name)
        end
      end
    end
  }},
  {autowrithe = {
    type = "string",
    check = function (what)
      if svo.contains({"black", "white", "off", "on"}, what:sub(1,5):lower()) then sk.oldautowrithe = conf.autowrithe return true end
    end,
    onset = function ()
      conf.autowrithe = string.lower(conf.autowrithe):sub(1,5)

      if conf.autowrithe == "off" then
        svo.ignore.hoisted = true
        conf.autowrithe = sk.oldautowrithe; sk.oldautowrithe = nil
        svo.echof("Disabled autowrithe completely (ie, will ignore curing hoisted aff).")
      elseif conf.autowrithe == "on" then
        svo.ignore.hoisted = nil
        conf.autowrithe = sk.oldautowrithe; sk.oldautowrithe = nil
        svo.echof("Enabled autowrithe (won't ignore curing hoisted anymore) - right now it's in %slist mode.", conf.autowrithe)
      elseif conf.autowrithe == "white" then
        local c = table.size(me.hoistlist)
        svo.echof("Autowrithe has been set to whitelist mode - that means we will be automatically writhing against everybody, except those on the hoist list (%d %s).", c, (c == 1 and "person" or "people"))
      elseif conf.autowrithe == "black" then
        local c = table.size(me.hoistlist)
        svo.echof("Autowrithe has been set to blacklist mode - that means we will only be writhing against people on the hoist list (%d %s).", c, (c == 1 and "person" or "people"))
      else
        svo.echof("... how did you manage to set the option to '%s'?", tostring(conf.autowrithe))
      end
    end,
    installstart = function ()
      conf.autowrithe = "white" end
  }},
  {hoistlist = {
    type = "string",
    check = function(what)
      if what:find("^%w+$") then return true end
    end,
    onset = function ()
      local name = string.title(conf.hoistlist)
      if not me.hoistlist[name] then me.hoistlist[name] = true else me.hoistlist[name] = nil end

      if me.hoistlist[name] then
        if conf.autowrithe == "black" then
          svo.echof("Added %s to the hoist list (so we will autowrithe against them).", name)
        elseif conf.autowrithe == "white" then
          svo.echof("Added %s to the hoist list (so we won't autowrithe against them).", name)
        else
          svo.echof("Added %s to the hoist list.", name)
        end
      else
        if conf.autowrithe == "black" then
          svo.echof("Removed %s from the hoist list (so we will not autowrithe against them now).", name)
        elseif conf.autowrithe == "white" then
          svo.echof("Removed %s from the hoist list (so we will autowrithe against them).", name)
        else
          svo.echof("Removed %s from the hoist list.", name)
        end
      end
    end
  }},
  {echotype = {
    type = "string",
    check = function (what)
      if svo.echos[what:title()] or svo.echos[what] then return true end
    end,
    onset = function ()
      conf.echotype = svo.echos[conf.echotype:title()] and conf.echotype:title() or conf.echotype
      signals.orgchanged:emit()
      svo.echof("This is how system messages will look like now :)")
    end,
    vconfig2 = true,
    installstart = function ()
      conf.org = nil end,
  }},
  {dragonflex = {
    type = "boolean",
    vconfig1 = "dragonflex",
    onenabled = function () svo.echof("<0,250,0>Will%s use dragonflex when we have balance.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use dragonflex.", svo.getDefaultColor()) end,
    installstart = function () conf.dragonflex = nil end,
    installcheck = function () svo.echof("Can you make use of the Dragonflex skill?") end
  }},
  {assumestats = {
    type = "number",
    vconfig2 = true,
    min = 0,
    max = 100,
    onset = function () svo.echof("Will assume we're at %d%% of health and mana when under blackout or recklessness.", conf.assumestats) end,
    installstart = function () conf.assumestats = 15 end,
  }},
  {healthaffsabove = {
    type = "number",
    vconfig2 = true,
    min = 0,
    max = 100,
    onset = function () svo.echof("Will apply health to cure afflictions only when above %d%% health.", conf.healthaffsabove) end,
    installstart = function () conf.healthaffsabove = 70 end,
  }},
  {warningtype = {
    type = "string",
    vconfig2 = true,
    check = function (what)
      if svo.contains({"all", "prompt", "none", "right", "off"}, what) then return true end
    end,
    onset = function ()
      if conf.warningtype == "none" or conf.warningtype == "off" then
        conf.warningtype = false
        svo.echof("Disabled extended instakill warnings.")
      elseif conf.warningtype == "all" then
        svo.echof("Will prefix instakill warnings to all lines.")
        if math.random(1, 10) == 1 then svo.echof("(muahah(") end
      elseif conf.warningtype == "prompt" then
        svo.echof("Will prefix instakill warnings only to prompt lines.")
      elseif conf.warningtype == "right" then
        svo.echof("Will place instakill warnings on all lines, aligned on the right side.")
      end
    end,
    installstart = function ()
      conf.warningtype = "right" end,
  }},
  {burstmode = {
    type = "string",
    vconfig2string = true,
    check = function (what)
      if defdefup[what:lower()] then return true end
    end,
    onshow = function (defaultcolour)
      local tooltip

      if svo.haveskillset('necromancy') then
        tooltip = "Set the defences mode system should autoswitch to upon starburst/soulcage"
      elseif svo.haveskillset('occultism') then
        tooltip = "Set the defences mode system should autoswitch to upon starburst/transmog"
      else
        tooltip = "Set the defences mode system should autoswitch to upon starburst"
      end

      fg(defaultcolour)
      echo("Upon starbursting, will go into ") fg("a_cyan")
      echoLink(tostring(conf.burstmode), 'printCmdLine"vconfig burstmode "', tooltip, true)
      cecho("<a_grey> defences mode.\n")
    end,
    onset = function ()
      conf.burstmode = conf.burstmode:lower()
      if svo.haveskillset('necromancy') then
            svo.echof("Upon starburst/soulcage, will go into %s defences mode.", conf.burstmode)
      elseif svo.haveskillset('occultism') then
            svo.echof("Upon starburst/transmogrify, will go into %s defences mode.", conf.burstmode)
      else
            svo.echof("Upon starburst, will go into %s defences mode.", conf.burstmode)
      end
    end,
    installstart = function ()
      conf.burstmode = "empty" end
  }},
  {oldts = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Touch shield only once on ts",
    onenabled = function () svo.echof("<0,250,0>Will%s use oldschool ts - using ts one will shield once.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use oldschool ts - using ts will enable shield keepup.", svo.getDefaultColor()) end,
    installstart = function () conf.oldts = false end,
    installcheck = function () svo.echof("In Svof, <0,255,0>ts%s is a toggle for <0,255,0>vkeep shield%s - it'll reshield you if the shield gets stripped. Previously it used to shield you once only. Would you like to be a toggle (<0,255,0>vconfig oldts no%s) or a one-time thing (<0,255,0>vconfig oldts yes%s)?", svo.getDefaultColor(), svo.getDefaultColor(), svo.getDefaultColor(), svo.getDefaultColor()) end
  }},
  {batch = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Batch multiple curing commands",
    onenabled = function () svo.echof("<0,250,0>Will%s batch multiple curing commands to be done at once, without prompts inbetween.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s batch curing commands to be done at once, but instead send them separately at once.", svo.getDefaultColor()) end,
    installstart = function () conf.batch = true end,
  }},
  {steedfollow = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Auto-order steed to follow us",
    onenabled = function () svo.echof("<0,250,0>Will%s make the steed follow us when we dismount (via va).", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s make the steed follow us anymore when we dismount (via va).", svo.getDefaultColor()) end,
    installstart = function () conf.steedfollow = true end
  }},
  {autotsc = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Automatically toggle tsc in aeon/ret",
    onenabled = function () svo.echof("<0,250,0>Will%s automatically toggle tsc - overrides in retardation and denies in aeon.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s automatically toggle tsc.", svo.getDefaultColor()) end,
  }},
  {medprone = {
    type = "boolean",
    vconfig2string = true,
    onshow = function (defaultcolour)
      fg("a_cyan")
      echoLink((conf.medprone and "Do" or "Don't"), 'printCmdLine"vconfig medprone '..(conf.medprone and "nope" or "yep")..'"',
      "Click to set whenever you'd like the system to put prone on ignore while meditating for you, so you can sit down while doing it. The drawback is that if you're trying to meditate in combat and get proned, the system won't get up",
       true)
      fg(defaultcolour)
      echo(" ignore prone while meditating, and ")
      fg("a_cyan")
      echoLink((conf.unmed and "do" or "don't"), 'printCmdLine"vconfig unmed '..(conf.unmed and "nope" or "yep")..'"',
      "Click to set whenever you'd like the system take meditate off keepup when you reach full willpower",
       true)
      fg(defaultcolour)
      echo(" stop at full willpower.\n")
    end,
    installstart = function() conf.medprone = false end,
    onenabled = function () svo.echof("<0,250,0>Will%s put prone on ignore when meditating, so you can be sitting.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s put prone on ignore when meditating.", svo.getDefaultColor()) end,
  }},
  {unmed = {
    type = "boolean",
    onshow = "Automatically disable med with full wp",
    onenabled = function () svo.echof("<0,250,0>Will%s take meditate off keepup when you reach full willpower.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s take meditate off keepup when you reach full willpower - so we'll meditate again if you lose any mana/willpower.", svo.getDefaultColor()) end,
  }},
  {classattacksamount = {
    type = "number",
    min = 0,
    vconfig2string = true,
    onset = function () svo.echof("Will enable a class after they hit us with %d attacks (within %d seconds).", conf.classattacksamount, conf.classattackswithin) end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      -- Enable class as fighting with after x attacks in x seconds
      echo("Enable class as fighting with after") fg("a_cyan")
      echoLink(" "..tostring(conf.classattacksamount), 'printCmdLine"vconfig classattacksamount "',
      "Set the amount of attacks an enemy will do to you within "..tostring(conf.classattackswithin).." seconds to enable the class tricks",
       true)
      cecho("<a_grey> attacks in") fg("a_cyan")
      echoLink(" "..tostring(conf.classattackswithin), 'printCmdLine"vconfig classattackswithin "',
      "Set the time within ".. tostring(conf.classattacksamount).. " attacks from a class will enable tricks for it",
       true)
      cecho(" seconds.\n")
    end,
    installstart = function () conf.classattacksamount = 3 end
  }},
  {classattackswithin = {
    type = "number",
    min = 0,
    onset = function () svo.echof("Will enable a class when they hit us within %d seconds (with %d attacks).", conf.classattackswithin, conf.classattacksamount) end,
    installstart = function () conf.classattackswithin = 15 end
  }},
  {enableclassesfor = {
    type = "number",
    min = 0,
    vconfig2string = true,
    onset = function () svo.echof("Will keep the class enabled for %s minutes after the fighting ends.", conf.enableclassesfor) end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      -- Keep a class enabled for x minutes after fighting
      echo("Keep a class enabled for") fg("a_cyan")
      echoLink(" "..tostring(conf.enableclassesfor), 'printCmdLine"vconfig enableclassesfor "',
      "Set (in minutes) how long to keep a class enabled for after the fighting ends",
       true)
      cecho("<a_grey> minutes after fighting.\n")
    end,
    installstart = function () conf.enableclassesfor = 2 end
  }},
  {gmcpaffechoes = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s notify you when GMCP updates your afflictions.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s notify you when GMCP updates your afflictions.", svo.getDefaultColor()) end,
  }},
  {gmcpdefechoes = {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Will%s notify you when GMCP updates your defences.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s notify you when GMCP updates your defences.", svo.getDefaultColor()) end,
  }},
  {releasechannel = {
    type = "string",
    vconfig2string = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Will use the ")
      fg("a_cyan")
      echoLink(tostring(conf.releasechannel),
        'printCmdLine("vconfig releasechannel ")',
        "Set the release channel to use for updates.",
        true
      )
      fg(defaultcolour)
      echo(" channel for downloading updates.\n")
    end,
    check = function (what)
      if what == "stable" or what == "testing" then return true end
    end,
    onset = function ()
      conf.releasechannel = conf.releasechannel:lower()
      svo.echof("Will use the '%s' release channel for updates.",
        conf.releasechannel)
    end,
    installstart = function ()
      conf.releasechannel = "stable"
    end
  }},
}

if svo.haveskillset('healing') then
  svo.config_dict:insert(1, "healingskill", {
    type = "string",
    check = function (what)
      if table.contains({"blindness", "paralysis", "deafness", "fear", "confusion", "insomnia", "slickness", "stuttering", "paranoia", "shyness", "hallucinations", "generosity", "loneliness", "impatience", "unconsciousness", "claustrophobia", "vertigo", "sensitivity", "dizziness", "arms", "dementia", "clumsiness", "ablaze", "recklessness", "anorexia", "agoraphobia", "disloyalty", "hypersomnia", "darkshade", "masochism", "epilepsy", "asthma", "stupidity", "vomiting", "weariness", "haemophilia", "legs", "hypochondria"}, what:lower()) then return true end
    end,
    onset = function ()
      conf.healingskill = conf.healingskill:lower()
      signals.healingskillchanged:emit()
      svo.echof("Thanks! That means that you can now cure:  \n%s", svo.oneconcat(sk.healingmap))
    end,
    vconfig2 = true,
    installstart = function ()
      conf.healingskill = nil end,
    installcheck = function ()
      svo.echof("What is the highest possible affliction that you can cure with Healing? If you don't have it yet, answer with 'blindness' and set 'none' for the 'usehealing' option.") end
  })
  svo.config_dict:insert(1, "usehealing", {
    type = "string",
    check = function (what)
      if table.contains({"full", "partial", "none", "off"}, what:lower()) then return true end
    end,
    onset = function ()
      conf.usehealing = conf.usehealing:lower()
      if conf.usehealing == "off" then conf.usehealing = "none" end
      svo.echof("Will use Healing in the '%s' mode.", conf.usehealing)
    end,
    vconfig2 = true,
    installstart = function ()
      conf.usehealing = nil end,
    installcheck = function ()
      svo.echof("Do you want to use Healing skillset in the full, partial or none mode? Full would mean that it'll use Healing for everything that it can and supplement it with normal cures. Partial would mean that it'll use normal cures and supplement it with Healing, while none means it won't make use of Healing at all.") end
  })
end
if svo.haveskillset('kaido') then
  svo.config_dict:insert(1, "transmute", {
    type = "string",
    check = function (what)
      if svo.convert_string(what) == false then return true end
      if table.contains({"replaceall", "replacehealth", "supplement", "none", "off"}, what:lower()) then return true end
    end,
    onset = function ()
      conf.transmute = conf.transmute:lower()
      if svo.convert_string(conf.transmute) == false or conf.transmute == "none" then
        conf.transmute = "none"
      end

      if conf.transmute == "off" then conf.transmute = "none" end

      if conf.transmute == "none" then
        svo.echof("Won't use transmute for anything.")
      else
        svo.echof("Will use transmute in the '%s' mode.", conf.transmute) end
    end,
    vconfig2 = true,
    installstart = function () conf.transmute = nil end,
    installcheck = function ()
      svo.echof("Do you want to use transmute skill in the replaceall, replacehealth, supplement or none mode? replaceall means that it won't sip health nor eat moss/potash to heal your health, but only use transmute. replacehealth will mean that it will not sip health, but use moss/potash and transmute. supplement means that it'll use all three ways to heal you, and none means that it won't use transmute.") end
  })
  svo.config_dict:insert(1, "transmuteamount", {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxhealth:emit()
      svo.echof("Will start transmuting for health if it falls below %d%% (%dh)%s.", conf.transmuteamount, sys.transmuteamount, (conf.transmute ~= "none" and "" or ", when you enable a transmute mode"))
    end,
    installstart = function () conf.transmuteamount = nil end,
    installcheck = function () svo.echof("At what %% of health do you want to start transmuting for health?") end
  })
  svo.config_dict:insert(1, "transsipprone", {
      type = "boolean",
      vconfig2 = "Transmute while prone",
      onenabled = function () svo.echof("If you're prone and using transmute in a replaceall or replacehealth mode, we <0,250,0>will%s sip health or vitality instead of waiting on transmute to be usable. This is most optimal for PK.", svo.getDefaultColor()) end,
      ondisabled = function () svo.echof("If you're prone and using transmute in a replaceall or replacehealth mode, we'll keep sipping mana and wait until we can use transmute again to heal our health. This is mainly good for bashing.", svo.getDefaultColor()) end,
      installstart = function () conf.transsipprone = true end
    })
end
if svo.haveskillset('voicecraft') then
  svo.config_dict:insert(1, "dwinnu", {
    type = "boolean",
    vconfig1 = "dwinnu",
    onenabled = function () svo.echof("<0,250,0>Will%s use dwinnu for writhing.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use dwinnu.", svo.getDefaultColor()) end,
    installstart = function () conf.dwinnu = nil end,
    installcheck = function () svo.echof("Can you make use of the Wwinnu skill?") end
  })
end
if svo.haveskillset('weaponmastery') then
  svo.config_dict:insert(1, "recoverfooting", {
      type = "boolean",
      vconfig1 = "recover footing",
      onenabled = function () svo.echof("<0,250,0>Will%s use Recover Footing to get up faster when we can.", svo.getDefaultColor()) end,
      ondisabled = function () svo.echof("<250,0,0>Won't%s use Recover Footing.", svo.getDefaultColor()) end,
      installstart = function () conf.recoverfooting = nil end,
      installcheck = function () svo.echof("Can you make use of the Recover Footing skill?") end
    })
end
if svo.haveskillset('venom') then
  svo.config_dict:insert(1, "shruggingfunc", {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      svo.echof("Scenarios to use shrugging in:")

      local sortednames = svo.keystolist(svo.shrugging)
      table.sort(sortednames)
      local longestfname = svo.longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = svo.shrugging[fname]

        if not me.disabledshruggingfunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[svo.me.disabledshruggingfunc["]]..fname..[["] = true; svo.config.set'shruggingfunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[svo.me.disabledshruggingfunc["]]..fname..[["] = false; svo.config.set'shruggingfunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline
    end
  })
end
if svo.haveskillset('devotion') then
  svo.config_dict:insert(1, "bloodswornoff", {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo(string.format("Unlinking Bloodsworn at %s%% (%sh).\n", conf.bloodswornoff or '?', sys.bloodswornoff or '?'))
    end,
    onset = function () signals.changed_maxhealth:emit() svo.echof("Will unlink from bloodsworn if below %d%% (%dh).", conf.bloodswornoff, sys.bloodswornoff) end,
    installstart = function () conf.bloodswornoff = 30 end
  })
end
if svo.haveskillset('woodlore') then
  svo.config_dict:insert(1, "weapon", {
    type = "string",
    onset = function ()
      conf.weapon = conf.weapon:lower()
      svo.echof("Set your weapon to '%s'.", conf.weapon)
    end,
    vconfig2 = true,
    onshow = string.format("Using a %s as a weapon", (conf.weapon and tostring(conf.weapon) or "(nothing)")),
    installstart = function ()
      conf.weapon = nil end,
    installcheck = function ()
      svo.echof("Are you using a spear or a trident as a weapon?") end
  })
end
if svo.haveskillset('metamorphosis') then
  svo.config_dict:insert(1, "transmorph", {
    type = "boolean",
    onenabled = function () svo.echof("<0,250,0>Have%s transmorph - won't go human between morphing.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Don't%s have transmorph - will go human between morphing.", svo.getDefaultColor()) end,
    onshow = "Have transmorph",
    installstart = function () conf.transmorph = nil end,
    installcheck = function () svo.echof("Do you have the Metamorphosis Transmorph skill?") end
  })
  svo.config_dict:insert(1, "morphskill", {
    type = "string",
    check = function (what)
      return sk.validmorphskill(what)
    end,
    onset = function ()
      conf.morphskill = conf.morphskill:lower()
      local t = {powers = "squirrel", bonding = "bear", transmorph = "elephant", affinity = "icewyrm"}
      if svo.me.class == "Druid" then
            t.truemorph = "hydra"
      else
            t.truemorph = "icewyrm"
      end
      if t[conf.morphskill] then
        svo.echof("Thanks! I've set your morphskill to '%s' though, because %s isn't a morph.", t[conf.morphskill], conf.morphskill)
        conf.morphskill = t[conf.morphskill]
      end
      signals.morphskillchanged:emit()
      svo.echof("Given your morph skill, these are all defences you can put up: %s.", svo.concatand(svo.keystolist(sk.morphsforskill)) ~= "" and svo.concatand(svo.keystolist(sk.morphsforskill)) or "(... none, actually. Nevermind!)")
    end,
    installstart = function () svo.sp_config.morphskill = nil end,
    installcheck = function () svo.echof("What is the highest available morph that you can go into?") end
  })
end
if not svo.haveskillset('tekura') then
  svo.config_dict:insert(1, "parry", {
    type = "boolean",
    vconfig1 = "parry",
    onenabled = function () svo.echof("<0,250,0>Will%s make use of parry.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s make use of parry.", svo.getDefaultColor()) end,
    installstart = function () conf.parry = nil end,
    installcheck = function () svo.echof("Are you able to use parry?") end
  })
else
  svo.config_dict:insert(1, "guarding", {
    type = "boolean",
    vconfig1 = "guarding",
    onenabled = function () svo.echof("<0,250,0>Will%s make use of guarding.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s make use of guarding.", svo.getDefaultColor()) end,
    installstart = function () conf.guarding = nil end,
    installcheck = function () svo.echof("Are you able to use guarding?") end
  })
end
if svo.haveskillset('shindo') then
  svo.config_dict:insert(1, "shindodeaf", {
    type = "boolean",
    vconfig1 = "shindodeaf",
    onenabled = function () svo.echof("<0,250,0>Will%s use the Shindo deaf skill for deaf.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use the Shindo deaf skill for deaf.", svo.getDefaultColor()) end,
    installstart = function () conf.shindodeaf = nil end,
    installcheck = function () svo.echof("Would you like to use Shindo deaf for deafness?") end
  })
  svo.config_dict:insert(1, "shindoblind", {
    type = "boolean",
    vconfig1 = "shindoblind",
    onenabled = function () svo.echof("<0,250,0>Will%s use the Shindo blind skill for blind.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use the Shindo blind skill for blind.", svo.getDefaultColor()) end,
    installstart = function () conf.shindoblind = nil end,
    installcheck = function () svo.echof("Would you like to use Shindo blind for blindness?") end
  })
end
if svo.haveskillset('kaido') then
  svo.config_dict:insert(1, "kaidodeaf", {
    type = "boolean",
    vconfig1 = "kaidodeaf",
    onenabled = function () svo.echof("<0,250,0>Will%s use the kaido deaf skill for deaf.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use the kaido deaf skill for deaf.", svo.getDefaultColor()) end,
    installstart = function () conf.kaidodeaf = nil end,
    installcheck = function () svo.echof("Would you like to use kaido deaf for deafness?") end
  })
  svo.config_dict:insert(1, "kaidoblind", {
    type = "boolean",
    vconfig1 = "kaidoblind",
    onenabled = function () svo.echof("<0,250,0>Will%s use the kaido blind skill for blind.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use the kaido blind skill for blind.", svo.getDefaultColor()) end,
    installstart = function () conf.kaidoblind = nil end,
    installcheck = function () svo.echof("Would you like to use kaido blind for blindness?") end
  })
end
if svo.haveskillset('chivalry') or svo.haveskillset('shindo') or svo.haveskillset('kaido') or svo.haveskillset('metamorphosis') then
  svo.config_dict:insert(1, "fitness", {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use fitness       ("
      echoLink("view scenarios", "svo.config.set'fitnessfunc'", "View, enable and disable scenarios in which fitness will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () svo.echof("<0,250,0>Will%s use of Fitness.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use of Fitness.", svo.getDefaultColor()) end,
    installstart = function () conf.fitness = nil end,
    installcheck = function () svo.echof("Can you make use of the Fitness skill?") end
  })
  svo.config_dict:insert(1, "fitnessfunc", {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      svo.echof("Scenarios to use fitness in:")
      local sortednames = svo.keystolist(svo.fitness)
      table.sort(sortednames)
      local longestfname = svo.longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = svo.fitness[fname]

        if not me.disabledfitnessfunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[svo.me.disabledfitnessfunc["]]..fname..[["] = true; svo.config.set'fitnessfunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[svo.me.disabledfitnessfunc["]]..fname..[["] = false; svo.config.set'fitnessfunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline

      svo.showprompt()
    end
  })
end
if svo.haveskillset('venom') then
  svo.config_dict:insert(1, "shrugging", {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use shrugging  ("
      echoLink("view scenarios", "svo.config.set'shruggingfunc'", "View, enable and disable scenarios in which shrugging will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () svo.echof("<0,250,0>Will%s use shrugging to cure when necessary.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use shrugging to cure.", svo.getDefaultColor()) end,
    installstart = function () conf.shrugging = nil end,
    installcheck = function () svo.echof("Can you make use of the shrugging?") end
  })
end
if svo.haveskillset('chivalry') then
  svo.config_dict:insert(1, "rage", {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use rage       ("
      echoLink("view scenarios", "svo.config.set'ragefunc'", "View, enable and disable scenarios in which rage will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () svo.echof("<0,250,0>Will%s use of Rage.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s use of Rage.", svo.getDefaultColor()) end,
    installstart = function () conf.rage = nil end,
    installcheck = function () svo.echof("Can you make use of the Rage skill?") end
  })
  svo.config_dict:insert(1, "ragefunc", {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      svo.echof("Scenarios to use rage in:")
      local sortednames = svo.keystolist(svo.rage)
      table.sort(sortednames)
      local longestfname = svo.longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = svo.rage[fname]

        if not me.disabledragefunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[svo.me.disabledragefunc["]]..fname..[["] = true; svo.config.set'ragefunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[svo.me.disabledragefunc["]]..fname..[["] = false; svo.config.set'ragefunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline

      svo.showprompt()
    end
  })
end

if not conf.releasechannel then
  conf.releasechannel = "stable"
end

if not conf.autowrithe then
  conf.autowrithe = "white"
end

do
  local conf_t = {}
  local conf_path = getMudletHomeDir() .. "/svo/config/conf"

  if lfs.attributes(conf_path) then
    local ok, msg = pcall(table.load,conf_path, conf_t)
    if ok then
      svo.update(conf, conf_t)
    else
      os.remove(conf_path)
      tempTimer(10, function()
        svo.echof("Your vconfig file got corrupted for some reason - I've deleted it so the system can load other stuff OK. You'll need to re-set all of the vconfig options again, though. (%q)", msg)
      end)
    end
  end

  if conf.ai_minherbbal == 0.7 or conf.ai_minherbbal == 1.2 then conf.ai_minherbbal = 1.1 end
  if conf.ai_resetherbbal == 5 then conf.ai_resetherbbal = 2.5 end
  -- recovered at 7.4s for Hirst for twohander aff
  if conf.ai_resetsipbal == 5 then conf.ai_resetsipbal = 7 end
  if conf.ai_resetsipbal == 7 then conf.ai_resetsipbal = 10 end
  if conf.org == "Shallam" then conf.org = "Targossas" end
  -- recovery was renamed as efficiency
  if conf.recovery then conf.efficiency = true; conf.recovery = nil end

  if conf.gagserverside == nil then conf.gagserverside = true end

  -- purgative used to be set at a default 5 before it was even used, it is now 7 for voyria
  if conf.ai_resetpurgativebal == 5 then conf.ai_resetpurgativebal = 10 end

  conf.eventaffs = true

  cnrl.update_wait()

  if conf.bashing then enableTrigger"svo Bashing triggers"
  else disableTrigger"svo Bashing triggers" end

  -- update whenever our riding takes up balance. If it doens't, then balanceless actions should be done asap
  if conf.freevault and svo.dict.riding.physical.balanceful_act then
    svo.dict.riding.physical.balanceless_act = true
    svo.dict.riding.physical.balanceful_act = nil
    signals.dragonform:emit()
  elseif not conf.freevault and svo.dict.riding.physical.balanceless_act then
    svo.dict.riding.physical.balanceless_act = nil
    svo.dict.riding.physical.balanceful_act = true
    signals.dragonform:emit()
  end

  if conf.burrowpause then
    signals.gmcproominfo:connect(sk.check_burrow_pause)
  end

  if not conf.customprompt and not conf.setdefaultprompt then
    tempTimer(math.random(10, 15), function()
      conf.setdefaultprompt = true
      svo.setdefaultprompt()
      -- disabled -- spammy for new users
      -- echo"\n" svo.echof("I've setup a custom prompt for you that mimics the normal Achaean one, but also displays which afflictions have you got. See http://doc.svo.vadisystems.com/#setting-a-custom-prompt on how to customize it if you'd like, or if you don't like it, do 'vconfig customprompt off' to disable it.")
      end)
  end

  if conf.singleprompt then
    sk.enable_single_prompt()
  end

  if conf.riftlabel then
    tempTimer(0, function()
      svo.riftlabel:show()
      rift.update_riftlabel()
    end)
  end
  svo.updateloggingconfig()
end

for k,v in svo.config_dict:iter() do
  -- pre-initialize values not declared
  if conf[k] == nil and v.type == "number" then
    conf[k] = 0
  elseif conf[k] == nil then
    conf[k] = false
  end
end

local tntf_tbl
tntf_tbl = {
  aillusion = { -- is used to change appropriate conf. option
    shortcuts = {"ai", "anti-illusion", "a", "antiillusion"},
    on = function () enableTrigger "Pre-parse anti-illusion";
          svo.echof"Anti-illusion enabled." end,
    alreadyon = function () enableTrigger "Pre-parse anti-illusion";
          svo.echof"Anti-illusion is already enabled." end,
    off = function () disableTrigger "Pre-parse anti-illusion";
          svo.echof"Anti-illusion disabled." end,
    alreadyoff = function () disableTrigger "Pre-parse anti-illusion";
          svo.echof"Anti-illusion is already disabled." end,
  },
  arena = {
    on = function()
      local echos = {"Arena mode enabled. Good luck!", "Beat 'em up! Arena mode enabled.", "Arena mode on.", "Arena mode enabled. Kill them all!"}
            svo.echof(echos[math.random(#echos)])
    end,
    alreadyon = function() svo.echof("Arena mode is already on.") end,
    off = function() svo.echof("Arena mode disabled.") end,
    alreadyoff = function() svo.echof("Arena mode is already off.") end
  },
  keepup = {
    on = function () svo.echof"Auto keepup on." svo.make_gnomes_work() end,
    alreadyon = function () svo.echof"Auto keepup is already on." end,
    off = function () svo.echof"Auto keepup is now off."svo.make_gnomes_work() end,
    alreadyoff = function() svo.echof"Auto keepup is already off." end
  },
  bashing = {
    on = function () enableTrigger"svo Bashing triggers" svo.echof("Enabled bashing triggers.") end,
    alreadyon = function () svo.echof("Bashing triggers are already on.") end,
    off = function() disableTrigger"svo Bashing triggers" svo.echof("Disabled bashing triggers.") end,
    alreadyoff = function() svo.echof("Bashing triggers are already off.") end,
  },
  raid = {
    on = function ()
      svo.tntf_set("keepup", true, true)
      defs.switch("combat", true)
      svo.echof("Switched into combat defence mode and keeping mass, cloak, insomnia, rebounding defences up.")
      defs.keepup("mass", true)
      defs.keepup("cloak", true)
      defs.keepup("mass", true)
      defs.keepup("insomnia", true)
      defs.keepup("rebounding", true)
    end,
    off = function ()
      defs.switch("basic", true)
      svo.echof("Switched to basic defence mode.")
    end
  },
  serverside = {
    shortcuts = {"ss"},
    on = function()
      do
        -- if we've got nothing on the list, setup these defaults
        if not next(svo.serverignore) then
          local list = sk.getallserversideactions()

          for _, action in ipairs(list) do
            svo.serverignore[action] = true
          end

          svo.serverignore.impale     = false -- serverside does not stack writhing atm
          svo.serverignore.lovers     = false -- lust not handled by serverside
          svo.serverignore.selfishness = false -- doesn't take selfish off
        end
      end

      -- take previous ignores off
      local removelist = {}
      for action, data in pairs(svo.ignore) do
        if type(data) == "table" and data.because == "using server-side curing" then
          removelist[#removelist+1] = action
        end
      end

      for _, action in ipairs(removelist) do
        svo.ignore[action] = nil
      end

      if next(removelist) then
        tempTimer(5, [[svo.echof("Took all affs set for serverside curing off ignore. 'vshow ignore' really means ignore again (both in Svof and serverside), use 'vshow server' to toggle what should be done by serverside or Svof.")]])
      end

      svo.echof("Serverside curing enabled (augmented with Svof's).")
      svo.setupserverside()
      svo.sendcuring("afflictions on")
      svo.sendcuring("sipping on")
      svo.sendcuring("defences on")
      svo.sendcuring("focus " .. (conf.focus and "on" or "off"))
      svo.sendcuring("batch on")
      svo.sendc("config advancedcuring on")
      svo.sendcuring("reporting on")
      if not conf.paused then svo.sendcuring("on") end
    end,
    off = function()
      svo.echof("Serverside curing disabled.")
      svo.sendcuring("off")
    end,
    alreadyon = function() svo.echof("Serverside affliction curing is already on.") end,
    alreadyoff = function() svo.echof("Serverside affliction curing is already off.") end,
  }
}

for k,v in pairs(tntf_tbl) do
  if v.shortcuts then
    for _,shortcut in pairs(v.shortcuts) do
      tntf_tbl[shortcut] = k
    end
    v.real = k
  end
end

function svo.tntf_set(what, option, echoback)
  local sendf
  if echoback then sendf = svo.echof else sendf = svo.errorf end

  option = svo.convert_string(option)
  svo.assert(what and (option ~= nil), "syntax is: svo.tntf(what, option)", sendf)

  if not tntf_tbl[what] then
    if echoback ~= "noerrors" then sendf("%s isn't something you can change.", what) end
    return
  end

  local oldechof, oldshowprompt = svo.echof, svo.showprompt

  if echoback == false then
    svo.echof = function() end
    oldshowprompt = svo.echof
  end

  if type(tntf_tbl[what]) == "string" then what = tntf_tbl[what] end
  if option and conf[what] then
    (tntf_tbl[what].alreadyon or tntf_tbl[what].on)()
  elseif not option and not conf[what] then
    (tntf_tbl[what].alreadyoff or tntf_tbl[what].off)()
  elseif not option then
    conf[what] = false
    tntf_tbl[what].off()
    raiseEvent("svo config changed", what)
  else
    conf[what] = true
    tntf_tbl[what].on()
    raiseEvent("svo config changed", what)
  end

  if echoback == false then
    svo.echof = oldechof
    svo.showprompt = oldshowprompt
  end

  if echoback then svo.showprompt() end

  return true
end

-- just display all options in 4 tabs
function svo.sk.show_all_confs()
  local count = 0
  local t = {}; for name, _ in svo.config_dict:iter() do t[#t+1] = name end; table.sort(t)

  for _, name in ipairs(t) do
    if printCmdLine then
      echoLink(string.format("%-20s", tostring(name)), 'printCmdLine("vconfig '..name..' ")', conf_installhint(name), true)
    else
      echo(string.format("%-20s", tostring(name))) end
    count = count + 1
    if count % 4 == 0 then echo "\n" end
  end
end

function svo.config.setoption(name, data)
  svo.config_dict:set(name, data)
  if conf[name] == nil and svo.config_dict[name].type == "number" then
    conf[name] = conf[name] or 0
  elseif conf[name] == nil then
    conf[name] = conf[name] or false
  end
end

function svo.config.deloption(name)
  if svo.config_dict[name] then
    svo.config_dict:set(name, nil)
  end
end

function svo.config.set(what, option, echoback)
  local sendf
  local showprompt = svo.showprompt
  local oldechof
  if echoback then
    sendf = svo.echof
  else
    sendf = svo.errorf
    -- hide echoes and prompt
    showprompt = function() end
    oldechof = svo.echof
    svo.echof = function() end
  end

  local function raiseevent(optionname)
    tempTimer(0, function() raiseEvent("svo config changed", optionname) end)
  end

  if not svo.config_dict[what] or what == "list" or what == "options" then
    sendf("%s - available ones are:", (what == "list" or what == "option") and "Listing all options" or "Don't know about such an option")
    sk.show_all_confs()
    echo"\n"
    showprompt()
    if not echoback then svo.echof = oldechof end
    return
  end
  if svo.config_dict[what].type == "boolean" then
    if (type(option) == "boolean" and option == true) or svo.convert_string(option) or (option == nil and not conf[what]) then
      conf[what] = true
      svo.config_dict[what].onenabled()
      raiseevent(what)
    elseif (type(option) == "boolean" and option == false) or not svo.convert_string(option) or (option == nil and conf[what]) then
      conf[what] = false
      svo.config_dict[what].ondisabled()
      raiseevent(what)
    else
      sendf("don't know about that option - try 'yes' or 'no' for %s.", what)
    end

  elseif svo.config_dict[what].type == "number" then
    if not option or tonumber(option) == nil then
      if svo.config_dict[what].percentage then
        sendf("What percentage do you want to set %s to?", what)
      else
        sendf("What number do you want to set %s to?", what)
      end
      if not echoback then svo.echof = oldechof end
      return
    end

    local num = tonumber(option)
    if svo.config_dict[what].max and num > svo.config_dict[what].max then
      sendf("%s can't be higher than %s.", what, svo.config_dict[what].max)
    elseif svo.config_dict[what].min and num < svo.config_dict[what].min then
      sendf("%s can't be lower than %s.", what, svo.config_dict[what].min)
    else
      conf[what] = num
      svo.config_dict[what].onset()
      raiseevent(what)
    end

  elseif svo.config_dict[what].type == "string" then
    if not option then sendf("What do you want to set %s to?", what)
      showprompt()
      if not echoback then svo.echof = oldechof end
      return
    end

    if svo.config_dict[what].check and not svo.config_dict[what].check(option) then
      sendf("%s isn't something you can set %s to be.", option, what)
      showprompt()
      if not echoback then svo.echof = oldechof end
      return
    end

    conf[what] = option
    svo.config_dict[what].onset()
    raiseevent(what)

  elseif svo.config_dict[what].type == "custom" then
    if not option then
      if svo.config_dict[what].onmenu then
        svo.config_dict[what].onmenu()
      else
        sendf("What do you want to set %s to?", what)
        showprompt()
      end

    else
      if svo.config_dict[what].onset then
        svo.config_dict[what].onset()
        raiseevent(what)
      end
    end

  else
    sendf("meep... %s doesn't have a type associated with it. Tis broken.", what)
    showprompt()
  end

  if not echoback then svo.echof = oldechof end
  showprompt()
  if svo.install.installing_system then svo.install.check_install_step() end
  svo.make_gnomes_work()
end


signals.saveconfig:connect(function () svo.tablesave(getMudletHomeDir() .. "/svo/config/conf", conf) end)

function svo.config.showcolours()
  svo.echof("Here's a list of available colors you can pick. To select, click on the name or use the %s command.", svo.green("vconfig echotype <name>"))

  for name, f in pairs(svo.echos) do
    local s = "  pick "..tostring(name).." -  "
    echo("  pick ")
    echoLink(tostring(name), 'svo.config.set("echotype", "'.. tostring(name) ..'", true)', 'Set it to '..tostring(name)..' colour style.', true)
    echo(" -  ")
    echo((" "):rep(30-#s)) f(true, "this is how it'll look")
  end
end

function svo.config.svo.showprompt()
  if not conf.customprompt then
    svo.echof("You don't have a custom prompt set currently.")
  else
    svo.echof("This is the script behind your custom prompt:\n")
    echo(conf.customprompt)
  end
end
