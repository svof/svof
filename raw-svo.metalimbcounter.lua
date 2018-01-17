-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

svo.ml_version = "1.0"

local sk = svo.sk

svo.ml_list = {}
local limbs = {'head', 'torso', 'rightarm', 'leftarm', 'rightleg', 'leftleg'}
svo.ml_limbs = limbs
local hittable = {}
svo.ml_break_at = 8

enableTrigger("svo Meta limbcounter")
enableAlias("svo Meta limbcounter")

-- Their blah, blah, blah are also prepped.
local function get_other_prepped(t, limbhit)
  local s = {}
  for i = 1, #limbs do
    if limbs[i] ~= limbhit and t[limbs[i]] == (t.ml_break_at - 1) then s[#s+1] = limbs[i] end
  end

  if #s == 0 then return ""
  else return string.format(" Their %s %s also prepped.", svo.concatand(s), (#s == 1 and 'is' or 'are')) end
end


function svo.ml_ignore()
  table.remove(select(2, next(hittable)))
end

function svo.sk.ml_checklimbcounter()
  -- make the announces work with a singleprompt
  local echof = svo.itf
  moveCursor(0, getLineNumber())

  -- we'll only ever have one name here so far
  local who, t = next(hittable)
  local where
  for i = 1, #t do
    local dmg
    where, dmg = next(t[i])
    svo.ml_list[who][where] = svo.ml_list[who][where] + dmg
    raiseEvent("svo limbcounter hit", who, where)
  end

  if not where then
    echof("Failed to connect.%s", get_other_prepped(svo.ml_list[who], ""))
  else
    if svo.ml_list[who][where] >= svo.ml_list[who].ml_break_at then
      echof("%s's %s broke.%s", who, where, get_other_prepped(svo.ml_list[who], where))
      svo.ml_list[who][where] = 0
    elseif svo.ml_list[who][where] >= svo.ml_list[who].ml_break_at - 1 then
      echof("%s's %s is prepped.%s", who, where, get_other_prepped(svo.ml_list[who], where))
    else
      echof("%s's %s is now at %s/%s.%s", who, where, svo.ml_list[who][where], svo.ml_list[who].ml_break_at, get_other_prepped(svo.ml_list[who], where))
    end
  end

  hittable = {}
  disableTrigger("svoml Don't register")
  svo.signals.after_prompt_processing:block(sk.ml_checklimbcounter)
end

function svo.ml_hit(who, where, maulorhydra)
  svo.ml_list[who] = svo.ml_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, ml_break_at = svo.ml_break_at}
  where = where:gsub(" ", "")
  svo.lasthit = who

  hittable[who] = hittable[who] or {}
  hittable[who][#hittable[who] + 1] = {[where] = (maulorhydra and tonumber(string.format("%.2f", svo.ml_list[who].ml_break_at / 4)) or 1)}
  svo.signals.after_prompt_processing:unblock(sk.ml_checklimbcounter)
  enableTrigger("svoml Don't register")
end

svo.signals.after_prompt_processing:connect(sk.ml_checklimbcounter)
svo.signals.after_prompt_processing:block(sk.ml_checklimbcounter)

function svo.ml_reset(whom)
  if svo.defc.dragonform then return end

  if whom then whom = string.title(whom) end

  local t = {
    h = 'head',
    t = 'torso',
    rl = 'rightleg',
    ll = 'leftleg',
    ra = 'rightarm',
    la = 'leftarm',
  }

  if whom == 'All' then
    svo.ml_list = {}
    svo.echof("Reset everyone's limb status.")
  elseif not whom and svo.lasthit then
    svo.ml_list[svo.lasthit] = {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, ml_break_at = svo.ml_break_at}
    svo.echof("Reset %s's limb status.", svo.lasthit)
  elseif t[whom:lower()] then
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
  if not next(svo.ml_list) then svo.echof("meta limbcounter: Not keeping track of anyone yet."); return end

  setFgColor(unpack(svo.getDefaultColorNums))
  for person, limbt in pairs(svo.ml_list) do
    echo("---"..person.." ") fg('a_darkgrey')
    echoLink("(reset)", 'svo.ml_reset"'..person..'"', "Reset limb status for "..person, true)
    setFgColor(unpack(svo.getDefaultColorNums))
    echo(string.format(" -- prep at %s -- break at %s --", limbt.ml_break_at - 1, limbt.ml_break_at))
    echo(string.rep("-", (52-#person-#tostring(limbt.ml_break_at - 1)-#tostring(limbt.ml_break_at))))
    echo"\n|"
    for i = 1, #limbs do
      if limbt[limbs[i]] >= limbt.ml_break_at - 1 then fg('green') end
      echo(string.format("%14s", (limbt[limbs[i]] >= limbt.ml_break_at - 1 and limbs[i].." prep" or limbs[i].. " "..limbt[limbs[i]])))
      if limbt[limbs[i]] >= limbt.ml_break_at - 1 then setFgColor(unpack(svo.getDefaultColorNums)) end
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
    svo.ml_list[person] = svo.ml_list[person] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0}

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

svo.echof("Loaded svo Meta limbcounter, version %s.", tostring(svo.ml_version))
