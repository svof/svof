-- Svof (c) 2011-2018 by Vadim Peretokin
-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

svo.modules_version = svo.modules_version or {}
svo.modules_version["svo (limbcounter)"] = 1
svo.loader.limbcounter = function()
local sk = svo.sk

svo.lc_list = {}
svo.lc_echo = svo.lc_echo or {}
svo.lc_priestdamage = svo.lc_priestdamage or false
svo.lc_shikudodamage = svo.lc_shikudodamage or "none"
svo.lc_limbreset = svo.lc_limbreset or false
svo.lc_shaping = svo.lc_shaping or 0
svo.lc_shikudoskill = { 
	lowest = lowest or 0,
	middle = middle or 0,
	highest = highest or 0
}

local limbs = {'head', 'torso', 'rightarm', 'leftarm', 'rightleg', 'leftleg'}
local hittable = {}
svo.lc_lasthit = svo.lc_lasthit or ""
svo.lc_break_at = svo.lc_break_at or 10
svo.lc_prep_at = function () local prep if svo.lc_break_at then prep = svo.lc_break_at - 1 return prep end end
svo.lc_myclass = svo.lc_myclass or ""
svo.lc_classlist =
  {
    "Magi",
    "Paladin",
    "Infernal",
    "Runewarden",
    "Monk",
    "Priest",
    "Dragon",
    "Druid",
		"Blademaster",
    "Sentinel",
    "Sylvan",
    "earth Elemental Lord",
    "Unnamable",
		"None",
  }
if table.contains(svo.lc_classlist, svo.me.class) or svo.defc["dragonform"] == true then
		disableTrigger("svo Meta limbcounter")
    disableTrigger("svo Sylvan limbcounter")
		disableTrigger("svo Monk limbcounter")
		disableTrigger("svo Burn limbcounter")
		disableTrigger("svo Priest limbcounter")
		disableTrigger("svo Magi limbcounter")
		disableTrigger("svo earth Elemental Lord limbcounter")
		disableTrigger("svo Dragon limbcounter")
		disableTrigger("svo Knight limbcounter")
  if svo.me.class == "Paladin" or svo.me.class == "Runewarden" or svo.me.class == "Infernal" or svo.me.class == "Unnamable" then
    enableTrigger("svo Knight limbcounter")
		svo.lc_myclass = svo.me.class
    svo.echof("Loaded svo limbcounter, %s %s.", svo.me.class, tostring(svo.modules_version["svo (limbcounter)"]))
  elseif svo.me.class == "Druid" or svo.me.class == "Sentinel" then
    enableTrigger("svo Meta limbcounter")
		svo.lc_myclass = svo.me.class
    svo.echof("Loaded svo limbcounter, %s %s.", svo.me.class, tostring(svo.modules_version["svo (limbcounter)"]))
  elseif svo.defc["dragonform"] == true then
		enableTrigger("svo Dragon limbcounter")
		svo.lc_myclass = svo.me.class
    svo.echof("Loaded svo limbcounter, %s %s.", "Dragon", tostring(svo.modules_version["svo (limbcounter)"]))
  elseif svo.me.class == "Monk" then
    if svo.me.path == "tekura" then
      enableTrigger("svo Monk limbcounter")
      enableTrigger("Tekura")
      disableTrigger("Shikudo")
      svo.config.setoption('legdamage', {
        type = "number",
        min = 1,
        max = 50,
        vconfig2string = true,
        onshow = function (defaultcolour)
          fg("gold")
          echoLink("Limbcounter:", "", "svo Limbcounter", true)
          fg(defaultcolour) echo(" Leg damage set to ")
          fg("a_cyan") echoLink(tostring(svo.conf.legdamage), "printCmdLine('vconfig legdamage ')", "Click to set leg damage for Tekura hits", true)
          fg(defaultcolour)
          echo(" \n")
        end,
        onset = function ()
          svo.echof("Changing Leg damage for Tekura hits to %d.", svo.conf.legdamage)
        end,
      })
      svo.config.setoption('armdamage', {
        type = "number",
        min = 1,
        max = 50,
        vconfig2string = true,
        onshow = function (defaultcolour)
          fg("gold")
          echoLink("Limbcounter:", "", "svo Limbcounter", true)
          fg(defaultcolour) echo(" Arm damage set to ")
          fg("a_cyan") echoLink(tostring(svo.conf.armdamage), "printCmdLine('vconfig armdamage ')", "Click to set arm damage for Tekura hits", true)
          fg(defaultcolour)
          echo(" \n")
        end,
        onset = function ()
          svo.echof("Changing Arm damage for Tekura hits to %d.", svo.conf.armdamage)
        end,
      })
      svo.echof("Loaded svo limbcounter, %s %s.", "Monk Tekura", tostring(svo.modules_version["svo (limbcounter)"]))
    elseif svo.me.path == "Shikudo" then
      enableTrigger("svo Monk limbcounter")
      enableTrigger("Shikudo")
      disablTrigger("Tekura")
      svo.echof("Loaded svo limbcounter, %s %s.", "Monk Shikudo", tostring(svo.modules_version["svo (limbcounter)"]))
    end    
	elseif table.contains(svo.lc_classlist, svo.me.class) then
		svo.lc_myclass = svo.me.class
    enableTrigger("svo " .. svo.me.class .. " limbcounter")
    svo.echof("Loaded svo limbcounter, %s %s.", svo.me.class, tostring(svo.modules_version["svo (limbcounter)"]))
  end
elseif not table.contains(svo.lc_classlist, svo.me.class) then
    disableTrigger("svo Meta limbcounter")
    disableTrigger("svo Sylvan limbcounter")
		disableTrigger("svo Monk limbcounter")
		disableTrigger("svo Burn limbcounter")
		disableTrigger("svo Priest limbcounter")
		disableTrigger("svo Magi limbcounter")
		disableTrigger("svo earth Elemental Lord limbcounter")
		disableTrigger("svo Dragon limbcounter")
		disableTrigger("svo Knight limbcounter")
end

function svo.lc_smash()
  hittable = {}
  disableTrigger("svolc Don't register")
  disableTrigger("svolc Don't register 2")
  signals.before_prompt_processing:disconnect(sk.svo.lc_checklimbcounter)
end

function svo.lc_shikudocount(person, low, mid, high)
	svo.lc_shikudoskill.highest = 1
	svo.lc_shikudoskill.highest = string.format("%2.1f", svo.lc_shikudoskill.highest)
	svo.lc_shikudoskill.highest = tonumber(svo.lc_shikudoskill.highest)
	svo.lc_shikudoskill.middle = (high / mid)
	svo.lc_shikudoskill.middle = string.format("%2.1f", svo.lc_shikudoskill.middle)
	svo.lc_shikudoskill.middle = tonumber(svo.lc_shikudoskill.middle) 
	svo.lc_shikudoskill.lowest = (high / low)
	svo.lc_shikudoskill.lowest = string.format("%2.1f", svo.lc_shikudoskill.lowest)
	svo.lc_shikudoskill.lowest = tonumber(svo.lc_shikudoskill.lowest)
	svo.lc_sethitsneeded(person, high)
end
	
function svo.lc_appliedreset(part, person)
	if table.contains(svo.lc_list, person) then
		echo("\n") svo.echof("Checking reset status")
		if part == "legs" then
			if svo.lc_list[person]["leftleg"] >= svo.lc_break_at then
				tempTimer(4, [[svo.lc_reset("ll"); svo.lc_limbreset = false]])
			elseif svo.lc_list[person]["rightleg"] >= svo.lc_break_at then
				tempTimer(4, [[svo.lc_reset("rl"); svo.lc_limbreset = false]])
			else
				echo("\n") svo.echof("Ignoring Cure")
			end
		elseif part == "arms" then
			if svo.lc_list[person]["leftarm"] >= svo.lc_break_at then
				tempTimer(4, [[svo.lc_reset("la"); svo.lc_limbreset = false]])
			elseif svo.lc_list[person]["rightarm"] >= svo.lc_break_at then
				tempTimer(4, [[svo.lc_reset("ra"); svo.lc_limbreset = false]])
			else
				echo("\n") svo.echof("Ignoring Cure")
			end
		elseif part == "torso" then
			if svo.lc_list[person]["torso"] >= svo.lc_break_at then
				tempTimer(4, [[svo.lc_reset("t"); svo.lc_limbreset = false]])
			else
				echo("\n") svo.echof("Ignoring Cure")
			end
		elseif part	== "head" then
			if svo.lc_list[person]["head"] >= svo.lc_break_at then
				tempTimer(4, [[svo.lc_reset("h"); svo.lc_limbreset = false]])
			else
				echo("\n") svo.echof("Ignoring Cure")
			end
		end
	end
end

local function get_other_prepped(t, limbhit)
  local s = {}
  for i = 1, #limbs do
    if limbs[i] ~= limbhit and t[limbs[i]] == svo.lc_prep_at then
      s[#s + 1] = limbs[i]
    end
  end
  if #s == 0 then
    return ""
  else
    return
      string.format(" Their %s %s also prepped.", svo.concatand(s), (#s == 1 and 'is' or 'are'))
  end
end

function svo.lc_priestdamage()
	if svo.lc_priestdamage == false then
		svo.lc_priestdamage = true
	else
		svo.lc_priestdamage = false
	end
end		

function svo.lc_shikudodamagecheck(limb)
	if limb == nil then
		svo.lc_shikudodamage = "none"
	else
		svo.lc_shikudodamage = limb
	end
end

function svo.lc_checklimbcounter()
  -- make the announces work with a singleprompt
  local echof = svo.itf
  moveCursor(0, getLineNumber())
  -- we'll only ever have one name here so far
  local s, m =
    pcall(
      function()
        local who, t = next(hittable)
        local where
        for i = 1, #t do
          local dmg
          where, dmg = next(t[i])
          svo.lc_list[who][where] = svo.lc_list[who][where] + dmg
          raiseEvent("svo limbcounter hit", who, where)
					
            if not where then
              svo.echof("Failed to connect.%s", get_other_prepped(svo.lc_list[who], ""))
            else
              if svo.lc_list[who][where] >= svo.lc_break_at then
                svo.echof("%s's %s broke.%s", who, where, get_other_prepped(svo.lc_list[who], where))
              elseif svo.lc_list[who][where] >= svo.lc_prep_at() then
                svo.echof(
                  "%s's %s is prepped.%s", who, where, get_other_prepped(svo.lc_list[who], where)
                )
              else
                svo.echof(
                  "%s's %s is now at %s/%s.%s",
                  who,
                  where,
                  svo.lc_list[who][where],
                  svo.lc_break_at,
                  get_other_prepped(svo.lc_list[who], where)
                )
              end
					end
				end
				svo.signals.before_prompt_processing:disconnect(svo.lc_checklimbcounter)
      end
    )
  if not s then
    echoLink("(e!)", [[echo([=[The problem was: ']] .. tostring(m) .. [[']=])]], 'Oy - there was a problem. Click on this link '
         ..'and submit a bug report with what it says along with a copy/paste of what you saw.')
  end
  hittable = {}
  disableTrigger("svolc Don't register")
  disableTrigger("svolc Don't register 2")
end

function svo.lc_hit(who, where, howmuch)
	local damage = howmuch
  svo.lc_list[who] =
    svo.lc_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0}
  where = where:gsub(" ", "")
  svo.lc_lasthit = who
  hittable[who] = hittable[who] or {}
  hittable[who][#hittable[who] + 1] = {[where] = (damage and damage or 1)}
  enableTrigger("svolc Don't register")
  enableTrigger("svolc Don't register 2")
	svo.signals.before_prompt_processing:connect(svo.lc_checklimbcounter)
end

function svo.lc_shikudohit(who, where, group)
	local damage = svo.lc_shikudoskill[group]
	if svo.lc_shikudodamage == "none" then
    svo.lc_list[who] =
      svo.lc_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0}
    where = where:gsub(" ", "")
    svo.lc_lasthit = who
    hittable[who] = hittable[who] or {}
    hittable[who][#hittable[who] + 1] = {[where] = (damage and damage or 1)}
		svo.signals.before_prompt_processing:connect(svo.lc_checklimbcounter)
	elseif svo.lc_shikudodamage == where then
		damage = (damage / 2)
    svo.lc_list[who] =
      svo.lc_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0}
    where = where:gsub(" ", "")
    svo.lc_lasthit = who
    hittable[who] = hittable[who] or {}
    hittable[who][#hittable[who] + 1] = {[where] = (damage and damage or 1)}
		svo.signals.before_prompt_processing:connect(svo.lc_checklimbcounter)
	end
end

function svo.lc_ignore()
  table.remove(select(2, next(hittable)))
	disableTrigger("svolc Don't Register")
end

function svo.lc_reset(whom)
  local lasthit = svo.lc_lasthit
  if whom then
    whom = string.title(whom)
  end
  local t =
    {h = 'head', t = 'torso', rl = 'rightleg', ll = 'leftleg', ra = 'rightarm', la = 'leftarm'}
  if whom == 'All' then
    svo.lc_list = {}
    svo.echof("Reset everyone's limb status.")
  elseif not whom and svo.lc_lasthit then
    svo.lc_list[lasthit] =
      {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, broke = 0}
    svo.echof("Reset %s's limb status.", svo.lc_lasthit)
  elseif t[whom:lower()] then
    if not svo.lc_lasthit or not svo.lc_list[svo.lc_lasthit] then
      svo.echof("Not keeping track of anyone yet to reset their limb.")
    else
      svo.lc_list[svo.lc_lasthit][t[whom:lower()]] = 0
      svo.echof("Reset %s %s's status.", svo.lc_lasthit, t[whom:lower()])
    end
  elseif whom then
    if svo.lc_list[whom] then
      svo.lc_list[whom] = nil
      svo.echof("Reset %s's limb status.", whom)
    else
      svo.echof("Weren't keeping track of %s anyway.", whom)
    end
  else
    svo.echof("Not keeping track of anyone to reset them anyway.")
  end
  raiseEvent("svo limbcounter reset")
end

function svo.lc_show()
  if svo.defc.dragonform then
    return
  end
  if svo.lc_list == {} then
    svo.echof("limbcounter: Not keeping track of anyone yet.");
    return
  end
  setFgColor(unpack(svo.getDefaultColorNums))
  for person, limbt in pairs(svo.lc_list) do
    echo("--- " .. person .. " ")
    fg('a_darkgrey')
    echoLink("(reset)", 'svo.lc_reset"' .. person .. '"', "Reset limb status for " .. person, true)
    setFgColor(unpack(svo.getDefaultColorNums))
    echo(string.format(" -- prep at %s -- break at %s --", svo.lc_prep_at(), svo.lc_break_at))
    echo(string.rep("-", (68 - #person - #tostring(svo.lc_prep_at()) - #tostring(svo.lc_break_at))))
    echo("\n|")
    for i = 1, #limbs do
      if limbt[limbs[i]] >= svo.lc_break_at - 1 then
        fg('green')
      end
      echo(
        string.format(
          "%14s",
          (
            limbt[limbs[i]] >= svo.lc_break_at -
            1 and
            limbs[i] ..
            " prep" or
            limbs[i] ..
            " " ..
            limbt[limbs[i]]
          )
        )
      )
      if limbt[limbs[i]] >= svo.lc_break_at - 1 then
        setFgColor(unpack(svo.getDefaultColorNums))
      end
      echo("|")
    end
    echo("\n")
  end
  echo(string.rep("-", 91))
end

function svo.lc_sethitsneeded(person, hits)
  if not tonumber(hits) then
    echof("At how many hits do you want to set the breaking point at?")
    return
  end
  svo.lc_break_at = hits
  if person then
    person = string.title(person)
    svo.lc_list[person] =
      svo.lc_list[person] or
      {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, broke = hits}
    svo.lc_list[person].broke = hits
    svo.echof("Set the breaking point for %s at %s.", person, hits)
    for i = 1, #limbs do
      if svo.lc_list[person][limbs[i]] > hits then
        svo.lc_list[person][limbs[i]] = 0
        svo.echof("Reset %s's %s limb (it's over hits needed).", person, limbs[i])
        raiseEvent("svo limb reset", svo.lc_list[person], limbs[i])
      end
    end
  elseif lc_lasthit and svo.lc_list[lc_lasthit] then
    svo.lc_list[lc_lasthit].broke = svo.lc_break_at
    echof("Set the breaking point for %s at %s.", lc_lasthit, svo.lc_break_at)
    for i = 1, #limbs do
      if svo.lc_list[lc_lasthit][limbs[i]] > hits then
        svo.lc_list[person][limbs[i]] = 0
        echof("Reset %s's %s limb (it's over hits needed).", lc_lasthit, limbs[i])
        raiseEvent("svo limb reset", svo.lc_list[person], limbs[i])
      end
    end
  else
    svo.lc_break_at = tonumber(hits)
    svo.echof("Set the breaking points for future targets at %s.", svo.lc_break_at)
  end
end

function svo.lc_synchits()
  if not lc_lasthit or not svo.lc_list[lc_lasthit] then
    svo.echof("Not tracking anybody to sync their hits.")
    return
  end
  local t = svo.lc_list[lc_lasthit]
  local highestnum = 0
  for i = 1, #limbs do
    if t[limbs[i]] > highestnum then
      highestnum = t[limbs[i]]
    end
  end
  t.svo.lc_break_at = highestnum
  echof("Set %s's breakpoint at %s.", lc_lasthit, highestnum)
  for i = 1, #limbs do
    if t[limbs[i]] >= highestnum then
      t[limbs[i]] = 0;
      svo.echof("Reset %s - it was over the hits needed.", limbs[i])
    end
  end
end

svo.config.setoption(
  "weapon",
  {
    type = "string",
    onset =
      function()
        svo.echof(
          "Setting your weapon to %s",
          svo.conf.weapon,
          (svo.conf.weaon == "none" and '' or 's')
        )
      end,
  }
)

svo.conf.limbprep = svo.conf.limbprep or 1
-- limbcounters prompt tag is defined here
-- feel free to tinker with it, but move it out into a script of its own,
-- so your changes don't get erased on an update!



function svo.lc_prompttag2()
  if not svo.lc_lasthit or not svo.lc_list or not svo.lc_list[svo.lc_lasthit] then
    return ""
  end
  local t = svo.lc_list[svo.lc_lasthit]
  return
    string.format(
      "%s: h %s|t %s|ra %s|la %s|rl %s|ll %s",
      svo.lc_lasthit,
      t.head,
      t.torso,
      t.rightarm,
      t.leftarm,
      t.rightleg,
      t.leftleg
    )
end

svo.adddefinition("@lc_prompttag2", "svo.lc_prompttag2()")

function svo.lc_prompttag()
  if
    svo.defc.dragonform or not svo.lc_lasthit or table.contains(svo.lc_list, svo.me.class) or not svo.lc_list[svo.lc_lasthit]
  then
    return ""
  end
  local t = svo.lc_list[svo.lc_lasthit]
  local prep = 1
  return
    string.format(
      "%s%s<a_white>/%s%s<a_white>|%s%s<a_white>/%s%s<a_white>|%s%s<a_white>/%s%s<a_white>|%s",
      ((svo.lc_break_at - t.leftarm) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.leftarm,
      ((svo.lc_break_at - t.rightarm) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.rightarm,
      ((svo.lc_break_at - t.leftleg) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.leftleg,
      ((svo.lc_break_at - t.rightleg) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.rightleg,
      ((svo.lc_break_at - t.head) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.head,
      ((svo.lc_break_at - t.torso) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.torso,
      svo.lc_break_at
    )
end

svo.adddefinition("@lc_prompttag", "svo.lc_prompttag()")

function svo.lc_prompttag3()
  if not svo.lc_lasthit or not svo.lc_list or not svo.lc_list[svo.lc_lasthit] then
    return ""
  end
  local t = svo.lc_list[svo.lc_lasthit]
  local prep = 1
  return
    string.format(
      "<a_darkgrey>(%s%s<a_darkgrey>:%s%s<a_darkgrey>:%s%s<a_darkgrey>:%s%s<a_darkgrey>:%s%s<a_darkgrey>:%s%s<a_darkgrey>:%s)",
      ((svo.lc_break_at - t.leftarm) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.leftarm,
      ((svo.lc_break_at - t.rightarm) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.rightarm,
      ((svo.lc_break_at - t.leftleg) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.leftleg,
      ((svo.lc_break_at - t.rightleg) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.rightleg,
      ((svo.lc_break_at - t.head) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.head,
      ((svo.lc_break_at - t.torso) <= prep) and "<a_red>" or "<a_darkyellow>",
      t.torso,
      svo.lc_break_at
    )
end

svo.adddefinition("@lc_prompttag3", "svo.lc_prompttag3()")
end
if svo.systemloaded then svo.loader.limbcounter() end