-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

--[[ Logic: keep the prios embedded in the svo.dict.*.*.spriority/svo.dict.*.*.aspriority, don't keep a table
      of it's own. When exporting/importing, create such tables.]]

svo = svo or {}; svo.loader = svo.loader or {}
svo.loader.prio = function()

local sys, signals, sk, prio = svo.sys, svo.signals, svo.sk, svo.prio

svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/prios")

-- The saved places of what svof doesn't have this session, by balance and
-- number, as the last import found them: defences the player defined or
-- changed (vcustomdef), which vconfig customdefinitions off leaves out,
-- and svof's own actions in another class, as svof loads only the class
-- it's in. Export would drop them, and they'd come back at the bottom of
-- the list (live test, 2026-10-18; a class change and back did it to the
-- last class's own). Export writes them back where they were instead.
-- prio.loaded holds the numbers import gave everything else, by balance
-- and name
prio.kept, prio.loaded = prio.kept or {}, prio.loaded or {}

-- svof's own actions with a priority that only some classes have, by
-- balance and name as the saved lists name them: tools/defence_catalog.lua
-- writes them, from every class, to prio_catalog.lua in Svof's folder.
-- Read once, when first needed
local catalog
function prio.catalog()
  if catalog then return catalog end
  catalog = {}
  local path = svo.installationfolder() .. "/prio_catalog.lua"
  local t, err = svo.read_data_file(path, "prio_catalog")
  if t then
    for balance, names in pairs(t) do
      catalog[balance] = {}
      for _, name in ipairs(type(names) == 'table' and names or {}) do catalog[balance][name] = true end
    end
  elseif t == nil then
    svo.echof("<250,0,0>Couldn't%s read Svof's list of every class's priorities, in %s: %s", svo.getDefaultColor(),
      path, err)
  end
  return catalog
end

-- whether the saved place of action in balance is kept: svof doesn't have
-- it there this session, and it's a defence the player defined or changed,
-- or svof has it there in another class. A slow curing action is named
-- with its balance
local function keeps(action, balance)
  local name, bal = action, balance
  if balance == 'slowcuring' then name, bal = action:match('(%w+)_(%w+)') end
  if name and svo.dict[name] and svo.dict[name][bal] then return false end
  if (prio.catalog()[balance] or {})[action] then return true end
  local defences = svo.defences
  if defences.custom and defences.custom[name] then return true end
  for _, names in pairs(defences.edits or {}) do
    if type(names) == 'table' and names[name] then return true end
  end
  return false
end

-- Of the actions import gave places to, the ones still in import's order
-- in now (name -> place): the longest run of them that is, so one the
-- player moved isn't in it
local function steady(loaded, now)
  local names = {}
  for name in pairs(loaded) do
    if now[name] then names[#names+1] = name end
  end
  table.sort(names, function(a, b) return loaded[a] < loaded[b] end)
  -- tails[k]: the index of the run of k with the lowest last place
  local tails, prev = {}, {}
  for i, name in ipairs(names) do
    local lo, hi = 1, #tails
    while lo <= hi do
      local mid = math.floor((lo + hi) / 2)
      if now[names[tails[mid]]] < now[name] then lo = mid + 1 else hi = mid - 1 end
    end
    prev[i] = tails[lo - 1]
    tails[lo] = i
  end
  local t, i = {}, tails[#tails]
  while i do
    t[names[i]] = true
    i = prev[i]
  end
  return t
end

-- Puts a balance's kept places back into data, the list export writes.
-- The places import gave move in a session: dict_setup moves every place
-- up to make room at the bottom for what has none, every call moves the
-- slow curing ones, for svo.dict.lovers.map, vcleargaps closes the gaps
-- the kept ones leave, and the player moves actions. So a kept place moves
-- as far as the nearest place below it that's still in import's order, or
-- the nearest above with none below, and stays below the nearest above.
-- Something svof put there this session moves up one, with the ones above
-- it up to the next gap. Each goes above the one put back before it: a run
-- of them with nothing below, after vcleargaps in another class, all move
-- to the bottom, and each put at the bottom would push the last one up,
-- turning the run over (live test, 2026-10-19: the Magi's own, Monk and
-- back)
local function putback(data, balance)
  local kept, nums = prio.kept[balance] or {}, {}
  for num, action in pairs(kept) do
    if keeps(action, balance) then nums[#nums+1] = num end
  end
  if not nums[1] then return end
  table.sort(nums)

  local loaded, now = prio.loaded[balance] or {}, {}
  for num, name in pairs(data) do now[name] = num end
  local still = steady(loaded, now)
  local last = 0
  for _, num in ipairs(nums) do
    local below, above
    for name in pairs(still) do
      local was = loaded[name]
      if was < num and (not below or was > loaded[below]) then below = name end
      if was > num and (not above or was < loaded[above]) then above = name end
    end
    local at = num
    if below then at = num + now[below] - loaded[below]
    elseif above then at = num + now[above] - loaded[above] end
    if above and at > now[above] then at = now[above] end
    at = math.max(last + 1, at)
    local top = at
    while data[top] do top = top + 1 end
    for i = top, at + 1, -1 do
      data[i] = data[i-1]
      now[data[i]] = i
    end
    data[at] = kept[num]
    last = at
  end
end

function prio.export (name, options, echoback)
  local sendf; if echoback then sendf = svo.echof end
  svo.assert(name, "what name do you want to save this list as?", sendf)

  -- kv table of what to export
  local to_export = {
    herb = {
      prewrite = "Herb cures: ",
    },
    smoke = {
      prewrite = "Smoke cures: ",
    },
    salve = {
      prewrite = "Salve cures: ",
    },
    sip = {
      prewrite = "Sipping balance: ",
    },
    purgative = {
      prewrite = "Purgative cures: ",
    },
    physical = {
      prewrite = "Balance or equilibrium actions: ",
    },
    focus = {
      prewrite = "Focus cures: ",
    },
    moss = {
      prewrite = "Moss balances (these don't really make sense to order): ",
    },
    misc = {
      prewrite = "Miscallaneous actions: ",
    },
    slowcuring = {
      prewrite = "Slow curing mode priorities: "
    }
  }

  if not options or options == "" or options == " " then
    for _, v in pairs(to_export) do
      v.o = true
    end
  elseif type(options) == 'string' then
    for w in string.gmatch(options, "%a+") do
      if to_export[w] then to_export[w].o = true end
    end
  elseif type(options) == 'table' then
    for _, w in ipairs(options) do
      if to_export[w] then to_export[w].o = true end
    end
  end

  --[[ generate a single table like so:
  {
    herb = {
      'relapsing',
      'paranoia',
      'vapors',
      ...
    },

    salve = {
    ....
    }

  }

  Writing out though, skip the initial whole table itself.
  ]]

  local data
  local s = {
    "-- Priorities list '".. name .. "' by ".. (sys.charname or "Unknown") .. ", exported @ " .. os.date().."\n",
    "-- Note: The lower the priority in the list without a number, or the lower number - the more important the thing is. ie, things at the bottom of the list will get done before those on the top!"
  }


  for priority, priotbl in pairs(to_export) do
    if priotbl.o then
      if priority == 'slowcuring' then
        data = svo.make_sync_prio_table("%s_%s")
      else
        data = svo.make_prio_table(priority)
      end
      putback(data, priority)

      s[#s+1] = "\n-- " .. priotbl.prewrite
      s[#s+1] = priority .. " = " .. svo.pl.pretty.write(data)
    end
  end

  s = table.concat(s, "\n")

  svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/prios")
  io.output(getMudletHomeDir() .. "/svo/prios/"..name, 'w')
  io.write(s)
  io.close()

  if echoback then svo.echof("exported %s prio to %s", name, getMudletHomeDir() .. "/svo/prios/"..name) end
  svo.debugf("exported %s prio to %s", name, getMudletHomeDir() .. "/svo/prios/"..name)
end

function prio.list(echoback)
  local dir = getMudletHomeDir() .. "/svo/prios"
  local list = {}

  for file in lfs.dir(dir) do
    if file ~= "." and file ~= ".." then
      list[#list+1] = file
    end
  end

  if echoback then
    svo.echof("Priorities that we've got stored in '%s':\n  %s", dir, svo.concatand(list))
  else
    return list
  end
end

-- returns the table of actions in a balance
function prio.getlist(balance)
  return svo.make_prio_table(balance)
end

-- returns a table of actions in a balance, sorted most important first, without gaps
function prio.getsortedlist(balance)
  -- get into table...
  local data
  if balance ~= 'slowcuring' then
    data = svo.make_prio_table(balance)
  else
    data = svo.make_sync_prio_table("%s_%s")
  end
  local orderly = {}

  -- create an indexed list of just the priorities only
  for i,_ in pairs(data) do
    orderly[#orderly+1] = i
  end

  -- invert the list, so actions are ordered most important first
  table.sort(orderly, function(a,b) return a>b end)

  -- sort original keys usin the new sorting
  local sortedprios = {}
  for _, sortedprio in ipairs(orderly) do
    sortedprios[#sortedprios+1] = data[sortedprio]
  end

  return sortedprios
end

-- returns the highest number used, and what uses it, in a balance
function prio.gethighest(balance)
  local t = svo.make_prio_table(balance)

  -- there could be holes - can't use #
  local maxprio, maxaction = 0
  for prioname, action in pairs(t) do
    if prioname > maxprio then
      maxprio = prioname
      maxaction = action
    end
  end

  return maxprio, maxaction
end

-- returns a sorted list of actions in a balance by priority
function prio.sortlist(actions, balance)
  svo.assert(type(actions) == 'table', "svo.prio.sortlist: actions must be an indexed table (a list)")
  svo.assert(balance, "svo.prio.sortlist: in which balance do you want to check these actions in?")

  table.sort(actions, function(a,b)
    return svo.dict[a] and svo.dict[a][balance] and svo.dict[b] and svo.dict[b][balance] and
      svo.dict[a][balance].aspriority > svo.dict[b][balance].aspriority
  end)

  return actions
end

function prio.getaction(num, balance)
  svo.assert(num and balance, "What number and balance to use?")
  local data = svo.make_prio_table(balance)
  return data[num]
end

function prio.getslowaction(num)
  svo.assert(num, "What number to use?")
  local data = svo.make_sync_prio_table("%s_%s")
  if data[num] then
    return data[num]:match("(%w+)_(%w+)")
  end
end

-- inserts an action at balance and bumps all current actions down if necessary
-- string, string, number -> boolean
-- inserts an action at balance and bumps all current actions down if necessary.
-- because we're really only swapping items in the priority list and not inserting, we don't need to worry
-- about items underflowing past 0 priority yet
function prio.insert(action, balance, number, echoback)
  number = tonumber(number)

  if balance == 'balance' then balance = 'physical' end

  -- vset ignores what this returns, so say why there
  local function refuse(why)
    if echoback then svo.echof("Can't set that priority: %s.", why) end
    return false, why
  end

  if balance == 'slowcuring' then
    local plainaction, why = svo.slow_curing_entry(action)
    if not plainaction then return refuse(why) end
  elseif not svo.dict[action] then
    return refuse("action "..tostring(action).." doesn't exist")
  -- the balances dict_setup gives no priority (aff, gone, waitingfor...) aren't in any list
  elseif not (type(svo.dict[action][balance]) == 'table' and svo.dict[action][balance].aspriority) then
    return refuse(action.." doesn't operate on the "..tostring(balance).." balance")
  end

  local function getpriotable(balancename)
    if balancename ~= 'slowcuring' then
      return svo.make_prio_table(balancename)
    else
      return svo.make_sync_prio_table("%s_%s")
    end
  end

  local function insertat(actionname, balancename, newprio)
    local eventaction, eventbalance = actionname, balancename
    if balancename ~= 'slowcuring' then
      svo.dict[actionname][balancename].aspriority = newprio
    else
      -- actionname is the sync name, action_balance: split it, as the shuffle below does
      local _, syncaction, syncbalance = svo.valid_sync_action(actionname)
      svo.dict[syncaction][syncbalance].spriority = newprio
      eventaction, eventbalance = syncaction, syncbalance
    end
    if echoback then svo.echof("Set %s's priority in %s balance to %d.", actionname, balancename, newprio) end
    raiseEvent("svo prio changed", eventaction, eventbalance, newprio, (balancename == 'slowcuring' and 'slowcuring'))
  end

  local t = getpriotable(balance)
  local originalt = svo.deepcopy(t)

  -- if nothing is in the desired index, then just insert. If something is, shuffle down first.
  if not t[number] then
    insertat(action, balance, number)
  else
    local function index_of(table, element)
      for k,v in pairs(table) do
        if v == element then return k end
      end
    end

    -- remove from its current position
    local oldnum = index_of(t, action)
    t[oldnum] = nil

    -- move everything below the old index (oldnum) one up
    local newt = {}
    for k,v in pairs(t) do
      if k <= oldnum then
        newt[k+1] = v
      else
        newt[k] = v
      end
    end

    -- copy items into a new table, one lower if they're at or below new index (number)
    local l = {}
    for k,v in pairs(newt) do
      if k <= number then -- if at or below - shuffle 1 down, unless it's at the previous position or below - then keep it
        l[k-1] = v
      else  -- if above: keep where it was
        l[k] = v
      end
    end

    l[number] = action -- insert our action back in
    local action_prio = {} -- create an action-value list of the new priorities
    for k,v in pairs(l) do action_prio[v] = k end

    -- then read off our diff of new list and store away new prios.
    local diff = svo.basictableindexdiff(originalt, l) -- obtain an indexed list of all the different positions
    for _, a in pairs(diff) do
      if balance ~= 'slowcuring' then
        svo.dict[a][balance].aspriority = action_prio[a]
        raiseEvent("svo prio changed", a, balance, action_prio[a])
      else
        local _, syncaction, syncbalance = svo.valid_sync_action(a)
        svo.dict[syncaction][syncbalance].spriority = action_prio[a]
        raiseEvent("svo prio changed", syncaction, syncbalance, action_prio[a], 'slowcuring')
      end
    end

    if echoback then svo.echof("Set %s's priority in %s balance to %d.", action, balance, number) end
  end

  return true
end

function prio.getnumber(aff, balance)
  svo.assert(aff and balance and svo.dict[aff] and svo.dict[aff][balance], "Such affliction/defence or balance doesn't exist")
  return svo.dict[aff][balance].aspriority
end

function prio.cleargaps(balance, echoback)
  -- sync mode
  if balance == 'slowcuring' then
    local data = svo.make_sync_prio_table("%s_%s")

    local max=0
    for k,_ in pairs(data) do
      if k>max then max=k end
    end

    local t, n = {}, 0

    for i=1,max do
      if data[i] then n=n+1 t[n]=data[i] end
    end

    -- create an action - prio table for retrieval of location using diffs
    local action_prio = {}
    for i = 1, #t do action_prio[t[i]] = i end

    -- create a diff, using the old table first as it has no holes
    local diff = svo.basictableindexdiff(t, data)

    -- now only change & notify for the delta differences
    for _, a in pairs(diff) do
      local _, syncaction, syncbalance = svo.valid_sync_action(a)
      svo.dict[syncaction][syncbalance].spriority = action_prio[a]
      raiseEvent("svo prio changed", syncaction, syncbalance, action_prio[a], 'slowcuring')
    end

    if echoback then svo.echof("Cleared all gaps for the slow curing prio.") end
  -- normal modes
  else
    local data = svo.make_prio_table(balance)

    local max=0
    for k,_ in pairs(data) do
      if k>max then max=k end
    end

    local t, n = {}, 0

    for i=1,max do
      if data[i] then n=n+1 t[n]=data[i] end
    end

    -- create an action - prio table for retrieval of location using diffs
    local action_prio = {}
    for i = 1, #t do action_prio[t[i]] = i end

    local diff = svo.basictableindexdiff(t, data)

    for _, a in pairs(diff) do
      svo.dict[a][balance].aspriority = action_prio[a]
      raiseEvent("svo prio changed", a, balance, action_prio[a])
    end

    if echoback then svo.echof("Cleared all gaps for the %s prio.", balance) end
  end
  svo.showprompt()
end

function prio.usedefault(echoback)
  local sendf; if echoback then sendf = svo.echof else sendf = function() end end

  -- um. this fails for some reason on Windows.
--[[  local s,m = os.remove(getMudletHomeDir() .. "/svo/prios/current")
  if not s then svo.echof("Couldn't update because of: "..tostring(m)) return end]]

  if prio.import('current', false, false, true) then
    sendf("Updated to default priorities.")
  else
    sendf("Couldn't update to default priorities :|") end
end

-- Cures that moved to another balance. A list saved before has one where
-- it was, which the import would skip, and with no place it would go to the
-- bottom of its new balance: the list every player has, current, is saved
-- on every quit. So it goes where the default list puts it, after the cure
-- named, or at the bottom when the list doesn't have that one; and its
-- slow curing entry keeps its place under its new name.
local moved = {
  -- whispering madness is eaten with lobelia, not smoked with elm
  { action = 'madness', from = 'smoke', to = 'herb', after = 'impatience' },
}

-- puts the renamed afflictions in i, a saved list as read, under their new
-- names (svo.renamed_affs), in the places the old names had. A slow curing
-- action is named with its balance. A list that has the new name already
-- keeps that one
local function import_renamed(i)
  for _, list in pairs(i) do
    if type(list) == 'table' then
      local has = {}
      for _, action in pairs(list) do
        if type(action) == 'string' then has[action] = true end
      end
      for num, action in pairs(list) do
        if type(action) == 'string' then
          local name, bal = action:match('^(%w+)(_%w+)$')
          if not name then name, bal = action, '' end
          local new = svo.renamed_affs[name]
          if new then
            if has[new .. bal] then list[num] = nil else list[num] = new .. bal end
          end
        end
      end
    end
  end
end

-- puts the moved cures in i, a saved list as read, where they are now
local function import_moved(i)
  for _, m in ipairs(moved) do
    local from, to = i[m.from], i[m.to]
    local was
    for num, action in pairs(type(from) == 'table' and from or {}) do
      if action == m.action then was = num end
    end
    local has = false
    for _, action in pairs(type(to) == 'table' and to or {}) do
      if action == m.action then has = true end
    end
    if was and type(to) == 'table' and not has then
      from[was] = nil
      local after = 0
      for num, action in pairs(to) do
        if action == m.after then after = num end
      end
      -- the ones above make room, as prio.insert's shuffle does
      local nums = {}
      for num in pairs(to) do
        if num > after then nums[#nums + 1] = num end
      end
      table.sort(nums, function(a, b) return a > b end)
      for _, num in ipairs(nums) do to[num + 1], to[num] = to[num], nil end
      to[after + 1] = m.action
    end
    -- and its slow curing entry, in its place
    local slow = i.slowcuring
    if type(slow) == 'table' then
      local old, new, newat = m.action .. '_' .. m.from, m.action .. '_' .. m.to, nil
      for _, action in pairs(slow) do
        if action == new then newat = true end
      end
      for num, action in pairs(slow) do
        if action == old and not newat then slow[num] = new end
      end
    end
  end
end

function prio.import(name, echoback, report_errors, use_default)
  local sendf; if echoback then sendf = svo.echof else sendf = function() end end

  -- Failures always speak, whatever echoback says.
  --
  -- The startup load is `prio.import('current')` with no echoback, so sendf is
  -- function() end there. Before the returns below were added, a missing
  -- default_prios at least reached io.input and raised a traceback - ugly, but
  -- visible. Returning quietly through a silent sendf turned the whole
  -- auto-load path mute: no priorities loaded, nothing said. That is the state
  -- a failed update leaves the profile in, so it is not a hypothetical.
  --
  -- Informational output stays gated - this is only for the paths that end in
  -- "and so nothing was loaded".
  local failf = svo.echof

  local filename
  if not name then
    filename = invokeFileDialog(true, "Select the priority list you'd like to import")
    if filename == "" then
      sendf("Cancelled; don't have anything to import.")
      return
    end
  end

  local path = filename or getMudletHomeDir() .. "/svo/prios/".. name

  local importables = {
    'herb',
    'smoke',
    'salve',
    'sip',
    'purgative',
    'physical',
    'focus',
    'moss',
    'misc',
    'slowcuring',
  }

  local s
  -- Both arms used svo.assert(cond, msg, sendf), which calls sendf and then
  -- CARRIES ON - so io.input still ran on the missing path and raised the raw
  -- traceback the message was meant to replace. The file's own convention for
  -- a recoverable failure is one line further down: say what went wrong and
  -- return, so the caller's `if prio.import(...) then` sees the failure.
  if name == 'current' and (use_default or not lfs.attributes(path)) then
    local defaults = svo.installationfolder() .. "/default_prios"
    if not lfs.attributes(defaults) then
      failf("The default priorities are missing from the installation (%s).", defaults)
      return
    end
    io.input(defaults)
    s = io.read("*a")
  else
    if not lfs.attributes(path) then
      failf("%s prio doesn't exist.", tostring(name))
      return
    end
    io.input(path)
    s = io.read("*all")
  end

  -- load file into our sandbox; credit to http://lua-users.org/wiki/SandBoxes
  local i = {}
  -- run code under environment
  local function run(untrusted_code)
    local untrusted_function, message = loadstring(untrusted_code)
    if not untrusted_function then return nil, message end
    setfenv(untrusted_function, i)
    return pcall(untrusted_function)
  end

  local ok, m = run(s)
  if not ok then failf("There's a syntax problem in the prios file, we couldn't load it:\n  %s", m) return end
  import_renamed(i)
  import_moved(i)

  local function set(num, action, balance, priority)
    if not (svo.dict[action] and svo.dict[action][balance]) then
      if report_errors then
        if not svo.dict[action] then sendf("Skipping %s, don't know such thing.", action) else
          sendf("Skipping %s, it doesn't use %s balance.", action, balance) end
      end
    else
      svo.dict[action][balance][priority] = num
    end
  end

  -- create a snapshot of the before state for all balances, since dict_setup might mess with any
  local beforestate = sk.getbeforestateprios()

  local contains, sfind = table.contains, string.find
  -- table i now contains subtables with all of our stuff
  for balance,balancet in pairs(i) do
    if contains(importables, balance) then
      -- and the places this list keeps (prio.kept)
      prio.kept[balance], prio.loaded[balance] = {}, {}
      if balance == 'slowcuring' then
        -- reset all current ones to zero
        svo.clear_sync_prios()

        for num, action in pairs(balancet) do
          -- have to weed out action name _ balance name first
          local _,_, actionname, balancename = sfind(action, '(%w+)_(%w+)')
          if keeps(action, balance) then
            prio.kept[balance][num] = action
          else
            set(num, actionname, balancename, 'spriority')
            prio.loaded[balance][action] = num
          end
        end
      else
        -- reset all current ones to zero
        svo.clear_balance_prios(balance)
        for num, action in pairs(balancet) do
          if keeps(action, balance) then
            prio.kept[balance][num] = action
          else
            set(num, action, balance, 'aspriority')
            prio.loaded[balance][action] = num
          end
        end
      end
    end
  end
  svo.dict_setup()
  svo.dict_validate()

  local afterstate = sk.getafterstateprios()
  sk.notifypriodiffs(beforestate, afterstate)

  if echoback then svo.echof("Imported %s prio list.", name) end
  svo.debugf("imported %s prio.", name)
  return true
end

signals.saveconfig:add_pre_emit(function ()
  prio.export('current')
end, 'save prios on quit')

signals.systemstart:connect(function ()
  prio.import('current')
end, 'load prios on start')

end -- end of svo prio loader

if svo.systemloaded then svo.loader.prio() end