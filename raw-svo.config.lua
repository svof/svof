-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

pl.dir.makepath(getMudletHomeDir() .. "/svo/config")

-- conf has actual values, config data for them

wait_tbl = {
  [0] = {n = 0.7, m = "Systems lag tolerance level set to normal."},
  [1] = {n = 1.1, m = "The lag level was set to \"decent\" - make sure to set it to normal when it clears up."},
  [2] = {n = 1.9, m = "The lag level was set to \"severe\" - make sure to set it to normal when it clears up."},
  [3] = {n = 3.5, m = "The lag level was set to \"awfully terrible\" - make sure to set it to normal when it clears up. Don't even think about fighting in this lag."},
  [4] = {n = 3.5, m = "The lag level was set to \"you're on a mobile in the middle of nowhere\" - make sure to set it to normal when it clears up. Don't even think about fighting in this lag. Don't use this for bashing with dor either - use 3 instead. This is more useful for scripts that rely on do - enchanting and etc."}
}

local conf_printinstallhint = function (which)
  assert(config_dict[which] and config_dict[which].type, which.." is missing a type")

  if config_dict[which].type == "boolean" then
    echof("Use %s to answer.", tostring(green("vconfig "..which.." yep/nope")))
  elseif config_dict[which].type == "string" then
    echof("Use %s to answer.", tostring(green("vconfig "..which.." (option)")))
  elseif config_dict[which].type == "number" and config_dict[which].percentage then
    echof("Use %s to answer.", tostring(green("vconfig "..which.." (percent)")))
  elseif config_dict[which].type == "number" then
    echof("Use %s to answer.", tostring(green("vconfig "..which.." (number)")))
  end
end

local conf_installhint = function (which)
  assert(config_dict[which] and config_dict[which].type, which.." is missing a type")

  if config_dict[which].type == "boolean" then
    return "Use vconfig "..which.." yep/nope to answer."
  elseif config_dict[which].type == "string" then
    return "Use vconfig "..which.." (option) to answer."
  elseif config_dict[which].type == "number" and config_dict[which].percentage then
    return "Use vconfig "..which.." (percent) to answer."
  elseif config_dict[which].type == "number" then
    return "Use vconfig "..which.." (number) to answer."
  else return ""
  end
end

config_dict = pl.OrderedMap {
#conf_name = "blockcommands"
  {$(conf_name) = {
    vconfig2 = true,
    type = "boolean",
    onenabled = function ()
      echof("<0,250,0>Will%s block your commands in slow curing mode (aeon/retardation) if the system is doing something.", getDefaultColor())
      if not denyCurrentSend then echof("Warning: your version of Mudlet doesn't support this, so blockcommands won't actually work. Update to 1.2.0+") end
    end,
    ondisabled = function () echof("<250,0,0>Won't%s block your commands in slow curing mode, but instead allow them to override what the system is doing.", getDefaultColor())
    if not denyCurrentSend then echof("Warning: your version of Mudlet doesn't support this, so blockcommands won't actually work.") end end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      if denyCurrentSend then
        echo "Override commands in slow-curing mode.\n" return
      else
        echo "Override commands in slow-curing mode (requires Mudlet 1.2.0+).\n" return end
    end,
    installstart = function () conf.blockcommands = true end,
  }},
#conf_name = "autoslick"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Automatically prioritise slickness",
    onenabled = function () echof("<0,250,0>Will%s automatically swap asthma herb priority in times of danger - when you have paralysis or impatience above asthma in prios, and you have asthma+slickness on you, getting hit with a herbstack.", getDefaultColor()) end,
    ondisabled = function ()
      if swapped_asthma then
        svo.prio_swap("asthma", "herb", svo.swapped_asthma)
        svo.swapped_asthma = nil
        svo.echof("Swapped asthma priority back down.")
      end

      echof("<250,0,0>Won't%s automatically swap asthma herb priority in times of danger.", getDefaultColor()) end,
    installstart = function () conf.autoslick = true end
  }},
#conf_name = "focus"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "focus",
    onenabled = function () echof("<0,250,0>Will%s use Focus to cure.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use Focus to cure.", getDefaultColor()) end,
    installstart = function () conf.focus = nil end,
    installcheck = function () echof("Can you make use of the Focus skill?") end
  }},
#conf_name = "siprandom"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s sip by random vial IDs of a potion - note that this requires the elist sorter to know which vial IDs have which potions - and you'll need to check 'elist' after a vial runs out.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s make use of random vials - will be sipping the first available one by name.", getDefaultColor()) end,
  }},
#conf_name = "autoclasses"
    {$(conf_name) = {
      type = "boolean",
      onenabled = function () echof("<0,250,0>Will%s automatically enable the classes you seem to be fighting (used for class tricks).", getDefaultColor()) end,
      ondisabled = function () echof("<250,0,0>Won't%s automatically enable classes that you seem to be fighting (you can use tn/tf class instead).", getDefaultColor()) end,

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
#conf_name = "havelifevision"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () defences.enablelifevision() echof("<0,250,0>Have%s Lifevision mask - added it to defup/keepup.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Don't%s have Lifevision mask - won't be adding it to defup/keepup.", getDefaultColor()) end,
  }},
#conf_name = "autoarena"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s automatically enable/disable arena mode as you enter into the arena.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s automatically enable/disable arena mode as you enter/leave the arena..", getDefaultColor()) end,
  }},
#conf_name = "haveshroud"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () defences.enableshroud() echof("<0,250,0>Have%s a Shroudcloak - added it to defup/keepup.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Don't%s have a Shroudcloak - won't be adding it to defup/keepup.", getDefaultColor()) end,
  }},
#conf_name = "focuswithcadmus"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Use Focus while you have cadmus",
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
    onenabled = function () echof("<0,250,0>Will%s focus for mental afflictions when you've got cadmus (this'll give you a physical affliction when you do).", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s focus when you've got cadmus.", getDefaultColor()) end,
  }},
#conf_name = "cadmusaffs"
  {$(conf_name) = {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      echofn("Afflictions for which we will use focus even though we have ")
      underline(true)
      setFgColor(unpack(getDefaultColorNums))
      echoLink("cadmus", '', "Cadmus will give you a physical affliction if you focus with it (and still cure the mental one)", true)
      underline(false)
      echo(":\n")

      local temp = prio.getlist("focus")

      -- clear gaps so we can sort and display in 2 columns
      local t = {}
      for _, focusaff in ipairs(temp) do t[#t+1] = focusaff end

      table.sort(t) -- display alphabetically

      for i = 1, #t, 2 do
        local focusaff, nextaff = t[i], t[i+1]

        if me.cadmusaffs[focusaff] then
          dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[$(sys).me.cadmusaffs["]]..focusaff..[["] = false; $(sys).config.set'cadmusaffs']], "Click to stop focusing for "..focusaff.." when you have camus", true)
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %s", focusaff))
        else
          dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[$(sys).me.cadmusaffs["]]..focusaff..[["] = true; $(sys).config.set'cadmusaffs']], "Click to start focusing for "..focusaff.." when you have camus and are able to focus", true)
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %s", focusaff))
        end

        -- equal out the spacing on the second column
        echo((" "):rep(30-#focusaff))

        if nextaff and me.cadmusaffs[nextaff] then
          dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[$(sys).me.cadmusaffs["]]..nextaff..[["] = false; $(sys).config.set'cadmusaffs']], "Click to stop focusing for "..nextaff.." when you have camus", true)
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %s\n", nextaff))
        elseif nextaff then
          dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[$(sys).me.cadmusaffs["]]..nextaff..[["] = true; $(sys).config.set'cadmusaffs']], "Click to start focusing for "..nextaff.." when you have camus and are able to focus", true)
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %s\n", nextaff))
        end
      end

      _G.setUnderline = underline
      echo'\n'
    end
  }},
#conf_name = "lyre"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Lyre mode",
    onenabled = function () defs.keepup("lyre", "on") echof("Lyre mode <0,250,0>ON%s.", getDefaultColor()) end,
    ondisabled = function () defs.keepup("lyre", "off") app("off", true) echof("Lyre mode <250,0,0>OFF%s.", getDefaultColor()) end,
  }},
#conf_name = "ninkharsag"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Experimental Nin'kharsag tracking",
    onenabled = function () echof("Experimental Nin'kharsag tracking <0,250,0>enabled%s - will attempt to work out which affs Nin'kharsag hides, and diagnose otherwise.", getDefaultColor()) end,
    ondisabled = function () echof("Experimental Nin'kharsag <250,0,0>disabled%s.", getDefaultColor()) end,
  }},
#conf_name = "shipmode"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Ship mode",
    onenabled = function () signals.newroom:connect(sk.check_shipmode) echof("Ship mode <0,250,0>enabled%s - this will allow the system to work properly with the 2-3 line prompts.", getDefaultColor()) end,
    ondisabled = function () signals.newroom:disconnect(sk.check_shipmode) echof("Ship mode <250,0,0>disabled%s.", getDefaultColor()) end,
  }},
#conf_name = "lyrecmd"
  {$(conf_name) = {
    type = "string",
    onset = function ()
      dict.lyre.physical.action = conf.lyrecmd
      echof("Will use the '%s' for the Lyre mode.", tostring(conf.lyrecmd))
    end
  }},
#conf_name = "commandseparator"
  {$(conf_name) = {
    type = "string",
    onset = function ()
      echof("Will use <0,250,0>%s%s as the in-game command separator.", tostring(conf.commandseparator), getDefaultColor())
    end
  }},
#conf_name = "buckawns"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Have buckawns",
    onenabled = function () echof("<0,250,0>Do%s have buckawns.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Don't%s have buckawns.", getDefaultColor()) end,
    installstart = function () conf.buckawns = nil end,
    installcheck = function () echof("Have you got the buckawns artifact?") end
  }},
#conf_name = "burrowpause"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () signals.gmcproominfo:connect(sk.check_burrow_pause) echof("<0,250,0>Will%s auto-pause when we burrow.", getDefaultColor()) end,
    ondisabled = function () signals.gmcproominfo:disconnect(sk.check_burrow_pause) echof("<250,0,0>Won't%s auto-pause when we burrow.", getDefaultColor()) end,
    installstart = function () conf.burrowpause = true end,
  }},
#conf_name = "freevault"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Vaulting doesn't take balance",
    onenabled = function ()
      if conf.freevault and dict.riding.physical.balanceful_act then
        dict.riding.physical.balanceless_act = true
        dict.riding.physical.balanceful_act = nil
        signals.dragonform:emit()
      elseif not conf.freevault and dict.riding.physical.balanceless_act then
        dict.riding.physical.balanceless_act = nil
        dict.riding.physical.balanceful_act = true
        signals.dragonform:emit()
      end
      echof("<0,250,0>Do%s have balanceless vaulting.", getDefaultColor())
    end,
    ondisabled = function ()
      if conf.freevault and dict.riding.physical.balanceful_act then
        dict.riding.physical.balanceless_act = true
        dict.riding.physical.balanceful_act = nil
        signals.dragonform:emit()
      elseif not conf.freevault and dict.riding.physical.balanceless_act then
        dict.riding.physical.balanceless_act = nil
        dict.riding.physical.balanceful_act = true
        signals.dragonform:emit()
      end
      echof("<250,0,0>Don't%s have balanceless vaulting.", getDefaultColor())
    end,
  }},
#conf_name = "deathsight"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Have deathsight",
    onenabled = function () echof("<0,250,0>Do%s have deathsight.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Don't%s have deathsight.", getDefaultColor()) end,
    installstart = function () conf.deathsight = nil end,
    installcheck = function () echof("Have you got the deathsight skill?") end
  }},
#if skills.chivalry then
#conf_name = "rage"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use rage       ("
      echoLink("view scenarios", "svo.config.set'ragefunc'", "View, enable and disable scenarios in which rage will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () echof("<0,250,0>Will%s use of Rage.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use of Rage.", getDefaultColor()) end,
    installstart = function () conf.rage = nil end,
    installcheck = function () echof("Can you make use of the Rage skill?") end
  }},
#conf_name = "ragefunc"
  {$(conf_name) = {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      echof("Scenarios to use rage in:")
      local sortednames = keystolist(rage)
      table.sort(sortednames)
      local longestfname = longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = rage[fname]

        if not me.disabledragefunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[$(sys).me.disabledragefunc["]]..fname..[["] = true; svo.config.set'ragefunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[$(sys).me.disabledragefunc["]]..fname..[["] = false; svo.config.set'ragefunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline

      showprompt()
    end
  }},
#end
#conf_name = "tree"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use tree       ("
      echoLink("view scenarios", "svo.config.set'treefunc'", "View, enable and disable scenarios in which tree will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () echof("<0,250,0>Will%s use of tree.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use of tree.", getDefaultColor()) end,
    installstart = function () conf.tree = nil end,
    installcheck = function () echof("Do you have a Tree tattoo?") end
  }},
#conf_name = "treebalance"
  {$(conf_name) = {
    type = "number",
    min = 0,
    max = 100000,
    onset = function ()
      if conf.treebalance == 0 then
        echof("Will use the default settings for tree balance length.")
      else
        echof("Set tree balance to be %ds - if it doesn't come back after that, I'll reset it.", conf.treebalance)
      end
    end,
    installstart = function () conf.treebalance = 0 end
  }},
#conf_name = "restore"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use restore    ("
      echoLink("view scenarios", "svo.config.set'restorefunc'", "View, enable and disable scenarios in which restore will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () echof("<0,250,0>Will%s use Restore to cure limbs when necessary.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use Restore to cure.", getDefaultColor()) end,
    installstart = function () conf.restore = nil end,
    installcheck = function () echof("Can you make use of the Restore skill?") end
  }},
#conf_name = "dragonheal"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use dragonheal ("
      echoLink("view scenarios", "svo.config.set'dragonhealfunc'", "View, enable and disable scenarios in which dragonheal will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () echof("<0,250,0>Will%s use dragonheal to cure when necessary.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use dragonheal to cure.", getDefaultColor()) end,
    installstart = function () conf.dragonheal = nil end,
    installcheck = function () echof("Can you make use of the Dragonheal?") end
  }},
#if skills.venom then
#conf_name = "shrugging"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use shrugging  ("
      echoLink("view scenarios", "svo.config.set'shruggingfunc'", "View, enable and disable scenarios in which shrugging will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () echof("<0,250,0>Will%s use shrugging to cure when necessary.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use shrugging to cure.", getDefaultColor()) end,
    installstart = function () conf.shrugging = nil end,
    installcheck = function () echof("Can you make use of the shrugging?") end
  }},
#end
#conf_name = "breath"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Auto-enable breathing on Kai Choke",
    onenabled = function () echof("<0,250,0>Will%s automatically enabling breathing against Kai Choke and to check for asthma.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use survival breathing.", getDefaultColor()) end,
    installstart = function () conf.breath = nil end,
    installcheck = function () echof("Can you make use of the survival breath skill?") end
  }},
#conf_name = "ignoresinglebites"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Ignore single serpent bites",
    onenabled = function () echof("<0,250,0>Will%s ignore all serpent bites that deliver only one affliction - most likely they'll be illusions, but may also be not against a smart Serpent who realizes that you're ignoring. So if you see them only biting, that's a warning sign that they're *really* biting, and you'd want to toggle this off & diagnose.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s ignore serpent bites that deliver only one affliction.", getDefaultColor()) end
  }},
#conf_name = "ignoresinglestabs"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Ignore single serpent doublestabs",
    onenabled = function () echof("<0,250,0>Will%s ignore all serpent doublestabs that deliver only one affliction (most likely they'll be illusions, but may also be not).", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s ignore serpent doublestabs that deliver only one affliction.", getDefaultColor()) end
  }},
#conf_name = "efficiency"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Have survival efficiency",
    onenabled = function () echof("<0,250,0>Have%s survival efficiency - tree tattoo balance will take shorter to come back.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Don't%s have efficiency - tree tattoo balance will take longer to come back.", getDefaultColor()) end,
    installstart = function () conf.efficiency = nil end,
    installcheck = function () echof("Do you have the survival efficiency skill?") end
  }},
#conf_name = "clot"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "clot",
    onenabled = function () echof("<0,250,0>Will%s use clot to control bleeding.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use clot for bleeding.", getDefaultColor()) end,
    installstart = function () conf.clot = nil end,
    installcheck = function () echof("Can you make use of the Clot skill?") end
  }},
#conf_name = "insomnia"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "insomnia",
    onenabled = function () echof("<0,250,0>Will%s use the Insomnia skill for insomnia.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use the Insomnia skill for insomnia, and will use cohosh instead.", getDefaultColor()) end,
    installstart = function () conf.insomnia = nil end,
    installcheck = function () echof("Can you make use of the Insomnia skill?") end
  }},
#conf_name = "thirdeye"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "thirdeye",
    onenabled = function () echof("<0,250,0>Will%s use the thirdeye skill for thirdeye instead of echinacea.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use the thirdeye skill for thirdeye, and will use echinacea instead.", getDefaultColor()) end,
    installstart = function () conf.thirdeye = nil end,
    installcheck = function () echof("Can you make use of the Thirdeye skill?") end
  }},
#if skills.shindo then
#conf_name = "shindodeaf"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "shindodeaf",
    onenabled = function () echof("<0,250,0>Will%s use the Shindo deaf skill for deaf.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use the Shindo deaf skill for deaf.", getDefaultColor()) end,
    installstart = function () conf.shindodeaf = nil end,
    installcheck = function () echof("Would you like to use Shindo deaf for deafness?") end
  }},
#conf_name = "shindoblind"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "shindoblind",
    onenabled = function () echof("<0,250,0>Will%s use the Shindo blind skill for blind.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use the Shindo blind skill for blind.", getDefaultColor()) end,
    installstart = function () conf.shindoblind = nil end,
    installcheck = function () echof("Would you like to use Shindo blind for blindness?") end
  }},
#end
#if skills.kaido then
#conf_name = "kaidodeaf"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "kaidodeaf",
    onenabled = function () echof("<0,250,0>Will%s use the kaido deaf skill for deaf.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use the kaido deaf skill for deaf.", getDefaultColor()) end,
    installstart = function () conf.kaidodeaf = nil end,
    installcheck = function () echof("Would you like to use kaido deaf for deafness?") end
  }},
#conf_name = "kaidoblind"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "kaidoblind",
    onenabled = function () echof("<0,250,0>Will%s use the kaido blind skill for blind.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use the kaido blind skill for blind.", getDefaultColor()) end,
    installstart = function () conf.kaidoblind = nil end,
    installcheck = function () echof("Would you like to use kaido blind for blindness?") end
  }},
#end
#if skills.chivalry or skills.shindo or skills.kaido or skills.metamorphosis then
#conf_name = "fitness"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Use fitness       ("
      echoLink("view scenarios", "svo.config.set'fitnessfunc'", "View, enable and disable scenarios in which fitness will be used")
      fg(defaultcolour) echo ")\n"
      resetFormat()
    end,
    onenabled = function () echof("<0,250,0>Will%s use of Fitness.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use of Fitness.", getDefaultColor()) end,
    installstart = function () conf.fitness = nil end,
    installcheck = function () echof("Can you make use of the Fitness skill?") end
  }},
#conf_name = "fitnessfunc"
  {$(conf_name) = {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      echof("Scenarios to use fitness in:")
      local sortednames = keystolist(fitness)
      table.sort(sortednames)
      local longestfname = longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = fitness[fname]

        if not me.disabledfitnessfunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[$(sys).me.disabledfitnessfunc["]]..fname..[["] = true; svo.config.set'fitnessfunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[$(sys).me.disabledfitnessfunc["]]..fname..[["] = false; svo.config.set'fitnessfunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline

      showprompt()
    end
  }},
#end
#conf_name = "moss"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s make use of moss/potash to heal.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s make use of moss/potash to heal.", getDefaultColor()) end,
    installstart = function ()
      conf.moss = nil end,
    installcheck = function ()
      echof("Do you want to make use of moss/potash to heal?") end,
  }},
#conf_name = "showchanges"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s show changes in health/mana on the prompt.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s show changes in health/mana on the prompt.", getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Show h/m changes (in "..tostring(conf.changestype).." format).\n")
    end,
    installstart = function () conf.showchanges = nil end,
    installcheck = function () echof("Do you want to show changes about your health/mana in the prompt?") end
  }},
#conf_name = "changestype"
  {$(conf_name) = {
    type = "string",
    check = function (what)
      if what == "full" or what == "short" or what == "fullpercent" or what == "shortpercent" then return true end
    end,
    onset = function ()
      echof("Will use the %s health/mana loss echoes.", conf.changestype)
    end,
    installstart = function () conf.changestype = "shortpercent" end
  }},
#conf_name = "showbaltimes"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s show balance times for balance, equilibrium and herbs.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s show balance times.", getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Show how long balances took.\n"
    end,
    installstart = function () conf.showbaltimes = true end,
    -- installcheck = function () echof("Do you want to show how long your balances take?") end
  }},
#conf_name = "showafftimes"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s show how long afflictions took to cure.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s show times for curing afflictions.", getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo "Show how quickly afflictions are cured.\n"
    end,
    installstart = function () conf.showafftimes = true end,
  }},
#conf_name = "doubledo"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s do actions twice under stupidity.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s do actions twice under stupidity.", getDefaultColor()) end,
    onshow = "Double do actions in stupidity",
    vconfig2 = true
  }},
#conf_name = "repeatcmd"
  {$(conf_name) = {
    type = "number",
    min = 0,
    max = 100000,
    onset = function ()
      if conf.repeatcmd == 0 then echof("Will not repeat commands.")
      elseif conf.repeatcmd == 1 then echof("Will repeat each command one more time.")
      else echof("Will repeat each command %d more times.", conf.repeatcmd)
    end end,
    installstart = function () conf.repeatcmd = 0 end
  }},
#if not skills.tekura then
#conf_name = "parry"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "parry",
    onenabled = function () echof("<0,250,0>Will%s make use of parry.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s make use of parry.", getDefaultColor()) end,
    installstart = function () conf.parry = nil end,
    installcheck = function () echof("Are you able to use parry?") end
  }},
#else
#conf_name = "guarding"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "guarding",
    onenabled = function () echof("<0,250,0>Will%s make use of guarding.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s make use of guarding.", getDefaultColor()) end,
    installstart = function () conf.guarding = nil end,
    installcheck = function () echof("Are you able to use guarding?") end
  }},
#end
#conf_name = "singleprompt"
  {$(conf_name) = {
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
      echof("<0,250,0>Enabled%s the use of a single prompt.", getDefaultColor())

      sk.enable_single_prompt()
    end,
    ondisabled = function ()
      echof("<250,0,0>Disabled%s the use a single prompt.", getDefaultColor())
      if moveprompt then killTrigger(moveprompt) end
      if bottomprompt then bottomprompt:hide(); bottomprompt.reposition = function() end end
      setBorderBottom(0)
      bottom_border = 0
    end
  }},
#conf_name = "singlepromptsize"
  {$(conf_name) = {
    type = "number",
    min = 0,
    max = 100,
    onset = function ()
      if bottomprompt then
        bottomprompt:setFontSize(conf.singlepromptsize)
        if conf.singleprompt then
          -- svo.config.set("singleprompt", "off", false)
          -- svo.config.set("singleprompt", "on", false)

          if moveprompt then killTrigger(moveprompt) end
          if bottomprompt then bottomprompt:hide(); bottomprompt.reposition = function() end end
          setBorderBottom(0)
          bottom_border = 0

          sk.enable_single_prompt()
          clearWindow("bottomprompt")
        end
      end

      echof("Will be displaying the font at size %d.", conf.singlepromptsize)
    end
  }},
#conf_name = "singlepromptblank"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function ()
      echof("<0,250,0>Enabled%s the single prompt to show a blank line for the prompt.", getDefaultColor())
      config.set("singlepromptkeep", false, false)
    end,
    ondisabled = function ()
      echof("<250,0,0>Disabled%s the blank line, will be deleting the prompt instead.", getDefaultColor())
    end
  }},
#conf_name = "singlepromptkeep"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function ()
      echof("<0,250,0>Enabled%s the single prompt to keep the prompt%s.", getDefaultColor(), (conf.singleprompt and '' or ' (when vconfig singleprompt is on)'))
      config.set("singlepromptblank", false, false)
    end,
    ondisabled = function ()
      echof("<250,0,0>Disabled%s keeping the prompt, will be removing it.", getDefaultColor())
    end
  }},
#conf_name = "waitherbai"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onenabled = function () echof("<0,250,0>Will%s pause eating of herbs while checking herb-cured illusions.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s pause eating of herbs while checking herb-cured illusions.", getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour) echo ("Don't eat while checking herb-cured illusions.\n")
    end,
    installstart = function () conf.waitherbai = true end
  }},
#conf_name = "waitparalysisai"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onenabled = function () echof("<0,250,0>Will%s wait for balance/eq to confirm a suspect paralysis instead of accepting it - so if we get a suspect paralysis while off bal/eq, we'll cure other things and check the paralysis when we can.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s wait for balance/eq to confirm a possible paralysis - if we get one off bal/eq, we'll eat bloodroot asap. Otherwise if we have bal/eq, we'll check first.", getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour) echo ("Wait for balance/eq to check suspicious paralysis.\n")
    end,
    installstart = function () conf.waitparalysisai = false end
  }},
#conf_name = "commandecho"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s show commands the system is doing.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s show commands the system is doing.", getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour) echo ("Show system commands ("..tostring(conf.commandechotype)..")\n")
    end,
    installstart = function () conf.commandecho = true end
  }},
#conf_name = "commandechotype"
  {$(conf_name) = {
    type = "string",
    check = function (what)
      if what == "plain" or what == "fancy" or what == "fancynewline" then return true end
    end,
    onset = function ()
      echof("Will use the %s command echoes.", conf.commandechotype)
    end,
    installstart = function () conf.commandechotype = "fancy" end
  }},
#conf_name = "curemethod"
  {$(conf_name) = {
    type = "string",
    check = function (what)
      if table.contains({"conconly", "transonly", "preferconc", "prefertrans", "prefercustom"}, what) then return true end
    end,
    onset = function ()
      signals.curemethodchanged:emit()
      if conf.curemethod == "conconly" then
        echof("Will only use the usual Concoctions herbs/potions/salve for curing.")
      elseif conf.curemethod == "transonly" then
        echof("Will only use Transmutation minerals for curing.")
      elseif conf.curemethod == "preferconc" then
        echof("Will use Concoctions and Transmutation cures as you have them, but prefer Concoctions cures.")
      elseif conf.curemethod == "prefertrans" then
        echof("Will use Concoctions and Transmutation cures as you have them, but prefer Transmutation cures.")
      elseif conf.curemethod == "prefercustom" then
        echof("Will use your preferred Concoctions or Transmutation cures, falling back to the alternatives if you run out. See 'vshow curelist' for the adjustment menu.")
      else
        echof("Will use Concoctions and Transmutation cures as you have them.")
      end
    end,
    -- onshow: done in vshow
    installstart = function () conf.curemethod = nil end,
    installcheck = function () echof("Would you like to use Concoctions or Transmutation cures?\n\n  You can answer with 'conconly' - which'll mean that you'd like to use Concoctions cures only, 'transonly' - which'll mean that you'd like to use Transmutation cures only, 'preferconc' - prefer Concoctions cures, but fall back to Transmutation cures should you run out, and lastly, 'prefertrans' - prefer Transmutation cures, but fall back to Concoctions should you run out.") end
  }},
#conf_name = "customprompt"
  {$(conf_name) = {
    type = "string",
    vconfig2 = true,
    onset = function ()
      if conf.customprompt == "none" or conf.customprompt == "off" or conf.customprompt == "of" then
        conf.customprompt = false
        echof("Custom prompt disabled.")
      elseif conf.customprompt == "on" then
        if conf.oldcustomprompt ~= "off" and conf.oldcustomprompt ~= "of" then
          conf.customprompt = conf.oldcustomprompt
          cp.makefunction()
          echof("Custom prompt restored.")
          if innews then
            innews = false
            echof("Disabled the news status and re-enabled the prompt.")
          end
        else
          echof("You haven't set a custom prompt before, so we can't revert back to it. Set it with 'vconfig customprompt <prompt line>.")
          conf.customprompt = false
        end
      else
        cp.makefunction()
        conf.oldcustomprompt = conf.customprompt
        echof("Custom prompt enabled and set; will replace the standard one with yours now.")
      end
    end,
    installstart = function () conf.customprompt = nil; conf.setdefaultprompt = nil end
  }},
#conf_name = "relight"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s auto-relight non-artifact pipes.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s auto-relight pipes.", getDefaultColor()) end,
    installstart = function () conf.relight = true end,
    installcheck = function () echof("Should we keep non-artifact pipes lit?") end
  }},
#conf_name = "gagrelight"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s hide relighting of pipes.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s hide relighting pipes.", getDefaultColor()) end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo(string.format("Re-light pipes quietly%s.\n", not conf.relight and " (when relighting is on)" or ""))
    end,
    installstart = function () conf.gagrelight = true end,
    installcheck = function () echof("Should we hide it when pipes are relit (it can get spammy)?") end
  }},
#conf_name = "gagotherbreath"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s hide others breathing.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s hide others breathing.", getDefaultColor()) end,
    onshow = "Completely gag others breathing",
    installstart = function () conf.gagotherbreath = true end
  }},
#conf_name = "gagbreath"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s hide the breathing defence.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s hide the breathing defence.", getDefaultColor()) end,
    onshow = "Completely gag breathing",
    installstart = function () conf.gagbreath = true end,
    -- installcheck = function () echof("Should we hide it when you use the breathing defence?") end
  }},
#conf_name = "gageqbal"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s hide the 'you're off eq/bal' messages.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s hide the 'you're off eq/bal' messages.", getDefaultColor()) end,
    onshow = "Completely gag off eq/bal messages",
    installstart = function () conf.gageqbal = true end,
    installcheck = function () echof("Should we hide the messages you get when you try and spam something off balance or equilibrium?") end
  }},
#conf_name = "gagserverside"
  {$(conf_name) = {
    type = "boolean",
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Gag Svof's use of serverside priorities/toggles.\n")
    end,
    onenabled = function () echof("<0,250,0>Will%s hide info lines from the serverside curing system.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s hide info lines from the serverside curing system.", getDefaultColor()) end,
    installstart = function () conf.gagserverside = true end,
  }},
#conf_name = "gagservercuring"
  {$(conf_name) = {
    type = "boolean",
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Gag serverside [CURING] messages.\n")
    end,
    onenabled = function () echof("<0,250,0>Will%s hide serverside's [CURING] messages.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s hide serverside's [CURING] messages.", getDefaultColor()) end,
    installstart = function () conf.gagservercuring = false end,
  }},
#conf_name = "ccto"
  {$(conf_name) = {
    type = "string",
    onset = function ()
      conf.ccto = conf.ccto:lower()
      if conf.ccto == "pt" or conf.ccto == "party" then
        echof("Will report stuff to party.")
      elseif conf.ccto == "clt" then
        echof("Will report stuff to the current selected clan.")
      elseif conf.ccto:find("^tell %w+") then
        echof("Will report stuff to %s via tells.", conf.ccto:match("^tell (%w+)"):title())
      elseif conf.ccto == "ot" then
        echof("Will report stuff to the Order channel.")
      elseif conf.ccto == "team" then
        echof("Will report stuff to the team channel.")
      elseif conf.ccto == "army" then
        echof("Will report stuff to the army channel.")
      elseif conf.ccto == "echo" then
        echof("Will echo ccto stuff back to you, instead of announcing it anywhere.")
      else
        echof("Will report stuff to the %s clan.", conf.ccto)
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
#if skills.woodlore then
#conf_name = "weapon"
  {$(conf_name) = {
    type = "string",
    onset = function ()
      conf.weapon = conf.weapon:lower()
      echof("Set your weapon to '%s'.", conf.weapon)
    end,
    vconfig2 = true,
    onshow = string.format("Using a %s as a weapon", (conf.weapon and tostring(conf.weapon) or "(nothing)")),
    installstart = function ()
      conf.weapon = nil end,
    installcheck = function ()
      echof("Are you using a spear or a trident as a weapon?") end
  }},
#end
#if skills.metamorphosis then
#conf_name = "transmorph"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Have%s transmorph - won't go human between morphing.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Don't%s have transmorph - will go human between morphing.", getDefaultColor()) end,
    onshow = "Have transmorph",
    installstart = function () conf.transmorph = nil end,
    installcheck = function () echof("Do you have the Metamorphosis Transmorph skill?") end
  }},
#conf_name = "morphskill"
  {$(conf_name) = {
    type = "string",
    check = function (what)
      return sk.validmorphskill(what)
    end,
    onset = function ()
      conf.morphskill = conf.morphskill:lower()
      local t = {powers = "squirrel", bonding = "bear", transmorph = "elephant", affinity = "icewyrm",
#if class == "druid" then
      truemorph = "hydra"}
#else
      truemorph = "icewyrm"}
#end
      if t[conf.morphskill] then
        echof("Thanks! I've set your morphskill to '%s' though, because %s isn't a morph.", t[conf.morphskill], conf.morphskill)
        conf.morphskill = t[conf.morphskill]
      end
      signals.morphskillchanged:emit()
      echof("Given your morph skill, these are all defences you can put up: %s.", concatand(keystolist(sk.morphsforskill)) ~= "" and concatand(keystolist(sk.morphsforskill)) or "(... none, actually. Nevermind!)")
    end,
    installstart = function () sp_config.morphskill = nil end,
    installcheck = function () echof("What is the highest available morph that you can go into?") end
  }},
#end
#conf_name = "mosshealth"
  {$(conf_name) = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxhealth:emit() echof("Will eat moss/potash for health if it falls below %d%% (%dh).", conf.mosshealth, sys.mosshealth) end,
    installstart = function () conf.mosshealth = nil end,
    installcheck = function () echof("At what %% of health do you want to start using moss/potash to heal, if enabled?") end
  }},
#conf_name = "pagelength"
  {$(conf_name) = {
    type = "number",
    vconfig2string = true,
    min = 1,
    max = 250,
    onset = function () echof("Will reset your pagelength to %d after changing it.", conf.pagelength) end,
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
#conf_name = "herbstatsize"
  {$(conf_name) = {
    type = "number",
    min = 1,
    max = 100,
    onset = function () rift.update_riftlabel(); echof("Set the font size in the herbstat window to %d.", conf.herbstatsize) end,
    installstart = function () conf.herbstatsize = 9 end
  }},
#conf_name = "mossmana"
  {$(conf_name) = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxmana:emit() echof("Will eat moss/potash for mana if it falls below %d%% (%dm).", conf.mossmana, sys.mossmana) end,
    installstart = function () conf.mossmana = nil end,
    installcheck = function () echof("At what %% of mana do you want to start using moss/potash to heal, if enabled?") end
  }},
#conf_name = "siphealth"
  {$(conf_name) = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxhealth:emit() echof("Will start sipping health if it falls below %d%% (%dh).", conf.siphealth, sys.siphealth) end,
    installstart = function () conf.siphealth = nil end,
    installcheck = function () echof("At what %% of health do you want to start sipping health?") end
  }},
#conf_name = "sipmana"
  {$(conf_name) = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxmana:emit() echof("Will start sipping mana if it falls below %d%% (%dm).", conf.sipmana, sys.sipmana) end,
    installstart = function () conf.sipmana = nil end,
    installcheck = function () echof("At what %% of mana do you want to start sipping mana?") end
  }},
#if skills.devotion then
#conf_name = "bloodswornoff"
  {$(conf_name) = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    vconfig2 = true,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo(string.format("Unlinking Bloodsworn at %s%% (%sh).\n", conf.bloodswornoff or '?', sys.bloodswornoff or '?'))
    end,
    onset = function () signals.changed_maxhealth:emit() echof("Will unlink from bloodsworn if below %d%% (%dh).", conf.bloodswornoff, sys.bloodswornoff) end,
    installstart = function () conf.bloodswornoff = 30 end
  }},
#end
#conf_name = "refillat"
  {$(conf_name) = {
    type = "number",
    min = 0,
    max = 30,
    onset = function () echof("Will start refilling pipes when they're at %d puffs.", conf.refillat) end,
    installstart = function () conf.refillat = 1 end
  }},
#conf_name = "manause"
  {$(conf_name) = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxmana:emit() echof("Will use mana-draining skills if only above %d%% mana (%d).", conf.manause, sys.manause) end,
    installstart = function () conf.manause = 35 end,
    installcheck = function () echof("Above which %% of mana is the system allowed to use mana skills? Like focus, insomnia, etc. If you got below this %%, it'll revert to normal cures.") end
  }},
#conf_name = "lag"
  {$(conf_name) = {
    type = "number",
    min = 0,
    max = 4,
    onset = function () cnrl.update_wait() echof(wait_tbl[conf.lag].m) end,
    installstart = function () conf.lag = 0 end
  }},
#conf_name = "unknownfocus"
  {$(conf_name) = {
    type = "number",
    min = 0,
    onset = function () echof("Will diagnose after we have %d or more unknown, but focusable afflictions.", conf.unknownfocus) end,
    installstart = function ()
#if skills.healing then
    conf.unknownfocus = 1
#else
    conf.unknownfocus = 2
#end
    end,
  }},
#conf_name = "unknownany"
  {$(conf_name) = {
    type = "number",
    min = 0,
    onset = function () echof("Will diagnose after we have %d or more unknown affs.", conf.unknownany) end,
    installstart = function ()
#if skills.healing then
    conf.unknownany = 1
#else
    conf.unknownany = 2
#end
    end,
  }},
#conf_name = "bleedamount"
  {$(conf_name) = {
    type = "number",
    vconfig2string = true,
    min = 0,
    onset = function () echof("Will start clotting if bleeding for more than %d health.", conf.bleedamount) end,
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
#conf_name = "manableedamount"
  {$(conf_name) = {
    type = "number",
    vconfig2string = true,
    min = 0,
    onset = function () echof("Will start clotting if bleeding for more than %d mana.", conf.manableedamount) end,
    installstart = function () conf.manableedamount = 60 end,
  }},
#conf_name = "corruptedhealthmin"
  {$(conf_name) = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxhealth:emit() echof("Will not clot your mana bleeding if your health falls below %d%% (%dh).", conf.corruptedhealthmin, sys.corruptedhealthmin) end,
    installstart = function () conf.corruptedhealthmin = 70 end
  }},
#conf_name = "valerianid"
  {$(conf_name) = {
    type = "number",
    min = 0,
    installstart = function () conf.valerianid = nil; pipes.valerian.id = 0 end,
    installcheck = function () echof("What pipe should we use for valerian? Answer with the ID, please.") end,
    onset = function ()
      pipes.valerian.id = tonumber(conf.valerianid)
      echof("Set the valerian pipe id to %d.", pipes.valerian.id) end,
  }},
#conf_name = "skullcapid"
  {$(conf_name) = {
    type = "number",
    min = 0,
    installstart = function () conf.skullcapid = nil; pipes.skullcap.id = 0 end,
    installcheck = function () echof("What pipe should we use for skullcap? Answer with the ID, please.") end,
    onset = function ()
      pipes.skullcap.id = tonumber(conf.skullcapid)
      echof("Set the skullcap pipe id to %d.", pipes.skullcap.id) end,
  }},
#conf_name = "treefunc"
  {$(conf_name) = {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      echof("Scenarios to use tree in:")
      local sortednames = keystolist(tree)
      table.sort(sortednames)
      local longestfname = longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = tree[fname]

        if not me.disabledtreefunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[$(sys).me.disabledtreefunc["]]..fname..[["] = true; svo.config.set'treefunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[$(sys).me.disabledtreefunc["]]..fname..[["] = false; svo.config.set'treefunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline

      showprompt()
    end
  }},
#conf_name = "restorefunc"
  {$(conf_name) = {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      echof("Scenarios to use restore in:")
      local sortednames = keystolist(restore)
      table.sort(sortednames)
      local longestfname = longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = restore[fname]

        if not me.disabledrestorefunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[$(sys).me.disabledrestorefunc["]]..fname..[["] = true; svo.config.set'restorefunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[$(sys).me.disabledrestorefunc["]]..fname..[["] = false; svo.config.set'restorefunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline
      showprompt()
    end
  }},
#conf_name = "dragonhealfunc"
  {$(conf_name) = {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      echof("Scenarios to use dragonheal in:")

      local sortednames = keystolist(dragonheal)
      table.sort(sortednames)
      local longestfname = longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = dragonheal[fname]
        if not me.disableddragonhealfunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[$(sys).me.disableddragonhealfunc["]]..fname..[["] = true; svo.config.set'dragonhealfunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[$(sys).me.disableddragonhealfunc["]]..fname..[["] = false; svo.config.set'dragonhealfunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline
    end
  }},
#if skills.venom then
#conf_name = "shruggingfunc"
  {$(conf_name) = {
    type = "custom",
    onmenu = function ()
      local underline = setUnderline; _G.setUnderline = function () end

      echof("Scenarios to use shrugging in:")

      local sortednames = keystolist(shrugging)
      table.sort(sortednames)
      local longestfname = longeststring(sortednames)

      for i = 1, #sortednames do
        local fname = sortednames[i]
        local t = shrugging[fname]

        if not me.disabledshruggingfunc[fname] then
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0>X<153,204,204>]", [[$(sys).me.disabledshruggingfunc["]]..fname..[["] = true; svo.config.set'shruggingfunc']], "Disable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0>X<153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        else
          if dechoLink then
            dechoLink("  <153,204,204>[<0,204,0> <153,204,204>]", [[$(sys).me.disabledshruggingfunc["]]..fname..[["] = false; svo.config.set'shruggingfunc']], "Enable "..fname, true)
          else
            decho("  <153,204,204>[<0,204,0> <153,204,204>]")
          end
          setFgColor(unpack(getDefaultColorNums))
          echo(string.format(" %-"..longestfname.."s - %s\n", fname, tostring(t.desc)))
        end
      end

      _G.setUnderline = underline
    end
  }},
#end
#conf_name = "elmid"
  {$(conf_name) = {
    type = "number",
    min = 0,
    installstart = function () conf.elmid = nil; pipes.elm.id = 0 end,
    installcheck = function () echof("What pipe should we use for elm? Answer with the ID, please.") end,
    onset = function ()
      pipes.elm.id = tonumber(conf.elmid)
      echof("Set the elm pipe id to %d.", pipes.elm.id) end,
  }},
#conf_name = "eventaffs"
  {$(conf_name) = {
    type = "boolean",
    -- vconfig2 = true,
    -- onshow = "Raise Mudlet events on each affliction",
    onenabled = function () update_eventaffs() echof("<0,250,0>Will%s raise Mudlet events for gained/lost afflictions.", getDefaultColor()) end,
    ondisabled = function () conf.eventaffs = true; update_eventaffs() echof("eventaffs are on by default now - and this option is depreciated; there's no point in turning it off.") end,
    installstart = function () conf.eventaffs = true; update_eventaffs() end
  }},
#conf_name = "gagclot"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Gag clotting",
    onenabled = function () echof("<0,250,0>Will%s gag the clotting spam.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s gag the clotting spam.", getDefaultColor()) end,
    installstart = function () conf.gagclot = true end,
  }},
#conf_name = "autorewield"
  {$(conf_name) = {
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
        echof("<0,250,0>Will%s automatically rewield items that we've been forced to unwield.", getDefaultColor())
      else
        echof("<0,250,0>Will%s automatically rewield items that we've been forced to unwield (requires GMCP being enabled).", getDefaultColor())
      end
    end,
    ondisabled = function () echof("<250,0,0>Won't%s automatically rewield things.", getDefaultColor()) end
  }},
#conf_name = "preclot"
  {$(conf_name) = {
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
    onenabled = function () echof("<0,250,0>Will%s do preclotting (saves health at expense of willpower).", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s do preclotting (saves willpwer at expense of health).", getDefaultColor()) end,
    installstart = function () conf.preclot = true end,
    installcheck = function () echof("Should the system do preclotting? Doing so will save you from some bleeding damage, at the cost of more willpower.") end
  }},
#conf_name = "org"
  {$(conf_name) = {
    type = "string",
    check = function (what)
      if contains({"Ashtan", "Hashan", "Mhaldor", "Targossas", "Cyrene", "Eleusis", "None", "Rogue"}, what:title()) then return true end
    end,
    onset = function ()
      if conf.org == "none" or conf.org == "rogue" then
        conf.org = "none"
        -- reset echotype so the org change can have effect on echoes
        conf.echotype = nil
        signals.orgchanged:emit()
        echof("Will use the default plain echoes.")
      else
        conf.org = string.title(conf.org)
        -- reset echotype so the org change can have effect on echoes
        conf.echotype = nil

        -- if NameDB is present, set own city to be allied - in case you weren't a citizen of this city before and it was an enemy to you
        if ndb and ndb.conf and type(ndb.conf.citypolitics) == "table" then
          ndb.conf.citypolitics[conf.org] = "ally"
        end

        signals.orgchanged:emit()
        echof("Will use %s-styled echoes.", conf.org)
      end

    end,
    installstart = function ()
      conf.org = nil end,
    installcheck = function ()
      echof("What city do you live in? Select from: Ashtan, Hashan, Mhaldor, Targossas, Cyrene, Eleusis or none.") end
  }},
#conf_name = "slowcurecolour"
  {$(conf_name) = {
    type = "string",
    vconfig2string = true,
    check = function (what)
      if color_table[what] or what == "off" then return true end
    end,
    onset = function ()
      local r,g,b = unpack(color_table[conf.slowcurecolour])
      echof("Will colour your actions in <%d,%d,%d>%s%s when in aeon or retardation.", r,g,b, conf.slowcurecolour, getDefaultColor())
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
#conf_name = "hinderpausecolour"
  {$(conf_name) = {
    type = "string",
    vconfig2string = true,
    check = function (what)
      if color_table[what] or what == "off" then return true end
    end,
    onset = function ()
      local r,g,b = unpack(color_table[conf.hinderpausecolour])
      echof("Will colour hindering afflictions in <%d,%d,%d>%s%s when paused.", r,g,b, conf.hinderpausecolour, getDefaultColor())
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
#conf_name = "autoreject"
  {$(conf_name) = {
    type = "string",
    check = function (what)
      if contains({"black", "white", "off", "on"}, what:sub(1,5):lower()) then sk.oldautoreject = conf.autoreject return true end
    end,
    onset = function ()
      conf.autoreject = string.lower(conf.autoreject):sub(1,5)

      if conf.autoreject == "off" then
        ignore.lovers = true
        conf.autoreject = sk.oldautoreject; sk.oldautoreject = nil
        echof("Disabled autoreject completely (ie, will ignore curing lovers aff).")
      elseif conf.autoreject == "on" then
        ignore.lovers = nil
        conf.autoreject = sk.oldautoreject; sk.oldautoreject = nil
        echof("Enabled autoreject (won't ignore curing lovers anymore) - right now it's in %slist mode.", conf.autoreject)
      elseif conf.autoreject == "white" then
        local c = table.size(me.lustlist)
        echof("Autoreject has been set to whitelist mode - that means we will be automatically rejecting everybody, except those on the lust list (%d %s).", c, (c == 1 and "person" or "people"))
      elseif conf.autoreject == "black" then
        local c = table.size(me.lustlist)
        echof("Autoreject has been set to blacklist mode - that means we will only be rejecting people on the lust list (%d %s).", c, (c == 1 and "person" or "people"))
      else
        echof("... how did you manage to set the option to '%s'?", tostring(conf.autoreject))
      end
    end,
    installstart = function ()
      conf.autoreject = "white" end
  }},
#conf_name = "lustlist"
  {$(conf_name) = {
    type = "string",
    check = function(what)
      if what:find("^%w+$") then return true end
    end,
    onset = function ()
      local name = string.title(conf.lustlist)
      if not me.lustlist[name] then me.lustlist[name] = true else me.lustlist[name] = nil end

      if me.lustlist[name] then
        if conf.autoreject == "black" then
          echof("Added %s to the lust list (so we will be autorejecting them).", name)
        elseif conf.autoreject == "white" then
          echof("Added %s to the lust list (so we won't be autorejecting them).", name)
        else
          echof("Added %s to the lust list.", name)
        end
      else
        if conf.autoreject == "black" then
          echof("Removed %s from the lust list (so we will not be autorejecting them now).", name)
        elseif conf.autoreject == "white" then
          echof("Removed %s from the lust list (so we will be autorejecting them).", name)
        else
          echof("Removed %s from the lust list.", name)
        end
      end
    end
  }},
#conf_name = "echotype"
  {$(conf_name) = {
    type = "string",
    check = function (what)
      if echos[what:title()] or echos[what] then return true end
    end,
    onset = function ()
      conf.echotype = echos[conf.echotype:title()] and conf.echotype:title() or conf.echotype
      signals.orgchanged:emit()
      echof("This is how system messages will look like now :)")
    end,
    vconfig2 = true,
    installstart = function ()
      conf.org = nil end,
  }},
#if skills.healing then
#conf_name = "healingskill"
  {$(conf_name) = {
    type = "string",
    check = function (what)
      if table.contains({"blindness", "paralysis", "deafness", "fear", "confusion", "insomnia", "slickness", "stuttering", "paranoia", "shyness", "hallucinations", "generosity", "loneliness", "impatience", "unconsciousness", "claustrophobia", "vertigo", "sensitivity", "dizziness", "arms", "dementia", "clumsiness", "ablaze", "recklessness", "anorexia", "agoraphobia", "disloyalty", "hypersomnia", "darkshade", "masochism", "epilepsy", "asthma", "stupidity", "vomiting", "weariness", "haemophilia", "legs", "hypochondria"}, what:lower()) then return true end
    end,
    onset = function ()
      conf.healingskill = conf.healingskill:lower()
      signals.healingskillchanged:emit()
      echof("Thanks! That means that you can now cure:  \n%s", oneconcat(sk.healingmap))
    end,
    vconfig2 = true,
    installstart = function ()
      conf.healingskill = nil end,
    installcheck = function ()
      echof("What is the highest possible affliction that you can cure with Healing? If you don't have it yet, answer with 'blindness' and set 'none' for the 'usehealing' option.") end
  }},
#conf_name = "usehealing"
  {$(conf_name) = {
    type = "string",
    check = function (what)
      if table.contains({"full", "partial", "none", "off"}, what:lower()) then return true end
    end,
    onset = function ()
      conf.usehealing = conf.usehealing:lower()
      if conf.usehealing == "off" then conf.usehealing = "none" end
      echof("Will use Healing in the '%s' mode.", conf.usehealing)
    end,
    vconfig2 = true,
    installstart = function ()
      conf.usehealing = nil end,
    installcheck = function ()
      echof("Do you want to use Healing skillset in the full, partial or none mode? Full would mean that it'll use Healing for everything that it can and supplement it with normal cures. Partial would mean that it'll use normal cures and supplement it with Healing, while none means it won't make use of Healing at all.") end
  }},
#end
#if skills.kaido then
#conf_name = "transmute"
  {$(conf_name) = {
    type = "string",
    check = function (what)
      if convert_string(what) == false then return true end
      if table.contains({"replaceall", "replacehealth", "supplement", "none", "off"}, what:lower()) then return true end
    end,
    onset = function ()
      conf.transmute = conf.transmute:lower()
      if convert_string(conf.transmute) == false or conf.transmute == "none" then
        conf.transmute = "none"
      end

      if conf.transmute == "off" then conf.transmute = "none" end

      if conf.transmute == "none" then
        echof("Won't use transmute for anything.")
      else
        echof("Will use transmute in the '%s' mode.", conf.transmute) end
    end,
    vconfig2 = true,
    installstart = function () conf.transmute = nil end,
    installcheck = function ()
      echof("Do you want to use transmute skill in the replaceall, replacehealth, supplement or none mode? replaceall means that it won't sip health nor eat moss/potash to heal your health, but only use transmute. replacehealth will mean that it will not sip health, but use moss/potash and transmute. supplement means that it'll use all three ways to heal you, and none means that it won't use transmute.") end
  }},
#conf_name = "transmuteamount"
  {$(conf_name) = {
    type = "number",
    percentage = true,
    min = 0,
    max = 100,
    onset = function () signals.changed_maxhealth:emit()
      echof("Will start transmuting for health if it falls below %d%% (%dh)%s.", conf.transmuteamount, sys.transmuteamount, (conf.transmute ~= "none" and "" or ", when you enable a transmute mode"))
    end,
    installstart = function () conf.transmuteamount = nil end,
    installcheck = function () echof("At what %% of health do you want to start transmuting for health?") end
  }},
#conf_name = "transsipprone"
    {$(conf_name) = {
      type = "boolean",
      vconfig2 = "Transmute while prone",
      onenabled = function () echof("If you're prone and using transmute in a replaceall or replacehealth mode, we <0,250,0>will%s sip health or vitality instead of waiting on transmute to be usable. This is most optimal for PK.", getDefaultColor()) end,
      ondisabled = function () echof("If you're prone and using transmute in a replaceall or replacehealth mode, we'll keep sipping mana and wait until we can use transmute again to heal our health. This is mainly good for bashing.", getDefaultColor()) end,
      installstart = function () conf.transsipprone = true end
    }},
#end
#if skills.voicecraft then
#conf_name = "dwinnu"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "dwinnu",
    onenabled = function () echof("<0,250,0>Will%s use dwinnu for writhing.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use dwinnu.", getDefaultColor()) end,
    installstart = function () conf.dwinnu = nil end,
    installcheck = function () echof("Can you make use of the Wwinnu skill?") end
  }},
#end
#if skills.weaponmastery then
#conf_name = "recoverfooting"
    {$(conf_name) = {
      type = "boolean",
      vconfig1 = "recover footing",
      onenabled = function () echof("<0,250,0>Will%s use Recover Footing to get up faster when we can.", getDefaultColor()) end,
      ondisabled = function () echof("<250,0,0>Won't%s use Recover Footing.", getDefaultColor()) end,
      installstart = function () conf.recoverfooting = nil end,
      installcheck = function () echof("Can you make use of the Recover Footing skill?") end
    }},
#end
#conf_name = "dragonflex"
  {$(conf_name) = {
    type = "boolean",
    vconfig1 = "dragonflex",
    onenabled = function () echof("<0,250,0>Will%s use dragonflex when we have balance.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use dragonflex.", getDefaultColor()) end,
    installstart = function () conf.dragonflex = nil end,
    installcheck = function () echof("Can you make use of the Dragonflex skill?") end
  }},
#conf_name = "assumestats"
  {$(conf_name) = {
    type = "number",
    vconfig2 = true,
    min = 0,
    max = 100,
    onset = function () echof("Will assume we're at %d%% of health and mana when under blackout or recklessness.", conf.assumestats) end,
    installstart = function () conf.assumestats = 15 end,
  }},
#conf_name = "healthaffsabove"
  {$(conf_name) = {
    type = "number",
    vconfig2 = true,
    min = 0,
    max = 100,
    onset = function () echof("Will apply health to cure afflictions only when above %d%% health.", conf.healthaffsabove) end,
    installstart = function () conf.healthaffsabove = 70 end,
  }},
#conf_name = "warningtype"
  {$(conf_name) = {
    type = "string",
    vconfig2 = true,
    check = function (what)
      if contains({"all", "prompt", "none", "right", "off"}, what) then return true end
    end,
    onset = function ()
      if conf.warningtype == "none" or conf.warningtype == "off" then
        conf.warningtype = false
        echof("Disabled extended instakill warnings.")
      elseif conf.warningtype == "all" then
        echof("Will prefix instakill warnings to all lines.")
        if math.random(1, 10) == 1 then echof("(muahah(") end
      elseif conf.warningtype == "prompt" then
        echof("Will prefix instakill warnings only to prompt lines.")
      elseif conf.warningtype == "right" then
        echof("Will place instakill warnings on all lines, aligned on the right side.")
      end
    end,
    installstart = function ()
      conf.warningtype = "right" end,
  }},
#conf_name = "burstmode"
  {$(conf_name) = {
    type = "string",
    vconfig2string = true,
    check = function (what)
      if defdefup[what:lower()] then return true end
    end,
    onshow = function (defaultcolour)
      fg(defaultcolour)
      echo("Upon starbursting, will go into ") fg("a_cyan")
      echoLink(tostring(conf.burstmode), 'printCmdLine"vconfig burstmode "',
#if skills.necromancy then
      "Set the defences mode system should autoswitch to upon starburst/soulcage",
#elseif skills.occultism then
      "Set the defences mode system should autoswitch to upon starburst/transmog",
#else
      "Set the defences mode system should autoswitch to upon starburst",
#end
       true)
      cecho("<a_grey> defences mode.\n")
    end,
    onset = function ()
      conf.burstmode = conf.burstmode:lower()
#if skills.necromancy then
      echof("Upon starburst/soulcage, will go into %s defences mode.", conf.burstmode)
#elseif skills.occultism then
      echof("Upon starburst/transmogrify, will go into %s defences mode.", conf.burstmode)
#else
      echof("Upon starburst, will go into %s defences mode.", conf.burstmode)
#end
    end,
    installstart = function ()
      conf.burstmode = "empty" end
  }},
#conf_name = "oldts"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Touch shield only once on ts",
    onenabled = function () echof("<0,250,0>Will%s use oldschool ts - using ts one will shield once.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s use oldschool ts - using ts will enable shield keepup.", getDefaultColor()) end,
    installstart = function () conf.oldts = false end,
    installcheck = function () echof("In Svof, <0,255,0>ts%s is a toggle for <0,255,0>vkeep shield%s - it'll reshield you if the shield gets stripped. Previously it used to shield you once only. Would you like to be a toggle (<0,255,0>vconfig oldts no%s) or a one-time thing (<0,255,0>vconfig oldts yes%s)?", getDefaultColor(), getDefaultColor(), getDefaultColor(), getDefaultColor()) end
  }},
#conf_name = "batch"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Batch multiple curing commands",
    onenabled = function () echof("<0,250,0>Will%s batch multiple curing commands to be done at once, without prompts inbetween.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s batch curing commands to be done at once, but instead send them separately at once.", getDefaultColor()) end,
    installstart = function () conf.batch = true end,
  }},
#conf_name = "steedfollow"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Auto-order steed to follow us",
    onenabled = function () echof("<0,250,0>Will%s make the steed follow us when we dismount (via va).", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s make the steed follow us anymore when we dismount (via va).", getDefaultColor()) end,
    installstart = function () conf.steedfollow = true end
  }},
#conf_name = "autotsc"
  {$(conf_name) = {
    type = "boolean",
    vconfig2 = true,
    onshow = "Automatically toggle tsc in aeon/ret",
    onenabled = function () echof("<0,250,0>Will%s automatically toggle tsc - overrides in retardation and denies in aeon.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s automatically toggle tsc.", getDefaultColor()) end,
  }},
#conf_name = "medprone"
  {$(conf_name) = {
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
    onenabled = function () echof("<0,250,0>Will%s put prone on ignore when meditating, so you can be sitting.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s put prone on ignore when meditating.", getDefaultColor()) end,
  }},
#conf_name = "unmed"
  {$(conf_name) = {
    type = "boolean",
    onshow = "Automatically disable med with full wp",
    onenabled = function () echof("<0,250,0>Will%s take meditate off keepup when you reach full willpower.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s take meditate off keepup when you reach full willpower - so we'll meditate again if you lose any mana/willpower.", getDefaultColor()) end,
  }},
#conf_name = "classattacksamount"
  {$(conf_name) = {
    type = "number",
    min = 0,
    vconfig2string = true,
    onset = function () echof("Will enable a class after they hit us with %d attacks (within %d seconds).", conf.classattacksamount, conf.classattackswithin) end,
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
#conf_name = "classattackswithin"
  {$(conf_name) = {
    type = "number",
    min = 0,
    onset = function () echof("Will enable a class when they hit us within %d seconds (with %d attacks).", conf.classattackswithin, conf.classattacksamount) end,
    installstart = function () conf.classattackswithin = 15 end
  }},
#conf_name = "enableclassesfor"
  {$(conf_name) = {
    type = "number",
    min = 0,
    vconfig2string = true,
    onset = function () echof("Will keep the class enabled for %s minutes after the fighting ends.", conf.enableclassesfor) end,
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
#conf_name = "gmcpaffechoes"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s notify you when GMCP updates your afflictions.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s notify you when GMCP updates your afflictions.", getDefaultColor()) end,
  }},
#conf_name = "gmcpdefechoes"
  {$(conf_name) = {
    type = "boolean",
    onenabled = function () echof("<0,250,0>Will%s notify you when GMCP updates your defences.", getDefaultColor()) end,
    ondisabled = function () echof("<250,0,0>Won't%s notify you when GMCP updates your defences.", getDefaultColor()) end,
  }},
#conf_name = "releasechannel"
  {$(conf_name) = {
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
      echof("Will use the '%s' release channel for updates.",
        conf.releasechannel)
    end,
    installstart = function ()
      conf.releasechannel = "stable"
    end
  }},
}

if not conf.releasechannel then
  conf.releasechannel = "stable"
end

do
  local conf_t = {}
  local conf_path = getMudletHomeDir() .. "/svo/config/conf"

  if lfs.attributes(conf_path) then
    local ok, msg = pcall(table.load,conf_path, conf_t)
    if ok then
      update(conf, conf_t)
    else
      os.remove(conf_path)
      tempTimer(10, function()
        echof("Your vconfig file got corrupted for some reason - I've deleted it so the system can load other stuff OK. You'll need to re-set all of the vconfig options again, though. (%q)", msg)
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
  update_eventaffs()

  cnrl.update_wait()

  if conf.bashing then enableTrigger"svo Bashing triggers"
  else disableTrigger"svo Bashing triggers" end

  -- update whenever our riding takes up balance. If it doens't, then balanceless actions should be done asap
  if conf.freevault and dict.riding.physical.balanceful_act then
    dict.riding.physical.balanceless_act = true
    dict.riding.physical.balanceful_act = nil
    signals.dragonform:emit()
  elseif not conf.freevault and dict.riding.physical.balanceless_act then
    dict.riding.physical.balanceless_act = nil
    dict.riding.physical.balanceful_act = true
    signals.dragonform:emit()
  end

  if conf.burrowpause then
    signals.gmcproominfo:connect(sk.check_burrow_pause)
  end

  if not conf.customprompt and not conf.setdefaultprompt then
    tempTimer(math.random(10, 15), function()
      conf.setdefaultprompt = true
      setdefaultprompt()
      -- disabled -- spammy for new users
      -- echo"\n" echof("I've setup a custom prompt for you that mimics the normal Achaean one, but also displays which afflictions have you got. See http://doc.svo.vadisystems.com/#setting-a-custom-prompt on how to customize it if you'd like, or if you don't like it, do 'vconfig customprompt off' to disable it.")
      end)
  end

  if conf.singleprompt then
    sk.enable_single_prompt()
  end

  if conf.riftlabel then
    tempTimer(0, function()
      riftlabel:show()
      rift.update_riftlabel()
    end)
  end
end

for k,v in config_dict:iter() do
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
          echof"Anti-illusion enabled." end,
    alreadyon = function () enableTrigger "Pre-parse anti-illusion";
          echof"Anti-illusion is already enabled." end,
    off = function () disableTrigger "Pre-parse anti-illusion";
          echof"Anti-illusion disabled." end,
    alreadyoff = function () disableTrigger "Pre-parse anti-illusion";
          echof"Anti-illusion is already disabled." end,
  },
  arena = {
    on = function()
      local echos = {"Arena mode enabled. Good luck!", "Beat 'em up! Arena mode enabled.", "Arena mode on.", "Arena mode enabled. Kill them all!"}
            echof(echos[math.random(#echos)])
    end,
    alreadyon = function() echof("Arena mode is already on.") end,
    off = function() echof("Arena mode disabled.") end,
    alreadyoff = function() echof("Arena mode is already off.") end
  },
  keepup = {
    on = function () echof"Auto keepup on." make_gnomes_work() end,
    alreadyon = function () echof"Auto keepup is already on." end,
    off = function () echof"Auto keepup is now off."make_gnomes_work() end,
    alreadyoff = function() echof"Auto keepup is already off." end
  },
  bashing = {
    on = function () enableTrigger"svo Bashing triggers" echof("Enabled bashing triggers.") end,
    alreadyon = function () echof("Bashing triggers are already on.") end,
    off = function() disableTrigger"svo Bashing triggers" echof("Disabled bashing triggers.") end,
    alreadyoff = function() echof("Bashing triggers are already off.") end,
  },
  raid = {
    on = function ()
      tntf_set("keepup", true, true)
      defs.switch("combat", true)
      echof("Switched into combat defence mode and keeping mass, cloak, insomnia, rebounding defences up.")
      defs.keepup("mass", true)
      defs.keepup("cloak", true)
      defs.keepup("mass", true)
      defs.keepup("insomnia", true)
      defs.keepup("rebounding", true)
    end,
    off = function ()
      defs.switch("basic", true)
      echof("Switched to basic defence mode.")
    end
  },
  serverside = {
    shortcuts = {"ss"},
    on = function()
      do
        -- if we've got nothing on the list, setup these defaults
        if not next(serverignore) then
          local list = sk.getallserversideactions()

          for _, action in ipairs(list) do
            serverignore[action] = true
          end

          serverignore.impale     = false -- serverside does not stack writhing atm
          serverignore.lovers     = false -- lust not handled by serverside
          serverignore.selfishness = false -- doesn't take selfish off
        end
      end

      -- take previous ignores off
      local removelist = {}
      for action, data in pairs(ignore) do
        if type(data) == "table" and data.because == "using server-side curing" then
          removelist[#removelist+1] = action
        end
      end

      for _, action in ipairs(removelist) do
        ignore[action] = nil
      end

      if next(removelist) then
        tempTimer(5, [[svo.echof("Took all affs set for serverside curing off ignore. 'vshow ignore' really means ignore again (both in Svof and serverside), use 'vshow server' to toggle what should be done by serverside or Svof.")]])
      end

      echof("Serverside curing enabled (augmented with Svof's).")
      setupserverside()
      sendcuring("afflictions on")
      sendcuring("sipping on")
      sendcuring("defences on")
      sendcuring("focus " .. (conf.focus and "on" or "off"))
      sendcuring("batch on")
      sendc("config advancedcuring on")
      sendcuring("reporting on")
      if not conf.paused then sendcuring("on") end
    end,
    off = function()
      echof("Serverside curing disabled.")
      sendcuring("off")
    end,
    alreadyon = function() echof("Serverside affliction curing is already on.") end,
    alreadyoff = function() echof("Serverside affliction curing is already off.") end,
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

function tntf_set(what, option, echoback)
  local sendf
  if echoback then sendf = echof else sendf = errorf end

  option = convert_string(option)
  assert(what and (option ~= nil), "syntax is: svo.tntf(what, option)", sendf)

  if not tntf_tbl[what] then
    if echoback ~= "noerrors" then sendf("%s isn't something you can change.", what) end
    return
  end

  local oldechof, oldshowprompt = echof, showprompt

  if echoback == false then
    echof = function() end
    oldshowprompt = echof
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
    echof = oldechof
    showprompt = oldshowprompt
  end

  if echoback then showprompt() end

  return true
end

-- just display all options in 4 tabs
function sk.show_all_confs()
  local count = 0
  local t = {}; for name, _ in config_dict:iter() do t[#t+1] = name end; table.sort(t)

  for _, name in ipairs(t) do
    if printCmdLine then
      echoLink(string.format("%-20s", tostring(name)), 'printCmdLine("vconfig '..name..' ")', conf_installhint(name), true)
    else
      echo(string.format("%-20s", tostring(name))) end
    count = count + 1
    if count % 4 == 0 then echo "\n" end
  end
end

function config.setoption(name, data)
  config_dict:set(name, data)
  if conf[name] == nil and config_dict[name].type == "number" then
    conf[name] = conf[name] or 0
  elseif conf[name] == nil then
    conf[name] = conf[name] or false
  end
end

function config.deloption(name)
  if config_dict[name] then
    config_dict:set(name, nil)
  end
end

function config.set(what, option, echoback)
  local sendf
  local showprompt = showprompt
  local oldechof
  if echoback then
    sendf = echof
  else
    sendf = errorf
    -- hide echoes and prompt
    showprompt = function() end
    oldechof = echof
    echof = function() end
  end

  local function raiseevent(what)
    tempTimer(0, function() raiseEvent("svo config changed", what) end)
  end

  if not config_dict[what] or what == "list" or what == "options" then
    sendf("%s - available ones are:", (what == "list" or what == "option") and "Listing all options" or "Don't know about such an option")
    sk.show_all_confs()
    echo"\n"
    showprompt()
    if not echoback then echof = oldechof end
    return
  end
  if config_dict[what].type == "boolean" then
    if (type(option) == "boolean" and option == true) or convert_string(option) or (option == nil and not conf[what]) then
      conf[what] = true
      config_dict[what].onenabled()
      raiseevent(what)
    elseif (type(option) == "boolean" and option == false) or not convert_string(option) or (option == nil and conf[what]) then
      conf[what] = false
      config_dict[what].ondisabled()
      raiseevent(what)
    else
      sendf("don't know about that option - try 'yes' or 'no' for %s.", what)
    end

  elseif config_dict[what].type == "number" then
    if not option or tonumber(option) == nil then
      if config_dict[what].percentage then
        sendf("What percentage do you want to set %s to?", what)
      else
        sendf("What number do you want to set %s to?", what)
      end
      if not echoback then echof = oldechof end
      return
    end

    local num = tonumber(option)
    if config_dict[what].max and num > config_dict[what].max then
      sendf("%s can't be higher than %s.", what, config_dict[what].max)
    elseif config_dict[what].min and num < config_dict[what].min then
      sendf("%s can't be lower than %s.", what, config_dict[what].min)
    else
      conf[what] = num
      config_dict[what].onset()
      raiseevent(what)
    end

  elseif config_dict[what].type == "string" then
    if not option then sendf("What do you want to set %s to?", what)
      showprompt()
      if not echoback then echof = oldechof end
      return
    end

    if config_dict[what].check and not config_dict[what].check(option) then
      sendf("%s isn't something you can set %s to be.", option, what)
      showprompt()
      if not echoback then echof = oldechof end
      return
    end

    conf[what] = option
    config_dict[what].onset()
    raiseevent(what)

  elseif config_dict[what].type == "custom" then
    if not option then
      if config_dict[what].onmenu then
        config_dict[what].onmenu()
      else
        sendf("What do you want to set %s to?", what)
        showprompt()
      end

    else
      if config_dict[what].onset then
        config_dict[what].onset()
        raiseevent(what)
      end
    end

  else
    sendf("meep... %s doesn't have a type associated with it. Tis broken.", what)
    showprompt()
  end

  if not echoback then echof = oldechof end
  showprompt()
  if install.installing_system then install.check_install_step() end
  make_gnomes_work()
end

signals.saveconfig:connect(function () table.save(getMudletHomeDir() .. "/svo/config/conf", conf) end)

function config.showcolours()
  echof("Here's a list of available colors you can pick. To select, click on the name or use the %s command.", green("vconfig echotype <name>"))

  for name, f in pairs(echos) do
    local s = "  pick "..tostring(name).." -  "
    echo("  pick ")
    echoLink(tostring(name), '$(sys).config.set("echotype", "'.. tostring(name) ..'", true)', 'Set it to '..tostring(name)..' colour style.', true)
    echo(" -  ")
    echo((" "):rep(30-#s)) f(true, "this is how it'll look")
  end
end

function config.showprompt()
  if not conf.customprompt then
    echof("You don't have a custom prompt set currently.")
  else
    echof("This is the script behind your custom prompt:\n")
    echo(conf.customprompt)
  end
end
