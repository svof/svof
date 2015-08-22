-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

pl.dir.makepath(getMudletHomeDir() .. "/svo/config")

sps.sp_fillup = function ()
  local t = {}
  for limb, _ in pairs(sp_limbs) do
    t[limb] = false
  end
  return t
end

sp_config = { parry = "", priority = {}, parry_actionlevel = {}, parry_shouldbe = sps.sp_fillup() }
sps.parry_currently = sps.sp_fillup()
me.parry_currently = sps.parry_currently

sps.parry_options = {
  full = "Parry the currently damaged limb (one that's mangled/mutilated).",
  lasthit = "Parry the last hit limb (ie got hit left leg - will parry left leg).",
  ["lasthit opposite limb"] = "Parry the opposite of the last hit limb, by limbs (ie got hit left leg - will parry right  leg).",
  ["lasthit opposite side"] = "Parry the opposite of the last hit limb, by sides (ie got hit left leg - will parry left arm).",
  manual = "Allows you to manually control parry with the p* aliases."
}

-- ask users to click on limbs for priority first, then ask for each limb in order to select action level,
-- then ask what to do with stancing when the action level happens, and what to do with parrying
sps.install = {
  {
    check = function () return #sp_config.priority == table.size(sp_limbs) end,
    act = function (step)
      echof("Step %d - assign priorities to the limbs. Click on the following in the order of most important, or use the %s command:", step, green("vp nextprio <limb>"))
      echo("  " .. oneconcat(sp_limbs))
          resetFormat()
          deselect()
      for name, _ in pairs(sp_limbs) do
        moveCursor("main",  1, getLineNumber()+2)
        if selectString(name, 1) ~= -1 then
          setLink('svo.sp.nextprio ("' .. name .. '", true)', 'Set ' .. name .. ' as the next limb in importance.')
          resetFormat()
          deselect()
        end
      end
      echo"\n"
    end},
  --[[{
    check = function ()
        for limb,_ in pairs(sp_limbs) do
          if sp_config.parry_actionlevel[limb] == nil then return false end
        end
        return true
      end,
    act = function (step)
      local function makecodestrings(name)
        local t = {}
        t[#t+1] = 'svo.sp.setparrylevel("'..name..'", false, true)'
        for amount = 275, 2000, 275 do
          t[#t+1] = 'svo.sp.setparrylevel("'..name..'", '..amount..', true)'
        end
        return t
      end
      local function maketooltipstrings(name)
        local t = {}
        t[#t+1] = 'Set ' .. name .. ' to ' .. 'none'
        for amount = 275, 2000, 275 do
          t[#t+1] = 'Set ' .. name .. ' to ' .. amount
        end
        return t
      end


      echof("Step %d - assign a level above which parry should act for for each limb by right-clicking, or use the %s command:", step, green("vp parrylevel <limb> <amount, or 'none'>"))
      echo "  "
      for name, _ in pairs(sp_limbs) do
        echoPopup(name, makecodestrings(name), maketooltipstrings(name))
        echo(" ")
      end
      echo"\n"
    end},
]]
  {
    check = function () return sp_config.parry ~= "" end,
    act = function (step)
      echof("Step %d - decide what parry strategy to use when a limb is over the limit by clicking on it, or using the %s command:", step, green("vp parrystrat <strategy>"))
      echo "  "
      for name, tooltip in pairs(sps.parry_options) do
        echoLink(name, 'svo.sp.setparry ("' .. name .. '", true)', tooltip)
        echo " "
      end
      echo"\n"
    end},

}

sps.installnext = function()
  if not sps.settingup then return end
  for i, c in ipairs(sps.install) do
    if not c.check() then
      echo"\n"
      c.act(i)
      return
    end
  end

  sps.settingup = nil
  echof("Parry setup done :)")
end


function sp.setup()
  sp_config = { parry = "", priority = {}, parry_actionlevel = {}, parry_shouldbe = sps.sp_fillup() }
  sps.settingup = true

  sps.installnext()
end

function sp.nextprio(limb, echoback)
  local sendf
  if echoback then sendf = echof else sendf = errorf end
  local prios = sp_config.priority

  if not sp_limbs[limb] then
    sendf("Sorry, %s isn't a proper limb name. They are:\n  %s", limb, oneconcat(sp_limbs))
    return; end

  if contains(prios, limb) then
    sendf("%s is already in the list.", limb); return; end

  prios[#prios+1] = limb
  if echoback then
    echof("%s added; current list: %s", limb, table.concat(prios, ", "))
  end

  if #prios == table.size(sp_limbs) then sps.installnext() end
end

function sp.setparry(option, echoback)
  local sendf
  if echoback then sendf = echof else sendf = errorf end

  if not option then
    sendf("Possible options are:")
    echo"  "
    for name, tooltip in pairs(sps.parry_options) do
      echoLink(name, 'svo.sp.setparry ("' .. name .. '", true)', tooltip)
      echo "   "
    end
    echo'\n'
    showprompt()
    return
  elseif not sps.parry_options[option] then
    sendf("Sorry, %s isn't a valid option for parry. They are:")
    echo"  "
    for name, tooltip in pairs(sps.parry_options) do
      echoLink(name, 'svo.sp.setparry ("' .. name .. '", true)', tooltip)
      echo "   "
    end
    echo'\n'
    showprompt()
    return
  end

  sp_config.parry = option
  if echoback then
    echof("Will use the %s strategy for parry.", sp_config.parry)
    showprompt()
  end

  sp_checksp()
  sps.installnext()
end

function sp.setparrylevel(limb, amount, echoback)
  local sendf
  if echoback then sendf = echof else sendf = errorf end

  if not sp_limbs[limb] then
    sendf("Sorry, %s isn't a proper limb name. They are:\n  %s", limb, oneconcat(sp_limbs))
    return; end

  if not tonumber(amount) and amount ~= false then
    sendf("To what amount do you want to set %s to?", limb)
    return; end

  sp_config.parry_actionlevel[limb] = tonumber(amount)

  if echoback then
    echof("Set the %s parry action level to %s", limb, amount and tostring(amount) or "none")
  end

  for limb,_ in pairs(sp_limbs) do
    if sp_config.parry_actionlevel[limb] == nil then return end
  end
  sps.installnext()
end

function sp_setparry(what, echoback)
  local sendf
  if echoback then sendf = echof else sendf = errorf end

  local t = {
    h = "head",
    tt = "torso",
    rl = "right leg",
    ll = "left leg",
    ra = "right arm",
    la = "left arm",
    n = "nothing"
  }

  assert(t[what], "invalid short letter for svo.sp_setparry", sendf)

  for limb, _ in pairs(sp_limbs) do
    if limb == t[what] then sp_config.parry_shouldbe[limb] = true
      else sp_config.parry_shouldbe[limb] = false end
  end

  sp_checksp()
  make_gnomes_work()
end

sp.show = function ()
  echof("Parry report:")

  --[[echof("Action levels:")
  for limb, level in pairs(sp_config.parry_actionlevel) do
    echo"  " echof("%s: parry %s", limb, tostring(level))
  end]]

  echof("Limb priorities: %s", table.concat(sp_config.priority, ", "))
  echof("Parry strategy: %s (currently parrying: %s)", type(sp_config.parry) == "string" and sp_config.parry or "custom function",

  (function ()
    local parrying_list = {}
    for limb, parrying in pairs(sp_config.parry_shouldbe) do
      if parrying then parrying_list[#parrying_list+1] = limb end
    end

    return table.concat(parrying_list, ", ") end)())
end

sp_checksp = function ()
  -- check parry
  -- see if any priories have been set for strategies that require them
  local prios, priosset = sp_config.priority, true
  if type(prios) ~= "table" then
    priosset = false
  end

  if priosset and sp_config.parry == "full" then
    local alreadyset
    for i = 1, #prios do
      local limb = prios[i]
      if not alreadyset and type(sp_config.parry_actionlevel[limb]) == "number" and (affs["mangled"..limb] or (limb == head and (affs.serioustrauma or affs.mildtrauma)) or (limb == "torso" and (affs.mildconcussion or affs.seriousconcussion))) then
        sp_config.parry_shouldbe[limb] = true
        alreadyset = true
      else
        sp_config.parry_shouldbe[limb] = false
      end
    end

  elseif sp_config.parry == "lasthit" then
    for limb, _ in pairs(sp_config.parry_shouldbe) do
      if limb == me.lasthitlimb then
        sp_config.parry_shouldbe[limb] = true
      else
        sp_config.parry_shouldbe[limb] = false
      end
    end

  elseif sp_config.parry == "lasthit opposite limb" then
    local t = {
      head = "torso",
      torso = "head",
      ["right arm"] = "left arm",
      ["left arm"] = "right arm",
      ["right leg"] = "left leg",
      ["left leg"] = "right leg"
    }

    local wanted = t[me.lasthitlimb]

    if wanted then
      for limb, _ in pairs(sp_config.parry_shouldbe) do
        if limb == wanted then
          sp_config.parry_shouldbe[limb] = true
        else
          sp_config.parry_shouldbe[limb] = false
        end
      end
    end

  elseif sp_config.parry == "lasthit opposite side" then
    local t = {
      head = "torso",
      torso = "head",
      ["right arm"] = "right leg",
      ["left arm"] = "left leg",
      ["right leg"] = "right arm",
      ["left leg"] = "left arm"
    }

    local wanted = t[me.lasthitlimb]

    if wanted then
      for limb, _ in pairs(sp_config.parry_shouldbe) do
        if limb == wanted then
          sp_config.parry_shouldbe[limb] = true
        else
          sp_config.parry_shouldbe[limb] = false
        end
      end
    end

  elseif type(sp_config.parry) == "function" then
    local s,m = pcall(sp_config.parry)
    if not s then echof("Your custom parry function had a problem:\n  %s", m) end
  end

  -- check if we need to adjust our parry
  check_sp_satisfied()

  signals.after_lifevision_processing:block(sp_checksp)
end

-- check custom parry functions whenever we gain or lose an aff
-- implemented in another function and not sp_checksp, because of https://github.com/katcipis/luanotify/issues/24
sps.checkcustomparry = function()
  if type(sp_config.parry) == "function" then
    sp_config.parry()

    -- check if we need to adjust our parry
    check_sp_satisfied()
  end
end
signals.svogotaff:connect(sps.checkcustomparry)
signals.svolostaff:connect(sps.checkcustomparry)
-- public API
checkcustomparry = sps.checkcustomparry

signals.after_lifevision_processing:connect(sp_checksp)
signals.after_lifevision_processing:block(sp_checksp)

sps.something_to_parry = function ()
  for _, shouldparry in pairs(sp_config.parry_shouldbe) do
    if shouldparry then return true end
  end

  return false -- don't unparry if we have all zero's as shouldparry
end

signals.saveconfig:connect(function () table.save(getMudletHomeDir() .. "/svo/config/sp_config", sp_config) end)

local sp_config_path = getMudletHomeDir() .. "/svo/config/sp_config"

if lfs.attributes(sp_config_path) then
  local ok = pcall(table.load,sp_config_path, sp_config)
  if not ok then
    os.remove(sp_config_path)
    tempTimer(10, function()
      echof("Your parry config file was corrupted - I've deleted it so the system can load other stuff OK. You'll need to set the parry options again with vconfig sp. (%q)", msg)
    end)
  end
end
