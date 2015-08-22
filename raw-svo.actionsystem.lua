-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

-- action system
actions = pl.OrderedMap()

 -- a map of balances, with a map of actions in each
actions_performed = actions_performed or {}
bals_in_use       = bals_in_use or {}

-- ie:
-- doaction(dict.healhealth.sip)
doaction = function(act)
  assert(act, "$(sys).doaction requires an argument")
  --it'll be in format of dict.what.#somebalance
  -- add to a table, create timers and store id's in there
  -- if ai is on, enable the relevant triggers <- maybe we should do
  -- it in dict action.

  local expirein =
    affs.seriousconcussion and sys.sync
    and (syncdelay()+.3) -- w/ aeon, waits 1.3s and etc, w/o aeon - 0.3s and etc..
    or ((act.customwait or (act.customwaitf and act.customwaitf()) or 0) + sys.wait) + syncdelay()

#if DEBUG_actions then
  debugf("expirein for %s set to %s", act.name, expirein)
#end

  local timerid = tempTimer(expirein,
    function ()
#if DEBUG_actions then
      debugf("actions: %s timed out", tostring(act.name))
#end
      actions:set(act.name, nil)  -- remove from actions list

      if bals_in_use[act.balance] then -- it should always be there, even after reset - but a failsafe is in place anyway
        bals_in_use[act.balance][act.name] = nil
      end
      actions_performed[act.action_name] = nil

      -- there might be a case where actions_performed was being taken up by another action, like a cure, that was overwritten by an aff now. This needs to be rectified back.
      for bal, _ in pairs(bals_in_use) do
        if actions[act.action_name.."_"..bal] then
          actions_performed[act.action_name] = bals_in_use[bal][act.action_name.."_"..bal]

#if DEBUG_actions then
          debugf("actions: added %s_%s back", act.action_name, bal)
#end
        end
      end

      -- don't need to pause the system itself as all actions timing out will come to this, ie build up, get disabled until next prompt
      sys.lagcount = sys.lagcount + 1
      if sys.lagcount < (sys.lagcountmax+1) then
        if act.ontimeout then act.ontimeout() end

        -- if we have a stupidity counted and we timed out, then stupidity might be real
        if sk.stupidity_count and sk.stupidity_count > 0 and not affs.stupidity then
          addaff(dict.stupidity)
          echof("I suspect we've got stupidity.")
        end

        make_gnomes_work()
      elseif sys.lagcount == (sys.lagcountmax+1) and not conf.paused then
        echof("Warning, lag detected (while doing/curing %s)", act.action_name)
        sk.increase_lagconf()
      end
    end
  )

  -- act.name is a single string of action + balance - ie, bleeding_misc (cure) or bleeding_aff (affliction)
  actions:set(act.name, {
    timerid = timerid,
    completed = function (other_action, arg)
      killTimer(timerid)
#if DEBUG_actions then
  if (other_action) then debugf("doaction other action: %s", tostring(other_action)) end
  if not (act[other_action or "oncompleted"]) then debugf("[error] %s does not exist for %s!", tostring(other_action or "oncompleted"), tostring(act.name)) end
#end
      act[other_action or "oncompleted"](arg)
#if DEBUG_actions then
      debugf("actions: %s%s completed (killed %s)", act.name, arg and (' ('..tostring(arg)..')') or "", tostring(timerid))
#end

      if act.balance == "focus" then signals.curedwith_focus:emit(other_action or "oncompleted") end
    end,
    p = act
  })

#if DEBUG_actions then
  if not (act.balance or act.action_name) then debugf("balance: " .. tostring(act.balance) .. ", name: " .. tostring(act.action_name) .. "what: " .. tostring(act)) end
#end

  bals_in_use[act.balance] = bals_in_use[act.balance] or {}
  bals_in_use[act.balance][act.name] = act
  -- ie, bleeding
  actions_performed[act.action_name] = act

  -- lastly, do it! :)

#if DEBUG_actions then
  debugf("actions: doing %s", act.name)
#end
  local s,m = pcall(act.onstart)
  if not s then
#if DEBUG_actions then
    debugf("error from onstart(): "..m)
#end
    echoLink("(e!)", [[echo("The problem was: ]]..tostring(act.action_name)..[[ failed to start (]]..tostring(m)..[[). If this is curing-related, please include that your curemethod is set to ]]..tostring(conf.curemethod)..[[")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
  else
    -- action started successfully - start the stopwatch for it. It's accessible via actions.action_balance.p.actionwatch
    act.actionwatch = act.actionwatch or createStopWatch()
    startStopWatch(act.actionwatch)
  end

end

-- if input is true, then add to the queue regardless
-- otherwise if it's output from us, only add if we got anti-illusion
--   off.
-- input determines if we should force insert
checkaction = function (act, input)
#if DEBUG_actions then
  if not act then debugf("[svo error]: checkaction called with -nothing-") return end
#end
  -- if doesnt exist in table, and we got ai off, make one up
  if not actions[act.name] and ((not conf.aillusion and input ~= false) or input) then

#if DEBUG_actions then
  debugf("actions: force-adding %s", act.name)
#end

    actions:set(act.name, {
      completed = function (other_action, arg)
#if DEBUG_actions then
  if (other_action) then debugf("checkaction other action: %s", other_action) end
  if not (act[other_action or "oncompleted"]) then debugf("[error] %s does not exist for %s!", tostring(other_action or "oncompleted"), tostring(act.name)) end
#end
        act[other_action or "oncompleted"](arg)
#if DEBUG_actions then
      debugf("actions: %s%s completed", act.name, arg and tostring(arg) or "")
#end
        if act.balance == "focus" then signals.curedwith_focus:emit(other_action or "oncompleted") end
      end,
      p = act,
    })

    bals_in_use[act.balance] = bals_in_use[act.balance] or {}
    bals_in_use[act.balance][act.name] = act
    actions_performed[act.action_name] = act
  end
end

-- checks if any of the actions are being done, returns one if true;
-- does not create new ever
checkany = function (...)
  local t = {...}

  for i=1,#t do
    local j = t[i]
#if DEBUG_actions then
    if not j then debugf("missing %s, traceback: %s", j, debug.traceback()) end
#end
    if actions[j.name] then
      return j
    end
  end
end

findbybal = function (balance)
  return bals_in_use[balance] and select(2, next(bals_in_use[balance]))
end

-- checks if any of the physical actions being done right now are expected to consume balance
will_take_balance = function()
  bals_in_use.physical = bals_in_use.physical or {}
  for action, data in pairs(bals_in_use.physical) do
    if data.balanceful_act then return true end
  end
end

codepaste.balanceful_codepaste = will_take_balance

findbybals = function(balances)
  local t = {}

  for _, bal in ipairs(balances) do
    if bals_in_use[bal] then
      for _, act in pairs(bals_in_use[bal]) do
        t[act.name] = act
      end
    end
  end

  if next(t) then return t end
end

-- for illusions/actions that need to be cancelled
actionclear = function(act)
#if DEBUG_actions then
  debugf("actions: cleared action %s", tostring(act.name))
#end

  actions:set(act.name, nil)
  if bals_in_use[act.balance] then -- it should always be there, even after reset - but a failsafe is in place anyway
    bals_in_use[act.balance][act.name] = nil
  end
  actions_performed[act.action_name] = nil

  -- there might be a case where actions_performed was being taken up by another action, like a cure, that was overwritten by an aff now. This needs to be rectified back.
  for bal, _ in pairs(bals_in_use) do
    if actions[act.action_name.."_"..bal] then
      actions_performed[act.action_name] = bals_in_use[bal][act.action_name.."_"..bal]

#if DEBUG_actions then
      debugf("actions: added %s_%s back", act.action_name, bal)
#end
    end
  end

  if act.oncancel then
    local s,m = pcall(act.oncancel)
    if not s then
#if DEBUG_actions then
      debugf("error from oncancel(): "..m)
#end
      echoLink("(e!)", [[echo("The problem was: ]]..tostring(act.action_name)..[[ failed to cancel (]]..tostring(m)..[[). If this is curing-related, please include that your curemethod is set to ]]..tostring(conf.curemethod)..[[")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
    end
  end
end

actionfinished = function(act, other_action, arg)
  assert(act, "$(sys).actionfinished wants an argument")
  if not act.name or not actions[act.name] or not actions[act.name].completed then echo("(e!)")

#if not DEBUG_actions then
    return
#else
  debugf("actionfinished: %s", debug.traceback())
#end
  end

#if DEBUG_actions then
  if not act.name then debugf("$(sys) error: no name field, total: %s", pl.pretty.write(act or {})) return end
  if not actions[act.name] then debugf("$(sys) error: no such action %s being done atm", act.name) return end
  if not actions[act.name].completed then debugf("$(sys) error: no completed method on %s", act.name) return end
#end

  local result, msg = pcall(actions[act.name].completed, other_action, arg)

  if not result then
#if DEBUG_actions then
    debugf("error from completed() "..msg)
    if other_action then debugf("other_action was: %s", other_action) end
#end
    echoLink("(e!)", [[$(sys).echof("The problem was: ]]..tostring(act.action_name)..[[ failed to complete: ]]..msg..[[")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
  end

  actions:set(act.name, nil)
  if bals_in_use[act.balance] then -- it should always be there, even after reset - but a failsafe is in place anyway
    bals_in_use[act.balance][act.name] = nil
  end
  actions_performed[act.action_name] = nil

#if DEBUG_actions then
  if not other_action then debugf("actions: finished action %s", tostring(act.name)) else
  debugf("actions: finished action %s, with non-default action: (%s)", tostring(act.name), other_action) end
#end

  -- there might be a case where actions_performed was being taken up by another action, like a cure, that was overwritten by an aff now. This needs to be rectified back.
  for bal, _ in pairs(bals_in_use) do
    if actions[act.action_name.."_"..bal] then
      actions_performed[act.action_name] = bals_in_use[bal][act.action_name.."_"..bal]

#if DEBUG_actions then
      debugf("actions: added %s_%s back", act.action_name, bal)
#end
    end
  end

  -- slow curing? kick the next action into going then
  if sys.sync then tempTimer(0, function() make_gnomes_work() end) end
end

-- needs the dict+balance, ie: killaction (dict.icing.waitingfor)
killaction = function (act)
#if DEBUG_actions then
  if not (act and act.name) then
    debugf("%s is invalid action to kill.", tostring(act))
    return
  end
#end

  assert(act, "$(sys).killaction wants an argument")

  if not actions[act.name] then return end

  if act.onkill then act.onkill() end

  if actions[act.name].timerid then
    killTimer(actions[act.name].timerid)
  end
  actions:set(act.name, nil)

  if bals_in_use[act.balance] then -- it should always be there, even after reset - but a failsafe is in place anyway
    bals_in_use[act.balance][act.name] = nil
  end
  actions_performed[act.action_name] = nil

#if DEBUG_actions then
  debugf("actions: killed early %s", tostring(act.name))
#end

  -- there might be a case where actions_performed was being taken up by another action, like a cure, that was overwritten by an aff now. This needs to be rectified back.
  for bal, _ in pairs(bals_in_use) do
    if actions[act.action_name.."_"..bal] then
      actions_performed[act.action_name] = bals_in_use[bal][act.action_name.."_"..bal]

#if DEBUG_actions then
      debugf("actions: added %s_%s back", act.action_name, bal)
#end
    end
  end

  if lifevision.l[act.name] then
    lifevision.l:set(act.name, nil)
#if DEBUG_actions then
    debugf("actions: also removed it from lifevision")
#end
  end

  -- slow curing? kick the next action into going then
  if sys.sync then tempTimer(0, function() make_gnomes_work() end) end
end

usingbal = function (which)
  return (bals_in_use[which] and next(bals_in_use[which])) and true or false
end

-- public function
usingbalance = usingbal

-- slight problem with this - it uses the short name, without the balance/action - so some misc things such as sleep, which can happen at once, are a problem. workaround is to combine doingaction with usingbal in there.
doingaction = function (which)
  assert(which, "$(sys).doingaction wants an argument")

  return actions_performed[which] and true or false
end

-- public function
-- fixme: allow for action_balance
doing = doingaction

-- String -> Action/Aff/Nil
-- returns true if we currently have or will register (after this prompt and no illusions) an affliction
haveorwill = function (aff)
  return actions[aff.."_aff"] or affs[aff]
end

-- string -> boolean
-- returns true if the given string in the format of actionname_balance exists
valid_sync_action = function(name)
  local actionname, balance = name:match("^(%w+)_(%w+)$")
  if not (actionname and balance) then return false, "actionname is in invalid format; it should be as 'actionname_balance'" end

  if not dict[actionname] then return false, "action "..actionname.." doesn't exist" end
  if not dict[actionname][balance] then return false, actionname.." doesn't operate on the "..balance.." balance" end

  return true, actionname, balance
end
