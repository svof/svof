-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local conf, sk = svo.conf, svo.sk

svo.ml_version = "1.0"

svo.ml_list = {}
local limbs = {"head", "torso", "rightarm", "leftarm", "rightleg", "leftleg"}
local hittable = {}

-- flag used to block a limb on a person from taking damage after it was recently broken
local block_limb, block_timer = false, false

svo.ml_break_at = conf.limbprep

enableTrigger("svo Monk limbcounter")
enableAlias("svo Monk limbcounter")

-- Their blah, blah, blah are also prepped.
local function get_other_prepped(t, limbhit)
  local s = {}
  for i = 1, #limbs do
    if limbs[i] ~= limbhit and t[limbs[i]] == (t.ml_break_at) then s[#s+1] =
    limbs[i] end
  end

  if #s == 0 then return ""
  else return string.format(" Their %s %s also prepped.", svo.concatand(s), (#s == 1 and "is" or "are")) end
end

function sk.ml_checklimbcounter()
  -- make the announces work with a singleprompt
  local echof = svo.itf
  moveCursor(0, getLineNumber())

  -- we'll only ever have one name here so far
  local s,m = pcall(function()
    local who, t = next(hittable)
    local where

    for i = 1, #t do
      local dmg
      where, dmg = next(t[i])
      svo.ml_list[who][where] = svo.ml_list[who][where] + dmg
      raiseEvent("svo limbcounter hit", who, where)

      if not where then
        echof("Failed to connect.%s\n", get_other_prepped(svo.ml_list[who], ""))
      else
        if svo.ml_list[who][where] >= svo.ml_list[who].ml_break_at then
          echof("%s's %s broke.%s\n", who, where, get_other_prepped(svo.ml_list[who], where))
          svo.ml_list[who][where] = 0

          -- remember which limb was recently broken to prevent it from taking damage on again before it's cured
          block_limb = {who = who, where = where}
          if block_timer then killTimer(block_timer) end
          block_timer = tempTimer(1, function() block_limb, block_timer = false, false end)

        elseif svo.ml_list[who][where] >= svo.ml_list[who].ml_break_at then
          echof("%s's %s is prepped.%s\n", who, where, get_other_prepped(svo.ml_list[who], where))

        else
          echof("%s's %s is now at %s/%s.%s\n", who, where, svo.ml_list[who][where], svo.ml_list[who].ml_break_at, get_other_prepped(svo.ml_list[who], where))
        end
      end
    end
  end)
  if not s then
    echoLink("(e!)", "echo([[The problem was: "..tostring(m).."]])", 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
  end

  hittable = {}
  svo.signals.after_prompt_processing:block(sk.ml_checklimbcounter)
end

function svo.ml_hit(who, where, location)
  svo.ml_list[who] = svo.ml_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, ml_break_at = conf.limbprep}
  where = where:gsub(" ", "")
  svo.lasthit = who

  hittable[who] = hittable[who] or {}

  -- if a limb was recently broken, prevent it from taking on damage - restoration will reset it at the end of 4s anyway
  if block_limb and block_limb.who == who and block_limb.where == where then return end

  if location == "arm" then
    hittable[who][#hittable[who] + 1] = {[where] = conf.armdamage}
  elseif location == "leg" then
    hittable[who][#hittable[who] + 1] = {[where] = conf.legdamage}
  elseif location == "AXK" then
    hittable[who][#hittable[who] + 1] = {[where] = svo.ml_break_at}
  end
  svo.signals.after_prompt_processing:unblock(sk.ml_checklimbcounter)
end
svo.signals.after_prompt_processing:connect(sk.ml_checklimbcounter)
svo.signals.after_prompt_processing:block(sk.ml_checklimbcounter)

function svo.ml_reset(whom)
  whom = string.title(whom)
  local t = {
    h = "head",
    t = "torso",
    rl = "rightleg",
    ll = "leftleg",
    ra = "rightarm",
    la = "leftarm",
  }

  if whom == "All" then
    svo.ml_list = {}
    svo.echof("Reset everyone's limb status.")
  elseif not whom and svo.lasthit then
    svo.ml_list[svo.lasthit] = {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, ml_break_at = conf.limbprep}
    svo.echof("Reset %s's limb status.", svo.lasthit)
  elseif t[whom] or t[whom:lower()] then
    if not svo.lasthit or not svo.ml_list[svo.lasthit] then
      svo.echof("Not keeping track of anyone yet to reset their limb.")
    else
      svo.ml_list[svo.lasthit][t[whom:lower()]] = 0
      svo.echof("Reset %s %s's status.", svo.lasthit, t[whom:lower()])
    end
  elseif whom then
    if svo.ml_list[whom] then
      svo.ml_list[whom] = nil
      svo.echof("Reset %s's limb status.", whom)
    else
      svo.echof("Weren't keeping track of %s anyway.", whom)
    end
  else
    svo.echof("Not keeping track of anyone to reset them anyway.")
  end
  raiseEvent("svo limbcounter reset")
end

function svo.ml_show()
  if not next(svo.ml_list) then svo.echof("monk limbcounter: Not keeping track of anyone yet."); return end

  setFgColor(unpack(svo.getDefaultColorNums))
  for person, limbt in pairs(svo.ml_list) do
    echo("---"..person.." ") fg("a_darkgrey")
    echoLink("(reset)", 'svo.ml_reset"'..person..'"', "Reset limb status for "..person, true)
    setFgColor(unpack(svo.getDefaultColorNums))
    echo(string.format(" --            -- break at %s --", limbt.ml_break_at))
    echo(string.rep("-", (52-#person-#tostring(limbt.ml_break_at)-#tostring(limbt.ml_break_at))))
    echo"\n|"
    for i = 1, #limbs do
      if limbt[limbs[i]] >= limbt.ml_break_at then fg("green") end
      echo(string.format("%14s", (limbt[limbs[i]] >= limbt.ml_break_at and limbs[i].." prep" or limbs[i].. " "..limbt[limbs[i]])))
      if limbt[limbs[i]] >= limbt.ml_break_at then setFgColor(unpack(svo.getDefaultColorNums)) end
      echo"|"
    end
    echo"\n"
  end
  echo(string.rep("-", 91))
end

function svo.ml_sethitsneeded(person, hits)
  if not tonumber(hits) then svo.echof("At how many hits do you want to set the breaking point at?") return end

  svo.ml_break_at = hits

  if person then
    person = string.title(person)
    svo.ml_list[person] = svo.ml_list[person] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, ml_break_at = conf.limbprep}

    svo.ml_list[person].ml_break_at = hits
    svo.echof("Set the breaking point for %s at %s.", person, hits)

    for i = 1, #limbs do
      if svo.ml_list[person][limbs[i]] > hits then
        svo.ml_list[person][limbs[i]] = 0
        svo.echof("Reset %s's %s limb (it's over hits needed).", svo.ml_list[person], limbs[i])
        raiseEvent("svo limb reset", svo.ml_list[person], limbs[i])
      end
    end
  elseif svo.lasthit and svo.ml_list[svo.lasthit] then
    svo.ml_list[svo.lasthit].ml_break_at = svo.ml_break_at
    svo.echof("Set the breaking point for %s at %s.", svo.lasthit, svo.ml_break_at)

    for i = 1, #limbs do
      if svo.ml_list[svo.lasthit][limbs[i]] > hits then
        svo.ml_list[person][limbs[i]] = 0
        svo.echof("Reset %s's %s limb (it's over hits needed).", svo.ml_list[svo.lasthit], limbs[i])
        raiseEvent("svo limb reset", svo.ml_list[person], limbs[i])
      end
    end
  else
    svo.ml_break_at = tonumber(hits)
    svo.echof("Set the breaking points for future targets at %s.", svo.ml_break_at)
  end
end

function svo.ml_synchits()
  if not svo.lasthit or not svo.ml_list[svo.lasthit] then svo.echof("Not tracking anybody to sync their hits.") return end

  local t = svo.ml_list[svo.lasthit]
  local highestnum = 0
  for i = 1, #limbs do
    if t[limbs[i]] > highestnum then highestnum = t[limbs[i]] end
  end

  t.ml_break_at = highestnum
  svo.echof("Set %s's breakpoint at %s.", svo.lasthit, highestnum)

  for i = 1, #limbs do
    if t[limbs[i]] >= highestnum then t[limbs[i]] = 0; svo.echof("Reset %s - it was over the hits needed.", limbs[i]) end
  end
end


conf.limbprep = conf.limbprep or 7
conf.armdamage = conf.armdamage or 3
conf.legdamage = conf.legdamage or 4
svo.config.setoption("armdamage",
{
  vconfig2string = true,
  type = "number",
  onset = function () svo.echof("Set the damage that your punches do to %s points.", conf.armdamage) end,
  onshow = function (defaultcolour)
    fg("gold")
    echoLink("ml:", "", "svo Monk limbcounter", true)
    fg(defaultcolour)
    echo(" arm damage is at ")
    fg("a_cyan") echoLink((conf.armdamage and conf.armdamage or "(not set)"), 'printCmdLine"vconfig armdamage "', "Set the damage your punches do", true) fg(defaultcolour)
    echo(", leg damage at ")
    fg("a_cyan") echoLink((conf.legdamage and conf.legdamage or "(not set)"), 'printCmdLine"vconfig legdamage "', "Set the damage your kicks do", true) fg(defaultcolour)
    echo(", prepped at ")
    fg("a_cyan") echoLink((conf.limbprep and conf.limbprep or "(not set)"), 'printCmdLine"vconfig limbprep "', "Set amount of hits at which a limb is away from breaking, ie prepped. This should generally be arm damage + arm damage + leg damage", true) fg(defaultcolour)
    echo(".\n")
  end
})
svo.config.setoption("legdamage",
{
  type = "string",
  onset = function () svo.echof("Set the damage that your kicks do to %s points.", conf.legdamage) end
})
svo.config.setoption("limbprep",
{
  type = "number",
  onset = function () svo.echof("Will consider a limb to be prepped when it's %s points away from breaking.", conf.limbprep) end,
})

enableTrigger("svo Monk limbcounter")
enableAlias("svo Monk limbcounter")
svo.echof("Loaded svo Monk limbcounter, version %s.", tostring(svo.ml_version))
