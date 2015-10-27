-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

-- update serverside prios in general
signals["svo prio changed"]:connect(function()
  if not conf.serverside then return end

  if not sk.priochangetimer then
    sk.priochangetimer = tempTimer(0, function() sk.updateserversideprios() end)
  end
end)

-- update serverside prios with custom dict overrides, ie for health which is not on serverside prios
signals["svo prio changed"]:connect(function(action, balance, newprio, slowcuring)
  if not (conf.serverside and dict[action][balance].onprioswitch) then return end

  dict[action][balance].onprioswitch(newprio, slowcuring)
end)

-- start out with blank prios, so a diff on switch to basic has the right stuff
signals["svo system loaded"]:connect(function()
  sk.priosbeforechange = sk.getblankbeforestateprios()
end)


function sk.sendpriorityswitch(action, balance, raffs, rdefs, cache)
  local isdefence, priority, gamename

  if dict[action][balance].def then
    isdefence = "defence "
    priority = rdefs[action]
  elseif dict[action].aff then
    isdefence = ""
    priority = raffs[action]
  else -- an action that's not an aff or a def - ignore
    debugf("(e!) sk.sendpriorityswitch: quitting, not an aff or a def")
    return
  end

  -- caps at 25, so pool everything after on 25
  if priority > 25 then priority = 25 end

  -- if already in cache at same priority, don't send
  if cache[action] == priority then
    debugf("%s is already on %s, ignoring", action, cache[action])
    return
  else
    cache[action] = priority
  end

  gamename = dict[action].gamename and dict[action].gamename or action

  local command = string.format("priority %s%s %s", isdefence, gamename, priority)

  sendcuring(command)
end

function sk.sendpriorityignore(action, balance, rignoreaffs, rignoredefs, cache)
  local isdefence, priority, gamename

  if dict[action][balance].def then
    isdefence = "defence "
    priority = "reset"
  elseif dict[action].aff then
    isdefence = ""
    priority = 26
  else -- an action that's not an aff or a def - ignore
    debugf("(e!) sk.sendpriorityignore: quitting, not an aff or a def")
    return
  end

  -- if already in cache at same priority, don't send
  if cache[action] == "ignore" then
    debugf("%s is already on %s, ignoring", action, cache[action])
    return
  else
    cache[action] = "ignore"
  end

  gamename = dict[action].gamename and dict[action].gamename or action

  local command = string.format("priority %s%s %s", isdefence, gamename, priority)

  sendcuring(command)
end

function sk.updateserversideprios()
  if not sk.priochangetimer then return end
  sk.updateserverwatch = sk.updateserverwatch or createStopWatch()
  startStopWatch(sk.updateserverwatch)

  -- don't notify of prio changes until the system is loaded, as they can get shuffled around a bit
  if not systemloaded then return end

  local afterstate = sk.getafterstateprios()
  debugf("sk.updateserverwatch sk.getafterstateprios: %s", getStopWatchTime(sk.updateserverwatch))

  local basictableindexdiff, valid_sync_action = basictableindexdiff, valid_sync_action

  for balance, data in pairs(sk.priosbeforechange) do
    if balance == "slowcuring" then
      sk.priochangecache[balance] = sk.priochangecache[balance] or {}
      local priochangecache = sk.priochangecache[balance]

      -- make the diff of snapshots
      local diffslow = basictableindexdiff(data.data, afterstate[balance].newdata)
      -- split the action_balance actions into separate balances
      local diff = sk.splitbals(diffslow)

      -- get the new list of prios, sorted in importance
      local neworderslow = prio.getsortedlist(balance)
      -- split the action_balance actions into separate balances
      local neworderbals = sk.splitbals(neworderslow)

      -- if not in slowcuring mode, switch to slowcuring prios first
      local needtoswitch, needtoswitchback = false, false
      if not sys.sync then
        needtoswitch = true
      end

      for balance, neworder in pairs(neworderbals) do
        if diff[balance] then
          priochangecache[balance] = priochangecache[balance] or {}
          local affs, defs, ignoreaffs, ignoredefs = sk.splitdefs(balance, neworder)
          local raffs, rdefs, rignoreaffs, rignoredefs = {}, {}, {}, {}
          for index, aff in pairs(affs) do raffs[aff] = index end
          for index, def in pairs(defs) do rdefs[def] = index end
          for index, aff in pairs(ignoreaffs) do rignoreaffs[aff] = index end
          for index, def in pairs(ignoredefs) do rignoredefs[def] = index end

          -- update for the changes
          for _, action in pairs(diff[balance]) do
            -- check if this is something actually on prios. an aff could be ignored, a def not on keepup
            if raffs[action] or rdefs[action] then
              if needtoswitch then sendc("curingset switch slowcuring"); needtoswitch = false; needtoswitchback = true end

              sk.sendpriorityswitch(action, balance, raffs, rdefs, priochangecache[balance])
            elseif rignoreaffs[action] or rignoredefs[action] then
              if needtoswitch then sendc("curingset switch slowcuring"); needtoswitch = false; needtoswitchback = true end

              sk.sendpriorityignore(action, balance, rignoreaffs, rignoredefs, priochangecache[balance])
            end
          end
        end
      end

      if needtoswitchback then
        sendc("curingset switch normal")
      end
    else
      sk.priochangecache[balance] = sk.priochangecache[balance] or {}

      -- make the diff of snapshots
      local diff = basictableindexdiff(data.data, afterstate[balance].newdata)
      -- if next(diff) then debugf("%s diff: %s", balance, pl.pretty.write(diff)) end
      -- get the new list of prios, sorted in importance
      local neworder = prio.getsortedlist(balance)
      local affs, defs, ignoreaffs, ignoredefs = sk.splitdefs(balance, neworder)
      local raffs, rdefs, rignoreaffs, rignoredefs = {}, {}, {}, {}
      for index, aff in pairs(affs) do raffs[aff] = index end
      for index, def in pairs(defs) do rdefs[def] = index end
      for index, aff in pairs(ignoreaffs) do rignoreaffs[aff] = index end
      for index, def in pairs(ignoredefs) do rignoredefs[def] = index end

      -- if not in slowcuring mode, switch to slowcuring prios first
      local needtoswitch, needtoswitchback = false, false
      if sys.sync then
        needtoswitch = true
      end

      -- update for the changes
      for _, action in pairs(diff) do
        -- check if this is something actually on prios. an aff could be ignored, a def not on keepup
        if raffs[action] or rdefs[action] then
          if needtoswitch then sendc("curingset switch normal"); needtoswitch = false; needtoswitchback = true end

          sk.sendpriorityswitch(action, balance, raffs, rdefs, sk.priochangecache[balance])
        elseif rignoreaffs[action] or rignoredefs[action] then
          if needtoswitch then sendc("curingset switch normal"); needtoswitch = false; needtoswitchback = true end

          sk.sendpriorityignore(action, balance, rignoreaffs, rignoredefs, sk.priochangecache[balance])
        end
      end

      if needtoswitchback then
        sendc("curingset switch slowcuring")
      end
    end
  end

  sk.priochangetimer = nil

  -- save new state for next change
  debugf("sk.updateserverwatch sk.getbeforestateprios: %s", getStopWatchTime(sk.updateserverwatch))
  sk.priosbeforechange = sk.getbeforestateprios()

  debugf("sk.updateserverwatch: %s", stopStopWatch(sk.updateserverwatch))
end

-- splits slowcuring prios by balance
function sk.splitbals(list)
  local balances, valid_sync_action = {}, valid_sync_action

  for i = 1, #list do
    local action_balance = list[i]

    local _, action, balance = valid_sync_action(action_balance)
    balances[balance] = balances[balance] or {}
    local balancet = balances[balance]
    balancet[#balancet+1] = action
  end

  return balances
end

-- returns true if the given action should be ignored on serverside, which it should be if:
-- it's ignored in system in general
-- it's handled by Svof instead of serverside
-- it's not on keepup
-- if we're in defup and it's not on defup
-- its custom onservereignore function returns true
function sk.shouldignoreserverside(action)
  return conf.serverside and (
    ignore[action] or
    not serverignore[action] or
    (not sys.deffing and defkeepup[defs.mode][action] == false) or
    (sys.deffing and defdefup[defs.mode][action] == false) or
    (dict[action].onservereignore and dict[action].onservereignore())
  ) -- false so afflictions are okay, which are a nil
end
shouldignoreserverside = sk.shouldignoreserverside

function sk.handleserversideswitch()
  if not sk.priochangetimer then
    sk.priochangetimer = tempTimer(0, function() sk.updateserversideprios() end)
  end
end

function sk.handleserversideswitch_keepup(defmode, action)
  if not dict[action] then return end

  -- don't do anything for the current defences mode
  if defmode ~= defs.mode then return end

  if not sk.priochangetimer then
    sk.priochangetimer = tempTimer(0, function() sk.updateserversideprios() end)
  end
end

-- splits defs up into another list and removes them from the affs one
-- also remove uncurable actions that aren't affs, and defs that
-- aren't on defup or keepup
function sk.splitdefs(balance, list)
  local defs, disableddefs, disabledaffs, dict, defmode, tremove = {}, {}, {}, dict, svo.defs.mode, table.remove

  -- prune list to only be a list of affs, save defs and disable defs into another list
  -- iterate backwards, so we can remove items from the list safely
  for i = #list, 1, -1 do
    local action = list[i]

    -- take care of defs
    if dict[action][balance].def then
      -- check that it's not undeffable in-game and on keepup
      if not dict[action][balance].undeffable and ((sys.deffing and defdefup[defmode][action]) or (not sys.deffing and defkeepup[defmode][action])) and not sk.shouldignoreserverside(action) then
        defs[i] = list[i]
        list[i] = nil
      -- if it's off keepup, send to another list so those defs get ignored
      elseif not dict[action][balance].undeffable and sk.shouldignoreserverside(action) then
        disableddefs[#disableddefs+1] = list[i]
        list[i] = nil
      else
        -- make sure to remove a def either way
        list[i] = nil
      end
    else
      -- remove if not priotisable
      if dict[action][balance].uncurable or dict[action][balance].irregular then
        list[i] = nil
      -- if handled by svo, or handled by serverside and on normal ignore, ignore
      elseif dict[action].aff and sk.shouldignoreserverside(action) then
        disabledaffs[#disabledaffs+1] = list[i]
        list[i] = nil
      end
    end
  end

  return list, defs, disabledaffs, disableddefs
end


-- gets a snapshot of priorities, skipping actions that should be ignored
function sk.getbeforestateprios()
  local beforestate = {}
  local importables = {
    "herb",
    "smoke",
    "salve",
    "sip",
    "purgative",
    "physical",
    "moss",
    "misc",
    "slowcuring",
  }
  local make_prio_tablef = make_prio_tablef

  for _, balance in ipairs(importables) do
    beforestate[balance] = {}

    if balance == "slowcuring" then
      -- get the before state for diffing
      local data = make_sync_prio_tablef("%s_%s", function(action)
        return not sk.shouldignoreserverside(action)
      end, { focus = true })
      beforestate[balance] = {data = data}
    else
      -- get the before state for diffing
      local data = make_prio_tablef(balance, function(action)
        return not sk.shouldignoreserverside(action)
      end)
      beforestate[balance] = {data = data}
    end
  end

  return beforestate
end

-- gets a blanked out state of before prios - useful if all of them need to be reset serverside
function sk.getblankbeforestateprios()
  local beforestate = {}
  local importables = {
    "herb",
    "smoke",
    "salve",
    "sip",
    "purgative",
    "physical",
    "moss",
    "misc",
    "slowcuring",
  }
  local make_prio_tablef = make_prio_tablef

  for _, balance in ipairs(importables) do
    beforestate[balance] = {}

    if balance == "slowcuring" then
      -- get the before state for diffing
      local data = make_sync_prio_tablef("%s_%s", nil, { focus = true })
      -- set all prios to negative, so things get set or ignored serverside properly
      local nullify, c = {}, -1
      for k,v in pairs(data) do nullify[c] = v; c = c - 1 end
      beforestate[balance] = {data = nullify}
    else
      -- get the before state for diffing
      local data = make_prio_tablef(balance)
      -- set all prios to negative, so things get set or ignored serverside properly
      local nullify, c = {}, -1
      for k,v in pairs(data) do nullify[c] = v; c = c - 1 end
      beforestate[balance] = {data = nullify}
    end
  end

  return beforestate
end

function sk.getafterstateprios()
  local afterstate = {}
  local importables = {
    "herb",
    "smoke",
    "salve",
    "sip",
    "purgative",
    "physical",
    "moss",
    "misc",
    "slowcuring",
  }
  local make_prio_tablef = make_prio_tablef

  for _, balance in ipairs(importables) do
    afterstate[balance] = {}

    if balance == "slowcuring" then
      -- get the new state
      local newdata = make_sync_prio_tablef("%s_%s", function(action)
        return not sk.shouldignoreserverside(action)
      end, { focus = true })
      -- create an action - prio table for retrieval of location using diffs
      local action_prio = {}
      for k,v in pairs(newdata) do action_prio[v] = k end
      afterstate[balance] = {newdata = newdata, action_prio = action_prio}
    else
      -- get the new state
      local newdata = make_prio_tablef(balance, function(action)
        return not sk.shouldignoreserverside(action)
      end)
      -- create an action - prio table for retrieval of location using diffs
      local action_prio = {}
      for k,v in pairs(newdata) do action_prio[v] = k end
      afterstate[balance] = {newdata = newdata, action_prio = action_prio}
    end
  end

  return afterstate
end

function sk.notifypriodiffs(beforestate, afterstate)
  local basictableindexdiff = basictableindexdiff

  -- don't notify of prio changes until the system is loaded, as they can get shuffled around a bit
  if not systemloaded then return end

  for balance, data in pairs(beforestate) do
    if balance == "slowcuring" then
      -- make the diff of snapshots
      local diff = basictableindexdiff(data.data, afterstate[balance].newdata)
      local valid_sync_action = valid_sync_action

      -- now only notify for the differences
      for _, a in pairs(diff) do
        local _, action, balance = valid_sync_action(a)
        raiseEvent("svo prio changed", action, balance, afterstate[balance].action_prio[a], "slowcuring")
      end
    else
      -- make the diff of snapshots
      local diff = basictableindexdiff(data.data, afterstate[balance].newdata)

      -- notify only for the changes
      for _, a in pairs(diff) do
        raiseEvent("svo prio changed", a, balance, afterstate[balance].action_prio[a])
      end
    end
  end
end


-- returns an alphabetically sorted indexed list of all actions serverside can do
function sk.getallserversideactions()
  local type = type

  local actions = {}
  for action, balances in pairs(dict) do
    for balance, data in pairs(balances) do
      if type(data) == "table" and balance ~= "waitingfor" and balance ~= "aff" and balance ~= "gone" and balance ~= "happened" and not data.uncurable and not data.undeffable then
        actions[action] = true
      end
    end
  end

  local actionslist = {}
  for k,v in pairs(actions) do
    actionslist[#actionslist+1] = k
  end

  table.sort(actionslist)

  return actionslist
end

--[[ register all signals needed for this to work ]]

signals.sync:connect(function ()
  if not conf.serverside then return end

  if sys.sync then
    sendc("curingset switch slowcuring")
  else
    sendc("curingset switch normal")
  end
end)

-- vconfig serverside
signals["svo config changed"]:connect(function(config)
  if config ~= "serverside" then return end

  if conf.serverside then
    sk.priochangecache = { special = {} }
    -- sync everything
    sk.priosbeforechange = sk.getblankbeforestateprios()
    sendcuring("PRIORITY RESET")
    sk.priochangetimer = true
    sk.updateserversideprios()
    -- sync all special things like health
    for action, actiont in pairs(dict) do
      for balance, balancet in pairs(actiont) do
        if type(balancet) == "table" and balancet.onprioswitch then
          balancet.onprioswitch()
        end
      end
    end

    -- initial sync of some config options.
    local option
#for _, conf in ipairs({"healthaffsabove", "mosshealth", "mossmana"}) do
    if conf.$(conf) == true then option = "on"
    elseif conf.$(conf) == false then option = "off"
    else
      option = conf.$(conf)
    end

    sendcuring("$(conf) "..option)
#end

    if conf.keepup then
      sendcuring("defences on")
    else
      sendcuring("defences off")
    end

    sk.togglefocusserver()
    sk.toggleclotserver()
    sk.toggleinsomniaserver()

    if sk.canclot() and conf.clot then sendcuring("clot on") else sendcuring("clot off") end
    sendcuring("clotat "..conf.bleedamount)

    if not serverignore.healhealth then
      sendcuring("siphealth 0")
      sk.priochangecache.special.healhealth = 0
    elseif serverignore.healhealth then
      sendcuring("siphealth "..conf.siphealth)
      sk.priochangecache.special.healhealth = conf.siphealth
    end

    if not serverignore.healmana then
      sendcuring("sipmana 0")
      sk.priochangecache.special.healmana = 0
    elseif serverignore.healmana then
      sendcuring("sipmana "..conf.sipmana)
      sk.priochangecache.special.healmana = conf.sipmana
    end

    if conf.curemethod == "transonly" then
      sendcuring("transmutation on")
    elseif conf.curemethod == "conconly" then
      sendcuring("transmutation off")
    elseif conf.curemethod == "prefertrans" then
      sendcuring("transmutation on")
      echof("Setting in-game curemethod to 'transmutation cures only', as serverside doesn't support mixed cures.")
    elseif conf.curemethod == "preferconc" then
       sendcuring("transmutation off")
       echof("Setting in-game curemethod to 'concoctions cures only', as serverside doesn't support mixed cures.")
    end

    sendcuring("manathreshold "..conf.manause)
  end
end)

#for _, conf in ipairs({"healthaffsabove", "mosshealth", "mossmana"}) do
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == "$(conf)") then return end

  if conf.$(conf) == true then option = "on"
  elseif conf.$(conf) == false then option = "off"
  else
    option = conf.$(conf)
  end

  sendcuring("$(conf) "..option)
end)
#end
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == "clot") then return end

  if sk.canclot() and conf.clot and not sk.clotting_on_serverside then
    sendcuring("clot on")
    sk.clotting_on_serverside = true
  elseif not (sk.canclot() and conf.clot) and sk.clotting_on_serverside then
    sendcuring("clot off")
    sk.clotting_on_serverside = false
  end
end)

-- healhealth / siphealth
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == "siphealth") then return end

  if not serverignore.healhealth and sk.priochangecache.special.healhealth ~= 0 then
    sendcuring("siphealth 0")
    sk.priochangecache.special.healhealth = 0
  elseif serverignore.healhealth and sk.priochangecache.special.healhealth ~= conf.siphealth then
    sendcuring("siphealth "..conf.siphealth)
    sk.priochangecache.special.healhealth = conf.siphealth
  end
end)
signals["svo serverignore changed"]:connect(function(config)
  if not (conf.serverside and config == "healhealth") then return end

  if not serverignore.healhealth and sk.priochangecache.special.healhealth ~= 0 then
    sendcuring("siphealth 0")
    sk.priochangecache.special.healhealth = 0
  elseif serverignore.healhealth and sk.priochangecache.special.healhealth ~= conf.siphealth then
    sendcuring("siphealth "..conf.siphealth)
    sk.priochangecache.special.healhealth = conf.siphealth
  end
end)

-- healmana / sipmana
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == "sipmana") then return end

  if not serverignore.healmana and sk.priochangecache.special.healmana ~= 0 then
    sendcuring("sipmana 0")
    sk.priochangecache.special.healmana = 0
  elseif serverignore.healmana and sk.priochangecache.special.healmana ~= conf.sipmana then
    sendcuring("sipmana "..conf.sipmana)
    sk.priochangecache.special.healmana = conf.sipmana
  end
end)
signals["svo serverignore changed"]:connect(function(config)
  if not (conf.serverside and config == "healmana") then return end

  if not serverignore.healmana and sk.priochangecache.special.healmana ~= 0 then
    sendcuring("sipmana 0")
    sk.priochangecache.special.healmana = 0
  elseif serverignore.healmana and sk.priochangecache.special.healmana ~= conf.sipmana then
    sendcuring("sipmana "..conf.sipmana)
    sk.priochangecache.special.healmana = conf.sipmana
  end
end)

-- bleedamount
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == "bleedamount") then return end

  sendcuring("clotat "..conf.bleedamount)
end)

-- manause
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == "manause") then return end

  sendcuring("manathreshold "..conf.manause)
end)

-- curemethod
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == "curemethod" and not logging_in) then return end

  if conf.curemethod == "transonly" then
    sendcuring("transmutation on")
  elseif conf.curemethod == "conconly" then
    sendcuring("transmutation off")
  elseif conf.curemethod == "prefertrans" then
    sendcuring("transmutation on")
    echof("Setting in-game curemethod to 'transmutation cures only', as serverside doesn't support mixed cures.")
  elseif conf.curemethod == "preferconc" then
     sendcuring("transmutation off")
     echof("Setting in-game curemethod to 'concoctions cures only', as serverside doesn't support mixed cures.")
  end
end)

-- pause
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == "paused" and not logging_in) then return end

  -- send right away, so chained commands are done in proper order
  if conf.paused then
    send("curing off")
  else
    send("curing on")
  end
end)

-- keepup
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == "keepup" and not logging_in) then return end

  if conf.keepup then
    sendcuring("defences on")
  else
    sendcuring("defences off")
  end
end)

signals["svo ignore changed"]:connect(sk.handleserversideswitch)
signals["svo ignore changed"]:connect(sk.handleserversideswitch_keepup)
signals["svo keepup changed"]:connect(sk.handleserversideswitch)
signals["svo keepup changed"]:connect(sk.handleserversideswitch_keepup)
signals["svo serverignore changed"]:connect(sk.handleserversideswitch)
signals["svo serverignore changed"]:connect(sk.handleserversideswitch_keepup)
signals["svo switched defence mode"]:connect(sk.handleserversideswitch)
signals["svo done defup"]:connect(sk.handleserversideswitch)

-- setup the block if serverside isn't on at load
signals["svo system loaded"]:connect(function()
  if not conf.serverside then
    signals["svo ignore changed"]:block(sk.handleserversideswitch)
    signals["svo ignore changed"]:block(sk.handleserversideswitch_keepup)
    signals["svo keepup changed"]:block(sk.handleserversideswitch)
    signals["svo keepup changed"]:block(sk.handleserversideswitch_keepup)
    signals["svo serverignore changed"]:block(sk.handleserversideswitch)
    signals["svo serverignore changed"]:block(sk.handleserversideswitch_keepup)
    signals["svo switched defence mode"]:block(sk.handleserversideswitch)
    signals["svo done defup"]:block(sk.handleserversideswitch)
  end
end)

-- toggle appropriately upon vconfig changed
signals["svo config changed"]:connect(function(config)
  if config ~= "serverside" then return end

  if conf.serverside then
    signals["svo ignore changed"]:unblock(sk.handleserversideswitch)
    signals["svo ignore changed"]:unblock(sk.handleserversideswitch_keepup)
    signals["svo keepup changed"]:unblock(sk.handleserversideswitch)
    signals["svo keepup changed"]:unblock(sk.handleserversideswitch_keepup)
    signals["svo serverignore changed"]:unblock(sk.handleserversideswitch)
    signals["svo serverignore changed"]:unblock(sk.handleserversideswitch_keepup)
    signals["svo switched defence mode"]:unblock(sk.handleserversideswitch)
    signals["svo done defup"]:unblock(sk.handleserversideswitch)
  else
    signals["svo ignore changed"]:block(sk.handleserversideswitch)
    signals["svo ignore changed"]:block(sk.handleserversideswitch_keepup)
    signals["svo keepup changed"]:block(sk.handleserversideswitch)
    signals["svo keepup changed"]:block(sk.handleserversideswitch_keepup)
    signals["svo serverignore changed"]:block(sk.handleserversideswitch)
    signals["svo serverignore changed"]:block(sk.handleserversideswitch_keepup)
    signals["svo switched defence mode"]:block(sk.handleserversideswitch)
    signals["svo done defup"]:block(sk.handleserversideswitch)
  end
end)


-- if we've got cadmus, and have one of of the me.cadmusaffs afflictions, then we should focus
function sk.canfocus()
  -- check if we haven't got cadmus
  if not affs.cadmus then return true end

  -- if we do, and focus with cadmus is on, check if any of the affs we've got allow us to focus
  if conf.focuswithcadmus then
    -- iterate aff list, as that'll be smaller most of the time than cadmusaffs
    for aff in pairs(affs) do
      if me.cadmusaffs[aff] == true then return true end
    end
  end

  return true
end

function sk.togglefocusserver()
  if not (conf.serverside and sk.logged_in) then return end

  if sk.canfocus() and conf.focus and not sk.priochangecache.special.focustoggle then
    sendcuring("focus on")
    sk.priochangecache.special.focustoggle = true
  elseif (not conf.focus or (conf.focus and not sk.canfocus())) and sk.priochangecache.special.focustoggle then
    sendcuring("focus off")
    sk.priochangecache.special.focustoggle = false
  end
end
signals.svogotaff:connect(sk.togglefocusserver)
-- use after prompt processing, not lost aff, so afflictions getting removed don't spam-toggle
signals.after_prompt_processing:connect(sk.togglefocusserver)
signals["svo config changed"]:connect(sk.togglefocusserver)

function sk.canclot()
  if (affs.corrupted and stats.currenthealth < sys.corruptedhealthmin) then
    return false
  else
    return true
  end
end

function sk.toggleclotserver()
  if not conf.serverside then return end

  if sk.canclot() and conf.clot and not sk.clotting_on_serverside then
    sendcuring("clot on")
    sk.clotting_on_serverside = true
  elseif not (sk.canclot() and conf.clot) and sk.clotting_on_serverside then
    sendcuring("clot off")
    sk.clotting_on_serverside = false
  end
end
-- use after prompt processing, not lost aff, so afflictions getting removed don't spam-toggle
signals.svogotaff:connect(sk.toggleclotserver)
signals.after_prompt_processing:connect(sk.toggleclotserver)


function sk.toggleinsomniaserver()
  if not (conf.serverside and sk.logged_in) then return end

  if conf.insomnia and not sk.priochangecache.special.insomniatoggle then
    sendcuring("insomnia on")
    sk.priochangecache.special.insomniatoggle = true
  elseif not conf.insomnia and sk.priochangecache.special.insomniatoggle then
    sendcuring("insomnia off")
    sk.priochangecache.special.insomniatoggle = false
  end
end
signals["svo config changed"]:connect(sk.toggleinsomniaserver)

--


function setupserverside()
  if not conf.serverside then return end

  sendc("curingset new normal")
  sendc("curingset new slowcuring")

  if serversidesetup then killTimer(serversidesetup) end
  serversidesetup = tempTimer(5+getping(), function()
    serversidesetup = nil
  end)
end
signals.charname:connect(setupserverside)
signals.gmcpcharname:connect(setupserverside)

function hitcuringsetlimit()
  if not serversidesetup then return end

  if not svo.conf.serverside then return end

  echo("\n")
  echofn("You don't have enough curingset slots to enable serverside use - Svof requires two. View your curingsets with ")
  setFgColor(unpack(getDefaultColorNums))
  setUnderline(true)
  echoLink("CURINGSET LIST", 'send"curingset list"', "CURINGSET LIST", true)
  setUnderline(false)
  echo(" and delete some with ")
  setUnderline(true)
  echoLink("CURINGSET DELETE", 'printCmdLine"curingset delete "', "CURINGSET DELETE", true)
  setUnderline(false)
  echo(".\n")

  tntf_set("serverside", "off", true)
end

function hitaliaslimit()
  if not serversidesetup then return end

  if not svo.conf.serverside then return end

  echo("\n")
  echofn("You haven't got enough space for Svof's two serverside aliases - view list with ")
  setFgColor(unpack(getDefaultColorNums))
  setUnderline(true)
  echoLink("ALIAS LIST", 'send"alias list"', "ALIAS LIST", true)
  setUnderline(false)
  echo(" and delete some with ")
  setUnderline(true)
  echoLink("CLEARALIAS", 'printCmdLine"clearalias "', "CLEARALIAS", true)
  setUnderline(false)
  echo(".\n")

  tntf_set("serverside", "off", true)
end
