-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

pl_version = "1.0"

pl_list = {}
local limbs = {"head", "torso", "rightarm", "leftarm", "rightleg", "leftleg"}
local hittable = {}
conf.limbprep = conf.limbprep or 1
pl_break_at = 4

enableTrigger("svo Priest limbcounter")
enableAlias("svo Priest limbcounter")

-- Their blah, blah, blah are also prepped.
local function get_other_prepped(t, limbhit)
  local s = {}
  for i = 1, #limbs do
    if limbs[i] ~= limbhit and t[limbs[i]] == (t.pl_break_at - conf.limbprep) then s[#s+1] = limbs[i] end
  end

  if #s == 0 then return ""
  else return string.format(" Their %s %s also prepped.", concatand(s), (#s == 1 and "is" or "are")) end
end

function pl_ignore()
  table.remove(select(2, next(hittable)))
end

function pl_smash()
  hittable = {}
  disableTrigger("svopl Don't register")
  signals.before_prompt_processing:disconnect(sk.pl_checklimbcounter)
end


function sk.pl_checklimbcounter()
  -- we'll only ever have one name here so far
  local s,m = pcall(function()
    local who, t = next(hittable)
    local where
    for i = 1, #t do
      local dmg
      where, dmg = next(t[i])
      pl_list[who][where] = pl_list[who][where] + dmg
      raiseEvent("svo limbcounter hit", who, where)
    end

    if not where then
      echof("Failed to connect.%s", get_other_prepped(pl_list[who], ""))
    else
      if pl_list[who][where] >= pl_break_at then
        echof("%s's %s broke.%s", who, where, get_other_prepped(pl_list[who], where))
        pl_list[who][where] = 0
      elseif pl_list[who][where] >= pl_list[who].pl_break_at - conf.limbprep then
        echof("%s's %s is prepped.%s", who, where, get_other_prepped(pl_list[who], where))
      else
        echof("%s's %s is now at %s/%s.%s", who, where, pl_list[who][where], pl_break_at, get_other_prepped(pl_list[who], where))
      end
    end
  end)
  if not s then
    echoLink("(e!)", [[echo("The problem was: ']]..tostring(m)..[['")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
  end

  hittable = {}
  disableTrigger("svopl Don't register")
  signals.before_prompt_processing:disconnect(sk.pl_checklimbcounter)
end

function pl_hit(who, where)
  pl_list[who] = pl_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, pl_break_at = pl_break_at}
  local where = where:gsub(" ", "")
  lasthit = who

  hittable[who] = hittable[who] or {}
  hittable[who][#hittable[who] + 1] = {[where] = 1}
  signals.before_prompt_processing:connect(sk.pl_checklimbcounter)
  enableTrigger("svopl Don't register")
end

function pl_reset(whom)
  if defc.dragonform then return end

  if whom then whom = string.title(whom) end

  local t = {
    h = "head",
    t = "torso",
    rl = "rightleg",
    ll = "leftleg",
    ra = "rightarm",
    la = "leftarm",
  }

  if whom == "All" then
    pl_list = {}
    echof("Reset everyone's limb status.")
  elseif not whom and lasthit then
    pl_list[lasthit] = {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, pl_break_at = pl_break_at}
    echof("Reset %s's limb status.", lasthit)
  elseif t[whom:lower()] then
    if not lasthit or not pl_list[lasthit] then
      echof("Not keeping track of anyone yet to reset their limb.")
    else
      pl_list[lasthit][t[whom:lower()]] = 0
      echof("Reset %s %s's status.", lasthit, t[whom:lower()])
    end
  elseif whom then
    if pl_list[whom] then
      pl_list[whom] = nil
      echof("Reset %s's limb status.", whom)
    else
      echof("Weren't keeping track of %s anyway.", whom)
    end
  else
    echof("Not keeping track of anyone to reset them anyway.")
  end
  raiseEvent("svo limbcounter reset")
end

function pl_show()
  if defc.dragonform then return end

  local s = {}
  if not next(pl_list) then echof("priest limbcounter: Not keeping track of anyone yet."); return end

  setFgColor(unpack(getDefaultColorNums))
  for person, limbt in pairs(pl_list) do
    echo("---"..person.." ") fg("a_darkgrey")
    echoLink("(reset)", 'svo.pl_reset"'..person..'"', "Reset limb status for "..person, true)
    setFgColor(unpack(getDefaultColorNums))
    echo(string.format(" -- prep at %s -- break at %s --", limbt.pl_break_at - conf.limbprep, limbt.pl_break_at))
    echo(string.rep("-", (52-#person-#tostring(limbt.pl_break_at - conf.limbprep)-#tostring(limbt.pl_break_at))))
    echo"\n|"
    for i = 1, #limbs do
      if limbt[limbs[i]] >= limbt.pl_break_at - conf.limbprep then fg("green") end
      echo(string.format("%14s", (limbt[limbs[i]] >= limbt.pl_break_at - conf.limbprep and limbs[i].." prep" or limbs[i].. " "..limbt[limbs[i]])))
      if limbt[limbs[i]] >= limbt.pl_break_at - conf.limbprep then setFgColor(unpack(getDefaultColorNums)) end
      echo"|"
    end
    echo"\n"
  end
  echo(string.rep("-", 91))
end

function pl_sethitsneeded(person, hits)
  if not tonumber(hits) then echof("At how many hits do you want to set the breaking point at?") return end

  pl_break_at = hits

  if person then
    person = string.title(person)
    pl_list[person] = pl_list[person] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0}

    pl_list[person].pl_break_at = hits
    echof("Set the breaking point for %s at %s.", person, hits)

    for i = 1, #limbs do
      if pl_list[person][limbs[i]] > hits then
        pl_list[person][limbs[i]] = 0
        echof("Reset %s's %s limb (it's over hits needed).", pl_list[person], limbs[i])
        raiseEvent("svo limb reset", pl_list[person], limbs[i])
      end
    end
  elseif lasthit and pl_list[lasthit] then
    pl_list[lasthit].pl_break_at = pl_break_at
    echof("Set the breaking point for %s at %s.", lasthit, pl_break_at)

    for i = 1, #limbs do
      if pl_list[lasthit][limbs[i]] > hits then
        pl_list[person][limbs[i]] = 0
        echof("Reset %s's %s limb (it's over hits needed).", pl_list[lasthit], limbs[i])
        raiseEvent("svo limb reset", pl_list[person], limbs[i])
      end
    end
  else
    pl_break_at = tonumber(hits)
    echof("Set the breaking points for future targets at %s.", pl_break_at)
  end
end


function pl_synchits()
  if not lasthit or not pl_list[lasthit] then echof("Not tracking anybody to sync their hits.") return end

  local t = pl_list[lasthit]
  local highestnum = 0
  for i = 1, #limbs do
    if t[limbs[i]] > highestnum then highestnum = t[limbs[i]] end
  end

  t.pl_break_at = highestnum
  echof("Set %s's breakpoint at %s.", lasthit, highestnum)

  for i = 1, #limbs do
    if t[limbs[i]] >= highestnum then t[limbs[i]] = 0; echof("Reset %s - it was over the hits needed.", limbs[i]) end
  end
end

config.setoption("limbprep",
{
  type = "number",
  onset = function () echof("Will consider a limb to be prepped when it's %s hit%s away from breaking.", conf.limbprep, (conf.limbprep == 1 and '' or 's')) end,
})

conf.limbprep = conf.limbprep or 1

echof("Loaded svo Priest limbcounter, version %s.", tostring(pl_version))
