-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

-- Integration with serverside curing - mirroring of Svof's priorities to
-- serverside in an efficient, seamless manner

svo = svo or {}; svo.loader = svo.loader or {}
svo.loader.serverside = function()

local sys, affs, defdefup, defkeepup, signals = svo.sys, svo.affs, svo.defdefup, svo.defkeepup, svo.signals
local conf, sk, me, defs = svo.conf, svo.sk, svo.me, svo.defs
local stats = svo.stats

-- update serverside prios in general
signals["svo prio changed"]:connect(function()
  if not conf.serverside then return end

  if not sk.priochangetimer then
    sk.priochangetimer = tempTimer(0, function() sk.updateserversideprios() end)
  end
end, 'update serverside prios on svo prio change')

-- update serverside prios with custom svo.dict overrides, ie for health which is not on serverside prios
signals["svo prio changed"]:connect(function(action, balance, newprio, slowcuring)
  if not (conf.serverside and svo.dict[action][balance].onprioswitch) then return end

  svo.dict[action][balance].onprioswitch(newprio, slowcuring)
end, 'run onprioswitch dict functions')

-- start out with blank prios, so a diff on switch to basic has the right stuff
signals["svo system loaded"]:connect(function()
  sk.priosbeforechange = sk.getblankbeforestateprios()
end, 'get initial state of prios')

function sk.resetserversideprios()
  if conf.serverside then
    -- clear both curingsets, not just the one in use, or the other keeps the
    -- old class's defences on keepup. Anything still queued was meant for the
    -- old class and is resent from scratch after this
    sk.affqueue, sk.defqueue, sk.affqueueslow, sk.defqueueslow = {}, {}, {}, {}
    sk.priolength = {affqueue = 0, affqueueslow = 0, defqueue = 0, defqueueslow = 0}
    sk.clearpriocommands()
    send("curingset switch "..(sys.sync and "slowcuring" or "normal"), false)
    for _, queue in ipairs({"normal", "slow"}) do
      -- the affliction numbers are the player's own in custom mode
      if not sk.customserverprios() then sk.sendpriocommand("curing priority reset", queue) end
      sk.sendpriocommand("curing priority defence list reset", queue)
    end
  else
    svo.sendcuringprio("reset","affliction")
    svo.sendcuringprio("list reset","defence")
  end

	sk.priochangecache = {
    special = {
      focustoggle = conf.focus
    }
	}
  sk.priosbeforechange = sk.getblankbeforestateprios()
end

-- after a class change has reloaded the system: the reset left both
-- curingsets on the game's defaults, so send the new class's priorities now
-- rather than at the next keepup or ignore change
function sk.resyncserversideprios()
  if not conf.serverside or svo.logging_in then return end

  sk.handleserversideswitch()
  -- the new class's dictionary can differ in what svof cures itself
  sk.serverprios_send()
  -- health and mana order, which the diff doesn't cover
  for _, actiont in pairs(svo.dict) do
    for _, balancet in pairs(actiont) do
      if type(balancet) == 'table' and balancet.onprioswitch then
        balancet.onprioswitch()
      end
    end
  end
end

function sk.sendpriorityswitch(action, balance, raffs, rdefs, cache, slow)
  local isdefence, priority, gamename, istype
	
  if svo.dict[action][balance].def then
    isdefence = 'defence '
    istype = 'defence'
    priority = rdefs[action]
  elseif svo.dict[action].aff and not svo.dict[action].aff.notagameaff then
    isdefence = ''
    istype = 'affliction'
    priority = raffs[action]
  else -- an action that's not an aff or a def - ignore
    svo.debugf("(e!) sk.sendpriorityswitch: quitting, %s (%s) is not an aff or a def", action, balance)
    return
  end

  -- in custom mode the affliction numbers are the player's, not a place in
  -- svof's lists
  if istype == 'affliction' and sk.customserverprios() then return end

  -- caps at 25, so pool everything after on 25
  if priority > 25 then priority = 25 end

  -- if already in cache at same priority, don't send
  if cache[action] == priority then
    svo.debugf("%s is already on %s, ignoring", action, cache[action])
    return
  else
    cache[action] = priority
  end

  gamename = svo.dict[action].gamename and svo.dict[action].gamename or action
  svo.sendcuringprio(gamename .. " " .. priority, istype, slow)
end

function sk.sendpriorityignore(action, balance, rignoreaffs, rignoredefs, cache, slow)
  if svo.logging_in then return end
  local isdefence, priority, gamename, istype

  if svo.dict[action][balance].def then
    isdefence = "defence "
    istype = 'defence'
    priority = 'reset'
  elseif svo.dict[action].aff and not svo.dict[action].aff.notagameaff then
    isdefence = ""
    istype = 'affliction'
    priority = 26
  else -- an action that's not an aff or a def - ignore
    svo.debugf("(e!) sk.sendpriorityignore: quitting, %s (%s) is not an aff or a def", action, balance)
    return
  end

  -- custom mode sends its own 26s (sk.serverprios_refresh)
  if istype == 'affliction' and sk.customserverprios() then return end

  -- if already in cache at same priority, don't send
  if cache[action] == 'ignore' then
    svo.debugf("%s is already on %s, ignoring", action, cache[action])
    return
  else
    cache[action] = 'ignore'
  end

  gamename = svo.dict[action].gamename and svo.dict[action].gamename or action

  svo.sendcuringprio(gamename .. " " .. priority, istype, slow)
end

function sk.updateserversideprios()
--Don't do anything before we log in. Clear the timer on the way out, or
--nothing would ever start another sync
  if svo.logging_in then sk.priochangetimer = nil return end

  if not sk.priochangetimer then return end
  sk.updateserverwatch = sk.updateserverwatch or createStopWatch()
  startStopWatch(sk.updateserverwatch)

  -- don't notify of prio changes until the system is loaded, as they can get shuffled around a bit
  if not svo.systemloaded then sk.priochangetimer = nil return end
  local afterstate = sk.getafterstateprios()
  svo.debugf("sk.updateserverwatch sk.getafterstateprios: %s", getStopWatchTime(sk.updateserverwatch))

  local basictableindexdiff = svo.basictableindexdiff

  for balance, data in pairs(sk.priosbeforechange) do
    if balance == 'slowcuring' then
      sk.priochangecache[balance] = sk.priochangecache[balance] or {}
      local priochangecache = sk.priochangecache[balance]

      -- make the diff of snapshots
      local diffslow = basictableindexdiff(data.data, afterstate[balance].newdata)
      -- split the slowcuring actions into separate balances
      local diff = sk.splitbals(diffslow)

      -- get the new list of prios, sorted in importance
      local neworderslow = svo.prio.getsortedlist(balance)
      -- split the action_balance actions into separate balances
      local neworderbals = sk.splitbals(neworderslow)

      -- if not in slowcuring mode, switch to slowcuring prios first
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

              sk.sendpriorityswitch(action, balance, raffs, rdefs, priochangecache[balance], true)
            elseif rignoreaffs[action] or rignoredefs[action] then
              sk.sendpriorityignore(action, balance, rignoreaffs, rignoredefs, priochangecache[balance], true)
            end
          end
        end
      end
    else
      sk.priochangecache[balance] = sk.priochangecache[balance] or {}

      -- make the diff of snapshots
      local diff = basictableindexdiff(data.data, afterstate[balance].newdata)
      -- if next(diff) then svo.debugf("%s diff: %s", balance, pl.pretty.write(diff)) end
      -- get the new list of prios, sorted in importance
      local neworder = svo.prio.getsortedlist(balance)
      local affs, defs, ignoreaffs, ignoredefs = sk.splitdefs(balance, neworder)
      local raffs, rdefs, rignoreaffs, rignoredefs = {}, {}, {}, {}
      for index, aff in pairs(affs) do raffs[aff] = index end
      for index, def in pairs(defs) do rdefs[def] = index end
      for index, aff in pairs(ignoreaffs) do rignoreaffs[aff] = index end
      for index, def in pairs(ignoredefs) do rignoredefs[def] = index end
      
      -- update for the changes
      for _, action in pairs(diff) do
        -- check if this is something actually on prios. an aff could be ignored, a def not on keepup
        if raffs[action] or rdefs[action] then

          sk.sendpriorityswitch(action, balance, raffs, rdefs, sk.priochangecache[balance], false)
        elseif rignoreaffs[action] or rignoredefs[action] then
          sk.sendpriorityignore(action, balance, rignoreaffs, rignoredefs, sk.priochangecache[balance], false)
        end
      end
    end
  end

  sk.priochangetimer = nil

  -- save new state for next change
  svo.debugf("sk.updateserverwatch sk.getbeforestateprios: %s", getStopWatchTime(sk.updateserverwatch))
  sk.priosbeforechange = sk.getbeforestateprios()

  svo.debugf("sk.updateserverwatch: %s", stopStopWatch(sk.updateserverwatch))
end

-- splits slowcuring prios by balance
function sk.splitbals(list)
  local balances, valid_sync_action = {}, svo.valid_sync_action

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
  return (
    svo.ignore[action] or
    not svo.serverignore[action] or
    (not sys.deffing and defkeepup[defs.mode][action] == false) or
    (sys.deffing and defdefup[defs.mode][action] == false) or
    (svo.dict[action].onservereignore and svo.dict[action].onservereignore())
  ) -- false so afflictions are okay, which are a nil
end
svo.shouldignoreserverside = sk.shouldignoreserverside

function sk.handleserversideswitch()
  if not sk.priochangetimer then
    sk.priochangetimer = tempTimer(0, function() sk.updateserversideprios() end)
  end
end

function sk.handleserversideswitch_keepup(defmode, action)
  if not svo.dict[action] then return end

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
  local defslist, disableddefs, disabledaffs, dict, defmode = {}, {}, {}, svo.dict, svo.defs.mode

  -- prune list to only be a list of affs, save defs and disable defs into another list
  -- iterate backwards, so we can remove items from the list safely
  for i = #list, 1, -1 do
    local action = list[i]

    -- take care of defs
    if dict[action][balance].def then
      -- check that it's not undeffable in-game and on keepup
      if not dict[action][balance].undeffable and 
			  ((sys.deffing and defdefup[defmode][action]) or 
				(not sys.deffing and defkeepup[defmode][action])) and not 
				sk.shouldignoreserverside(action) then
				
          defslist[i] = list[i]
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

  return list, defslist, disabledaffs, disableddefs
end


-- gets a snapshot of priorities, skipping actions that should be ignored
function sk.getbeforestateprios()
  local beforestate = {}
  local importables = {
    'herb',
    'smoke',
    'salve',
    'sip',
    'purgative',
    'physical',
    'moss',
    'misc',
    'slowcuring',
  }

  local make_prio_tablef = svo.make_prio_tablef

  for _, balance in ipairs(importables) do
    beforestate[balance] = {}

    if balance == 'slowcuring' then
      -- get the before state for diffing
      local data = svo.make_sync_prio_tablef("%s_%s", function(action)
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
    'herb',
    'smoke',
    'salve',
    'sip',
    'purgative',
    'physical',
    'moss',
    'misc',
    'slowcuring',
  }
  local make_prio_tablef = svo.make_prio_tablef

  for _, balance in ipairs(importables) do
    beforestate[balance] = {}

    if balance == 'slowcuring' then
      -- get the before state for diffing
      local data = svo.make_sync_prio_tablef("%s_%s", nil, { focus = true })
      -- set all prios to negative, so things get set or ignored serverside properly
      local nullify, c = {}, -1
      for _,v in pairs(data) do nullify[c] = v; c = c - 1 end
      beforestate[balance] = {data = nullify}
    else
      -- get the before state for diffing
      local data = make_prio_tablef(balance)
      -- set all prios to negative, so things get set or ignored serverside properly
      local nullify, c = {}, -1
      for _,v in pairs(data) do nullify[c] = v; c = c - 1 end
      beforestate[balance] = {data = nullify}
    end
  end

  return beforestate
end

function sk.getafterstateprios()
  local afterstate = {}
  local importables = {
    'herb',
    'smoke',
    'salve',
    'sip',
    'purgative',
    'physical',
    'moss',
    'misc',
    'slowcuring',
  }

  local make_prio_tablef = svo.make_prio_tablef

  for _, balance in ipairs(importables) do
    afterstate[balance] = {}

    if balance == 'slowcuring' then
      -- get the new state
      local newdata = svo.make_sync_prio_tablef("%s_%s", function(action)
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
  local basictableindexdiff = svo.basictableindexdiff
	local raiseEvent = raiseEvent

  -- don't notify of prio changes until the system is loaded, as they can get shuffled around a bit
  if not svo.systemloaded then return end

  for balance, data in pairs(beforestate) do
    if balance == 'slowcuring' then
      -- make the diff of snapshots
      local diff = basictableindexdiff(data.data, afterstate[balance].newdata)
      local valid_sync_action = svo.valid_sync_action

      -- now only notify for the differences. An action taken out, such as
      -- a defence the player defined and deleted, is in the before state
      -- only, and there is nothing to change for it
      for _, a in pairs(diff) do
        -- not balance: the number is in slowcuring's snapshot, not the entry's own balance's
        local valid, action, syncbalance = valid_sync_action(a)
        if valid then
          raiseEvent("svo prio changed", action, syncbalance, afterstate[balance].action_prio[a], 'slowcuring')
        end
      end
    else
      -- make the diff of snapshots
      local diff = basictableindexdiff(data.data, afterstate[balance].newdata)

      -- notify only for the changes
      for _, a in pairs(diff) do
        if svo.dict[a] then
          raiseEvent("svo prio changed", a, balance, afterstate[balance].action_prio[a])
        end
      end
    end
  end
end


-- returns an alphabetically sorted, indexed list of all actions serverside can do
function sk.getallserversideactions()
  local type = type

  local actions = {}
  for action, balances in pairs(svo.dict) do
    for balance, data in pairs(balances) do
      if type(data) == 'table' and balance ~= 'waitingfor' and balance ~= 'aff' and balance ~= 'gone' and balance ~= 'happened' and not data.uncurable and not data.undeffable then
        actions[action] = true
      end
    end
  end

  local actionslist = {}
  for k,_ in pairs(actions) do
    actionslist[#actionslist+1] = k
  end

  table.sort(actionslist)

  return actionslist
end

--[[ reading the game's own affliction priorities ]]

-- What the game says its affliction priorities are, read from CURING PRIORITY
-- LIST and from the lines that answer a change. Only custom mode uses it
-- (vconfig serverprios custom, below).
--   sets       curingset name -> { [entry] = number }, with each entry named
--              as the list names it: 'paralysis', or 'unweavingmind(2)' for
--              exactly two stacks. Afflictions svof has no action for are
--              kept too. A set is here only once its whole list was read
--   active     the curingset in use, once the game has said which: in a
--              switch, or in a list's header
--   maxstacks  the game's affliction name -> the most stacks it said it has
--   list       the list being read, and reader, the trigger reading it
sk.serverread = sk.serverread or {sets = {}, maxstacks = {}}

local serverlist_header = "^Your affliction curing priorities for the priority set (%w+):$"
local serverlist_footer = "Affs with priority 26 are ignored."
-- a list is 26 levels and their wraps; past this, something else is being read
local serverlist_longest = 100

-- 'paralysis' gives paralysis, 'unweavingmind(2)' gives unweavingmind and 2,
-- and anything that isn't an entry gives nil
function sk.serverentry(entry)
  local name, stack = entry:match("^([%w_]+)%((%d+)%)$")
  if name then return name, tonumber(stack) end
  if entry:match("^[%w_]+$") then return entry end
end

local function serverlist_stop()
  local read = sk.serverread
  read.list = nil
  if read.reader then killTrigger(read.reader); read.reader = nil end
end

-- files the open level's entries, false if one of them isn't an entry or was
-- already listed
local function serverlist_closelevel(list)
  if not list.level then return true end

  -- the game wraps a long level at the screen width, so the entries are
  -- split only after joining. A level with nothing on it is an empty line
  for listed in table.concat(list.text, " "):gmatch("[^,]+") do
    local entry = listed:match("^%s*(.-)%s*$")
    if entry ~= "" then
      if not sk.serverentry(entry) or list.entries[entry] then return false end
      list.entries[entry] = list.level
    end
  end

  list.level, list.text = nil, nil
  return true
end

-- every line after a list's header. The set is kept only when the footer
-- arrives with every line before it read, so a list that is cut short, or
-- that something else lands in, changes nothing
function sk.serverlist_line(text, isprompt)
  local read = sk.serverread
  local list = read.list
  if not list or isprompt then serverlist_stop() return end

  if text == "" then return end
  -- the reader can be handed the header that started it
  if not list.level and not next(list.entries) and text:match(serverlist_header) then return end

  list.lines = list.lines + 1
  if list.lines > serverlist_longest then serverlist_stop() return end

  if text == serverlist_footer then
    -- a list svof asked for is hidden, and the prompt after it
    if list.asked then svo.deleteLineP() end
    local whole = serverlist_closelevel(list) and next(list.entries)
    if whole then read.sets[list.set] = list.entries end
    serverlist_stop()
    if whole then sk.serverlist_read(list.set, list.asked) end
    return
  end

  if list.asked then deleteLine() end

  local level, rest = text:match("^(%d+):%s*(.*)$")
  if level then
    level = tonumber(level)
    if not serverlist_closelevel(list) or level < 1 or level > 26 or list.levels[level] then
      serverlist_stop()
      return
    end
    list.level, list.text, list.levels[level] = level, {rest}, true
  elseif list.level then
    -- a wrapped level carries on without a number
    list.text[#list.text+1] = text
  else
    serverlist_stop()
  end
end

-- the game's lines about its affliction priorities, other than a list's own:
-- a list's header, a curingset switch, a changed entry, a stack the
-- affliction can't have, and a reset
function sk.serverprio_line(text)
  local read = sk.serverread

  local set = text:match(serverlist_header)
  if set then
    serverlist_stop()
    -- the game lists the curingset in use, and names it
    read.active = set:lower()
    read.list = {set = read.active, entries = {}, levels = {}, lines = 0}
    -- why svof asked for this set's list, if it did
    if read.asked and read.asked[read.active] then
      read.list.asked = read.asked.why
      deleteLine()
    end
    read.reader = tempRegexTrigger("^", "svo.sk.serverlist_line(line, isPrompt())")
    return
  end

  set = text:match("^You will now cure using the (%w+) set%.$")
  if set then
    read.active = set:lower()
    return
  end

  local entry, number = text:match("^You have set the '(.-)' affliction to the (%d+) priority%.$")
  if entry then
    number = tonumber(number)
    -- only into a set that was read whole: one entry alone would pass for
    -- knowing the set, and without the set in use there is nowhere to put it
    local entries = read.active and read.sets[read.active]
    if entries and sk.serverentry(entry) and number >= 1 and number <= 26 then
      entries[entry] = number
    end
    if read.active and sk.serverentry(entry) and number >= 1 and number <= 26 then
      sk.serverprios_confirmed(read.active, entry, number)
    end
    return
  end

  local aff, most = text:match("^The (%w+) affliction can only have up to (%d+) stacks%.$")
  if aff then
    read.maxstacks[aff] = tonumber(most)
    sk.serverprios_stacklimit(aff, tonumber(most))
    return
  end

  if text == "All your curing affliction priorities have been reset to defaults." then
    -- the game resets only the curingset in use, stack entries included, and
    -- its defaults aren't known until the list is read again. Without the
    -- set in use, any of them could be the one that was reset
    serverlist_stop()
    if read.active then
      read.sets[read.active] = nil
    else
      read.sets = {}
    end
    -- the player's own numbers are the game's defaults now: read them, and
    -- then put back at 26 what svof keeps there
    if sk.customserverprios() then sk.serverprios_ask('reset') end
  end
end

-- names svof sends that the game takes and lists under another: CURING
-- PRIORITY BLIND 26 answers "You have set the 'blindness' affliction"
sk.serverlistnames = {blind = 'blindness', deaf = 'deafness'}

-- the name the game's priority list has for each affliction action, and the
-- action each of its names stands for. An action the game names another way
-- when it reports afflictions (sstosvoa) is found by that name too. Where two
-- actions have one name, the one the game reports it as has it: the game's
-- lovers is the lover's curse, svof's inlove. svof's lovers action is lust,
-- which the game handles with CURING REJECTION and not with a priority
function sk.serverprionames()
  local toserver, toaction = {}, {}

  for ssa, svoa in pairs(svo.dict.sstosvoa) do
    if type(svoa) == 'string' then toaction[ssa] = svoa end
  end

  for action, entry in pairs(svo.dict) do
    if type(entry) == 'table' and type(entry.aff) == 'table' and not entry.aff.notagameaff then
      local name = entry.gamename or action
      name = sk.serverlistnames[name] or name
      if not toaction[name] or toaction[name] == action or not svo.dict.sstosvoa[name] then
        toserver[action] = name
        toaction[name] = action
      end
    end
  end

  return toserver, toaction
end

-- the entries of a read set that svof has no action for, sorted
function sk.serverunmapped(set)
  local _, toaction = sk.serverprionames()
  local unmapped = {}

  for entry in pairs(sk.serverread.sets[set] or {}) do
    if not toaction[(sk.serverentry(entry))] then unmapped[#unmapped+1] = entry end
  end

  table.sort(unmapped)
  return unmapped
end

--[[ the player's own affliction priorities: vconfig serverprios custom ]]

-- In custom mode svof doesn't work out the game's affliction priorities from
-- its own lists. svo.serverprios holds the player's numbers for each
-- curingset, taken from the game's list and kept up from the lines confirming
-- a change, so a number set in game stays. svof still keeps at 26 what it
-- cures itself or is told to ignore, and gives the player's number back
-- afterwards. Defence priorities are svof's in both modes.

function sk.customserverprios()
  return (conf.serverside and conf.serverprios == 'custom') and true or false
end

local serversets = {'normal', 'slowcuring'}

-- whether svof keeps an affliction action at 26 on the server: the test the
-- sync uses for the afflictions it sends 26 for (sk.splitdefs)
local function serverkeeps26(action)
  local entry = svo.dict[action]
  return (entry and entry.aff and sk.shouldignoreserverside(action)) and true or false
end

-- the number auto mode gives each affliction action in a curingset: its place
-- in its balance's list, 25 at most. For an action on several balances, the
-- most important place
function sk.autoserverprios(set)
  local numbers = {}

  local function place(balance, list)
    for i = 1, #list do
      local action = list[i]
      local entry = svo.dict[action]
      local onbalance = entry and entry[balance]
      if entry and type(entry.aff) == 'table' and not entry.aff.notagameaff and type(onbalance) == 'table'
        and not onbalance.def and not onbalance.uncurable and not onbalance.irregular then
        local number = i > 25 and 25 or i
        if not numbers[action] or number < numbers[action] then numbers[action] = number end
      end
    end
  end

  if set == 'slowcuring' then
    for balance, list in pairs(sk.splitbals(svo.prio.getsortedlist('slowcuring'))) do place(balance, list) end
  else
    for _, balance in ipairs({'herb', 'smoke', 'salve', 'sip', 'purgative', 'physical', 'moss', 'misc'}) do
      place(balance, svo.prio.getsortedlist(balance))
    end
  end

  return numbers
end

-- what svof last sent for each entry of each curingset, so a number isn't
-- sent again; emptied whenever the game's numbers may have moved without it
local function serverprios_forgetsent()
  sk.serverprios_sent = {normal = {}, slowcuring = {}}
end
serverprios_forgetsent()

-- what svof sent that the game hasn't confirmed yet, for each entry of each
-- curingset: the numbers in the order they went out, each with when. A
-- confirmation of one of them is svof's own send and not the player's edit.
-- One the game never confirms is dropped after a while, so a lost line or a
-- refused command doesn't leave it waiting
sk.serverprios_pending = {normal = {}, slowcuring = {}}
-- in seconds, long enough for a whole table paced under the game's limit
local serverpending_life = 60

local function serverprios_pend(set, entry, number)
  local pending = sk.serverprios_pending[set]
  pending[entry] = pending[entry] or {}
  local list = pending[entry]
  list[#list+1] = {number = number, at = getEpoch()}
end

-- whether a confirmed number is one svof sent. It and what was sent before it
-- stop waiting: the game confirms in the order sent, so those were lost
local function serverprios_unpend(set, entry, number)
  local pending = sk.serverprios_pending[set]
  local list = pending[entry]
  if not list then return false end

  local now, own = getEpoch(), false
  while list[1] and now - list[1].at > serverpending_life do table.remove(list, 1) end
  for i = 1, #list do
    if list[i].number == number then
      for _ = 1, i do table.remove(list, 1) end
      own = true
      break
    end
  end

  if not list[1] then pending[entry] = nil end
  return own
end

-- sends an entry's number to a curingset: unweavingmind(2) goes as
-- unweavingmind2
local function serverprios_sendentry(set, entry, number)
  local sent = sk.serverprios_sent[set]
  -- nil is an entry svof has no number for
  if not number or sent[entry] == number then return end
  sent[entry] = number

  local name, stack = sk.serverentry(entry)
  -- the name the game is known to take, which it confirms under the listed one
  for sendname, listname in pairs(sk.serverlistnames) do
    if listname == name then name = sendname end
  end
  local prio = name .. (stack or "") .. " " .. number
  -- the same entry and number already waiting this tick goes out only once,
  -- so it's confirmed only once
  local queue = set == 'slowcuring' and sk.affqueueslow or sk.affqueue
  if not table.contains(queue, " "..prio) then serverprios_pend(set, entry, number) end
  svo.sendcuringprio(prio, 'affliction', set == 'slowcuring')
end

-- afflictions the game has that its list can lack: a reset set's list has
-- neither
local serverunlisted = {blindness = true, deafness = true}

-- vignore <aff> <count> in custom mode: the server leaves one stack of a
-- counted affliction alone. svo.serverprios.stackignore has them by the game's
-- name, {unweavingmind = {[2] = true}}, for both curingsets. They never go
-- into svo.ignore, which every curing check takes as the whole affliction
local function serverstackignored(entry)
  local name, stack = sk.serverentry(entry)
  local ignored = stack and svo.serverprios.stackignore and svo.serverprios.stackignore[name]
  return (ignored and ignored[stack]) and true or false
end

-- the stack entries svof made in the game for a stack ignore, and that the
-- player never gave a number, for each curingset. The game can't remove a
-- stack entry, so one svof made follows the plain entry, as a stack without
-- its own entry does
local function servermade(set)
  svo.serverprios.made = svo.serverprios.made or {}
  svo.serverprios.made[set] = svo.serverprios.made[set] or {}
  return svo.serverprios.made[set]
end

-- the entries of a curingset that are an affliction's: its plain one, and its
-- stack entries in the table, made by svof, or ignored. A name the table
-- doesn't have is one the game might not know, so svof sends nothing for it,
-- bar the ones the list can lack
local function serverprios_entriesof(set, name)
  local numbers, seen, entries = svo.serverprios[set], {}, {}
  local function add(entry)
    if not seen[entry] then seen[entry] = true; entries[#entries+1] = entry end
  end

  if numbers[name] or serverunlisted[name] then add(name) end
  for _, from in ipairs({numbers, servermade(set)}) do
    for entry in pairs(from) do
      local entryname, stack = sk.serverentry(entry)
      if stack and entryname == name then add(entry) end
    end
  end
  local ignored = svo.serverprios.stackignore and svo.serverprios.stackignore[name]
  for stack in pairs(ignored or {}) do add(name .. "(" .. stack .. ")") end
  return entries
end

-- Tactical overrides: numbers svof moves for a while on top of the table, and
-- gives back afterwards. They never go into the table. pva, avs and pvd each
-- swap two afflictions' numbers and stay on until used again, a restart
-- included. svo.serverprios.toggles has them in the order they went on, and a
-- later one swaps what the earlier ones left. Autoslick puts asthma first
sk.serverswaps = {
  pva = {'paralysis', 'asthma'},
  avs = {'slickness', 'impatience'},
  pvd = {'paralysis', 'darkshade'},
}

-- the curingsets autoslick has put asthma first in
sk.serverslick = {}

-- the number a tactical override gives each plain entry of a curingset it
-- moves. A 26 svof keeps an affliction at still comes first
local function serverprios_moved(set, toserver)
  local numbers = svo.serverprios[set] or {}
  local moved = {}
  local function now(entry) return moved[entry] or numbers[entry] end

  for _, toggle in ipairs(svo.serverprios.toggles or {}) do
    local pair = sk.serverswaps[toggle]
    local a, b = pair and toserver[pair[1]], pair and toserver[pair[2]]
    local na, nb = a and now(a), b and now(b)
    if na and nb then moved[a], moved[b] = nb, na end
  end

  local asthma = toserver.asthma
  if sk.serverslick[set] and asthma and numbers[asthma] then
    -- what is first makes room, so asthma is first alone
    local first = {}
    for entry in pairs(numbers) do
      if entry ~= asthma and not select(2, sk.serverentry(entry)) and now(entry) == 1 then first[#first+1] = entry end
    end
    for _, entry in ipairs(first) do moved[entry] = 2 end
    moved[asthma] = 1
  end

  return moved
end

-- the number the game should have for an entry of a curingset: 26 for what
-- svof keeps there and for an ignored stack, else a tactical override's, else
-- the table's. A stack entry svof made has its plain entry's. action, when
-- given, is the entry's, so toaction isn't needed
local function serverprios_want(set, entry, toaction, moved, action)
  local name, stack = sk.serverentry(entry)
  action = action or toaction[name]
  if action and serverkeeps26(action) then return 26 end
  if stack and serverstackignored(entry) then return 26 end

  local numbers = svo.serverprios[set]
  if moved[entry] or numbers[entry] then return moved[entry] or numbers[entry] end
  if stack and servermade(set)[entry] then return moved[name] or numbers[name] end
end

-- every action svof keeps at 26, and every affliction with a stack ignored
local function serverprios_overridden(toserver, toaction)
  local actions = {}
  for action in pairs(toserver) do
    if serverkeeps26(action) then actions[action] = true end
  end
  for name in pairs(svo.serverprios.stackignore or {}) do
    if toaction[name] then actions[toaction[name]] = true end
  end
  return actions
end

-- what the tactical overrides moved when they were last sent, for each
-- curingset, so an entry they stop moving gets its number back
sk.serverprios_lastmoved = {normal = {}, slowcuring = {}}

-- sends what the tactical overrides move now, and gives back what they no
-- longer do
function sk.serverprios_applymoves()
  if not sk.customserverprios() or svo.logging_in then return end

  local toserver, toaction = sk.serverprionames()
  for _, set in ipairs(serversets) do
    local numbers = svo.serverprios[set]
    if numbers and next(numbers) then
      local moved = serverprios_moved(set, toserver)
      local touched = {}
      for entry in pairs(sk.serverprios_lastmoved[set]) do touched[entry] = true end
      for entry in pairs(moved) do touched[entry] = true end
      sk.serverprios_lastmoved[set] = moved

      for entry in pairs(touched) do
        local want = serverprios_want(set, entry, toaction, moved)
        if want then serverprios_sendentry(set, entry, want) end
      end
    end
  end
end

-- pva, avs and pvd in custom mode: the swap of svof's own list happens as it
-- always has, and this one moves the server's numbers
function sk.serverprios_toggle(name)
  local pair = sk.serverswaps[name]
  if not pair or not sk.customserverprios() then return end

  local toggles = svo.serverprios.toggles or {}
  svo.serverprios.toggles = toggles
  local on = true
  for i = #toggles, 1, -1 do
    if toggles[i] == name then table.remove(toggles, i); on = false end
  end
  if on then toggles[#toggles+1] = name end

  signals.saveconfig:emit()
  sk.serverprios_applymoves()

  if on then
    svo.echof("Swapped the serverside numbers of %s and %s, until you use %s again.", pair[1], pair[2], name)
  else
    svo.echof("Gave %s and %s their own serverside numbers back.", pair[1], pair[2])
  end
end

-- autoslick in custom mode. With asthma and slickness, and paralysis or
-- impatience at asthma's number or before it, the server cures asthma first,
-- until slickness or asthma is gone. As with svof's own lists, two
-- afflictions alone don't need it
function sk.serverprios_autoslick()
  if not sk.customserverprios() then return end

  local affl = svo.affl
  local both = conf.autoslick and affl.slickness and affl.asthma
  local toserver, toaction
  local on, off = false, false

  for _, set in ipairs(serversets) do
    local numbers = svo.serverprios[set]
    if not both then
      if sk.serverslick[set] then sk.serverslick[set] = nil; off = true end
    elseif not sk.serverslick[set] and numbers and next(numbers) and table.size(affl) > 2 then
      if not toserver then toserver, toaction = sk.serverprionames() end
      local moved = serverprios_moved(set, toserver)
      local function now(action)
        local entry = toserver[action]
        return entry and serverprios_want(set, entry, toaction, moved)
      end
      local asthma, paralysis, impatience = now('asthma'), now('paralysis'), now('impatience')
      if asthma and asthma < 26 and ((paralysis and paralysis <= asthma) or (impatience and impatience <= asthma)) then
        sk.serverslick[set] = true
        on = true
      end
    end
  end

  if not on and not off then return end
  sk.serverprios_applymoves()
  if on then
    echo'\n' svo.echof("Asthma and slickness, with paralysis or impatience before asthma: the server cures asthma first for now.")
  else
    echo'\n' svo.echof("Gave asthma its serverside number back.")
  end
end

-- vignore <aff> <count>: the server leaves one stack of an affliction alone,
-- or cures it again
function sk.serverprios_stackignore(action, count)
  if not sk.customserverprios() then
    svo.echof("Only serverside can ignore one stack of an affliction, and Svof does that in custom mode "
      .."(vconfig serverprios custom). vignore %s ignores all of it.", tostring(action))
    return
  end

  local toserver = sk.serverprionames()
  local entry, name = svo.dict[action], toserver[action]
  if not (entry and entry.count ~= nil and name) then
    svo.echof("Svof doesn't count stacks of %s, so it has no stack to ignore.", tostring(action))
    return
  end
  if not svo.serverignore[action] then
    svo.echof("Svof cures %s itself, and its own curing can't tell stacks apart. To ignore one stack, leave "
      .."%s to serverside first (vshow serverside).", action, action)
    return
  end
  if count < 2 then
    svo.echof("Stack 1 is %s's plain entry, which also stands for every stack without a number of its own. "
      .."vignore %s ignores all of it.", action, action)
    return
  end
  local most = sk.serverread.maxstacks[name]
  if most and count > most then
    svo.echof("%s can only have up to %d stacks.", action, most)
    return
  end

  svo.serverprios.stackignore = svo.serverprios.stackignore or {}
  local stacks = svo.serverprios.stackignore[name] or {}
  svo.serverprios.stackignore[name] = stacks
  local on = not stacks[count]
  stacks[count] = on or nil
  if not next(stacks) then svo.serverprios.stackignore[name] = nil end
  if not next(svo.serverprios.stackignore) then svo.serverprios.stackignore = nil end

  -- the game has no entry for that stack yet, so svof makes one
  local stackentry = name .. "(" .. count .. ")"
  if on then
    for _, set in ipairs(serversets) do
      if not (svo.serverprios[set] or {})[stackentry] then servermade(set)[stackentry] = true end
    end
  end

  signals.saveconfig:emit()
  sk.serverprios_refresh(action, toserver)

  if on then
    svo.echof("The server won't cure %s at %d stacks now. Use vignore %s %d again to undo it.", action, count, action, count)
  else
    svo.echof("The server cures %s at %d stacks again.", action, count)
  end
end

-- the game refused a stack number: it says how many stacks the affliction
-- can have, so an ignore of a stack past that goes
function sk.serverprios_stacklimit(name, most)
  local stacks = svo.serverprios.stackignore and svo.serverprios.stackignore[name]
  if not stacks then return end

  local dropped = {}
  for stack in pairs(stacks) do
    if stack > most then
      stacks[stack] = nil
      dropped[#dropped+1] = stack
      for _, set in ipairs(serversets) do servermade(set)[name .. "(" .. stack .. ")"] = nil end
    end
  end
  if not next(stacks) then svo.serverprios.stackignore[name] = nil end
  if not next(svo.serverprios.stackignore) then svo.serverprios.stackignore = nil end
  if not dropped[1] then return end

  table.sort(dropped)
  signals.saveconfig:emit()
  svo.echof("The game says %s can only have up to %d stacks, so Svof stopped ignoring stack %s.", name, most,
    table.concat(dropped, ", "))
end

-- the stack ignores, for vshow ignore: {name, stack, action}, sorted
function sk.serverprios_stackignores()
  local _, toaction = sk.serverprionames()
  local list = {}
  for name, stacks in pairs(svo.serverprios.stackignore or {}) do
    for stack in pairs(stacks) do list[#list+1] = {name, stack, toaction[name] or name} end
  end
  table.sort(list, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
  return list
end

-- sends an action's entries what they should have now, in both curingsets:
-- 26 while svof keeps the affliction there or ignores a stack, and the
-- player's numbers otherwise
function sk.serverprios_refresh(action, toserver)
  if not sk.customserverprios() or svo.logging_in then return end

  toserver = toserver or sk.serverprionames()
  local name = toserver[action]
  if not name then return end

  local keeps26 = serverkeeps26(action)
  for _, set in ipairs(serversets) do
    local numbers = svo.serverprios[set]
    -- a set that was never read has no numbers to give back
    if numbers and next(numbers) then
      local moved = keeps26 and {} or serverprios_moved(set, toserver)
      for _, entry in ipairs(serverprios_entriesof(set, name)) do
        local want = serverprios_want(set, entry, nil, moved, action)
        if want then
          serverprios_sendentry(set, entry, want)
        elseif sk.serverprios_sent[set][entry] == 26 then
          -- svof put it at 26 and the player never gave it a number
          local auto = sk.autoserverprios(set)[action]
          if auto then serverprios_sendentry(set, entry, auto) end
        end
      end
    end
  end
end

-- sends both curingsets the whole table, with the tactical overrides, and 26
-- for what svof keeps there
function sk.serverprios_send()
  if not sk.customserverprios() or svo.logging_in then return end

  serverprios_forgetsent()
  local toserver, toaction = sk.serverprionames()

  for _, set in ipairs(serversets) do
    local moved = serverprios_moved(set, toserver)
    sk.serverprios_lastmoved[set] = moved
    for entry in pairs(svo.serverprios[set] or {}) do
      serverprios_sendentry(set, entry, serverprios_want(set, entry, toaction, moved))
    end
  end

  for action in pairs(serverprios_overridden(toserver, toaction)) do sk.serverprios_refresh(action, toserver) end
end

-- takes a curingset's numbers as the game listed them. A 26 on an affliction
-- svof keeps at 26 is svof's and not the player's, so that entry keeps the
-- number the table had or, with fresh set, gets auto's. With fresh set, a
-- stack entry the table had and the game doesn't is sent again: auto mode's
-- reset clears them
function sk.serverprios_take(set, entries, fresh)
  local toserver, toaction = sk.serverprionames()
  local old = svo.serverprios[set] or {}
  local new, auto = {}, nil
  -- a number a tactical override moved is svof's, not the player's. After
  -- auto mode the game has auto's numbers, which no override moved
  local moved = fresh and {} or serverprios_moved(set, toserver)
  local oldmade, made = servermade(set), {}

  for entry, number in pairs(entries) do
    local name, stack = sk.serverentry(entry)
    local action = toaction[name]
    -- what the game has, so it isn't sent again, unless svof sent it another
    -- number since it was asked for the list
    if not sk.serverprios_pending[set][entry] then sk.serverprios_sent[set][entry] = number end
    if number == 26 and action and serverkeeps26(action) then
      auto = auto or sk.autoserverprios(set)
      if fresh then
        number = (not stack and auto[action]) or 26
      else
        number = old[entry] or (not stack and auto[action]) or 26
      end
    elseif moved[entry] and number == moved[entry] and old[entry] then
      number = old[entry]
    elseif stack and not old[entry] and (oldmade[entry] or serverstackignored(entry))
      and (number == 26 or number == entries[name]) then
      -- a stack entry svof made, at svof's 26 or at its plain entry's number
      number = nil
      made[entry] = true
    elseif number == 26 and serverstackignored(entry) then
      number = old[entry] or 26
    end
    new[entry] = number
  end

  -- an ignored stack the game lost to a reset is made again when it's sent
  for name, stacks in pairs(svo.serverprios.stackignore or {}) do
    for stack in pairs(stacks) do
      local entry = name .. "(" .. stack .. ")"
      if not new[entry] then made[entry] = true end
    end
  end

  svo.serverprios[set] = new
  svo.serverprios.made[set] = made

  if fresh then
    for entry, number in pairs(old) do
      local name, stack = sk.serverentry(entry)
      if stack and not new[entry] then
        new[entry] = number
        local action = toaction[name]
        serverprios_sendentry(set, entry, (action and serverkeeps26(action)) and 26 or number)
      end
    end
  end
end

-- asks the game for both curingsets' lists, the one in use last so it stays
-- in use. why is 'switch' when custom mode starts, 'reset' after a reset in
-- game, and 'login' to compare them with the table
function sk.serverprios_ask(why)
  local read = sk.serverread
  read.asked = {normal = true, slowcuring = true, why = why}
  read.logindiffs = nil

  if read.askedtimer then killTimer(read.askedtimer) end
  read.askedtimer = tempTimer(15, function()
    read.askedtimer = nil
    if not read.asked then return end
    read.asked = nil
    if why == 'login' then
      svo.echof("The game didn't list your serverside priorities, so Svof couldn't check them against its own.")
    else
      svo.echof("The game didn't list your serverside priorities, so Svof doesn't have them. "
        .."Use vconfig serverprios custom to ask again.")
    end
  end)

  local inuse, other = 'normal', 'slowcuring'
  if sys.sync then inuse, other = other, inuse end
  sendAll("curingset switch "..other, "curing priority list",
    "curingset switch "..inuse, "curing priority list", false)
end

local function serverprios_count(set)
  local count = 0
  for _ in pairs(svo.serverprios[set] or {}) do count = count + 1 end
  return count
end

-- where a listed curingset differs from what svof expects of it, sorted by
-- entry: {entry, the game's number, svof's}, with nil for a missing number.
-- svof expects its 26s and the tactical overrides that are on
local function serverprios_compare(set)
  local toserver, toaction = sk.serverprionames()
  local listed, numbers = sk.serverread.sets[set], svo.serverprios[set]
  local moved = serverprios_moved(set, toserver)
  local diffs = {}

  for entry, number in pairs(listed) do
    local expected = serverprios_want(set, entry, toaction, moved)
    if expected ~= number then diffs[#diffs+1] = {entry, number, expected} end
  end
  -- what svof expects that the game doesn't list: the table's entries, and
  -- the stack entries svof made or ignores
  local expected = {}
  for entry in pairs(numbers) do expected[entry] = true end
  for entry in pairs(servermade(set)) do expected[entry] = true end
  for name, stacks in pairs(svo.serverprios.stackignore or {}) do
    for stack in pairs(stacks) do expected[name .. "(" .. stack .. ")"] = true end
  end
  for entry in pairs(expected) do
    -- the list can lack these without the game having lost them
    if not listed[entry] and not serverunlisted[entry] then
      diffs[#diffs+1] = {entry, nil, serverprios_want(set, entry, toaction, moved)}
    end
  end

  table.sort(diffs, function(a, b) return a[1] < b[1] end)
  return diffs
end

local function serverprios_showdiffs(diffs)
  svo.echof("Your serverside priorities in the game aren't the ones Svof has:")
  for _, set in ipairs(serversets) do
    for _, diff in ipairs(diffs[set]) do
      svo.echof("  %s set: %s is %s in the game and %s in Svof.", set, diff[1],
        diff[2] or "missing", diff[3] or "missing")
    end
  end

  svo.echofn("Keep ")
  setFgColor(unpack(svo.getDefaultColorNums))
  setUnderline(true)
  echoLink("the game's", 'svo.sk.serverprios_keepgame()', "Take the game's numbers into Svof", true)
  setUnderline(false)
  echo(", or send ")
  setUnderline(true)
  echoLink("Svof's", 'svo.sk.serverprios_keepsvof()', "Send Svof's numbers to the game", true)
  setUnderline(false)
  echo(".\n")
end

-- after the login comparison: the game's numbers go into the table
function sk.serverprios_keepgame()
  local read = sk.serverread
  if not sk.customserverprios() or not read.sets.normal or not read.sets.slowcuring then
    svo.echof("Svof doesn't have both of the game's lists any more, so nothing changed.")
    return
  end

  for _, set in ipairs(serversets) do
    local entries = {}
    for entry, number in pairs(read.sets[set]) do entries[entry] = number end
    sk.serverprios_take(set, entries)
  end
  -- what svof keeps at 26 stays there, and the tactical overrides that are on
  -- stay on
  local toserver, toaction = sk.serverprionames()
  for action in pairs(serverprios_overridden(toserver, toaction)) do sk.serverprios_refresh(action, toserver) end
  sk.serverprios_applymoves()
  signals.saveconfig:emit()
  svo.echof("Kept the game's serverside priorities.")
end

-- after the login comparison: the game gets what svof expects it to have.
-- What only the game has goes into the table, since svof has no number to
-- send for it
function sk.serverprios_keepsvof()
  local read = sk.serverread
  if not sk.customserverprios() then return end

  local toserver, toaction = sk.serverprionames()
  for _, set in ipairs(serversets) do
    local numbers, made = svo.serverprios[set], servermade(set)
    for entry, number in pairs(read.sets[set] or {}) do
      if not numbers[entry] and not made[entry] and not serverstackignored(entry) then numbers[entry] = number end
    end
    -- what was sent stands for what the game listed, so only what differs goes
    local moved = serverprios_moved(set, toserver)
    sk.serverprios_lastmoved[set] = moved
    for _, from in ipairs({numbers, made}) do
      for entry in pairs(from) do
        serverprios_sendentry(set, entry, serverprios_want(set, entry, toaction, moved))
      end
    end
  end
  for action in pairs(serverprios_overridden(toserver, toaction)) do sk.serverprios_refresh(action, toserver) end
  signals.saveconfig:emit()
  svo.echof("Sent Svof's serverside priorities to the game.")
end

-- a curingset's whole list was read. asked is why svof asked for it, or nil
-- when the player did
function sk.serverlist_read(set, asked)
  local read = sk.serverread
  if asked and read.asked then read.asked[set] = nil end
  if not sk.customserverprios() then return end

  if asked == 'login' then
    -- what the game has, whatever svof makes of it
    sk.serverprios_sent[set] = {}
    for entry, number in pairs(read.sets[set]) do sk.serverprios_sent[set][entry] = number end

    -- the overrides that are on, so an entry they stop moving gets its number
    -- back
    sk.serverprios_lastmoved[set] = serverprios_moved(set, (sk.serverprionames()))
    read.logindiffs = read.logindiffs or {}
    read.logindiffs[set] = serverprios_compare(set)
    if read.asked and not read.asked.normal and not read.asked.slowcuring then
      read.asked = nil
      if read.askedtimer then killTimer(read.askedtimer); read.askedtimer = nil end
      if next(read.logindiffs.normal) or next(read.logindiffs.slowcuring) then
        serverprios_showdiffs(read.logindiffs)
      end
    end
    return
  end

  local entries = {}
  for entry, number in pairs(read.sets[set]) do entries[entry] = number end
  sk.serverprios_sent[set] = {}
  sk.serverprios_take(set, entries, asked == 'switch')

  -- put at 26 what svof keeps there and the list had elsewhere: all of it
  -- after a reset, and little or nothing after auto mode's own numbers
  local toserver, toaction = sk.serverprionames()
  for action in pairs(serverprios_overridden(toserver, toaction)) do sk.serverprios_refresh(action, toserver) end
  -- and the tactical overrides that are on, which a reset or auto mode undid
  sk.serverprios_applymoves()

  if asked and read.asked and not read.asked.normal and not read.asked.slowcuring then
    read.asked = nil
    if read.askedtimer then killTimer(read.askedtimer); read.askedtimer = nil end
    signals.saveconfig:emit()

    if asked == 'switch' then
      svo.echof("Took your serverside priorities from the game: %d in the normal set and %d in the slowcuring "
        .."set. Svof leaves them as you set them, and only keeps at 26 what it cures itself or ignores.",
        serverprios_count('normal'), serverprios_count('slowcuring'))
    elseif asked == 'reset' then
      svo.echof("Your serverside priorities were reset, so Svof read them again and put back at 26 what it "
        .."cures itself or ignores.")
    end
  end
end

-- the game confirmed a changed entry of a curingset. svof's own sends aren't
-- the player's edits, and neither is a 26 on an affliction svof keeps at 26:
-- that one is svof's too, confirmed after it stopped waiting
function sk.serverprios_confirmed(set, entry, number)
  if not sk.customserverprios() then return end

  local numbers = svo.serverprios[set]
  if not numbers or not next(numbers) then return end

  local own = serverprios_unpend(set, entry, number)
  -- with more of svof's sends on the way, the game won't keep this number
  local settled = not sk.serverprios_pending[set][entry]
  if settled then sk.serverprios_sent[set][entry] = number end

  local toserver, toaction = sk.serverprionames()
  local name, stack = sk.serverentry(entry)
  local action = toaction[name]
  local keeps26 = (action and serverkeeps26(action)) or (stack and serverstackignored(entry)) or false

  local edited = not own and not (keeps26 and number == 26)
  local moved = serverprios_moved(set, toserver)
  if edited then
    numbers[entry] = number
    -- the player gave a stack entry svof made a number of their own
    servermade(set)[entry] = nil
    -- the override's number for it can come from the player's new one
    moved = serverprios_moved(set, toserver)
    if moved[entry] then
      svo.echof("%s's serverside number is %d, and Svof keeps it at %d while %s.", entry, number, moved[entry],
        sk.serverslick[set] and entry == toserver.asthma and "autoslick has asthma first" or "a swap is on (pva, avs, pvd)")
    end
  end

  -- the game should have svof's 26, an override's number, or else the
  -- player's: an edit of something svof keeps at 26 goes back to 26, and an
  -- edit that crossed svof's own send gets the player's number back
  if settled then
    local want = serverprios_want(set, entry, toaction, moved)
    if want and want ~= number then serverprios_sendentry(set, entry, want) end
    -- the stack entries svof made for a plain entry follow its number
    if not stack then
      for made in pairs(servermade(set)) do
        local follows = sk.serverentry(made) == name and serverprios_want(set, made, toaction, moved)
        if follows then serverprios_sendentry(set, made, follows) end
      end
    end
  end
  -- an entry swapped with this one takes the player's new number
  if edited then sk.serverprios_applymoves() end
end

-- drops the sync's memory of what it sent, so the next one sends everything
local function serverprios_forgetsync()
  for balance in pairs(sk.priochangecache) do
    if balance ~= 'special' then sk.priochangecache[balance] = nil end
  end
  sk.priosbeforechange = sk.getblankbeforestateprios()
end

-- vconfig serverprios: does the switch and says what it did
function sk.serverpriosmode()
  -- autoslick starts again from the afflictions, in the new mode's numbers
  sk.serverslick = {}

  if conf.serverprios == 'custom' then
    if not conf.serverside then
      svo.echof("Svof will keep your own serverside priorities once serverside is on (tn serverside).")
      return
    end

    svo.echof("Reading your serverside priorities from the game...")
    serverprios_forgetsent()
    sk.serverprios_ask('switch')
    return
  end

  if not conf.serverside then
    svo.echof("Svof will work out your serverside priorities from its own lists once serverside is on.")
    return
  end

  local stacks = false
  for _, set in ipairs(serversets) do
    for entry in pairs(svo.serverprios[set] or {}) do
      if select(2, sk.serverentry(entry)) then stacks = true end
    end
  end

  -- only custom mode ignores single stacks: they get their numbers back. The
  -- set in use is reset next, so only the other one needs them sent
  local stackignores = sk.serverprios_stackignores()
  local other = sys.sync and 'normal' or 'slowcuring'
  local numbers = svo.serverprios[other] or {}
  for _, ignored in ipairs(stackignores) do
    local name, entry = ignored[1], ignored[1] .. "(" .. ignored[2] .. ")"
    local number = numbers[entry] or numbers[name]
    if number and next(numbers) then serverprios_sendentry(other, entry, number) end
  end
  svo.serverprios.stackignore = nil

  -- what vconfig serverside on does for priorities
  serverprios_forgetsync()
  sk.sendpriocommand("curing PRIORITY RESET", "current")
  sk.priochangetimer = true
  sk.updateserversideprios()

  svo.echof("Svof works out your serverside priorities from its own lists again.")
  if stackignores[1] then
    svo.echof("Only custom mode ignores single stacks, so the server cures every stack again.")
    signals.saveconfig:emit()
  end
  if stacks then
    svo.echof("The stack priorities you set are gone from the %s set, which was reset, and stay in the other. "
      .."Svof sends them again if you go back to custom.", sys.sync and "slowcuring" or "normal")
  end
end

-- keep at 26, or give the player's number back, as what svof cures and
-- ignores changes. These pass the action that changed
local function serverprios_changed(action)
  if type(action) ~= 'string' or not svo.dict[action] then return end
  sk.serverprios_refresh(action)
end
signals["svo ignore changed"]:connect(serverprios_changed, "keep or give back a custom server priority")
signals["svo serverignore changed"]:connect(serverprios_changed, "keep or give back a custom server priority")

-- a few afflictions are kept at 26 by their own rule, which goes by keepup
-- and defup: blindness and deafness while they are kept as defences, burning
-- for a fire elemental
local function serverprios_ruleschanged()
  if not sk.customserverprios() then return end
  for action, entry in pairs(svo.dict) do
    if type(entry) == 'table' and entry.aff and entry.onservereignore then sk.serverprios_refresh(action) end
  end
end
for _, event in ipairs({"svo keepup changed", "svo switched defence mode", "svo done defup"}) do
  signals[event]:connect(serverprios_ruleschanged, "keep or give back custom server priorities by rule")
end

-- at login, check the game's numbers against the table: they can have been
-- changed from another client, or while svof was off
function sk.serverprios_login()
  -- the afflictions autoslick went by are gone with the old session
  sk.serverslick = {}
  if not sk.customserverprios() then return end
  if next(svo.serverprios.normal or {}) and next(svo.serverprios.slowcuring or {}) then
    sk.serverprios_ask('login')
  else
    -- custom was chosen while serverside was off, so there are none yet
    sk.serverprios_ask('switch')
  end
end

-- logging in is when svo.logging_in, set on load and on connecting, goes
-- back to false
local serverprios_loggingin = false
signals.changecuring:connect(function()
  if svo.logging_in then
    serverprios_loggingin = true
  elseif serverprios_loggingin then
    serverprios_loggingin = false
    sk.serverprios_login()
  end
end, "check custom server priorities at login")

-- vconfig autoslick off gives asthma its number back
signals["svo config changed"]:connect(function(config)
  if config == 'autoslick' then sk.serverprios_autoslick() end
end, "autoslick in custom server priorities")

--[[ register all signals needed for this to work ]]

signals.sync:connect(function ()
  if not conf.serverside then return end

  if sys.sync then
    svo.sendc("curingset switch slowcuring")
  else
    svo.sendc("curingset switch normal")
  end
end, 'update curingset on aeon/retardation')

-- vconfig serverside
signals["svo config changed"]:connect(function(config)
  if config ~= 'serverside' then return end

  if conf.serverside then
    sk.priochangecache = {
      special = {
        focustoggle = conf.focus
      }
    }
    -- sync everything
    sk.priosbeforechange = sk.getblankbeforestateprios()
    if not sk.customserverprios() then
      sk.sendpriocommand("curing PRIORITY RESET", "current")
    elseif next(svo.serverprios.normal or {}) and next(svo.serverprios.slowcuring or {}) then
      -- the player's own numbers, and 26 for what svof keeps there
      sk.serverprios_send()
    else
      -- custom was chosen while serverside was off, so there are none yet
      sk.serverprios_ask('switch')
    end
    sk.priochangetimer = true
    sk.updateserversideprios()
    -- sync all special things like health
    for _, actiont in pairs(svo.dict) do
      for _, balancet in pairs(actiont) do
        if type(balancet) == 'table' and balancet.onprioswitch then
          balancet.onprioswitch()
        end
      end
    end

    -- initial sync of some config options.
    local option
    for _, optionname in ipairs({'healthaffsabove', 'mosshealth', 'mossmana'}) do
      if conf[optionname] == true then option = 'on'
      elseif conf[optionname] == false then option = 'off'
      else
        option = conf[optionname]
      end

      svo.sendcuring(optionname.. " "..option)
    end

    if conf.keepup then
      svo.sendcuring("defences on")
    else
      svo.sendcuring("defences off")
    end

    sk.togglefocusserver()
    sk.toggleclotserver()
    sk.toggleinsomniaserver()
    sk.sendfocuswith()

    if sk.canclot() and conf.clot then svo.sendcuring("clot on") else svo.sendcuring("clot off") end
    svo.sendcuring("clotat "..conf.bleedamount)

    if not svo.serverignore.healhealth then
      svo.sendcuring("siphealth 0")
      sk.priochangecache.special.healhealth = 0
    elseif svo.serverignore.healhealth then
      svo.sendcuring("siphealth "..conf.siphealth)
      sk.priochangecache.special.healhealth = conf.siphealth
    end

    if not svo.serverignore.healmana then
      svo.sendcuring("sipmana 0")
      sk.priochangecache.special.healmana = 0
    elseif svo.serverignore.healmana then
      svo.sendcuring("sipmana "..conf.sipmana)
      sk.priochangecache.special.healmana = conf.sipmana
    end

    if conf.curemethod == 'transonly' then
      svo.sendcuring("transmutation on")
       svo.sendcuring("fallback off")
    elseif conf.curemethod == 'conconly' then
      svo.sendcuring("transmutation off")
       svo.sendcuring("fallback off")
    elseif conf.curemethod == 'prefertrans' then
      svo.sendcuring("transmutation on")
      svo.sendcuring("fallback on")
    elseif conf.curemethod == 'preferconc' then
       svo.sendcuring("transmutation off")
       svo.sendcuring("fallback on")
    end

    svo.sendcuring("manathreshold "..conf.manause)
  end
end, 'update serverside prios on config change')

signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == 'healthaffsabove') then return end

  local option
  if conf.healthaffsabove == true then option = 'on'
  elseif conf.healthaffsabove == false then option = 'off'
  else
    option = conf.healthaffsabove
  end

  svo.sendcuring("healthaffsabove "..option)
end, 'update healthaffsabove')

for _, optionname in ipairs({'mosshealth', 'mossmana'}) do
  signals["svo config changed"]:connect(function(config)
    if not (conf.serverside and config == optionname) then return end

    local option
    if conf.moss then
      option = conf[optionname]
    else
      option = '0'
    end

    svo.sendcuring(optionname .." "..option)
  end, 'update serverside ' .. optionname)
end

-- vconfig moss
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == 'moss') then return end

  if conf.moss then
    svo.sendcuring("mosshealth ".. (conf.mosshealth or 0))
    svo.sendcuring("mossmana ".. (conf.mossmana or 0))
  else
    svo.sendcuring("mosshealth 0")
    svo.sendcuring("mossmana 0")
  end

end, 'update serverside moss use amount')

signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == 'clot') then return end

  if sk.canclot() and conf.clot and not sk.clotting_on_serverside then
    svo.sendcuring("clot on")
    sk.clotting_on_serverside = true
  elseif not (sk.canclot() and conf.clot) and sk.clotting_on_serverside then
    svo.sendcuring("clot off")
    sk.clotting_on_serverside = false
  end
end, 'update serverside clot')

-- healhealth / siphealth
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == 'siphealth') then return end

  if not svo.serverignore.healhealth and sk.priochangecache.special.healhealth ~= 0 then
    svo.sendcuring("siphealth 0")
    sk.priochangecache.special.healhealth = 0
  elseif svo.serverignore.healhealth and sk.priochangecache.special.healhealth ~= conf.siphealth then
    svo.sendcuring("siphealth "..conf.siphealth)
    sk.priochangecache.special.healhealth = conf.siphealth
  end
end, 'update serverside siphealth')
signals["svo serverignore changed"]:connect(function(config)
  if not (conf.serverside and config == 'healhealth') then return end

  if not svo.serverignore.healhealth and sk.priochangecache.special.healhealth ~= 0 then
    svo.sendcuring("siphealth 0")
    sk.priochangecache.special.healhealth = 0
  elseif svo.serverignore.healhealth and sk.priochangecache.special.healhealth ~= conf.siphealth then
    svo.sendcuring("siphealth "..conf.siphealth)
    sk.priochangecache.special.healhealth = conf.siphealth
  end
end, 'update serverside healhealth')

-- healmana / sipmana
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == 'sipmana') then return end

  if not svo.serverignore.healmana and sk.priochangecache.special.healmana ~= 0 then
    svo.sendcuring("sipmana 0")
    sk.priochangecache.special.healmana = 0
  elseif svo.serverignore.healmana and sk.priochangecache.special.healmana ~= conf.sipmana then
    svo.sendcuring("sipmana "..conf.sipmana)
    sk.priochangecache.special.healmana = conf.sipmana
  end
end, 'update serverside sipmana')
signals["svo serverignore changed"]:connect(function(config)
  if not (conf.serverside and config == 'healmana') then return end

  if not svo.serverignore.healmana and sk.priochangecache.special.healmana ~= 0 then
    svo.sendcuring("sipmana 0")
    sk.priochangecache.special.healmana = 0
  elseif svo.serverignore.healmana and sk.priochangecache.special.healmana ~= conf.sipmana then
    svo.sendcuring("sipmana "..conf.sipmana)
    sk.priochangecache.special.healmana = conf.sipmana
  end
end, 'update serverside sipmana')

-- bleedamount
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == 'bleedamount') then return end

  svo.sendcuring("clotat "..conf.bleedamount)
end, 'update serverside clot amount')

-- manause
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == 'manause') then return end

  svo.sendcuring("manathreshold "..conf.manause)
end, 'update serverside manathreshold')

-- curemethod
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == 'curemethod' and not svo.logging_in) then return end

  if conf.curemethod == 'transonly' then
    svo.sendcuring("transmutation on")
    svo.sendcuring("fallback off")
  elseif conf.curemethod == 'conconly' then
    svo.sendcuring("transmutation off")
    svo.sendcuring("fallback off")
  elseif conf.curemethod == 'prefertrans' then
    svo.sendcuring("transmutation on")
    svo.sendcuring("fallback on")
  elseif conf.curemethod == 'preferconc' then
     svo.sendcuring("transmutation off")
     svo.sendcuring("fallback on")
  end
end, 'update serverside curemethod')

-- pause
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == 'paused' and not svo.logging_in) then return end

  -- send right away, so chained commands are done in proper order
  if conf.paused then
    svo.force_send("curing off")
  else
    svo.force_send("curing on")
  end
end, 'update serverside curing pause')

-- keepup
signals["svo config changed"]:connect(function(config)
  if not (conf.serverside and config == 'keepup' and not svo.logging_in) then return end

  if conf.keepup then
    svo.sendcuring("defences on")
  else
    svo.sendcuring("defences off")
  end
end, 'update serverside keepup')

-- focuswithfulminated and focuswithguilt. The game has its own switch for
-- each, so hand it the decision rather than turning focus off and on as the
-- affliction comes and goes. sk.sendfocuswith sends one switch, or with no
-- argument all of them, as the initial sync above does.
local focuswith_affs = {'fulminated', 'guilt'}
function sk.sendfocuswith(only)
  for _, aff in ipairs(focuswith_affs) do
    if not only or aff == only then
      svo.sendcuring("focus "..(conf['focuswith'..aff] and "with" or "without")..aff)
    end
  end
end

for _, aff in ipairs(focuswith_affs) do
  signals["svo config changed"]:connect(function(config)
    if not (conf.serverside and config == 'focuswith'..aff and not svo.logging_in) then return end

    sk.sendfocuswith(aff)
  end, 'update serverside focus with '..aff)
end

signals["svo ignore changed"]:connect(sk.handleserversideswitch, "sk.handleserversideswitch")
signals["svo ignore changed"]:connect(sk.handleserversideswitch_keepup, "sk.handleserversideswitch_keepup")
signals["svo keepup changed"]:connect(sk.handleserversideswitch, "sk.handleserversideswitch")
signals["svo keepup changed"]:connect(sk.handleserversideswitch_keepup, "sk.handleserversideswitch_keepup")
signals["svo serverignore changed"]:connect(sk.handleserversideswitch, "sk.handleserversideswitch")
signals["svo serverignore changed"]:connect(sk.handleserversideswitch_keepup, "sk.handleserversideswitch_keepup")
signals["svo switched defence mode"]:connect(sk.handleserversideswitch, "sk.handleserversideswitch")
signals["svo done defup"]:connect(sk.handleserversideswitch, "sk.handleserversideswitch")

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
end, 'disable serverside functions when not using serverside')

-- toggle appropriately upon vconfig changed
signals["svo config changed"]:connect(function(config)
  if config ~= 'serverside' then return end

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
end, 'toggle serverside functions')


-- if we've got cadmus, and have one of the me.cadmusaffs afflictions, then we should focus
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

  return false
end

function sk.togglefocusserver()
  if not (conf.serverside and sk.logged_in) then return end

  if sk.canfocus() and conf.focus and not sk.priochangecache.special.focustoggle then
    svo.sendcuring("focus on")
    sk.priochangecache.special.focustoggle = true
  elseif (not conf.focus or (conf.focus and not sk.canfocus())) and sk.priochangecache.special.focustoggle then
    svo.sendcuring("focus off")
    sk.priochangecache.special.focustoggle = false
  end
end
signals.svogotaff:connect(sk.togglefocusserver, "sk.togglefocusserver")
-- use after prompt processing, not lost aff, so afflictions getting removed don't spam-toggle
signals.after_prompt_processing:connect(sk.togglefocusserver, "sk.togglefocusserver")
signals["svo config changed"]:connect(sk.togglefocusserver, "sk.togglefocusserver")

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
    svo.sendcuring("clot on")
    sk.clotting_on_serverside = true
  elseif not (sk.canclot() and conf.clot) and sk.clotting_on_serverside then
    svo.sendcuring("clot off")
    sk.clotting_on_serverside = false
  end
end
-- use after prompt processing, not lost aff, so afflictions getting removed don't spam-toggle
signals.svogotaff:connect(sk.toggleclotserver, "sk.toggleclotserver")
signals.after_prompt_processing:connect(sk.toggleclotserver, "sk.toggleclotserver")


function sk.toggleinsomniaserver()
  if not (conf.serverside and sk.logged_in) then return end

  if conf.insomnia and not sk.priochangecache.special.insomniatoggle then
    svo.sendcuring("insomnia on")
    sk.priochangecache.special.insomniatoggle = true
  elseif not conf.insomnia and sk.priochangecache.special.insomniatoggle then
    svo.sendcuring("insomnia off")
    sk.priochangecache.special.insomniatoggle = false
  end
end
signals["svo config changed"]:connect(sk.toggleinsomniaserver, "sk.toggleinsomniaserver")

--


function svo.setupserverside()
  if not conf.serverside then return end

  svo.sendc("curingset new normal")
  svo.sendc("curingset new slowcuring")

  -- The full sync runs only when serverside is switched on, so a player who
  -- already had it on when focuswithfulminated and focuswithguilt arrived
  -- would never send the game either switch. Send both at every login.
  sk.sendfocuswith()

  if svo.serversidesetup then killTimer(svo.serversidesetup) end
  svo.serversidesetup = tempTimer(5+svo.getping(), function()
    svo.serversidesetup = nil
  end)
end
signals.charname:connect(svo.setupserverside, "svo.setupserverside")
signals.gmcpcharname:connect(svo.setupserverside, "svo.setupserverside")

function svo.hitcuringsetlimit()
  if not svo.serversidesetup then return end

  if not svo.conf.serverside then return end

  echo("\n")
  svo.echofn("You don't have enough curingset slots to enable serverside use - Svof requires two. View your curingsets with ")
  setFgColor(unpack(svo.getDefaultColorNums))
  setUnderline(true)
  echoLink("CURINGSET LIST", 'send"curingset list"', "CURINGSET LIST", true)
  setUnderline(false)
  echo(" and delete some with ")
  setUnderline(true)
  echoLink("CURINGSET DELETE", 'printCmdLine"curingset delete "', "CURINGSET DELETE", true)
  setUnderline(false)
  echo(".\n")

  svo.tntf_set('serverside', 'off', true)
end

-- what Svof handles instead of serverside by default; serverside handles the
-- rest. The first setup and (restore defaults) in vshow serverside both use it
sk.svof_handles_by_default = {
  impale        = true, -- serverside does not stack writhing atm
  daeggerimpale = true, -- writhed as impale is
  lovers        = true, -- lust not handled by serverside
  selfishness   = true, -- doesn't take selfish off
}

function svo.setup_default_serverignore()
  if not next(svo.serverignore) then
    local list = sk.getallserversideactions()

    for _, action in ipairs(list) do
      svo.serverignore[action] = true
    end

    for action in pairs(sk.svof_handles_by_default) do
      svo.serverignore[action] = false
    end
  end
end

function svo.hitaliaslimit()
  if not svo.serversidesetup then return end

  if not svo.conf.serverside then return end

  echo("\n")
  svo.echofn("You haven't got enough space for Svof's two serverside aliases - view list with ")
  setFgColor(unpack(svo.getDefaultColorNums))
  setUnderline(true)
  echoLink("ALIAS LIST", 'send"alias list"', "ALIAS LIST", true)
  setUnderline(false)
  echo(" and delete some with ")
  setUnderline(true)
  echoLink('CLEARALIAS', 'printCmdLine"clearalias "', 'CLEARALIAS', true)
  setUnderline(false)
  echo(".\n")

  svo.tntf_set('serverside', 'off', true)
end

end -- end of svo serverside loader

if svo.systemloaded then svo.loader.serverside() end