-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

kl_version = "1.0"

kl_list = {}
local limbs = {"head", "torso", "rightarm", "leftarm", "rightleg", "leftleg"}
local hittable = {}
local kl_last_endurance
kl_break_at = 10

enableTrigger("svo Knight limbcounter")
enableAlias("svo Knight limbcounter")

-- Their blah, blah, blah are also prepped.
local function get_other_prepped(t)
  local s = {}
  for i = 1, #limbs do
    if t[limbs[i]] == (t.kl_break_at - conf.limbprep) then s[#s+1] = limbs[i] end
  end

  if #s == 0 then return ""
  else return string.format("Their %s %s now prepped.", concatand(s), (#s == 1 and "is" or "are")) end
end

function svo.kl_ignore()
  table.remove(select(2, next(hittable)))
end

function sk.kl_checklimbcounter()
  -- AI check
  -- check for balance loss, or in case of game queueing, a queueing message
  if conf.aillusion and not sk.sawqueueing() then
    -- bals is not updated until the prompt, so bals. atm has the old value

    if not affs.blackout and not (kl_had_balance and not newbals.balance) then
      ignore_illusion("This doesn't look like an attack from you, it's fake!")

      -- turn things off
      hittable = {}
      disableTrigger("svokl Don't register")
      signals.after_prompt_processing:block(sk.kl_checklimbcounter)
      return
    end
  end

  -- make the announces work with a singleprompt
  local echof = itf
  moveCursor(0, getLineNumber())

  -- we'll only ever have one name here so far. Actually add up the hits here and store them
  local who, t = next(hittable)
  local where
  local limbshit = {}
  for i = 1, #t do
    local dmg
    where, dmg = next(t[i])
    -- bad capture? don't break
    if kl_list[who][where] then
      kl_list[who][where] = kl_list[who][where] + dmg
      raiseEvent("svo limbcounter hit", who, where)
      if not table.contains(limbshit, where) then limbshit[#limbshit+1] = where end
    end
  end

  if not where then
    echof("Failed to connect.%s\n", get_other_prepped(kl_list[who], ""))
  else
    local text = {}
    for _, where in pairs(limbshit) do
      if kl_list[who][where] >= kl_list[who].kl_break_at then
        raiseEvent("svo limb broke", who, where)
        text[#text+1] = string.format("%s's %s broke.", who, where)
        kl_list[who][where] = 0
      elseif kl_list[who][where] >= kl_list[who].kl_break_at - conf.limbprep then
        -- text[#text+1] = string.format("%s's %s is prepped.", who, where)
      else
        text[#text+1] = string.format("%s's %s is now at %s/%s.", who, where, kl_list[who][where], kl_list[who].kl_break_at)
      end
    end

    text[#text+1] = get_other_prepped(kl_list[who])

    echof(table.concat(text, ' ').."\n")
  end

  -- turn things off
  hittable = {}
  disableTrigger("svokl Don't register")
  signals.after_prompt_processing:block(sk.kl_checklimbcounter)
end

function kl_hit(who, where, howmuch)
  kl_had_balance = bals.balance

  kl_list[who] = kl_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, kl_break_at = kl_break_at}
  local where = where:gsub(" ", "")
  lasthit = who

  hittable[who] = hittable[who] or {}
  hittable[who][#hittable[who] + 1] = {[where] = (howmuch and howmuch or 1)}
  -- sk.onprompt_beforeaction_add("knight limbcounter", sk.kl_checklimbcounter)
  signals.after_prompt_processing:unblock(sk.kl_checklimbcounter)
  enableTrigger("svokl Don't register")
  kl_last_endurance = stats.currentendurance
end

signals.after_prompt_processing:connect(sk.kl_checklimbcounter)
signals.after_prompt_processing:block(sk.kl_checklimbcounter)

function kl_reset(whom, quiet)
  if defc.dragonform then return end

  if whom then whom = string.title(whom) end
  local echof = echof
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
    kl_list = {}
    echof("Reset everyone's limb status.")
  elseif not whom and lasthit then
    kl_list[lasthit] = {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, kl_break_at = kl_break_at}
    echof("Reset %s's limb status.", lasthit)
  elseif t[whom:lower()] then
    if not lasthit or not kl_list[lasthit] then
      echof("Not keeping track of anyone yet to reset their limb.")
    else
      kl_list[lasthit][t[whom:lower()]] = 0
      echof("Reset %s %s's status.", lasthit, t[whom:lower()])
    end
  elseif whom then
    if kl_list[whom] then
      kl_list[whom] = nil
      echof("Reset %s's limb status.", whom)
    else
      echof("Weren't keeping track of %s anyway.", whom)
    end
  else
    echof("Not keeping track of anyone to reset them anyway.")
  end
  raiseEvent("svo limbcounter reset")
end

function kl_show()
  if not next(kl_list) then echof("knight limbcounter: Not keeping track of anyone yet."); return end

  setFgColor(unpack(getDefaultColorNums))
  for person, limbt in pairs(kl_list) do
    echo("---"..person.." ") fg("a_darkgrey")
    echoLink("(reset)", 'svo.kl_reset"'..person..'"', "Reset limb status for "..person, true)
    setFgColor(unpack(getDefaultColorNums))
    echo(string.format(" -- prep at %s -- break at %s --", limbt.kl_break_at - conf.limbprep, limbt.kl_break_at))
    echo(string.rep("-", (52-#person-#tostring(limbt.kl_break_at - conf.limbprep)-#tostring(limbt.kl_break_at))))
    echo"\n|"
    for i = 1, #limbs do
      if limbt[limbs[i]] >= limbt.kl_break_at - conf.limbprep then fg("green") end
      echo(string.format("%14s", (limbt[limbs[i]] >= limbt.kl_break_at - conf.limbprep and limbs[i].." prep" or limbs[i].. " "..limbt[limbs[i]])))
      if limbt[limbs[i]] >= limbt.kl_break_at - conf.limbprep then setFgColor(unpack(getDefaultColorNums)) end
      echo"|"
    end
    echo"\n"
  end
  echo(string.rep("-", 91))
end

function kl_sethitsneeded(person, hits)
  if not tonumber(hits) then echof("At how many hits do you want to set the breaking point at?") return end

  kl_break_at = hits

  if person then
    person = string.title(person)
    kl_list[person] = kl_list[person] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0}

    kl_list[person].kl_break_at = hits
    echof("Set the breaking point for %s at %s.", person, hits)

    for i = 1, #limbs do
      if kl_list[person][limbs[i]] > hits then
        raiseEvent("svo limb broke", kl_list[person], limbs[i])
        kl_list[person][limbs[i]] = 0
        echof("Reset %s's %s limb (it's over hits needed).", kl_list[person], limbs[i])
        raiseEvent("svo limb reset", kl_list[person], limbs[i])
      end
    end
  elseif lasthit and kl_list[lasthit] then
    kl_list[lasthit].kl_break_at = kl_break_at
    echof("Set the breaking point for %s at %s.", lasthit, kl_break_at)

    for i = 1, #limbs do
      if kl_list[lasthit][limbs[i]] > hits then
        raiseEvent("svo limb broke", kl_list[person], limbs[i])
        kl_list[person][limbs[i]] = 0
        echof("Reset %s's %s limb (it's over hits needed).", kl_list[lasthit], limbs[i])
        raiseEvent("svo limb reset", kl_list[person], limbs[i])
      end
    end
  else
    kl_break_at = tonumber(hits)
    echof("Set the breaking points for future targets at %s.", kl_break_at)
  end
end

function kl_synchits()
  if not lasthit or not kl_list[lasthit] then echof("Not tracking anybody to sync their hits.") return end

  local t = kl_list[lasthit]
  local highestnum = 0
  for i = 1, #limbs do
    if t[limbs[i]] > highestnum then highestnum = t[limbs[i]] end
  end

  t.kl_break_at = highestnum
  echof("Set %s's breakpoint at %s.", lasthit, highestnum)

  for i = 1, #limbs do
    if t[limbs[i]] >= highestnum then
      local limb = limbs[i]
      t[limb] = 0
      echof("Reset %s - it was over the hits needed.", limb)
      raiseEvent("svo limb reset", lasthit, limb)
    end
  end
end

config.setoption("weaponone",
{
  vconfig2string = true,
  type = "number",
  onset = function () echof("Set the damage of your first weapon to %s.", conf.weaponone) end,
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
config.setoption("weapontwo",
{
  type = "string",
  onset = function () echof("Set the damage of your second weapon to %s.", conf.weapontwo) end
})
config.setoption("limbprep",
{
  type = "number",
  onset = function () echof("Will consider a limb to be prepped when it's %s hits away from breaking.", conf.limbprep) end,
})

conf.limbprep = conf.limbprep or 2
echof("Loaded svo Knight limbcounter, version %s.", tostring(kl_version))
