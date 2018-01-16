-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

--[[ Logic: keep the prios embedded in the svo.dict.*.*.spriority/svo.dict.*.*.aspriority, don't keep a table
      of it's own. When exporting/importing, create such tables.]]

local sys, signals, sk, prio = svo.sys, svo.signals, svo.sk, svo.prio

svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/prios")

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
  elseif type(options) == "string" then
    for w in string.gmatch(options, "%a+") do
      if to_export[w] then to_export[w].o = true end
    end
  elseif type(options) == "table" then
    for _, w in ipairs(options) do
      if to_export[w] then to_export[w].o = true end
    end
  end

  --[[ generate a single table like so:
  {
    herb = {
      "relapsing",
      "paranoia",
      "vapors",
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
    "-- Priorities list '".. name .. "' by ".. sys.charname .. ", exported @ " .. os.date().."\n",
    "-- Note: The lower the priority in the list without a number, or the lower number - the more important the thing is. ie, things at the bottom of the list will get done before those on the top!"
  }


  for priority, priotbl in pairs(to_export) do
    if priotbl.o then
      if priority == "slowcuring" then
        data = svo.make_sync_prio_table("%s_%s")
      else
        data = svo.make_prio_table(priority)
      end

      s[#s+1] = "\n-- " .. priotbl.prewrite
      s[#s+1] = priority .. " = " .. svo.pl.pretty.write(data)
    end
  end

  s = table.concat(s, "\n")

  svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/prios")
  io.output(getMudletHomeDir() .. "/svo/prios/"..name, "w")
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
  if balance ~= "slowcuring" then
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
  svo.assert(type(actions) == "table", "svo.prio.sortlist: actions must be an indexed table (a list)")
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

  if balance == "balance" then balance = "physical" end

  if balance == "slowcuring" then
    local validaction, plainaction = svo.valid_sync_action(action)

    if not validaction then return false, plainaction end
  end

  local function getpriotable(balancename)
    if balancename ~= "slowcuring" then
      return svo.make_prio_table(balancename)
    else
      return svo.make_sync_prio_table("%s_%s")
    end
  end

  local function insertat(actionname, balancename, newprio)
    if balancename ~= "slowcuring" then
      svo.dict[actionname][balancename].aspriority = newprio
    else
      svo.dict[actionname][balancename].spriority = newprio
    end
    if echoback then svo.echof("Set %s's priority in %s balance to %d.", actionname, balancename, newprio) end
    raiseEvent("svo prio changed", actionname, balancename, newprio, (balancename == "slowcuring" and "slowcuring"))
  end

  local t = getpriotable(balance)
  local originalt = svo.deepcopy(t)

  if balance ~= "slowcuring" and not t then return nil, "no such balance: "..balance end

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
      if balance ~= "slowcuring" then
        svo.dict[a][balance].aspriority = action_prio[a]
        raiseEvent("svo prio changed", a, balance, action_prio[a])
      else
        local _, syncaction, syncbalance = svo.valid_sync_action(a)
        svo.dict[syncaction][syncbalance].spriority = action_prio[a]
        raiseEvent("svo prio changed", syncaction, syncbalance, action_prio[a], "slowcuring")
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
  if balance == "slowcuring" then
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
      raiseEvent("svo prio changed", syncaction, syncbalance, action_prio[a], "slowcuring")
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

  if prio.import("current", false, false, true) then
    sendf("Updated to default priorities.")
  else
    sendf("Couldn't update to default priorities :|") end
end

function prio.import(name, echoback, report_errors, use_default)
  local sendf; if echoback then sendf = svo.echof else sendf = function() end end

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
    "herb",
    "smoke",
    "salve",
    "sip",
    "purgative",
    "physical",
    "focus",
    "moss",
    "misc",
    "slowcuring",
  }

  local s
  if name == "current" and (use_default or not lfs.attributes(path)) then
    s = ""
    -- adds in the default prios here at compile-time
    -- s = $(
    --     io.input("bin/default_prios")
    --     local prios = io.read("*a")
    --     _put(string.format("%q", prios))
    --     )
  else
    svo.assert(lfs.attributes(path), name .. " prio doesn't exist.", sendf)

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
  if not ok then sendf("There's a syntax problem in the prios file, we couldn't load it:\n  %s", m) return end

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
      if balance == "slowcuring" then
        -- reset all current ones to zero
        svo.clear_sync_prios()

        for num, action in pairs(balancet) do
          -- have to weed out action name _ balance name first
          local _,_, actionname, balancename = sfind(action, '(%w+)_(%w+)')
          set(num, actionname, balancename, "spriority")
        end
      else
        -- reset all current ones to zero
        svo.clear_balance_prios(balance)
        for num, action in pairs(balancet) do
          set(num, action, balance, "aspriority")
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

signals.saveconfig:connect(function ()
  prio.export("current")
end)

signals.systemstart:connect(function ()
  prio.import("current")
end)
