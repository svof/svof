-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local conf, sk = svo.conf, svo.sk

svo.pl_version = "1.0"

svo.pl_list = {}
local limbs = {"head", "torso", "rightarm", "leftarm", "rightleg", "leftleg"}
local hittable = {}
conf.limbprep = conf.limbprep or 1
svo.pl_break_at = 4

enableTrigger("svo Priest limbcounter")
enableAlias("svo Priest limbcounter")

-- Their blah, blah, blah are also prepped.
local function get_other_prepped(t, limbhit)
  local s = {}
  for i = 1, #limbs do
    if limbs[i] ~= limbhit and t[limbs[i]] == (t.pl_break_at - conf.limbprep) then s[#s+1] = limbs[i] end
  end

  if #s == 0 then return ""
  else return string.format(" Their %s %s also prepped.", svo.concatand(s), (#s == 1 and "is" or "are")) end
end

function svo.pl_ignore()
  table.remove(select(2, next(hittable)))
end

function svo.pl_smash()
  hittable = {}
  disableTrigger("svopl Don't register")
  svo.signals.before_prompt_processing:disconnect(sk.pl_checklimbcounter)
end


function sk.pl_checklimbcounter()
  -- we'll only ever have one name here so far
  local s,m = pcall(function()
    local who, t = next(hittable)
    local where
    for i = 1, #t do
      local dmg
      where, dmg = next(t[i])
      svo.pl_list[who][where] = svo.pl_list[who][where] + dmg
      raiseEvent("svo limbcounter hit", who, where)
    end

    if not where then
      svo.echof("Failed to connect.%s", get_other_prepped(svo.pl_list[who], ""))
    else
      if svo.pl_list[who][where] >= svo.pl_break_at then
        svo.echof("%s's %s broke.%s", who, where, get_other_prepped(svo.pl_list[who], where))
        svo.pl_list[who][where] = 0
      elseif svo.pl_list[who][where] >= svo.pl_list[who].pl_break_at - conf.limbprep then
        svo.echof("%s's %s is prepped.%s", who, where, get_other_prepped(svo.pl_list[who], where))
      else
        svo.echof("%s's %s is now at %s/%s.%s", who, where, svo.pl_list[who][where], svo.pl_break_at, get_other_prepped(svo.pl_list[who], where))
      end
    end
  end)
  if not s then
    echoLink("(e!)", [[echo("The problem was: ']]..tostring(m)..[['")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
  end

  hittable = {}
  disableTrigger("svopl Don't register")
  svo.signals.before_prompt_processing:disconnect(sk.pl_checklimbcounter)
end

function svo.pl_hit(who, where)
  svo.pl_list[who] = svo.pl_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, pl_break_at = svo.pl_break_at}
  where = where:gsub(" ", "")
  svo.lasthit = who

  hittable[who] = hittable[who] or {}
  hittable[who][#hittable[who] + 1] = {[where] = 1}
  svo.signals.before_prompt_processing:connect(sk.pl_checklimbcounter)
  enableTrigger("svopl Don't register")
end

function svo.pl_reset(whom)
  if svo.defc.dragonform then return end

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
    svo.pl_list = {}
    svo.echof("Reset everyone's limb status.")
  elseif not whom and svo.lasthit then
    svo.pl_list[svo.lasthit] = {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, pl_break_at = svo.pl_break_at}
    svo.echof("Reset %s's limb status.", svo.lasthit)
  elseif t[whom:lower()] then
    if not svo.lasthit or not svo.pl_list[svo.lasthit] then
      svo.echof("Not keeping track of anyone yet to reset their limb.")
    else
      svo.pl_list[svo.lasthit][t[whom:lower()]] = 0
      svo.echof("Reset %s %s's status.", svo.lasthit, t[whom:lower()])
    end
  elseif whom then
    if svo.pl_list[whom] then
      svo.pl_list[whom] = nil
      svo.echof("Reset %s's limb status.", whom)
    else
      svo.echof("Weren't keeping track of %s anyway.", whom)
    end
  else
    svo.echof("Not keeping track of anyone to reset them anyway.")
  end
  raiseEvent("svo limbcounter reset")
end

function svo.pl_show()
  if svo.defc.dragonform then return end

  if not next(svo.pl_list) then svo.echof("priest limbcounter: Not keeping track of anyone yet."); return end

  setFgColor(unpack(svo.getDefaultColorNums))
  for person, limbt in pairs(svo.pl_list) do
    echo("---"..person.." ") fg("a_darkgrey")
    echoLink("(reset)", 'svo.pl_reset"'..person..'"', "Reset limb status for "..person, true)
    setFgColor(unpack(svo.getDefaultColorNums))
    echo(string.format(" -- prep at %s -- break at %s --", limbt.pl_break_at - conf.limbprep, limbt.pl_break_at))
    echo(string.rep("-", (52-#person-#tostring(limbt.pl_break_at - conf.limbprep)-#tostring(limbt.pl_break_at))))
    echo"\n|"
    for i = 1, #limbs do
      if limbt[limbs[i]] >= limbt.pl_break_at - conf.limbprep then fg("green") end
      echo(string.format("%14s", (limbt[limbs[i]] >= limbt.pl_break_at - conf.limbprep and limbs[i].." prep" or limbs[i].. " "..limbt[limbs[i]])))
      if limbt[limbs[i]] >= limbt.pl_break_at - conf.limbprep then setFgColor(unpack(svo.getDefaultColorNums)) end
      echo"|"
    end
    echo"\n"
  end
  echo(string.rep("-", 91))
end

function svo.pl_sethitsneeded(person, hits)
  if not tonumber(hits) then svo.echof("At how many hits do you want to set the breaking point at?") return end

  svo.pl_break_at = hits

  if person then
    person = string.title(person)
    svo.pl_list[person] = svo.pl_list[person] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0}

    svo.pl_list[person].pl_break_at = hits
    svo.echof("Set the breaking point for %s at %s.", person, hits)

    for i = 1, #limbs do
      if svo.pl_list[person][limbs[i]] > hits then
        svo.pl_list[person][limbs[i]] = 0
        svo.echof("Reset %s's %s limb (it's over hits needed).", svo.pl_list[person], limbs[i])
        raiseEvent("svo limb reset", svo.pl_list[person], limbs[i])
      end
    end
  elseif svo.lasthit and svo.pl_list[svo.lasthit] then
    svo.pl_list[svo.lasthit].pl_break_at = svo.pl_break_at
    svo.echof("Set the breaking point for %s at %s.", svo.lasthit, svo.pl_break_at)

    for i = 1, #limbs do
      if svo.pl_list[svo.lasthit][limbs[i]] > hits then
        svo.pl_list[person][limbs[i]] = 0
        svo.echof("Reset %s's %s limb (it's over hits needed).", svo.pl_list[svo.lasthit], limbs[i])
        raiseEvent("svo limb reset", svo.pl_list[person], limbs[i])
      end
    end
  else
    svo.pl_break_at = tonumber(hits)
    svo.echof("Set the breaking points for future targets at %s.", svo.pl_break_at)
  end
end


function svo.pl_synchits()
  if not svo.lasthit or not svo.pl_list[svo.lasthit] then svo.echof("Not tracking anybody to sync their hits.") return end

  local t = svo.pl_list[svo.lasthit]
  local highestnum = 0
  for i = 1, #limbs do
    if t[limbs[i]] > highestnum then highestnum = t[limbs[i]] end
  end

  t.pl_break_at = highestnum
  svo.echof("Set %s's breakpoint at %s.", svo.lasthit, highestnum)

  for i = 1, #limbs do
    if t[limbs[i]] >= highestnum then t[limbs[i]] = 0; svo.echof("Reset %s - it was over the hits needed.", limbs[i]) end
  end
end

svo.config.setoption("limbprep",
{
  type = "number",
  onset = function () svo.echof("Will consider a limb to be prepped when it's %s hit%s away from breaking.", conf.limbprep, (conf.limbprep == 1 and '' or 's')) end,
})

conf.limbprep = conf.limbprep or 1

svo.echof("Loaded svo Priest limbcounter, version %s.", tostring(svo.pl_version))
