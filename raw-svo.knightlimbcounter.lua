-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

svo.kl_version = "1.0"
local conf, sk = svo.conf, svo.sk

svo.kl_list = {}
local limbs = {"head", "torso", "rightarm", "leftarm", "rightleg", "leftleg"}
local hittable = {}
svo.kl_break_at = 10

enableTrigger("svo Knight limbcounter")
enableAlias("svo Knight limbcounter")

-- Their blah, blah, blah are also prepped.
local function get_other_prepped(t)
  local s = {}
  for i = 1, #limbs do
    if t[limbs[i]] == (t.kl_break_at - conf.limbprep) then s[#s+1] = limbs[i] end
  end

  if #s == 0 then return ""
  else return string.format("Their %s %s now prepped.", svo.concatand(s), (#s == 1 and "is" or "are")) end
end

function svo.kl_ignore()
  table.remove(select(2, next(hittable)))
end

function sk.kl_checklimbcounter()
  -- AI check
  -- check for balance loss, or in case of game queueing, a queueing message
  if conf.aillusion and not sk.sawqueueing() then
    -- bals is not updated until the prompt, so bals. atm has the old value

    if not svo.affs.blackout and not (svo.kl_had_balance and not svo.newbals.balance) then
      svo.ignore_illusion("This doesn't look like an attack from you, it's fake!")

      -- turn things off
      hittable = {}
      disableTrigger("svokl Don't register")
      svo.signals.after_prompt_processing:block(sk.kl_checklimbcounter)
      return
    end
  end

  -- make the announces work with a singleprompt
  local echof = svo.itf
  moveCursor(0, getLineNumber())

  -- we'll only ever have one name here so far. Actually add up the hits here and store them
  local who, t = next(hittable)
  local where
  local limbshit = {}
  for i = 1, #t do
    local dmg
    where, dmg = next(t[i])
    -- bad capture? don't break
    if svo.kl_list[who][where] then
      svo.kl_list[who][where] = svo.kl_list[who][where] + dmg
      raiseEvent("svo limbcounter hit", who, where)
      if not table.contains(limbshit, where) then limbshit[#limbshit+1] = where end
    end
  end

  if not where then
    echof("Failed to connect.%s\n", get_other_prepped(svo.kl_list[who], ""))
  else
    local text = {}
    for _, where in pairs(limbshit) do
      if svo.kl_list[who][where] >= svo.kl_list[who].kl_break_at then
        raiseEvent("svo limb broke", who, where)
        text[#text+1] = string.format("%s's %s broke.", who, where)
        svo.kl_list[who][where] = 0
      elseif svo.kl_list[who][where] >= svo.kl_list[who].kl_break_at - conf.limbprep then
        -- text[#text+1] = string.format("%s's %s is prepped.", who, where)
      else
        text[#text+1] = string.format("%s's %s is now at %s/%s.", who, where, svo.kl_list[who][where], svo.kl_list[who].kl_break_at)
      end
    end

    text[#text+1] = get_other_prepped(svo.kl_list[who])

    echof(table.concat(text, ' ').."\n")
  end

  -- turn things off
  hittable = {}
  disableTrigger("svokl Don't register")
  svo.signals.after_prompt_processing:block(sk.kl_checklimbcounter)
end

function svo.kl_hit(who, where, howmuch)
  svo.kl_had_balance = svo.bals.balance

  svo.kl_list[who] = svo.kl_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, kl_break_at = svo.kl_break_at}
  where = where:gsub(" ", "")
  svo.lasthit = who

  hittable[who] = hittable[who] or {}
  hittable[who][#hittable[who] + 1] = {[where] = (howmuch and howmuch or 1)}
  -- sk.onprompt_beforeaction_add("knight limbcounter", sk.kl_checklimbcounter)
  svo.signals.after_prompt_processing:unblock(sk.kl_checklimbcounter)
  enableTrigger("svokl Don't register")
  svo.kl_last_endurance = svo.stats.currentendurance
end

svo.signals.after_prompt_processing:connect(sk.kl_checklimbcounter)
svo.signals.after_prompt_processing:block(sk.kl_checklimbcounter)

function svo.kl_reset(whom, quiet)
  if svo.defc.dragonform then return end

  if whom then whom = string.title(whom) end
  local echof = svo.echof
  if quiet then echof = function() end end

  local t = {
    h = "head",
    t = "torso",
    rl = "rightleg",
    ll = "leftleg",
    ra = "rightarm",
    la = "leftarm",
  }

  if whom == "All" then
    svo.kl_list = {}
    echof("Reset everyone's limb status.")
  elseif not whom and svo.lasthit then
    svo.kl_list[svo.lasthit] = {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, kl_break_at = svo.kl_break_at}
    echof("Reset %s's limb status.", svo.lasthit)
  elseif t[whom:lower()] then
    if not svo.lasthit or not svo.kl_list[svo.lasthit] then
      echof("Not keeping track of anyone yet to reset their limb.")
    else
      svo.kl_list[svo.lasthit][t[whom:lower()]] = 0
      echof("Reset %s %s's status.", svo.lasthit, t[whom:lower()])
    end
  elseif whom then
    if svo.kl_list[whom] then
      svo.kl_list[whom] = nil
      echof("Reset %s's limb status.", whom)
    else
      echof("Weren't keeping track of %s anyway.", whom)
    end
  else
    echof("Not keeping track of anyone to reset them anyway.")
  end
  raiseEvent("svo limbcounter reset")
end

function svo.kl_show()
  if not next(svo.kl_list) then svo.echof("knight limbcounter: Not keeping track of anyone yet."); return end

  setFgColor(unpack(svo.getDefaultColorNums))
  for person, limbt in pairs(svo.kl_list) do
    echo("---"..person.." ") fg("a_darkgrey")
    echoLink("(reset)", 'svo.kl_reset"'..person..'"', "Reset limb status for "..person, true)
    setFgColor(unpack(svo.getDefaultColorNums))
    echo(string.format(" -- prep at %s -- break at %s --", limbt.kl_break_at - conf.limbprep, limbt.kl_break_at))
    echo(string.rep("-", (52-#person-#tostring(limbt.kl_break_at - conf.limbprep)-#tostring(limbt.kl_break_at))))
    echo"\n|"
    for i = 1, #limbs do
      if limbt[limbs[i]] >= limbt.kl_break_at - conf.limbprep then fg("green") end
      echo(string.format("%14s", (limbt[limbs[i]] >= limbt.kl_break_at - conf.limbprep and limbs[i].." prep" or limbs[i].. " "..limbt[limbs[i]])))
      if limbt[limbs[i]] >= limbt.kl_break_at - conf.limbprep then setFgColor(unpack(svo.getDefaultColorNums)) end
      echo"|"
    end
    echo"\n"
  end
  echo(string.rep("-", 91))
end

function svo.kl_sethitsneeded(person, hits)
  if not tonumber(hits) then svo.echof("At how many hits do you want to set the breaking point at?") return end

  svo.kl_break_at = hits

  if person then
    person = string.title(person)
    svo.kl_list[person] = svo.kl_list[person] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0}

    svo.kl_list[person].kl_break_at = hits
    svo.echof("Set the breaking point for %s at %s.", person, hits)

    for i = 1, #limbs do
      if svo.kl_list[person][limbs[i]] > hits then
        raiseEvent("svo limb broke", svo.kl_list[person], limbs[i])
        svo.kl_list[person][limbs[i]] = 0
        svo.echof("Reset %s's %s limb (it's over hits needed).", svo.kl_list[person], limbs[i])
        raiseEvent("svo limb reset", svo.kl_list[person], limbs[i])
      end
    end
  elseif svo.lasthit and svo.kl_list[svo.lasthit] then
    svo.kl_list[svo.lasthit].kl_break_at = svo.kl_break_at
    svo.echof("Set the breaking point for %s at %s.", svo.lasthit, svo.kl_break_at)

    for i = 1, #limbs do
      if svo.kl_list[svo.lasthit][limbs[i]] > hits then
        raiseEvent("svo limb broke", svo.kl_list[person], limbs[i])
        svo.kl_list[person][limbs[i]] = 0
        svo.echof("Reset %s's %s limb (it's over hits needed).", svo.kl_list[svo.lasthit], limbs[i])
        raiseEvent("svo limb reset", svo.kl_list[person], limbs[i])
      end
    end
  else
    svo.kl_break_at = tonumber(hits)
    svo.echof("Set the breaking points for future targets at %s.", svo.kl_break_at)
  end
end

function svo.kl_synchits()
  if not svo.lasthit or not svo.kl_list[svo.lasthit] then svo.echof("Not tracking anybody to sync their hits.") return end

  local t = svo.kl_list[svo.lasthit]
  local highestnum = 0
  for i = 1, #limbs do
    if t[limbs[i]] > highestnum then highestnum = t[limbs[i]] end
  end

  t.kl_break_at = highestnum
  svo.echof("Set %s's breakpoint at %s.", svo.lasthit, highestnum)

  for i = 1, #limbs do
    if t[limbs[i]] >= highestnum then
      local limb = limbs[i]
      t[limb] = 0
      svo.echof("Reset %s - it was over the hits needed.", limb)
      raiseEvent("svo limb reset", svo.lasthit, limb)
    end
  end
end

svo.config.setoption("weaponone",
{
  vconfig2string = true,
  type = "number",
  onset = function () svo.echof("Set the damage of your first weapon to %s.", conf.weaponone) end,
  onshow = function (defaultcolour)
    fg("gold")
    echoLink("kl:", "", "svo Knight limbcounter", true)
    fg(defaultcolour)
    echo(" 1st weapons damage is at ")
    fg("a_cyan") echoLink((conf.weaponone and conf.weaponone or "(not set)"), 'printCmdLine"vconfig weaponone "', "Set the damage on the first weapon", true) fg(defaultcolour)
    echo(", 2nd weapons at ")
    fg("a_cyan") echoLink((conf.weapontwo and conf.weapontwo or "(not set)"), 'printCmdLine"vconfig weapontwo "', "Set the damage on the second weapon", true) fg(defaultcolour)
    echo(", prepped at ")
    fg("a_cyan") echoLink((conf.limbprep and conf.limbprep or "(not set)"), 'printCmdLine"vconfig limbprep "', "Set amount of hits at which a limb is away from breaking, ie prepped. This is generally 2 for knights and 1 for single-hitters", true) fg(defaultcolour)
    echo(".\n")
  end
})
svo.config.setoption("weapontwo",
{
  type = "string",
  onset = function () svo.echof("Set the damage of your second weapon to %s.", conf.weapontwo) end
})
svo.config.setoption("limbprep",
{
  type = "number",
  onset = function () svo.echof("Will consider a limb to be prepped when it's %s hits away from breaking.", conf.limbprep) end,
})

conf.limbprep = conf.limbprep or 2
svo.echof("Loaded svo Knight limbcounter, version %s.", tostring(svo.kl_version))
