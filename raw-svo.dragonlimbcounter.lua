-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

dl_version = "1.0"

dl_list = {}
local limbs = {"head", "torso", "rightarm", "leftarm", "rightleg", "leftleg"}
local hittable = {}
dl_prep_at = 3
dl_break_at = 4

enableTrigger("svo Dragon limbcounter")
enableAlias("svo Dragon limbcounter")

-- Their blah, blah, blah are also prepped.
local function get_other_prepped(t, limbhit)
  local s = {}
  for i = 1, #limbs do
    if limbs[i] ~= limbhit and t[limbs[i]] == dl_prep_at then s[#s+1] = limbs[i] end
  end

  if #s == 0 then return ""
  else return string.format(" Their %s %s also prepped.", concatand(s), (#s == 1 and "is" or "are")) end
end

function svo.dl_ignore()
  if not next(hittable) then return end
  table.remove(select(2, next(hittable)))
end


function sk.dl_checklimbcounter()
  -- make the announces work with a singleprompt
  local echof = itf
  moveCursor(0, getLineNumber())

  -- we'll only ever have one name here so far
  local who, t = next(hittable)
  local where
  for i = 1, #t do
    local dmg
    where, dmg = next(t[i])
    dl_list[who][where] = dl_list[who][where] + dmg
    raiseEvent("svo limbcounter hit", who, where)
  end

  if not where then
    echof("Failed to connect.%s", get_other_prepped(dl_list[who], ""))
  else
    if dl_list[who][where] >= dl_break_at then
      echof("%s's %s broke.%s", who, where, get_other_prepped(dl_list[who], where))
      dl_list[who][where] = 0
    elseif dl_list[who][where] >= dl_prep_at then
      echof("%s's %s is prepped.%s", who, where, get_other_prepped(dl_list[who], where))
    else
      echof("%s's %s is now at %s/%s.%s", who, where, dl_list[who][where], dl_break_at, get_other_prepped(dl_list[who], where))
    end
  end

  hittable = {}
  disableTrigger("svodl Don't register")
  signals.before_prompt_processing:disconnect(sk.dl_checklimbcounter)
end

function dl_hit(who, where)
  dl_list[who] = dl_list[who] or {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0}
  local where = where:gsub(" ", "")
  lasthit = who

  hittable[who] = hittable[who] or {}
  hittable[who][#hittable[who] + 1] = {[where] = 1}
  signals.before_prompt_processing:connect(sk.dl_checklimbcounter)
  enableTrigger("svodl Don't register")
end

function dl_reset(whom)
  if not defc.dragonform then return end

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
    dl_list = {}
    echof("Reset everyone's limb status.")
  elseif not whom and lasthit then
    dl_list[lasthit] = {head = 0, torso = 0, rightarm = 0, leftarm = 0, rightleg = 0, leftleg = 0, dl_break_at = dl_break_at}
    echof("Reset %s's limb status.", lasthit)
  elseif t[whom:lower()] then
    if not lasthit or not dl_list[lasthit] then
      echof("Not keeping track of anyone yet to reset their limb.")
    else
      dl_list[lasthit][t[whom:lower()]] = 0
      echof("Reset %s %s's status.", lasthit, t[whom:lower()])
    end
  elseif whom then
    if dl_list[whom] then
      dl_list[whom] = nil
      echof("Reset %s's limb status.", whom)
    else
      echof("Weren't keeping track of %s anyway.", whom)
    end
  else
    echof("Not keeping track of anyone to reset them anyway.")
  end
  raiseEvent("svo limbcounter reset")
end

function dl_show()
  if not defc.dragonform then return end

  if not next(dl_list) then echof("dragon limbcounter: Not keeping track of anyone yet."); return end

  setFgColor(unpack(getDefaultColorNums))
  for person, limbt in pairs(dl_list) do
    echo("---"..person.." ") fg("a_darkgrey")
    echoLink("(reset)", 'svo.dl_reset"'..person..'"', "Reset limb status for "..person, true)
    setFgColor(unpack(getDefaultColorNums))
    echo(string.format(" -- prep at %s -- break at %s --", dl_prep_at, dl_break_at))
    echo(string.rep("-", (52-#person-#tostring(dl_prep_at)-#tostring(dl_break_at))))
    echo"\n|"
    for i = 1, #limbs do
      if limbt[limbs[i]] >= dl_break_at - 1 then fg("green") end
      echo(string.format("%14s", (limbt[limbs[i]] >= dl_break_at - 1 and limbs[i].." prep" or limbs[i].. " "..limbt[limbs[i]])))
      if limbt[limbs[i]] >= dl_break_at - 1 then setFgColor(unpack(getDefaultColorNums)) end
      echo"|"
    end
    echo"\n"
  end
  echo(string.rep("-", 91))
end

echof("Loaded svo Dragon limbcounter, version %s.", tostring(dl_version))
