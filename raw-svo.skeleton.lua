-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local sys, affs, defdefup, defkeepup, signals = svo.sys, svo.affs, svo.defdefup, svo.defkeepup, svo.signals
local deepcopy, conf, sk, me, defs, defc = svo.deepcopy, svo.conf, svo.sk, svo.me, svo.defs, svo.defc
local defences, stats, cnrl, rift = svo.defences, svo.stats, svo.cnrl, svo.rift
local bals, pipes, watch = svo.bals, svo.pipes, svo.watch

-- misc functions
function svo.errorf(...)
  error(string.format(...))
end

function svo.echon(...)
  local function wrapper(...) decho(string.format(...)) end
  local status, result = pcall(wrapper, ...)
  if not status then error(result, 2) end
  echo("\n")
end

function svo.contains(t, value)
  svo.assert(type(t) == "table", "svo.contains wants a table!")

  for k, v in pairs(t) do
    if v == value then
      return k
    end
  end

  return false
end

if svo.haveskillset('healing') then
  -- used by 'normal' cure functions to see if we should ignore curing this aff
  -- returns true - Healing will *not* cure, use normal
  -- returns false - Healing *will* cure, don't use normal
  function sk.wont_heal_this(aff)
    if type(conf.usehealing) ~= "string" or conf.usehealing ~= "full" or not svo.can_usemana() then return true end

    if sk.healingmap[aff] and sk.healingmap[aff]() then
      return false
    end

    return true
  end
end

svo.sk.checking_herb_ai = function()
  return (svo.doingaction"checkparalysis" or svo.doingaction"checkasthma" or svo.doingaction"checkimpatience") and true or false
end

svo.force_send = _G.send

-- new incoming balances that are tracked between the lines and the prompt
svo.newbals = {}

-- checks

-- sip check
local healthchecks = {
  healhealth = {p = svo.dict.healhealth},
  healmana = {p = svo.dict.healmana}
}

-- build a table of all the things we need to do with their priority numbers,
-- sort it, and do the topmost thing.
svo.check_sip = function(sync_mode)
  -- can we even sip?
  if not bals.sip or svo.usingbal("sip") or affs.stun or affs.unconsciousness or affs.sleep or affs.anorexia then
      return
  end

  -- get all prios in the list
  local prios = {}
  local function check(what)
    for i, j in pairs(what) do
      if not (conf.serverside and svo.serverignore[i]) and j.p.sip and j.p.sip.isadvisable() and not svo.ignore[i] then
        prios[i] = (not sync_mode) and j.p.sip.aspriority or j.p.sip.spriority
      end
    end
  end

  check(affs)
  check(healthchecks)

  -- have nada?
  if not next(prios) then return end

  -- otherwise, do the highest!
  if not sync_mode then
    svo.doaction(svo.dict[svo.getHighestKey(prios)].sip) else
    return svo.dict[svo.getHighestKey(prios)].sip end
end

-- purgative check: needs to be asynced as well
svo.check_purgative = function(sync_mode)
  -- can we even sip?
  if not bals.purgative or svo.usingbal("purgative") or affs.stun or affs.unconsciousness or affs.sleep or affs.anorexia then
      return
  end

  -- get all prios in the list
  local prios = {}
  local function check(what)
    local gotsomething = false
    for i, j in pairs(what) do
      if not (conf.serverside and svo.serverignore[i]) and j.p.purgative and j.p.purgative.isadvisable() and not svo.ignore[i] then
        if svo.haveskillset('healing') and not sk.wont_heal_this(i) then
          return
        end

      prios[i] = (not sync_mode) and j.p.purgative.aspriority or j.p.purgative.spriority
      gotsomething = true
      end
    end

    return gotsomething
  end

  check(affs)

  if sys.deffing or conf.keepup then
    check(svo.dict_purgative)
  end

  -- have nada?
  if not next(prios) then return end

  -- otherwise, do the highest!
  if not sync_mode then
    svo.doaction(svo.dict[svo.getHighestKey(prios)].purgative) else
    return svo.dict[svo.getHighestKey(prios)].purgative end
end


-- salve check
svo.check_salve = function(sync_mode)
  -- can we even use salves?
  if not bals.salve or svo.usingbal("salve") or
    affs.sleep or affs.stun or affs.unconsciousness or affs.slickness then
      return
  end

  -- get all prios in the list
  local prios = {}
  local function check(what)
    for i, j in pairs(what) do
      if not (conf.serverside and svo.serverignore[i]) and j.p.salve and j.p.salve.isadvisable() and not svo.ignore[i] then
        if svo.haveskillset('healing') and not sk.wont_heal_this(i) then
          return
        end
        prios[i] = (not sync_mode) and j.p.salve.aspriority or j.p.salve.spriority
      end
    end
  end

  check(affs)
  if sys.deffing or conf.keepup then check(svo.dict_salve_def) end

  -- have nada?
  if not next(prios) then return false end

  -- otherwise, do the highest!
  if not sync_mode then
    svo.doaction(svo.dict[svo.getHighestKey(prios)].salve) else
    return svo.dict[svo.getHighestKey(prios)].salve end
end

-- herb check

-- build a table of all the things we need to do with their priority numbers,
-- sort it, and do the topmost thing.
svo.check_herb = function(sync_mode)
  -- can we even eat?
  if not bals.herb or svo.usingbal("herb") or affs.sleep
    or affs.stun or affs.unconsciousness or svo.sacid or affs.anorexia
    or (conf.aillusion and conf.waitherbai and sk.checking_herb_ai()) then
      return
  end

  -- get all prios in the list
  local prios = {}
  local function check (what)
    for i, j in pairs(what) do
      if not (conf.serverside and svo.serverignore[i]) and j.p.herb and j.p.herb.isadvisable() and not svo.ignore[i]
        -- make sure that we can outrift things, or if we can't, we have the herb in our inventory
        and (sys.canoutr or sk.can_eat_for(j.p.herb)) then
          if svo.haveskillset('healing') and not sk.wont_heal_this(i) then
            return
          end
          prios[i] = (not sync_mode) and j.p.herb.aspriority or j.p.herb.spriority
      end
    end
  end

  check(affs)
  if sys.deffing or conf.keepup then check(svo.dict_herb) end

  -- have nada?
  if not next(prios) then return false end

  -- otherwise, do the highest!
  if not sync_mode then
    svo.doaction(svo.dict[svo.getHighestKey(prios)].herb) else
    return svo.dict[svo.getHighestKey(prios)].herb end
end

-- misc check

-- build a table of all the things we need to do with their priority numbers,
-- sort it, and do the topmost thing.

-- this is just in case we're checking amnesia only
local amnesias = {
  amnesia = {p = svo.dict.amnesia},
  fear    = {p = svo.dict.fear},
}
svo.check_misc = function(sync_mode, onlyamnesia)
  -- we -don't- check for sleep here, but a bit lower down - so waking can be on a misc
  if affs.stun or affs.unconsciousness then
    return
  end

  -- get all prios in the list
  local prios = {}
  local function check(what)
    for i, j in pairs(what) do
      if not (conf.serverside and svo.serverignore[i]) and j.p.misc and j.p.misc.isadvisable() and not svo.ignore[i] and not svo.doingaction (i) and (not affs.sleep or j.p.misc.action_name == "sleep") then
        if svo.haveskillset('healing') and not sk.wont_heal_this(i) then
          return
        end
        prios[i] = (not sync_mode) and j.p.misc.aspriority or j.p.misc.spriority
      end
    end
  end

  if not onlyamnesia then
    check(affs)
    check(svo.dict_misc)
    if sys.deffing or conf.keepup then check(svo.dict_misc_def) end
  else
    check(amnesias)
  end

  -- have nada?
  if not next(prios) then return end

  -- otherwise, do the highest! Also go down the list in priorities in case you need to dontbatch
  if not sync_mode then
    local set = svo.index_map(prios)

    local highest, lowest = svo.getBoundary(prios)

    local dontbatch
    for i = highest, lowest, -1 do
      if set[i] then
        if not svo.dict[set[i]].misc.dontbatch or not dontbatch then
          svo.doaction(svo.dict[set[i]].misc)

          if svo.dict[set[i]].misc.dontbatch then dontbatch = true end
        end
      end
    end
  else
    -- otherwise, do the highest!
    return svo.dict[svo.getHighestKey(prios)].misc
  end
end

local check_for_asthma = {
  checkasthma = {p = svo.dict.checkasthma}
}
svo.check_smoke = function(sync_mode)
  if not bals.smoke or affs.stun or affs.unconsciousness or affs.sleep or affs.asthma or affs.mucous then
    return
  end

  -- get all prios in the list
  local prios = {}
  local function check(what)
    for i, j in pairs(what) do
      if not (conf.serverside and svo.serverignore[i]) and j.p.smoke and j.p.smoke.isadvisable() and not svo.ignore[i] and not svo.doingaction(i) then
        if svo.haveskillset('healing') and not sk.wont_heal_this(i) then
          return
        end
        prios[i] = (not sync_mode) and j.p.smoke.aspriority or j.p.smoke.spriority
      end
    end
  end

  check(affs)
  if svo.affsp.asthma then check(check_for_asthma) end
  if sys.deffing or conf.keepup then check(svo.dict_smoke_def) end

  -- have nada?
  if not next(prios) then return end

  if not sync_mode then
    local set = svo.index_map(prios)

    local highest, lowest = svo.getBoundary(prios)
    for i = highest, lowest, -1 do
      if set[i] then
        svo.doaction(svo.dict[set[i]].smoke)
      end
    end
  else
    -- otherwise, do the highest!
    return svo.dict[svo.getHighestKey(prios)].smoke
  end
end

svo.check_moss = function(sync_mode)
  -- can we even sip?
  if not conf.moss or svo.usingbal("moss") or affs.stun or affs.unconsciousness or not bals.moss
    or affs.sleep or affs.anorexia then
      return
  end

  -- get all prios in the list
  local prios = {}
  local function check(what)
    for i, j in pairs(what) do
      if not (conf.serverside and svo.serverignore[i]) and j.p.moss and j.p.moss.isadvisable() and not svo.ignore[i] then
        prios[i] = (not sync_mode) and j.p.moss.aspriority or j.p.moss.spriority
      end
    end
  end

  if not conf.secondarymoss then check(healthchecks) end

  -- have nada?
  if not next(prios) then return end

  -- otherwise, do the highest!
  if not sync_mode then
    svo.doaction(svo.dict[svo.getHighestKey(prios)].moss) else
    return svo.dict[svo.getHighestKey(prios)].moss end
end

svo.check_focus = function(sync_mode)
  -- can we even focus?
  if not next(affs) or svo.usingbal("focus") or affs.stun or affs.unconsciousness or not bals.focus
    or affs.sleep or not svo.can_usemana() or not conf.focus or stats.currentwillpower <= 75
    or affs.impatience or affs.inquisition or (affs.cadmus and not conf.focuswithcadmus) then
      return
  end

  local wont_heal_this = sk.wont_heal_this

  -- get all prios in the list
  local prios = {}
  for i, j in pairs(affs) do
    if not (conf.serverside and svo.serverignore[i]) and j.p.focus and (not affs.cadmus or (conf.focuswithcadmus and me.cadmusaffs[i])) and j.p.focus.isadvisable() and not svo.ignore[i] then
          if svo.haveskillset('healing') and not wont_heal_this(i) then
            return
          end
        prios[i] = (not sync_mode) and j.p.focus.aspriority or j.p.focus.spriority
    end
  end

  -- have nada?
  if not next(prios) then return end

  -- otherwise, do the highest!
  if not sync_mode then
    svo.doaction(svo.dict[svo.getHighestKey(prios)].focus) else
    return svo.dict[svo.getHighestKey(prios)].focus end
end


-- lifevision system

-- if something was added here, that means it was validated via other
-- means already - all we need to do now is to check if we had lifevision
-- catch the line or no.

-- other_action means do something else than default when done
-- arg is the argument to pass either to the default action
-- lineguard is how many lines this should be across - ineffective with vconfig batch
function svo.lifevision.add(what, other_action, arg, lineguard)
  svo.lifevision.l:set(what.name, {
    p = what,
    other_action = other_action,
    arg = arg
  })

  if lineguard and (not sys.lineguard or sys.lineguard > lineguard) then -- remember the smallest one, because if we have two conflicts, the smallest one is most valid
    sys.lineguard = lineguard
  end

  svo.debugf("svo.lifevision: %s added with '%s' call (%s)%s", tostring(what.name), other_action and other_action or "default", tostring(arg), (lineguard and " lg: "..lineguard or ""))

  if not sys.sync then return end
  if svo.actions[what.name] and what.balance ~= "aff" and what.balance ~= "gone" and color_table[conf.slowcurecolour] then
    selectCurrentLine()
    fg(conf.slowcurecolour)
    resetFormat()
    deselect()
  end
end

-- special: adds something where required, ie, first position in the queue
-- was necessary to have blackout be above everything else so stun AI doesn't slow it down 'till next prompt
function svo.lifevision.addcust(what, where, other_action, arg)
  svo.assert(what, "svo.lifevision.addcust wants an argument")
  svo.lifevision.l:insert(where, what.name, {
    p = what,
    other_action = other_action,
    arg = arg
  })
  svo.debugf("svo.lifevision: %s added (pos %d) with '%s' call (%s)", tostring(what.name), where, other_action and other_action or "default", tostring(arg))
end

-- returns the current lineguard that's set or nil
function svo.lifevision.getlineguard()
  return sys.lineguard
end

function svo.lifevision.clearlineguard()
  sys.lineguard = nil
end

local function run_through_actions()
  for _,j in svo.lifevision.l:iter() do
    if not sk.stopprocessing then
      svo.actionfinished(j.p, j.other_action, j.arg)
    else
      svo.actionclear(j.p)
    end
  end
end

function svo.lifevision.validate()
  -- take a line off the paragraph_length if the game's curing went off, as it is a "meta" message and shouldn't be counted
  local paragraph_length = svo.paragraph_length
  if sk.sawcuring() then paragraph_length = paragraph_length - 1 end

  -- batch needs to disable lineguard, as commands come at once then. Plus, illusions aren't as prevalent anymore since serverside curing is completely immune to them
  if sys.flawedillusion or (not conf.batch and sys.lineguard and paragraph_length > sys.lineguard) then
    if sys.not_illusion then
      svo.debugf("cancelled illusion")
      run_through_actions()

      moveCursor(0, getLineNumber()-1)
      moveCursor(#getCurrentLine(), getLineNumber())
      insertLink(" (!i)", '', (type(sys.not_illusion) == "string" and sys.not_illusion or "Cancelled detected 'illusion' due to script override."))
      sys.not_illusion = false
    else
      svo.debugf("got an illusion")

      for _,j in svo.lifevision.l:iter() do
        svo.actionclear(j.p)
      end

      if sys.lineguard and not sys.flawedillusion then
        svo.debugf("svo.lifevision.validate: paragraph_length %d, sys.lineguard %d", paragraph_length, sys.lineguard)
        moveCursor(0, getLineNumber()-1)
        moveCursor(#getCurrentLine(), getLineNumber())
        insertLink(" (i)", '', "Ignored this whole illusion because the line(s) present need to be in their own.")
        moveCursorEnd()
      end
    end
    sys.flawedillusion, me.haveillusion = false, false
  else
    run_through_actions()
  end
  svo.lifevision.l = svo.pl.OrderedMap()
  sk.stopprocessing = nil
  sys.lineguard = false
end

svo.checkanyaffs = function (...)
  local t = {...}
  for i=1,#t do
    local j = t[i]

    if affs[j.name] then
    return j end
  end
end

-- balanceful check
svo.check_balanceful_acts = function(sync_mode)
  if affs.sleep or affs.stun or affs.unconsciousness or not bals.balance or not bals.equilibrium or not bals.rightarm or not bals.leftarm or (svo.me.class == "Druid" and not bals.hydra)
  then return end

  -- get all prios in the list
  local prios = {}
  local function check(what)
    for i, j in pairs(what) do
      if not (conf.serverside and svo.serverignore[i]) and j.p.physical.balanceful_act and j.p.physical.isadvisable() and not svo.ignore[i] then
        prios[i] = (not sync_mode) and j.p.physical.aspriority or j.p.physical.spriority
      end
    end
  end

  check(svo.dict_balanceful)

  if sys.deffing or conf.keepup then
    check(svo.dict_balanceful_def)
  end

  -- have nada?
  if not next(prios) then return false end

  -- otherwise, do the highest!
  if not sync_mode then
    svo.doaction(svo.dict[svo.getHighestKey(prios)].physical) else
    return svo.dict[svo.getHighestKey(prios)].physical end

  return true
end

-- balanceless check
svo.check_balanceless_acts = function(sync_mode)
  if affs.sleep or affs.stun or affs.unconsciousness or not bals.balance or not bals.equilibrium or not bals.rightarm or not bals.leftarm or (svo.me.class == "Druid" and not bals.hydra)
   then return end

  -- get all prios in the list
  local prios = {}
  local function check(what)
    local gotsomething = false

    for i, j in pairs(what) do
      if not (conf.serverside and svo.serverignore[i]) and j.p.physical.balanceless_act and j.p.physical.isadvisable() and not svo.ignore[i] then
        prios[i] = (not sync_mode) and j.p.physical.aspriority or j.p.physical.spriority
        gotsomething = true
      end
    end

    return gotsomething
  end

  check(svo.dict_balanceless)

  if sys.deffing or conf.keepup then
    check(svo.dict_balanceless_def)
  end

  -- have nada?
  if not next(prios) then return end

  -- otherwise, do the highest!
  if not sync_mode then
    local set = svo.index_map(prios)

    local highest, lowest = svo.getBoundary(prios)
    for i = highest, lowest, -1 do
      if set[i] then
        svo.doaction(svo.dict[set[i]].physical)
      end
    end
  else
    return svo.dict[svo.getHighestKey(prios)].physical
  end

  return true
end

local balanceless = svo.balanceless or {}
local balanceful = svo.balanceful or {}

function svo.sk.balance_controller()
  if sys.balanceid == sys.balancetick then return end

  if not (bals.balance and bals.equilibrium) or (affs.webbed or affs.bound or affs.transfixed or affs.roped or affs.impale or affs.paralysis or affs.sleep) then return end

  -- loop through all balanceless functions
  for _, f in pairs(balanceless) do
    f()
  end

-- loop through balanceful actions until we get one that takes bal or eq
  local r
  for _,f in pairs(balanceful) do
    r = f()
    if r then
      if sys.actiontimeoutid then killTimer(sys.actiontimeoutid) end
      if type(r) == "number" then
        sys.actiontimeoutid = tempTimer(r, function () sys.balancetick = sys.balancetick + 1; svo.make_gnomes_work() end)
      elseif conf.lag and conf.lag == 4 then
        -- 24 does it right away!
        sys.actiontimeoutid = tempTimer(60*60*23, function () sys.balancetick = sys.balancetick + 1; svo.make_gnomes_work() end)
      else
        sys.actiontimeoutid = tempTimer(sys.actiontimeout, function () sys.balancetick = sys.balancetick + 1; svo.make_gnomes_work() end)
      end

      sys.balanceid = sys.balancetick
      break
    end
  end
end

function svo.addbalanceless(name, func)
  svo.assert(name and func, "svo.addbalanceless: both name and function are required")
  svo.assert(type(func) == 'function', "svo.addbalanceless: function needs to be an actual function, while you gave it a "..type(func))

  balanceless[name] = func
end

function svo.removebalanceless(name)
  balanceless[name] = nil
end

function svo.addbalanceful(name, func)
  svo.assert(name and func, "svo.addbalanceful: both name and function are required")
  svo.assert(type(func) == "function", "svo.addbalanceful: second argument has to be a function (you gave it a "..type(func)..")")

  balanceful[name] = func
end

function svo.removebalanceful(name)
  balanceful[name] = nil
end

function svo.clearbalanceful()
  balanceful = {}
  svo.addbalanceful("svo check do", sk.check_do)
  raiseEvent("svo balanceful ready")
end

function svo.clearbalanceless()
  balanceless = {}
  svo.addbalanceless("svo check dofree", svo.check_dofree)
  raiseEvent("svo balanceless ready")
end

tempTimer(0, function ()
  raiseEvent("svo balanceless ready")
  raiseEvent("svo balanceful ready")
end)

-- svo Got prompt
-- DO WORK!

-- utils
local function find_highest_action(tbl)
  local result
  local highest = 0
  for _,j in pairs(tbl) do
    if j.spriority > highest then
      highest = j.spriority
      result = j
    end
  end

  return result
end

local workload = {svo.check_salve, svo.check_focus, svo.check_sip, svo.check_purgative,
            svo.check_smoke, svo.check_herb, svo.check_moss, svo.check_misc,
            svo.check_balanceless_acts, svo.check_balanceful_acts}

-- real functions
local function work_slaves_work()
  -- in async, ask each bal to do its action

  svo.check_misc(false, true) -- amnesia & fear only

  svo.check_focus()
  svo.check_salve()

  svo.check_sip()
  svo.check_purgative()
  svo.check_smoke()
  svo.check_herb()

  svo.check_misc() -- fails for amnesia, but works for Priest Healing...

  svo.check_moss()

  svo.check_balanceless_acts()

  -- if the system didn't use bal, let it be used for other things.
  if not svo.check_balanceful_acts() and not svo.will_take_balance() then sk.balance_controller() end

  -- serverside prios: eat, apply, smoke, focus
end

svo.make_gnomes_work_async = function()
  if conf.paused then return end

  signals.sysdatasendrequest:block(cnrl.processusercommand)

  if conf.commandecho and (conf.commandechotype == "fancy" or conf.commandechotype == "fancynewline") then
    send = svo.fancysend

    -- insert expandAlias (used in dofree, dor and similar) into the current batch, breaking the batch up in the process
    local oldexpandAlias = expandAlias
    if conf.batch then
      expandAlias = function(command, show)
        svo.sendc({ func = oldexpandAlias, args = {command, show} })
      end
    end

    work_slaves_work()
    -- commands are echoed by fancysendall() in onpromptr() in case of a prompt from the game, otherwise echo them right away if from a forced svo.make_gnomes_work()
    if not sk.processing_prompt then svo.fancysendall() end
    send = svo.oldsend

    if conf.batch then
      expandAlias = oldexpandAlias
    end
  else
    work_slaves_work()
  end

  signals.sysdatasendrequest:unblock(cnrl.processusercommand)
end

svo.make_gnomes_work_sync = function()
  sk.syncdebug = false
  if conf.paused or svo.sacid then return end

  signals.sysdatasendrequest:block(cnrl.processusercommand)

  -- if we're already doing an action that is not of an "waitingfor" type, don't do anything!
  -- logic: if next returns nil,
  local result
  for balance,actions in pairs(svo.bals_in_use) do
    if balance ~= "waitingfor" and balance ~= "gone" and balance ~= "aff" and next(actions) then result = select(2, next(actions)) break end
  end
  if result then
    svo.debugf("doing %s, quitting for now", result.name)
    sk.syncdebug = string.format("[%s]: Currently doing: %s", getTimestamp(getLineCount()):trim(), result.name)

    signals.sysdatasendrequest:unblock(cnrl.processusercommand)
    return
  end

  sk.gnomes_are_working = true

  local action_list = {}

  --... check for all bals.
  -- in sync, only return values
  for _,j in pairs(workload) do
    result = j(true)
    if result then action_list[result.name] = result end
  end

  local actions = svo.pl.tablex.keys(action_list)
  table.sort(actions, function(a,b)
    return action_list[a].spriority > action_list[b].spriority
  end)

  sk.syncdebug = string.format('[%s]: Feasible actions we\'re currently considering doing (in order): %s', getTimestamp(getLineCount()):trim(), (not next(action_list) and '(none)' or svo.concatand(actions)))

  -- nothing to do =)
  if not next(action_list) then
    sk.gnomes_are_working = false

    signals.sysdatasendrequest:unblock(cnrl.processusercommand)
    return
  end

  if conf.commandecho and conf.commandechotype == "fancy" then
    send = svo.fancysend
    local oldbatch = conf.batch
    conf.batch = false
    svo.doaction(find_highest_action(action_list))
    -- commands are echoed by fancysendall() in onpromptr() in case of a prompt from the game, otherwise echo them right away if from a forced svo.make_gnomes_work()
    if not sk.processing_prompt then svo.fancysendall() end
    send = svo.oldsend
    conf.batch = oldbatch
  else
    svo.doaction(find_highest_action(action_list))
  end
  sk.gnomes_are_working = false

  signals.sysdatasendrequest:unblock(cnrl.processusercommand)
end

-- default is async
signals.aeony:connect(function()
  if sys.sync then
    svo.make_gnomes_work = svo.make_gnomes_work_sync
  else
    svo.make_gnomes_work = svo.make_gnomes_work_async
  end
end)
sk.checkaeony()
signals.aeony:emit()

function svo.send_in_the_gnomes()
  -- at first, deal with lifevision.
  svo.lifevision.validate()
  signals.after_lifevision_processing:emit()

  svo.make_gnomes_work()
end

function svo.update_rift_view()
  local status, msg = pcall(function () svo.mm_create_riftlabel() end)

  if not status then error(msg) end
end

-- retrieve all lines until the last prompt, not including it
function svo.sk.getuntilprompt()
  -- lastpromptnumber would include the prompt, -1 doesn't
  return getLines(svo.lastpromptnumber+1, getLastLineNumber("main"))
end

function svo.sk.makewarnings()
  svo.sk.warnings = {
    lowwillpower = {
      time = 30,
      msg = "Warning: your <253,63,73>willpower is too low"..svo.getDefaultColor().."! Need to regen some - otherwise you can't fight well (no clot, focus, and so on)."
    },
    somewhatreavable = {
      time = 10,
      msg = "Warning: you have two humours - an Alchemists <253,63,73>Reave"..svo.getDefaultColor().." will take 10s",
    },
    nearlyreavable = {
      time = 5,
      msg = "Warning: you have three humours - an Alchemists <253,63,73>Reave"..svo.getDefaultColor().." will take 8s",
    },
    reavable = {
      time = 5,
      msg = "Warning: you have all four humours - an Alchemists <253,63,73>Reave"..svo.getDefaultColor().." will only take 4s",
    },
    dismemberable = {
      time = 5,
      msg = "Warning: you're bound and impaled - you can be instakilled! (dismember)"
    },
    cantclotmana = {
      time = 10,
      msg = "Going temporarily pause clotting your mana bleeding, your health is below corruptedhealthmin"
    },
    golemdestroyable = {
      time = 5,
      msg = "Warning: your flesh is melting - you can be instakilled! (golem destroy)"
    },
    pulpable = {
      time = 5,
      msg = "Warning: prone and serious concussion - you can be installed! (pulp)"
    },
    badaeon = {
      time = 5,
      msg = function()
        svo.echof("Warning: your aeon situation is looking bad, you might want to %swalk out%s",
          (not conf.blockcommands and '' or "tsc off and "),
          (conf.org == "Ashtan" and " and ask for an empress") or
          (conf.org == "Targossas" and " and ask for a deliver") or
          (conf.org == "Cyrene" and " and ask for a deliver") or
          ""
        )
      end
    }
  }

  if conf.curemethod == "transonly" then
    sk.warnings.noelmid = {
      time = 20,
      msg = "Warning: need to use your <31,31,153>cinnabar"..svo.getDefaultColor().." pipe and you don't have one!",
    }
    sk.warnings.novalerianid = {
      time = 20,
      msg = "Warning: need to use your <31,31,153>realgar"..svo.getDefaultColor().." pipe and you don't have one!",
    }
    sk.warnings.noskullcapid = {
      time = 20,
      msg = "Warning: need to use your <31,31,153>malachite"..svo.getDefaultColor().." pipe and you don't have one!",
    }
    sk.warnings.emptyvalerianpipe = {
      time = 10,
      msg = "Warning: need to refill your <31,31,153>realgar"..svo.getDefaultColor().." pipe and it's empty! Don't chase balance for a bit",
    }
    sk.warnings.emptyvalerianpipenorefill = {
      time = 10,
      msg = "Warning: need to refill your <31,31,153>realgar"..svo.getDefaultColor().." pipe, it's empty, but can't due to blocking afflictions :(",
    }
  elseif conf.curemethod == "preferconc" then
    sk.warnings.noelmid = {
      time = 20,
      msg = "Warning: need to use your <31,31,153>elm"..svo.getDefaultColor().."/<31,31,153>cinnabar"..svo.getDefaultColor().." pipe and you don't have one!",
    }
    sk.warnings.novalerianid = {
      time = 20,
      msg = "Warning: need to use your <31,31,153>valerian"..svo.getDefaultColor().."/<31,31,153>realgar"..svo.getDefaultColor().." pipe and you don't have one!",
    }
    sk.warnings.noskullcapid = {
      time = 20,
      msg = "Warning: need to use your <31,31,153>skullcap"..svo.getDefaultColor().."/<31,31,153>malachite"..svo.getDefaultColor().." pipe and you don't have one!",
    }
    sk.warnings.emptyvalerianpipe = {
      time = 10,
      msg = "Warning: need to refill your <31,31,153>valerian"..svo.getDefaultColor().."/<31,31,153>realgar"..svo.getDefaultColor().." pipe and it's empty! Don't chase balance for a bit",
    }
    sk.warnings.emptyvalerianpipenorefill = {
      time = 10,
      msg = "Warning: need to refill your <31,31,153>valerian"..svo.getDefaultColor().."/<31,31,153>realgar"..svo.getDefaultColor().." pipe, it's empty, but can't due to blocking afflictions :(",
    }
  elseif conf.curemethod == "prefertrans" then
    sk.warnings.noelmid = {
      time = 20,
      msg = "Warning: need to use your <31,31,153>cinnabar"..svo.getDefaultColor().."/<31,31,153>elm"..svo.getDefaultColor().." pipe and you don't have one!",
    }
    sk.warnings.novalerianid = {
      time = 20,
      msg = "Warning: need to use your <31,31,153>realgar"..svo.getDefaultColor().."/<31,31,153>valerian"..svo.getDefaultColor().." pipe and you don't have one!",
    }
    sk.warnings.noskullcapid = {
      time = 20,
      msg = "Warning: need to use your <31,31,153>malachite"..svo.getDefaultColor().."/<31,31,153>skullcap"..svo.getDefaultColor().." pipe and you don't have one!",
    }
    sk.warnings.emptyvalerianpipe = {
      time = 10,
      msg = "Warning: need to refill your <31,31,153>realgar"..svo.getDefaultColor().."/<31,31,153>valerian"..svo.getDefaultColor().." pipe and it's empty! Don't chase balance for a bit",
    }
    sk.warnings.emptyvalerianpipenorefill = {
      time = 10,
      msg = "Warning: need to refill your <31,31,153>realgar"..svo.getDefaultColor().."/<31,31,153>valerian"..svo.getDefaultColor().." pipe, it's empty, but can't due to blocking afflictions :(",
    }
  else
    sk.warnings.noelmid = {
        time = 20,
        msg = "Warning: need to use your <31,31,153>elm"..svo.getDefaultColor().." pipe and you don't have one!",
      }
    sk.warnings.novalerianid = {
      time = 20,
      msg = "Warning: need to use your <31,31,153>valerian"..svo.getDefaultColor().." pipe and you don't have one!",
    }
    sk.warnings.noskullcapid = {
      time = 20,
      msg = "Warning: need to use your <31,31,153>skullcap"..svo.getDefaultColor().." pipe and you don't have one!",
    }
    sk.warnings.emptyvalerianpipe = {
      time = 10,
      msg = "Warning: need to refill your <31,31,153>valerian"..svo.getDefaultColor().." pipe and it's empty! Don't chase balance for a bit",
    }
    sk.warnings.emptyvalerianpipenorefill = {
      time = 10,
      msg = "Warning: need to refill your <31,31,153>valerian"..svo.getDefaultColor().." pipe, it's empty, but can't due to blocking afflictions :(",
    }
  end
end

signals.systemstart:add_post_emit(sk.makewarnings)
signals.orgchanged:add_post_emit(sk.makewarnings)
signals.curemethodchanged:connect(sk.makewarnings)

svo.sk.warn = function (what)
  if sk.warnings[what].warned then return end

  tempTimer(sk.warnings[what].time, function() sk.warnings[what].warned = false end)
  sk.warnings[what].warned = true

  moveCursorEnd("main")
  echo("\n")

  if type(sk.warnings[what].msg) == 'function' then
    sk.warnings[what].msg()
  else svo.echof(sk.warnings[what].msg) end

  echo("\n")
end

sk.retardation_count = 0
function svo.sk.retardation_symptom()
  if (affs.retardation or affs.aeon or svo.affsp.retardation or svo.affsp.aeon or svo.affsp.truename) then return end

  sk.retardation_count = sk.retardation_count + 1
  if sk.retardation_count >= 4 then
    if not affs.blackout then
      if not conf.aillusion then
        svo.valid.simpleretardation()
        echo"\n" svo.echof("auto-detected retardation.")
      else
        svo.checkaction(svo.dict.checkslows.aff, true)
        svo.lifevision.add(svo.actions.checkslows_aff.p, nil, "retardation")
        echo"\n" svo.echof("Maybe we're in retardation - checking it.")
      end
    else
      svo.valid.simpleunknownany(conf.unknownany)
      echo"\n" svo.echof("auto-detection aeon or retardation (going to diagnose to check which)")
    end
    sk.retardation_count = 0
    return
  end

  tempTimer(svo.syncdelay() + sys.wait * 3, function ()
    sk.retardation_count = sk.retardation_count - 1
    if sk.retardation_count < 0 then sk.retardation_count = 0 end
  end)
end

sk.stupidity_count = 0
function svo.sk.stupidity_symptom()

  if conf.serverside then return end

  if affs.stupidity then return end

  sk.stupidity_count = sk.stupidity_count + 1

  if sk.stupidity_count >= 3 then
    svo.valid.simplestupidity()
    echo"\n" svo.echof("auto-detected stupidity.")
    sk.stupidity_count = 0
    return
  end

  tempTimer(svo.syncdelay() + 2, function ()
    sk.stupidity_count = sk.stupidity_count - 1
    if sk.stupidity_count < 0 then sk.stupidity_count = 0 end
  end)
end

sk.illness_constitution_count = 0
function svo.sk.illness_constitution_symptom()
  if not defc.constitution then return end
  if conf.serverside then return end

  if affs.illness_constitution then return end

  sk.illness_constitution_count = sk.illness_constitution_count + 1

  if sk.illness_constitution_count >= 2 then
    svo.valid.simplehypochondria()

    echo"\n" svo.echof("auto-detected hypochondria.")

    sk.illness_constitution_count = 0
    return
  end

  tempTimer(svo.syncdelay() + sys.wait * 3, function ()
    sk.illness_constitution_count = sk.illness_constitution_count - 1
    if sk.illness_constitution_count < 0 then sk.illness_constitution_count = 0 end
  end)
end

sk.transfixed_count = 0
function svo.sk.transfixed_symptom()
  if affs.transfixed then return end
  if conf.serverside then return end

  if affs.transfixed then return end

  sk.transfixed_count = sk.transfixed_count + 1

  if sk.transfixed_count >= 2 then
    svo.valid.simpletransfixed()

    -- supress echo when got hit with it before ai went off
    if not svo.affsp.transfixed then
      echo"\n" svo.echof("auto-detected transfix.")
    end
    sk.transfixed_count = 0
    return
  end

  tempTimer(svo.syncdelay() + sys.wait * 3, function ()
    sk.transfixed_count = sk.transfixed_count - 1
    if sk.transfixed_count < 0 then sk.transfixed_count = 0 end
  end)
end

sk.stun_count = 0
function svo.sk.stun_symptom()
  if affs.stun then return end

  sk.stun_count = sk.stun_count + 1

  if sk.stun_count >= 3 then
    svo.valid.simplestun()
    echo"\n" svo.echof("auto-detected stun.")
    sk.stun_count = 0
    return
  end

  tempTimer(svo.syncdelay() + sys.wait * 2, function ()
    sk.stun_count = sk.stun_count - 1
    if sk.stun_count < 0 then sk.stun_count = 0 end
  end)
end

sk.impale_count = 0
function svo.sk.impale_symptom()
  if conf.serverside then return end

  if affs.impale then return end

  sk.impale_count = sk.impale_count + 1

  if sk.impale_count >= 2 then
    svo.valid.simpleimpale()
    echo"\n" svo.echof("auto-detected impale.")
    sk.impale_count = 0
    return
  end

  tempTimer(svo.syncdelay() + sys.wait * 2, function ()
    sk.impale_count = sk.impale_count - 1
    if sk.impale_count < 0 then sk.impale_count = 0 end
  end)
end

sk.aeon_count = 0
function svo.sk.aeon_symptom()
  if affs.aeon then return end

  sk.aeon_count = sk.aeon_count + 1

  if sk.aeon_count >= 2 then
    svo.valid.simpleaeon()
    defs.lost_speed()
    echo"\n" svo.echof("auto-detected aeon.")
    sk.aeon_count = 0
    return
  end

  tempTimer(svo.syncdelay() + sys.wait * 2, function ()
    sk.aeon_count = sk.aeon_count - 1
    if sk.aeon_count < 0 then sk.aeon_count = 0 end
  end)
end

sk.paralysis_count = 0
function svo.sk.paralysis_symptom()
  if conf.serverside then return end

  if affs.paralysis then return end

  sk.paralysis_count = sk.paralysis_count + 1

  if sk.paralysis_count >= 2 then
    svo.valid.simpleparalysis()
    echo"\n" svo.echof("auto-detected paralysis.")
    sk.paralysis_count = 0
    return
  end

  tempTimer(svo.syncdelay() + sys.wait * 2, function ()
    sk.paralysis_count = sk.paralysis_count - 1
    if sk.paralysis_count < 0 then sk.paralysis_count = 0 end
  end)
end

sk.haemophilia_count = 0
function svo.sk.haemophilia_symptom()
 if affs.haemophilia then return end

  sk.haemophilia_count = sk.haemophilia_count + 1

  if sk.haemophilia_count >= 2 then
    svo.valid.simplehaemophilia()
    echo"\n" svo.echof("haemophilia seems to be real.")
    sk.haemophilia_count = 0
    return
  end

  -- special # 1 - so haemophilia illusions 'can't' happen within 1s
  tempTimer(svo.syncdelay() + 1, function ()
    sk.haemophilia_count = sk.haemophilia_count - 1
    if sk.haemophilia_count < 0 then sk.haemophilia_count = 0 end
  end)
end

sk.webbed_count = 0
function svo.sk.webbed_symptom()
  if conf.serverside then return end

  if affs.webbed then return end

  sk.webbed_count = sk.webbed_count + 1
  if sk.webbed_count >= 2 then
    svo.valid.simplewebbed()
    echo"\n" svo.echof("auto-detected web.")
    sk.webbed_count = 0
    return
  end

  tempTimer(svo.syncdelay() + sys.wait * 2, function ()
    sk.webbed_count = sk.webbed_count - 1
    if sk.webbed_count < 0 then sk.webbed_count = 0 end
  end)
end

sk.roped_count = 0
function svo.sk.roped_symptom()
  if conf.serverside then return end

  if affs.roped then return end

  sk.roped_count = sk.roped_count + 1

  if sk.roped_count >= 2 then
    svo.valid.simpleroped()
    echo"\n" svo.echof("auto-detected roped.")
    sk.roped_count = 0
    return
  end

  tempTimer(svo.syncdelay() + sys.wait * 2, function ()
    sk.roped_count = sk.roped_count - 1
    if sk.roped_count < 0 then sk.roped_count = 0 end
  end)
end

sk.impaled_count = 0
function svo.sk.impaled_symptom()
  if conf.serverside then return end

  if affs.impale then return end

  sk.impaled_count = sk.impaled_count + 1

  if sk.impaled_count >= 2 then
    svo.valid.simpleimpale()
    echo"\n" svo.echof("auto-detected impale.")
    sk.impaled_count = 0
    return
  end

  tempTimer(svo.syncdelay() + sys.wait * 2, function ()
    sk.impaled_count = sk.impaled_count - 1
    if sk.impaled_count < 0 then sk.impaled_count = 0 end
  end)
end


sk.hypochondria_count = 0
function svo.sk.hypochondria_symptom()
  if svo.find_until_last_paragraph(line, "exact") or affs.hypochondria then return end

  sk.hypochondria_count = sk.hypochondria_count + 1

  if sk.hypochondria_count >= 3 then
    svo.valid.simplehypochondria()
    sk.hypochondria_count = 0
  end

  tempTimer(12, function ()
    sk.hypochondria_count = sk.hypochondria_count - 1
    if sk.hypochondria_count < 0 then sk.hypochondria_count = 0 end
  end)
end

sk.unparryable_count = 0
function svo.sk.unparryable_symptom()
  if conf.aillusion and svo.paragraph_length ~= 1 and not svo.find_until_last_paragraph("Your scabbard does not contain your blade, Warrior.", "exact") and not svo.find_until_last_paragraph("You have not positioned a scabbard on your hip, Warrior.", "exact") then
    svo.ignore_illusion("not first") return
  elseif affs.unparryable then return end

  sk.unparryable_count = sk.unparryable_count + 1

  if sk.unparryable_count >= 2 then
    sk.cant_parry()
    sk.unparryable_count = 0
    return
  end

  tempTimer(svo.syncdelay() + sys.wait * 2, function ()
    sk.unparryable_count = sk.unparryable_count - 1
    if sk.unparryable_count < 0 then sk.unparryable_count = 0 end
  end)
end

svo.updateaffcount = function (which)
  svo.affl[which.name].count = which.count

  raiseEvent("svo updated aff", which.name, "count", which.count)
end


-- adds an affliction for the system to be tracking (ie - you are afflicted with it)
-- does not mess with aff.<affliction>s table if the aff is already registered.
-- this is the old internal 'addaff' function that Svof used when it was out of Mudlet
local old_internal_addaff = function (new_aff)
  if not new_aff then svo.debugf("no new, log: %s", debug.traceback()) end
  if affs[new_aff.name] then return end

  local name = new_aff.name

  svo.affs[name] = {
    p = new_aff,
    sw = new_aff.sw or createStopWatch()
  }
  startStopWatch(affs[name].sw)

  -- call the onadded handler if any
  if svo.dict[name].onadded then svo.dict[name].onadded() end

  if not svo.affl[name] then
    svo.affl[name] = { sw = affs[name].sw }
    signals.svogotaff:emit(name)
    raiseEvent("svo got aff", name)
  end
end
-- this is the old public 'addaff' function that Svof enabled when it was out of Mudlet
local old_public_addaff = function (new_aff)
  svo.assert(type(new_aff) == "string", "svo.addaff: what aff would you like to add? name must be a string")
  svo.assert(svo.dict[new_aff] and svo.dict[new_aff].aff, "svo.addaff: "..new_aff.." isn't a known aff name")

  if affs[new_aff] then
    return false
  else
    if svo.dict[new_aff].aff and svo.dict[new_aff].aff.forced then
      svo.dict[new_aff].aff.forced()
    elseif svo.dict[new_aff].aff then
      svo.dict[new_aff].aff.oncompleted()
    else
      old_internal_addaff(svo.dict[new_aff])
    end

    signals.after_lifevision_processing:unblock(cnrl.checkwarning)
    sk.checkaeony()
    signals.aeony:emit()
    svo.codepaste.badaeon()

    return true
  end
end
svo.addaff = function(aff_string_or_table)
  if type(aff_string_or_table) == "table" then
    old_internal_addaff(aff_string_or_table)
  else
    old_public_addaff(aff_string_or_table)
  end
end
svo.addaffdict = old_public_addaff

-- old internal version of removeaff
svo.rmaff = function (old)
  if type(old) == "table" then
    for _,aff in pairs(old) do
      svo.rmaff(aff)
    end
    return
  end

  if not affs[old] then return end

  if svo.affl[old] then
    svo.affl[old] = nil
    signals.svolostaff:emit(old)
    raiseEvent("svo lost aff", old)
  end

  -- rmaff can be called on affs that don't exist, that's valid
  local sw = (affs[old] and affs[old].sw or nil)
  affs[old] = nil

  -- call the onremoved handler if any. Should be called after affs is cleaned, because scripts here reply on the 'current' state
  if svo.dict[old].onremoved then
    svo.debugf("calling onremoved for %s", old)
    svo.dict[old].onremoved()
  end

  if conf.showafftimes and sw then
    svo.echoafftime(stopStopWatch(sw), old)
  end
end

-- public version of removeaff. The two should be merged.
svo.removeaff = function (which)
  svo.assert(type(which) == "string", "svo.removeaff: what aff would you like to remove? name must be a string")
  svo.assert(svo.dict[which] and svo.dict[which].aff, "svo.removeaff: "..which.." isn't a known aff name")

  local removed = false
  if svo.lifevision.l[which.."_aff"] then
    svo.lifevision.l:set(which.."_aff", nil)
    removed = true
  end

  if affs[which] then
    if svo.dict[which].gone then
      svo.dict[which].gone.oncompleted()
    else
      svo.removeaff(which)
    end

    removed = true
  end

  signals.after_lifevision_processing:unblock(cnrl.checkwarning)
  sk.checkaeony()
  signals.aeony:emit()

  return removed
end

svo.removeafflevel = function (which, amount, keep)
  svo.assert(type(which) == "string", "svo.removeafflevel: what aff would you like to remove? name must be a string")
  svo.assert(svo.dict[which] and svo.dict[which].aff, "svo.removeafflevel: "..which.." isn't a known aff name")

  local removed = false
  if svo.lifevision.l[which.."_aff"] then
    svo.lifevision.l:set(which.."_aff", nil)
    removed = true
  end

  if affs[which] then
    if svo.dict[which].gone then
      svo.dict[which].gone.general_cure(amount or 1, not keep)
    else
      svo.removeaff(which)
    end

    removed = true
  end

  signals.after_lifevision_processing:unblock(cnrl.checkwarning)
  sk.checkaeony()
  signals.aeony:emit()

  return removed
end

-- externally available as svo.prompttrigger
sk.onpromptfuncs = {}
function sk.onprompt_beforeaction_add(name, what)
  sk.onpromptfuncs[name] = what
end

sk.onprompt_beforeaction_do = function()
  for name, func in pairs(sk.onpromptfuncs) do
    local s,m = pcall(func)
    if not s then
    svo.debugf("sk.onprompt_beforeaction_do error from %s: %q", name, m)
      echoLink("(e!)", "echo([[The problem was: "..tostring(name).." prompttrigger failed to work: "..string.format("%q", m).."]])", 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw if this isn\'t your own function.')
    end
  end
  sk.onpromptfuncs = {}
end
signals.after_lifevision_processing:connect(sk.onprompt_beforeaction_do)

-- externally available as svo.aiprompt
sk.onpromptaifuncs = {}
function sk.onprompt_beforelifevision_add(name, what)
  sk.onpromptaifuncs[name] = what
end

sk.onprompt_beforelifevision_do = function()
  for name, func in pairs(sk.onpromptaifuncs) do
    local s,m = pcall(func)
    if not s then
      echoLink("(e!)", "echo([[The problem was: "..tostring(name).." aiprompt failed to work: "..string.format("%q", m).."]])", 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw if this isn\'t your own function.')
    end
  end
  sk.onpromptaifuncs = {}
end
signals.before_prompt_processing:connect(sk.onprompt_beforelifevision_do)

svo.lostbal_tree = function()
  if bals.tree then tempTimer(0, [[raiseEvent("svo lost balance", "tree")]]) end
  bals.tree = false
  svo.startbalancewatch("tree")
  if sys.treetimer then killTimer(sys.treetimer) end
  -- if conf.treebalance is set, use that - otherwise use the defaults as setup by conf.efficiency + hardcoded numbers
  local timeout
  if not conf.treebalance or conf.treebalance == 0 then
    timeout = conf.efficiency and (16+svo.getping()) or (40+svo.getping())
  else
    timeout = conf.treebalance
  end
  if affs.ninkharsag then timeout = timeout + 10 end

  sys.treetimer = tempTimer(timeout, [[svo.bals.tree = true;
    svo.echof("Can touch tree again.")
    svo.showprompt()
    raiseEvent("svo got balance", "tree")]])
end

svo.lostbal_focus = function()
  if not bals.focus then return end

  bals.focus = false
  svo.startbalancewatch("focus")
  sk.focustick = sk.focustick + 1
  local oldfocustick = sk.focustick

  -- respect conf.ai_resetfocusbal while setting a minimum of 8s
  local timeout = conf.ai_resetfocusbal
  if affs.rixil then
    if conf.ai_resetfocusbal < 5 then
      timeout = conf.ai_resetfocusbal + 5
    else
      timeout = 8
    end
  end

  tempTimer(timeout, function ()
    if not bals.focus and sk.focustick == oldfocustick then
      bals.focus = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "focus")
    end
  end)

  raiseEvent("svo lost balance", "focus")
end

svo.lostbal_shrugging = function()
  if not bals.shrugging then return end

  bals.shrugging = false
  svo.startbalancewatch("shrugging")
  sk.shruggingtick = sk.shruggingtick + 1
  local oldshruggingtick = sk.shruggingtick

  tempTimer(10+svo.getping(), function ()
    if not bals.shrugging and sk.shruggingtick == oldshruggingtick then
      bals.shrugging = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "shrugging")
    end
  end)

  raiseEvent("svo lost balance", "shrugging")
end

svo.lostbal_fitness = function()
  if not bals.fitness then return end

  bals.fitness = false
  svo.startbalancewatch("fitness")
  sk.fitnesstick = sk.fitnesstick + 1
  local oldfitnesstick = sk.fitnesstick

  -- takes 9s to recover
  tempTimer(15+svo.getping(), function ()
    if not bals.fitness and sk.fitnesstick == oldfitnesstick then
      bals.fitness = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "fitness")
    end
  end)

  raiseEvent("svo lost balance", "fitness")
end

svo.lostbal_rage = function()
  if not bals.rage then return end

  bals.rage = false
  svo.startbalancewatch("rage")
  sk.ragetick = sk.ragetick + 1
  local oldragetick = sk.ragetick

  -- takes 9s to recover
  tempTimer(15+svo.getping(), function ()
    if not bals.rage and sk.ragetick == oldragetick then
      bals.rage = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "rage")
    end
  end)

  raiseEvent("svo lost balance", "rage")
end

svo.lostbal_voice = function()
  if not bals.voice then return end

  bals.voice = false
  svo.startbalancewatch("voice")
  sk.voicetick = sk.voicetick + 1
  local oldvoicetick = sk.voicetick

  tempTimer(10+svo.getping(), function ()
    if not bals.voice and sk.voicetick == oldvoicetick then
      bals.voice = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "voice")
    end
  end)

  raiseEvent("svo lost balance", "voice")
end

svo.lostbal_sip = function()
  bals.sip = false
  svo.startbalancewatch("sip")
  sk.siptick = sk.siptick + 1
  local oldsiptick = sk.siptick

  -- multiply by 2 if we have addiction
  local lostbalance = conf.ai_resetsipbal
  if affs.addiction then lostbalance = lostbalance * 2 end
  -- add .5s for earth disrupt delaying it
  if affs.earthdisrupt then lostbalance = lostbalance + 0.5 end

  tempTimer(lostbalance, function ()
    if not bals.sip and sk.siptick == oldsiptick then
      bals.sip = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "sip")
    end
  end)

  raiseEvent("svo lost balance", "sip")
end

svo.lostbal_herb = function(noeffect, mickey)
  bals.herb = false
  svo.startbalancewatch("herb")
  sk.herbtick = sk.herbtick + 1
  local oldherbtick = sk.herbtick

  tempTimer(conf.ai_resetherbbal, function ()
    if not bals.herb and sk.herbtick == oldherbtick then
      bals.herb = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "herb")
    end
  end)

  watch["bal_herb"] = watch["bal_herb"] or createStopWatch()
  startStopWatch(watch["bal_herb"])

  -- voided gives us the balance quick enough
  if (affs.voided and noeffect) then raiseEvent("svo lost balance", "herb") return end

  watch.herb_block = watch.herb_block or createStopWatch()
  startStopWatch(watch.herb_block)

  if sk.blockherbbal then killTimer(sk.blockherbbal) end
  -- mickey steals bal for .8s
  sk.blockherbbal = tempTimer((mickey and .5 or conf.ai_minherbbal), function ()
    sk.blockherbbal = nil
  end)

  raiseEvent("svo lost balance", "herb")
end

svo.lostbal_salve = function()
  bals.salve = false
  svo.startbalancewatch("salve")
  sk.salvetick = sk.salvetick + 1
  local oldsalvetick = sk.salvetick

  tempTimer(conf.ai_resetsalvebal, function ()
    if not bals.salve and sk.salvetick == oldsalvetick then
      bals.salve = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "salve")
    end
  end)

  raiseEvent("svo lost balance", "salve")
end

svo.lostbal_moss = function()
  bals.moss = false
  svo.startbalancewatch("moss")
  sk.mosstick = sk.mosstick + 1
  local oldmosstick = sk.mosstick

  tempTimer(conf.ai_resetmossbal, function ()
    if not bals.moss and sk.mosstick == oldmosstick then
      bals.moss = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "moss")
    end
  end)

  raiseEvent("svo lost balance", "moss")
end

svo.lostbal_purgative = function()
  bals.purgative = false
  svo.startbalancewatch("purgative")
  sk.purgativetick = sk.purgativetick + 1
  local oldpurgativetick = sk.purgativetick

  tempTimer(conf.ai_resetpurgativebal, function ()
    if not bals.purgative and sk.purgativetick == oldpurgativetick then
      bals.purgative = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "purgative")
    end
  end)

  raiseEvent("svo lost balance", "purgative")
end

svo.lostbal_smoke = function()
  bals.smoke = false
  svo.startbalancewatch("smoke")
  sk.smoketick = sk.smoketick + 1
  local oldsmoketick = sk.smoketick

  tempTimer(conf.ai_resetsmokebal, function ()
    if not bals.smoke and sk.smoketick == oldsmoketick then
      bals.smoke = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "smoke")
    end
  end)

  watch["bal_smoke"] = watch["bal_smoke"] or createStopWatch()
  startStopWatch(watch["bal_smoke"])

  raiseEvent("svo lost balance", "smoke")
end

svo.lostbal_dragonheal = function()
  bals.dragonheal = false
  svo.startbalancewatch("dragonheal")
  sk.dragonhealtick = sk.dragonhealtick + 1
  local olddragonhealtick = sk.dragonhealtick

  -- dragonheal bal is quite long, add a bit of variation on it
  tempTimer(conf.ai_resetdragonhealbal+svo.getping(), function ()
    if not bals.dragonheal and sk.dragonhealtick == olddragonhealtick then
      bals.dragonheal = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "dragonheal")
    end
  end)

  raiseEvent("svo lost balance", "dragonheal")
end

if svo.haveskillset('healing') then
svo.lostbal_healing = function()
  if not bals.healing then return end

  bals.healing = false
  svo.startbalancewatch("healing")
  sk.healingtick = sk.healingtick + 1
  local oldhealingtick = sk.healingtick

  tempTimer(conf.ai_resethealingbal, function ()
    if not bals.healing and sk.healingtick == oldhealingtick then
      svo.endbalancewatch("healing")
      bals.healing = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "healing")
    end
  end)

  raiseEvent("svo lost balance", "healing")
end
end

if svo.haveskillset('terminus') then
svo.lostbal_word = function()
  if not bals.word then return end

  bals.word = false
  svo.startbalancewatch("word")
  sk.wordtick = sk.wordtick + 1
  local oldwordtick = sk.wordtick

  tempTimer(17+svo.getping(), function ()
    if not bals.word and sk.wordtick == oldwordtick then
      bals.word = true
      svo.make_gnomes_work()
      raiseEvent("svo got balance", "word")
    end
  end)

  raiseEvent("svo lost balance", "word")
end
end

function sk.doingstuff_inslowmode()
  local result
  for balance,actions in pairs(svo.bals_in_use) do
    if balance ~= "waitingfor" and balance ~= "gone" and balance ~= "aff" and next(actions) then result = select(2, next(actions)) break end
  end
  if result then return true end
end

function sk.checkwillpower()
  if stats.currentwillpower <= 1000 and not sk.lowwillpower then
    sk.lowwillpower = true
    sk.warn("lowwillpower")

    svo.can_usemana = function()
      return (stats.currentmana > sys.manause and stats.currentwillpower >= 100 and not svo.doingaction ("nomana"))
    end

  -- amounts differ so we don't toggle often
  elseif stats.currentwillpower > 1500 and sk.lowwillpower then
    sk.lowwillpower = false

    svo.can_usemana = function()
      return (stats.currentmana > sys.manause and not svo.doingaction ("nomana"))
    end
  end
end

sk.limbnames = {
  rightarm = true,
  leftarm = true,
  leftleg = true,
  rightleg = true,
  torso = true,
  head = true
}

if svo.haveskillset('healing') then
  sk.updatehealingmap = function ()
    sk.healingmap = {}
    if not conf.healingskill then return end

    local healdata = svo.pl.OrderedMap{}
    -- afflictions sorted in order of learning the Healing skillset - so not sort this list!
    -- healdata:set("blind", function() return defc.earth end)
    healdata:set("blindaff", function() return defc.earth end)
    healdata:set("paralysis", function() return defc.fire end)
    -- healdata:set("deaf", function() return defc.air end)
    healdata:set("deafaff", function() return defc.air end)
    -- healdata:set("fear", function() return defc.water end)
    healdata:set("confusion", function() return defc.fire end)
    -- healdata:set("insomnia", function() return defc.air end)
    healdata:set("slickness", function() return defc.earth end)
    healdata:set("stuttering", function() return defc.fire end)
    healdata:set("paranoia", function() return defc.earth and defc.water end)
    healdata:set("shyness", function() return defc.earth end)
    healdata:set("hallucinations", function() return defc.earth end)
    healdata:set("generosity", function() return defc.earth end)
    healdata:set("loneliness", function() return defc.air and defc.water end)
    healdata:set("impatience", function() return defc.fire end)
    healdata:set("unconsciousness", function() return defc.earth and defc.fire end)
    healdata:set("claustrophobia", function() return defc.fire and defc.water end)
    healdata:set("vertigo", function() return defc.earth and defc.fire end)
    healdata:set("sensitivity", function() return defc.earth and defc.fire and defc.water end)
    healdata:set("dizziness", function() return defc.water end)
    healdata:set("crippledrightarm", function() return defc.earth and not affs.mangledrightarm and not affs.mutilatedrightarm and not affs.mangledleftarm and not affs.mutilatedleftarm end)
    healdata:set("crippledleftarm", function() return defc.earth and not affs.mangledleftarm and not affs.mutilatedleftarm and not affs.mangledrightarm and not affs.mutilatedrightarm end)
    healdata:set("dementia", function() return defc.fire end)
    healdata:set("clumsiness", function() return defc.air and defc.water end)
    healdata:set("ablaze", function() return defc.earth and defc.water end)
    healdata:set("recklessness", function() return defc.water end)
    healdata:set("anorexia", function() return defc.earth and defc.air end)
    healdata:set("agoraphobia", function() return defc.air and defc.fire end)
    healdata:set("disloyalty", function() return defc.fire and defc.water end)
    healdata:set("hypersomnia", function() return defc.air and defc.water end)
    healdata:set("darkshade", function() return defc.earth and defc.fire end)
    healdata:set("masochism", function() return defc.air and defc.fire end)
    healdata:set("epilepsy", function() return defc.air and defc.fire end)
    healdata:set("asthma", function() return defc.air end)
    healdata:set("stupidity", function() return defc.water end)
    healdata:set("illness", function() return defc.earth and defc.water end)
    healdata:set("weakness", function() return defc.fire end)
    healdata:set("haemophilia", function() return defc.water end)
    healdata:set("crippledrightleg", function() return defc.air and defc.earth and not affs.mangledrightleg and not affs.mutilatedrightleg and not affs.mangledleftleg and not affs.mutilatedleftleg end)
    healdata:set("crippledleftleg", function() return defc.air and defc.earth and not affs.mangledleftleg and not affs.mutilatedleftleg and not affs.mangledrightleg and not affs.mutilatedrightleg end)
    healdata:set("hypochondria", function() return defc.earth and defc.air and defc.fire and defc.water end)

    local svonames = {
      ablaze          = "burning",
      blindness       = "blind",
      crippledleftarm = "arms",
      crippledleftleg = "legs",
      deafness        = "deaf",
      illness         = "vomiting",
      weakness        = "weariness",
    }

    -- setup a map of afflictions that we can cure - key is aff, value is the proper aura cure as a string / table if it's a regen
    for aff, afft in healdata:iter() do
      sk.healingmap[aff] = afft

      if aff == conf.healingskill or (svonames[aff] and svonames[aff] == conf.healingskill) then break end
    end

  end
  signals.healingskillchanged:connect(sk.updatehealingmap)
  signals.systemstart:connect(sk.updatehealingmap)
end

function svo.sk.increase_lagconf()
  -- don't go above 3, 4 is reserved for do really
  if conf.lag >= 3 then return end

  if sk.lag_tickedonce and not sk.increasedlag then
    conf.lag = conf.lag+1
    echo"\n" svo.echof("auto-increased the lag tolerance level to %d.", conf.lag)
    raiseEvent("svo config changed", "lag")
    sk.increasedlag = true
    cnrl.update_wait()

    if sys.reset_laglevel then killTimer(sys.reset_laglevel) end
    sys.reset_laglevel = tempTimer(30, function ()
      if not svo.wait_tbl[conf.lag-1] then return end

      local variance = getNetworkLatency()*2+getNetworkLatency()
      for i = 0, #svo.wait_tbl do
        if variance <= svo.wait_tbl[i].n then
          conf.lag = i
          cnrl.update_wait()
          echo"\n" svo.echof("automatically reset lag tolerance down to %d.", conf.lag)
          raiseEvent("svo config changed", "lag")
          break
        end
      end
    end)
  else
    sk.lag_tickedonce = tempTimer(10, function () sk.lag_tickedonce = nil; sk.increasedlag = true end)
  end
end

if svo.haveskillset('metamorphosis') then
function svo.sk.clearmorphs()
  local morphs
  if svo.me.class == "Druid" then
    morphs = {"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra"}
  else
    morphs = {"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm"}
  end
  for _, morph in ipairs(morphs) do
    if defc[morph] then
      defences.lost(morph)
    end
  end
end

function svo.sk.inamorph()
  local t
if svo.me.class == "Druid" then
  t = {"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra"}
else
  t = {"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm"}
end
  for i = 1, #t do
    if defc[t[i]] then return true end
  end

  return false
end

function svo.sk.validmorphskill(name)
  local morphs
if svo.me.class == "Druid" then
  morphs = {"squirrel", "powers", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "bear", "bonding", "nightingale", "elephant", "transmorph", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "affinity", "wyvern", "hydra", "truemorph"}
else
  morphs = {"squirrel", "powers", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "bonding", "nightingale", "elephant", "transmorph", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "affinity", "truemorph"}
end

  for _, morph in ipairs(morphs) do
    if name:lower() == morph then return true end
  end

  return false
end

function svo.sk.inamorphfor(defence)
  if not sk.morphsforskill[defence] then return false end

  for i = 1, #sk.morphsforskill[defence] do
    if defc[sk.morphsforskill[defence][i]] then return true end
  end

  return false
end

function svo.sk.updatemorphskill()
  sk.morphsforskill = {}
if svo.me.class == "Druid" then
  sk.morphsforskill.elusiveness = { "hyena", "wolverine" }
else
  sk.morphsforskill.elusiveness = { "basilisk", "hyena", "wolverine", "jaguar" }
end
if svo.me.class == "Druid" then
  sk.morphsforskill.fitness = { "wolf", "cheetah", "hyena", "elephant", "wyvern", "hydra" }
else
  sk.morphsforskill.fitness = { "wolf", "cheetah", "hyena", "elephant", "jaguar"}
end
if svo.me.class == "Druid" then
  sk.morphsforskill.flame = { "wyvern" }
else
  sk.morphsforskill.flame = { "wyvern", "basilisk" }
end
  sk.morphsforskill.lyre = { "nightingale" }
if svo.me.class == "Druid" then
  sk.morphsforskill.nightsight = { "wildcat", "wolf", "cheetah", "owl", "hyena", "condor", "wolverine", "eagle", "icewyrm", "wyvern", "hydra" }
else
  sk.morphsforskill.nightsight = { "wildcat", "wolf", "cheetah", "owl", "hyena", "condor", "wolverine", "jaguar", "eagle", "icewyrm" }
end
  sk.morphsforskill.rest = { "sloth" }
if svo.me.class == "Druid" then
  sk.morphsforskill.resistance = { "hydra" }
else
  sk.morphsforskill.resistance = { "basilisk", "jaguar" }
end
if svo.me.class == "Druid" then
  sk.morphsforskill.stealth = { "hyena" }
else
  sk.morphsforskill.stealth = { "basilisk", "hyena", "jaguar" }
end
if svo.me.class == "Druid" then
  sk.morphsforskill.temperance = { "icewyrm", "wyvern", "hydra" }
else
  sk.morphsforskill.temperance = { "icewyrm" }
end
if svo.me.class == "Druid" then
  sk.morphsforskill.vitality = { "bear", "elephant", "icewyrm", "wyvern", "hydra" }
else
  sk.morphsforskill.vitality = { "bear", "elephant", "jaguar", "icewyrm" }
end

  sk.skillmorphs = {}
  for skill, t in pairs(sk.morphsforskill) do
    for _, morph in ipairs(t) do
      sk.skillmorphs[morph] = sk.skillmorphs[morph] or {}
      sk.skillmorphs[morph][skill] = true
    end
  end

  local newskillmorphs = {}
  local morphlist
if svo.me.class == "Druid" then
  morphlist = {"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "bear", "nightingale", "elephant", "wolverine", "eagle", "gorilla", "icewyrm", "wyvern", "hydra"}
else
  morphlist = {"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm"}

end
  for _, morph in pairs(morphlist) do
    newskillmorphs[morph] = sk.skillmorphs[morph]
    if svo.conf.morphskill == morph then break end
  end
  sk.skillmorphs = newskillmorphs

  sk.morphsforskill = {}
  for morph, t in pairs(sk.skillmorphs) do
    for def, _ in pairs(t) do
      sk.morphsforskill[def] = sk.morphsforskill[def] or {}
      sk.morphsforskill[def][#sk.morphsforskill[def]+1] = morph
    end
  end

  do -- sort morph names in sk.morphsforskill such that the first one has the most morphs
    local morphdefs = {}
    for morph, t in pairs(sk.skillmorphs) do
      morphdefs[morph] = table.size(t)
    end

    for _, t in pairs(sk.morphsforskill) do
      table.sort(t, function(a,b) if morphdefs[a] and morphdefs[b] then return morphdefs[a] > morphdefs[b] end end)
    end
  end
end
  signals.morphskillchanged:connect(sk.updatemorphskill)
  signals.systemstart:connect(sk.updatemorphskill)
end

signals.gmcpcharitemslist:connect(function ()
  if not gmcp.Char.Items.List.location then svo.debugf("(GMCP problem) location field is missing from Achaea's response.") return end
  if not sk.inring or gmcp.Char.Items.List.location ~= "inv" then return end

  local hadsomething = {}
  for _, t in pairs(gmcp.Char.Items.List.items) do
    if t.attrib and t.attrib:find("r", 1, true) then

      -- see if we can optimize groupables with 'inr all <type>', making it easier count as well: handle groups first
      if t.name and t.name:find("a group of", 1, true) then
        -- function to scan plurals table
        local check = function(value,input) return input:find("a group of "..value) end

        -- check herbs table
        local found_plural = next(svo.pl.tablex.map(check, rift.herbs_plural, t.name or ""))
        -- check other riftable items table
        found_plural = found_plural or next(svo.pl.tablex.map(check, rift.items_plural, t.name or ""))

        if found_plural and not hadsomething[found_plural] then
          svo.sendc("inr all "..found_plural, false)
          hadsomething[found_plural] = true
        elseif not found_plural and not hadsomething[t.id] then
          svo.sendc("inr "..t.id, false)
          hadsomething[t.id] = true
        end

      -- singular herb items that we know of
      elseif t.name and rift.herbs_singular[t.name] and not hadsomething[rift.herbs_singular[t.name]] then
        hadsomething[rift.herbs_singular[t.name]] = true
        svo.sendc("inr all "..rift.herbs_singular[t.name], false)

      -- singular non-herb items
      elseif t.name and rift.items_singular[t.name] and not hadsomething[rift.items_singular[t.name]] then
        hadsomething[rift.items_singular[t.name]] = true
        svo.sendc("inr all "..rift.items_singular[t.name], false)

      -- all the rest
      elseif not rift.items_singular[t.name] and not rift.herbs_singular[t.name] and not hadsomething[t.id] and t.attrib and t.attrib:find("r", 1, true) then
        svo.sendc("inr "..t.id, true)
        hadsomething[t.id] = true
      end
    end
  end

  sk.inring = nil
  if next(hadsomething) then
    svo.echof("Stuffing everything away...")
  else
    svo.echof("There's nothing to stuff away.")
  end
end)

signals.gmcpcharitemslist:connect(function()
  if not sk.retrieving_herbs or gmcp.Char.Items.List.location ~= "room" then return end

  for _, t in pairs(gmcp.Char.Items.List.items) do
    if rift.herbs_singular[t.name] then
      svo.doaddfree("get "..t.id)
    end

    -- tally up rift.herbs_plural items
    for _,l in pairs(rift.herbs_plural) do
      local result = t.name:match(l)
      if result then
        for _ = 1, tonumber(result) do -- getting group # only gets 1 item, have to repeatedly cycle it
          svo.doaddfree("get "..t.id)
        end
      end
    end
  end

  sk.retrieving_herbs = nil
end)

for _, herb in ipairs{"elm", "valerian", "skullcap"} do
  sk[herb.."_smokepuff"] = function ()
    if not conf.arena then
      pipes[herb].puffs = pipes[herb].puffs - 1
      if pipes[herb].puffs < 0 then pipes[herb].puffs = 0 end
    end

    if herb == "valerian" then
      signals.after_lifevision_processing:unblock(cnrl.checkwarning)
    end

    moveCursor(0, getLineNumber()-1)
    moveCursor(#getCurrentLine(), getLineNumber())
    setFgColor(unpack(svo.getDefaultColorNums))
    insertText(string.format(" (%s %s left)", pipes[herb].puffs, pipes[herb].filledwith))
    resetFormat()
    moveCursorEnd()
  end
end

if svo.haveskillset('occultism') then
signals.gmcpcharitemslist:connect(function ()
  if not gmcp.Char.Items.List.location or not gmcp.Char.Items.List.items then svo.debugf("(GMCP problem) location or items field is missing from Achaea's response.") return end

  if gmcp.Char.Items.List.location ~= "inv" then return end

  for _, t in pairs(gmcp.Char.Items.List.items) do
    if t.name then
      if t.name == "a heartstone" then
        defences.got("heartstone")
      elseif t.name == "a simulacrum shaped like "..me.name then
        defences.got("simulacrum")
      end
    end
  end
end)
end

function svo.sk.enable_single_prompt()
  if svo.bottomprompt then svo.bottomprompt:show() end
  svo.bottomprompt = Geyser.MiniConsole:new({
    name="svo.bottomprompt",
    x=0, y="100%",
    width="98%", height="1c",
    fontSize = conf.singlepromptsize or 11
  })
  svo.bottomprompt:setFontSize(conf.singlepromptsize or 11)

  function svo.bottomprompt:reposition()
     local _,height = calcFontSize(conf.singlepromptsize or 11)

     if not svo.bottom_border or svo.bottom_border ~= height then
       svo.bottom_border = height
       tempTimer(0, function() setBorderBottom(height) end)
     end

     moveWindow(self.name, self:get_x(), self:get_y()-(height+(height/3)))
     resizeWindow(self.name, self:get_width(), self:get_height())
  end
  setBackgroundColor("svo.bottomprompt",0,0,0,255)
  svo.bottomprompt:reposition()

  if svo.moveprompt then killTrigger(svo.moveprompt) end
  -- moveprompt = tempRegexTrigger('^', [[
  --   if not isPrompt() then return end
  --   selectCurrentLine()
  --   copy()
  --   clearWindow("svo.bottomprompt")
  --   paste("svo.bottomprompt")
  --   if svo.conf.singlepromptblank then
  --     replace("")
  --   elseif not svo.conf.singlepromptkeep then deleteLine() end
  --   deselect()
  -- ]])
end

function svo.sk.showstatchanges()
  local t = sk.statchanges
  if #t > 0 then
    if conf.singleprompt then
      moveCursor(0, getLineNumber()-1)
      moveCursor(#getCurrentLine(), getLineNumber())
      dinsertText(' <192,192,192>('..table.concat(t, ", ")..'<192,192,192>) ')
    else
      decho('<192,192,192>('..table.concat(t, ", ")..'<192,192,192>) ')
    end

    resetFormat()
    if conf.singleprompt then moveCursorEnd() end
  end
end

-- logic: if something we are wielding does not show up unparryables, then we can wield
function svo.sk.have_parryable()
  me.unparryables = me.unparryables or {}

  for _, item in pairs(me.wielded) do
    if not me.unparryables[item.name] then return true end
  end
end

function svo.sk.cant_parry()
  local t = {}
  me.unparryables = me.unparryables or {}
  for _, item in pairs(me.wielded) do
    if not me.unparryables[item.name] then
      t[#t+1] = item.name
      me.unparryables[item.name] = true
    end
  end

  if #t > 0 then
    echo'\n'

    local lines = {
      "Oh, looks like we can't parry with %s.",
      "Doesn't look like we can parry with %s.",
      "Oops. Can't parry with %s.",
      "And %s won't fly, either.",
      "And %s won't work, either."
    }

    svo.echof(lines[math.random(#lines)], table.concat(t, ' or '))
  end
end

signals.newroom:connect(function ()
  -- don't get tricked by dementia, which does send false gmcp
  -- nor by hidden dementia
  if affs.dementia or affs.unknownany or affs.unknownmental or not conf.autoarena then return end

  local t = sk.arena_areas

  local area = atcp.RoomArea or gmcp.Room.Info.area

  if t[area] and not conf.arena then
    conf.arena = true
    raiseEvent("svo config changed", "arena")
    svo.prompttrigger("arena echo", function()
      local echos = {"Arena mode enabled. Good luck!", "Beat 'em up! Arena mode enabled.", "Arena mode on.", "Arena mode enabled. Kill them all!"}
      svo.itf(echos[math.random(#echos)]..'\n')
    end)
  elseif conf.arena and not t[area] then
    conf.arena = false
    raiseEvent("svo config changed", "arena`")
    tempTimer(0, function()
      local echos = {"Arena mode disabled."}
      svo.echof(echos[math.random(#echos)]..'\n')

      -- the game resets armbals quietly
      if not bals.rightarm then bals.rightarm = true end
      if not bals.leftarm then bals.leftarm = true end
    end)
  end
end)

-- this will get connected on load
sk.check_burrow_pause = function()
  local roomname = _G.gmcp.Room.Info.name

  if not conf.paused and roomname == "Surrounded by dirt" then sk.paused_for_burrow = true; svo.app("on")
  elseif sk.paused_for_burrow and conf.paused and roomname ~= "Surrounded by dirt" and stats.currenthealth > 0 then svo.app("off")
  end
end

function svo.sk.check_shipmode()
  -- failsafe for disabling captain control - since there are a few ways in which you can lose it without an explicit line.
  if conf.shipmode and gmcp.Room.Info.environment ~= "Vessel" then
    svo.config.set("shipmode", "off", true)
  end
end

function svo.balanceful_used()
  return (sys.balanceid == sys.balancetick) and true or false
end

-- getNetworkLatency, with a cap
function svo.getping(caparg)
  local cap = caparg or .500
  local lat = getNetworkLatency()

  return (lat < cap) and lat or cap
end

-- returns true if a curing command was seen in this paragraph
function svo.sk.sawcuring()
  -- don't search the buffer, but set a flag, because people could be gagging the line and buffer search will thus fail
  return sk.sawcuringcommand and true or false
end

function svo.sk.sawqueueing()
  return sk.sawqueueingcommand and true or false
end

function svo.amiwielding(what)
  for _, item in pairs(svo.me.wielded) do
    if item.name:find("%f[%a]"..what.."%f[%A]") then return true end
  end

  return false
end

function sk.sendqueuecmd(...)
  local args = {...}
  for i = 1, #args do
    local what = args[i]
    if type(what) == "string" then
      -- flush the buffer if it'll overflow how many chars we can send
      if sk.sendqueuel + #what + 1 >= sk.achaea_command_max_length then
        sk.dosendqueue()
      end

      sk.sendqueue[#sk.sendqueue+1] = what
      sk.sendqueuel = sk.sendqueuel + #what + 1 -- +1 for the separator
      if not sk.sendcuringtimer then
        sk.sendcuringtimer = tempTimer(0, sk.dosendqueue)
      end
    elseif type(what) == "table" and what.func then
      sk.dosendqueue() --flush send queue first
      if what.args then
        what.func(unpack(what.args))
      else
        what.func()
      end
    end
  end
end

function svo.sendcuring(what)
  what = "curing "..what

  sk.sendqueuecmd(what)
end

-- public function
svo.sendc = sk.sendqueuecmd

function svo.sk.dosendqueue()
  if sk.sendcuringtimer then killTimer(sk.sendcuringtimer) end

  if #sk.sendqueue <= 1 then
    send(sk.sendqueue[1] or '', false)
  elseif conf.commandseparator and conf.commandseparator ~= '' and #sk.sendqueue <= 10 then
    send(table.concat(sk.sendqueue, conf.commandseparator), false)
  elseif #sk.sendqueue <= 9 then
    send("9multicmd {"..table.concat(sk.sendqueue, "}{").."}", false)
  else
    local text = table.concat(sk.sendqueue, "/")
    sendAll("setalias multicmd "..text, "multicmd", false)
  end

  sk.sendqueue = {}
  sk.sendqueuel = 18 -- 'setalias multicmd ' is 24 characters
  sk.sendcuringtimer = nil
end

function svo.sk.setup9multicmd()
  send("setalias 9multicmd %1/%2/%3/%4/%5/%6/%7/%8/%9", false)
end
signals.charname:connect(sk.setup9multicmd)
signals.gmcpcharname:connect(sk.setup9multicmd)

svo["9multicmd_cleared"] = function()
  send("setalias 9multicmd %1/%2/%3/%4/%5/%6/%7/%8/%9")

  echo("\n")
  svo.echof("Oy! I need that! This is for vconfig batch to work.")

  svo.reenabled9multi = tempTimer(5, function() svo.reenabled9multi = nil end)
end

-- things line blind/deaf can be either afflictions or defences.
-- This function is called whenever their status as a defence might change, and you have them - hence they need to be
-- changed to a defence now or back
function svo.sk.fix_affs_and_defs()
  if affs.blindaff and ((defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind)
    or (svo.me.class ~= "Apostate" and defc.mindseye)) then
    svo.rmaff("blindaff")
    defences.got("blind")
    svo.echof("blindness is now considered a defence.")
  elseif defc.blind and not ((defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind)
   or (svo.me.class ~= "Apostate" and defc.mindseye)) then
    defences.lost("blind")
    svo.addaffdict(svo.dict.blindaff)
    svo.echof("blindness is now considered an affliction, will cure it.")
  end

  if affs.deafaff and ((defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf) or defc.mindseye) then
    svo.rmaff("deafaff")
    defences.got("deaf")
    svo.echof("deafness is now considered a defence.")
  elseif defc.deaf and not ((defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf) or defc.mindseye) then
    defences.lost("deaf")
    svo.addaffdict(svo.dict.deafaff)
    svo.echof("deafness is now considered an affliction, will cure it.")
  end
end


function svo.sk.checkrewield()
  local s,m = pcall(function()
    if svo.paragraph_length > 1 and not svo.find_until_last_paragraph("You cease to prop up a tall totem pole.", "exact") and
      not svo.find_until_last_paragraph("You lob", "substring") and not svo.lifevision.l.breath_gone and
      not svo.find_until_last_paragraph("You begin to wield", "substring") then
      -- we wish to rewield wieldables!
      svo.dict.rewield.rewieldables = deepcopy(sk.rewielddables)
      svo.debugf("dict.rewield.rewieldables - %s", svo.pl.pretty.write(svo.dict.rewield.rewieldables))
      svo.echof("Need to rewield %s%s!", tostring(svo.dict.rewield.rewieldables[1].name),
        tostring(((svo.dict.rewield.rewieldables[2] and svo.dict.rewield.rewieldables[2].name) and
          (" and "..svo.dict.rewield.rewieldables[2].name) or "")))
    end
  end)
  if not s then
    echoLink("(e!)", [[echo("The problem was: ']]..tostring(m)..[['")]], 'Oy - there was a problem. Click on this link '
      ..'and submit a bug report with what it says along with a copy/paste of what you saw.')
  end

  sk.rewielddables = nil
  signals.before_prompt_processing:disconnect(sk.checkrewield)
end

signals.gmcpcharitemsremove:connect(function ()
  sk.removed_something = true
  sk.onprompt_beforeaction_add("gmcpcharitemsremove", function ()
    sk.removed_something = nil
  end)
end)

