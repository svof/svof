-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

ml_version = "1.0"

ml_list = {}
local limbs = {"head", "torso", "rightarm", "leftarm", "rightleg", "leftleg"}
local hittable = {}

-- flag used to block a limb on a person from taking damage after it was recently broken
local block_limb, block_timer = false, false

ml_break_at = conf.limbprep

enableTrigger("svo Monk limbcounter")
enableAlias("svo Monk limbcounter")

-- Their blah, blah, blah are also prepped.
local function get_other_prepped(t, limbhit)
  local s = {}
  for i = 1, #limbs do
    if limbs[i] ~= limbhit and t[limbs[i]] == (t.ml_break_at) then s[#s+1] = limbs[i] end
  end

  if #s == 0 then return ""
  else return string.format(" Their %s %s also prepped.", concatand(s), (#s == 1 and "is" or "are")) end
end

function sk.ml_checklimbcounter()
  -- make the announces work with a singleprompt
  local echof = itf
  moveCursor(0, getLineNumber())

  -- we'll only ever have one name here so far
  local s,m = pcall(function()
    local who, t = next(hittable)
    local where

    for i = 1, #t do
      local dmg
      where, dmg = next(t[i])
      ml_list[who][where] = ml_list[who][where] + dmg
      raiseEvent("svo limbcounter hit", who, where)

      if not where then
        echof("Failed to connect.%s\n", get_other_prepped(ml_list[who], ""))
      else
        if ml_list[who][where] >= ml_list[who].ml_break_at then
          echof("%s's %s broke.%s\n", who, where, get_other_prepped(ml_list[who], where))
          ml_list[who][where] = 0

          -- remember which limb was recently broken to prevent it from taking damage on again before it's cured
          block_limb = {who = who, where = where}
          if block_timer then killTimer(block_timer) end
          block_timer = tempTimer(1, function() block_limb, block_timer = false, false end)

        elseif ml_list[who][where] >= ml_list[who].ml_break_at then
          echof("%s's %s is prepped.%s\n", who, where, get_other_prepped(ml_list[who], where))

        else
          echof("%s's %s is now at %s/%s.%s\n", who, where, ml_list[who][where], ml_list[who].ml_break_at, get_other_prepped(ml_list[who], where))
        end
      end
    end
  end)
  if not s then
    echoLink("(e!)", "echo([[The problem was: "..tostring(m).."]])", 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
  end

  hittable = {}
  signals.after_prompt_processing:block(sk.ml_checklimbcounter)
end

function ml_hit(who, where, location)
  ml_list[who] = ml_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, ml_break_at = conf.limbprep}
  local where = where:gsub(" ", "")
  lasthit = who

  hittable[who] = hittable[who] or {}

  -- if a limb was recently broken, prevent it from taking on damage - restoration will reset it at the end of 4s anyway
  if block_limb and block_limb.who == who and block_limb.where == where then return end

  if location == "arm" then
    hittable[who][#hittable[who] + 1] = {[where] = conf.armdamage}
  elseif location == "leg" then
    hittable[who][#hittable[who] + 1] = {[where] = conf.legdamage}
  elseif location == "AXK" then
    hittable[who][#hittable[who] + 1] = {[where] = ml_break_at}
  end
  signals.after_prompt_processing:unblock(sk.ml_checklimbcounter)
end
signals.after_prompt_processing:connect(sk.ml_checklimbcounter)
signals.after_prompt_processing:block(sk.ml_checklimbcounter)

function ml_reset(whom)
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
    ml_list = {}
    echof("Reset everyone's limb status.")
  elseif not whom and lasthit then
    ml_list[lasthit] = {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, ml_break_at = conf.limbprep}
    echof("Reset %s's limb status.", lasthit)
  elseif t[whom] or t[whom:lower()] then
    if not lasthit or not ml_list[lasthit] then
      echof("Not keeping track of anyone yet to reset their limb.")
    else
      ml_list[lasthit][t[whom:lower()]] = 0
      echof("Reset %s %s's status.", lasthit, t[whom:lower()])
    end
  elseif whom then
    if ml_list[whom] then
      ml_list[whom] = nil
      echof("Reset %s's limb status.", whom)
    else
      echof("Weren't keeping track of %s anyway.", whom)
    end
  else
    echof("Not keeping track of anyone to reset them anyway.")
  end
  raiseEvent("svo limbcounter reset")
end

function ml_show()
  local s = {}
  if not next(ml_list) then echof("monk limbcounter: Not keeping track of anyone yet."); return end

  setFgColor(unpack(getDefaultColorNums))
  for person, limbt in pairs(ml_list) do
    echo("---"..person.." ") fg("a_darkgrey")
    echoLink("(reset)", 'svo.ml_reset"'..person..'"', "Reset limb status for "..person, true)
    setFgColor(unpack(getDefaultColorNums))
    echo(string.format(" --            -- break at %s --", limbt.ml_break_at))
    echo(string.rep("-", (52-#person-#tostring(limbt.ml_break_at)-#tostring(limbt.ml_break_at))))
    echo"\n|"
    for i = 1, #limbs do
      if limbt[limbs[i]] >= limbt.ml_break_at then fg("green") end
      echo(string.format("%14s", (limbt[limbs[i]] >= limbt.ml_break_at and limbs[i].." prep" or limbs[i].. " "..limbt[limbs[i]])))
      if limbt[limbs[i]] >= limbt.ml_break_at then setFgColor(unpack(getDefaultColorNums)) end
      echo"|"
    end
    echo"\n"
  end
  echo(string.rep("-", 91))
end

function ml_sethitsneeded(person, hits)
  if not tonumber(hits) then echof("At how many hits do you want to set the breaking point at?") return end

  ml_break_at = hits

  if person then
    person = string.title(person)
    ml_list[person] = ml_list[person] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, ml_break_at = conf.limbprep}

    ml_list[person].ml_break_at = hits
    echof("Set the breaking point for %s at %s.", person, hits)

    for i = 1, #limbs do
      if ml_list[person][limbs[i]] > hits then
        ml_list[person][limbs[i]] = 0
        echof("Reset %s's %s limb (it's over hits needed).", ml_list[person], limbs[i])
        raiseEvent("svo limb reset", ml_list[person], limbs[i])
      end
    end
  elseif lasthit and ml_list[lasthit] then
    ml_list[lasthit].ml_break_at = ml_break_at
    echof("Set the breaking point for %s at %s.", lasthit, ml_break_at)

    for i = 1, #limbs do
      if ml_list[lasthit][limbs[i]] > hits then
        ml_list[person][limbs[i]] = 0
        echof("Reset %s's %s limb (it's over hits needed).", ml_list[lasthit], limbs[i])
        raiseEvent("svo limb reset", ml_list[person], limbs[i])
      end
    end
  else
    ml_break_at = tonumber(hits)
    echof("Set the breaking points for future targets at %s.", ml_break_at)
  end
end

function ml_synchits()
  if not lasthit or not ml_list[lasthit] then echof("Not tracking anybody to sync their hits.") return end

  local t = ml_list[lasthit]
  local highestnum = 0
  for i = 1, #limbs do
    if t[limbs[i]] > highestnum then highestnum = t[limbs[i]] end
  end

  t.ml_break_at = highestnum
  echof("Set %s's breakpoint at %s.", lasthit, highestnum)

  for i = 1, #limbs do
    if t[limbs[i]] >= highestnum then t[limbs[i]] = 0; echof("Reset %s - it was over the hits needed.", limbs[i]) end
  end
end


conf.limbprep = conf.limbprep or 7
conf.armdamage = conf.armdamage or 3
conf.legdamage = conf.legdamage or 4
config.setoption("armdamage",
{
  vconfig2string = true,
  type = "number",
  onset = function () echof("Set the damage that your punches do to %s points.", conf.armdamage) end,
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
config.setoption("legdamage",
{
  type = "string",
  onset = function () echof("Set the damage that your kicks do to %s points.", conf.legdamage) end
})
config.setoption("limbprep",
{
  type = "number",
  onset = function () echof("Will consider a limb to be prepped when it's %s points away from breaking.", conf.limbprep) end,
})

enableTrigger("svo Monk limbcounter")
enableAlias("svo Monk limbcounter")
echof("Loaded svo Monk limbcounter, version %s.", tostring(ml_version))
