-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

--[[ Logic: keep the prios embedded in the dict.*.*.spriority/dict.*.*.aspriority, don't keep a table
      of it's own. When exporting/importing, create such tables.]]
pl.dir.makepath(getMudletHomeDir() .. "/svo/prios")

do

  local private_prios = {}

  setmetatable(private_prios, { __index = function() return {} end })

  local set_new_prios = function(balance)

    local balance_prios = private_prios[balance]
local dbg = balance == "misc"
if dbg then display({balance = balance, balance_prios = balance_prios, callstack = debug.traceback() }) end

    local max = 0
    for prio in pairs(balance_prios) do
      if prio > max then max = prio end
    end


    local get_action_balance
    if balance == "slowcuring" then
      get_action_balance = function(action)
        local _, ac, bal = valid_sync_action(action)
        return ac, bal
      end
    else
      get_action_balance = function(action)
        return action, balance
      end
    end

    local effective_prio = 1

    for i = 1, max do
      if balance_prios[i] then
        local act_action, act_balance = get_action_balance(balance_prios[i])
        if act_action and dict[act_action] and dict[act_action][act_balance] then
          if balance == "slowcuring" then
            dict[act_action][act_balance].spriority = effective_prio
          else
            dict[act_action][act_balance].aspriority = effective_prio
          end
          effective_prio = effective_prio + 1
        end
      end
    end
  end

  function prio.export (name, options, echoback)
    local sendf; if echoback then sendf = echof end
    assert(name, "what name do you want to save this list as?", sendf)

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
      for k, v in pairs(to_export) do
        v.o = true
      end
    elseif type(options) == "string" then
      for w in string.gmatch(options, "%a+") do
        if to_export[w] then to_export[w].o = true end
      end
    elseif type(options) == "table" then
      for i, w in ipairs(options) do
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

        data = private_prios[priority]

        s[#s+1] = "\n-- " .. priotbl.prewrite
        s[#s+1] = priority .. " = " .. pl.pretty.write(data)
      end
    end

    s = table.concat(s, "\n")

    pl.dir.makepath(getMudletHomeDir() .. "/svo/prios")
    io.output(getMudletHomeDir() .. "/svo/prios/"..name, "w")
    io.write(s)
    io.close()

    if echoback then echof("exported %s prio to %s", name, getMudletHomeDir() .. "/svo/prios/"..name) end
#if DEBUG_prio then
    debugf("exported %s prio to %s", name, getMudletHomeDir() .. "/svo/prios/"..name)
#end
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
      echof("Priorities that we've got stored in '%s':\n  %s", dir, concatand(list))
    else
      return list
    end
  end

  -- returns the table of actions in a balance
  function prio.getlist(balance)
    return private_prios[balance]
  end

  -- returns a table of actions in a balance, sorted most important first, without gaps
  function prio.getsortedlist(balance)
    -- get into table...
    local data = private_prios[balance]
    local orderly = {}

    -- create an indexed list of just the priorities only
    for i,j in pairs(data) do
      orderly[#orderly+1] = i
    end

    -- invert the list, so actions are ordered most important first
    table.sort(orderly, function(a,b) return a>b end)

    -- sort original keys usin the new sorting
    local sortedprios = {}
    for _, prio in ipairs(orderly) do
      sortedprios[#sortedprios+1] = data[prio]
    end

    return sortedprios
  end

  -- returns the highest number used, and what uses it, in a balance
  function prio.gethighest(balance)
    local t = private_prios[balance]

    -- there could be holes - can't use #
    local maxprio, maxaction = 0
    for prio, action in pairs(t) do
      if prio > maxprio then
        maxprio = prio
        maxaction = action
      end
    end

    return maxprio, maxaction
  end

  -- returns a sorted list of actions in a balance by priority
  -- only works well with active actions and if their balances exist
  function prio.sortlist(actions, balance)
    assert(type(actions) == "table", "svo.prio.sortlist: actions must be an indexed table (a list)")
    assert(balance, "svo.prio.sortlist: in which balance do you want to check these actions in?")

    table.sort(actions, function(a,b)
      return dict[a] and dict[a][balance] and dict[b] and dict[b][balance] and
        dict[a][balance].aspriority > dict[b][balance].aspriority
    end)

    return actions
  end

  function prio.getaction(num, balance)
    assert(num and balance, "What number and balance to use?")
    local data = private_prios[balance]
    return data[num]
  end

  function prio.getslowaction(num)
    assert(num, "What number to use?")
    local data = private_prios["slowcuring"]
    if data[num] then
      return data[num]:match("(%w+)_(%w+)")
    end
  end

  -- string, string, number -> boolean
  -- inserts an action at balance and bumps all current actions down if necessary.
  -- because we're really only swapping items in the priority list and not inserting, we don't need to worry
  -- about items underflowing past 0 priority yet
  function prio.insert(action, balance, number, echoback)
    number = tonumber(number)

    if balance == "balance" then balance = "physical" end

    if balance == "slowcuring" then
      local validaction, plainaction, plainbalance = valid_sync_action(action)

      if not validaction then return false, plainaction end
    end

    local t = private_prios[balance]
    local originalt = deepcopy(t)
if balance == "misc" then display({t = t, action = action}) end

    if balance ~= "slowcuring" and not t then return nil, "no such balance: "..balance end

    local function index_of(table, element)
      for k,v in pairs(table) do
        if v == element then return k end
      end
      if balance == "slowcuring" then
        local _
        _, element = valid_sync_action(element)
      end
      -- not in there yet? Do we know that key?
      if all_dict_keys[element] then
        return 1000000000000000  -- cheat, so everything gets moved up
      end
    end

    -- remove from its current position
    local oldnum = index_of(t, action)
    if not oldnum then display(action) display(balance) return end

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
    local diff = basictableindexdiff(originalt, l) -- obtain an indexed list of all the different positions

    private_prios[balance] = l
    set_new_prios(balance)

    for _, a in pairs(diff) do
      if balance ~= "slowcuring" then
        raiseEvent("svo prio changed", a, balance, action_prio[a])
      else
        local _, action, balance = valid_sync_action(a)
        raiseEvent("svo prio changed", action, balance, action_prio[a], "slowcuring")
      end
    end

    if echoback then echof("Set %s's priority in %s balance to %d.", action, balance, number) end

    return true
  end

  function prio.getnumber(aff, balance)
    assert(aff and balance and private_prios[balance], "You need to give an aff and an existing balance.")
    for prio, action in pairs(private_prios[balance]) do
      if action == aff then
        return prio
      end
    end
  end

  function prio.cleargaps(balance, echoback)
    local data = private_prios[balance]

    local max=0
    for k,v in pairs(data) do
      if k>max then max=k end
    end

    local t, n = {}, 0

    for i=1,max do
      if data[i] then n=n+1 t[n]=data[i] end
    end

    -- create an action - prio table for retrieval of location using diffs
    local action_prio = {}
    for i = 1, #t do action_prio[t[i]] = i end

    local diff = basictableindexdiff(t, data)

    private_prios[balance] = t
    set_new_prios(balance)

    for _, a in pairs(diff) do
      if balance == slowcuring then
        local _, action, balance = valid_sync_action(a)
        raiseEvent("svo prio changed", action, balance, action_prio[a], "slowcuring")
      else
        raiseEvent("svo prio changed", a, balance, action_prio[a])
      end
    end

    if echoback then echof("Cleared all gaps for the %s prio.", balance) end
    showprompt()
  end

  function prio.usedefault(echoback)
    local sendf; if echoback then sendf = echof else sendf = errorf end

    -- um. this fails for some reason on Windows.
  --[[  local s,m = os.remove(getMudletHomeDir() .. "/svo/prios/current")
    if not s then echof("Couldn't update because of: "..tostring(m)) return end]]

    if prio.import("current", false, false, true) then
      echof("Updated to default priorities.")
    else
      echof("Couldn't update to default priorities :|")
    end
  end

  function prio.import(name, echoback, report_errors, use_default)
    local sendf; if echoback then sendf = echof else sendf = errorf end

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
      -- adds in the default prios here at compile-time
      s = $(
          io.input("bin/default_prios")
          local prios = io.read("*a")
          _put(string.format("%q", prios))
          )
    else
      assert(lfs.attributes(path), name .. " prio doesn't exist.", sendf)

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

    local s, m = run (s)
    if not s then sendf("There's a syntax problem in the prios file, we couldn't load it:\n  %s", m) return end

    local function set(num, action, balance, silently_skip_unknown)
      local actual_action
      if balance == "slowcuring" then
        local _
        _, actual_action = valid_sync_action(action)
      else
        actual_action = action
      end
      if not all_dict_keys[actual_action] then
        if report_errors and not silently_skip_unknown then
          sendf("Skipping %s, don't know such thing.", action)
        end
      else
        private_prios[balance][num] = action
      end
    end

    -- create a snapshot of the before state for all balances, since dict_setup might mess with any
    local beforestate = sk.getbeforestateprios()

    local contains = table.contains
    -- table i now contains subtables with all of our stuff
    for balance,balancet in pairs(i) do
      if contains(importables, balance) then
        for _, action in pairs(private_prios[balance]) do
          if balance == "slowcuring" then
            _, act_action, act_balance = valid_sync_action(action)
          else
            act_action, act_balance = action, balance
          end
          if dict[act_action] and dict[act_action][act_balance] then
            if balance == "slowcuring" then
              dict[act_action][act_balance].spriority = 0
            else
              dict[act_action][act_balance].aspriority  = 0
            end
          end
        end
        private_prios[balance] = {}
        for num, action in pairs(balancet) do
          set(num, action, balance, use_default)
        end
        set_new_prios(balance)
      end
    end
    dict_setup()
    dict_validate()

    local afterstate = sk.getafterstateprios()
    sk.notifypriodiffs(beforestate, afterstate)

    if echoback then echof("Imported %s prio list.", name) end
#if DEBUG_prio then
      debugf("imported %s prio.", name)
#end
    return true
  end

  -- limited_around: don't show the full list, but only 13 elements around the center one
  prio.printorder = function(balance, limited_around)
    -- translate the obvious 'balance' to 'physical'
    if balance == "balance" then balance = "physical" end
    local sendf; if echoback then sendf = echof else sendf = errorf end
    assert(type(balance) == "string", "what balance do you want to print for?", sendf)

    -- get into table...
    local data = private_prios[balance]
    local orderly = {}

    -- get a sorted list of just the prios
    for i,j in pairs(data) do
      orderly[#orderly+1] = i
    end

    table.sort(orderly, function(a,b) return a>b end)

    -- locate where the center of the list is, if we need it
    local center
    if limited_around then
      local counter = 1
      for _, j in pairs(orderly) do
        if j == limited_around then center = counter break end
        counter = counter +1
      end
    end

    echof("%s balance priority list (<112,112,112>clear gaps%s):", balance:title(), getDefaultColor())
    if selectString("clear gaps", 1) ~= -1 then
      setLink("svo.prio.cleargaps('"..balance.."', true)", "Clear all gaps in the "..balance.." balance")
    end

    if not limited_around then
      echof("Stuff at the top will be cured first, if it's possible to cure it.")
    end

    local list = prio.getsortedlist(balance)
    local affs, defs = sk.splitdefs(balance, list)
    local raffs, rdefs = {}, {}
    for index, aff in pairs(affs) do raffs[aff] = index end
    for index, def in pairs(defs) do rdefs[def] = index end

    if limited_around then
      echofn("(")
      setFgColor(unpack(getDefaultColorNums))
      setUnderline(true)
      echoLink("...", "svo.printorder('"..balance.."')", "Click to view the full "..balance.." priority list", true)
      setUnderline(false)
      echo(")\n")
    end

    local function echoserver(j, raffs, rdefs, balance, ssprioamount)
      if raffs[data[j]] then
        return string.format("ss aff %"..ssprioamount.."s", (raffs[data[j]] <= 25 and raffs[data[j]] or "25"))
      elseif rdefs[data[j]] then
        return string.format("ss def %"..ssprioamount.."s", (rdefs[data[j]] <= 25 and rdefs[data[j]] or "25"))
      elseif dict[data[j]][balance].def then
        return "ss def"..(' '):rep(ssprioamount).."-"
      elseif dict[data[j]][balance].aff then
        return "ss aff"..(' '):rep(ssprioamount).."-"
      else
        return "ss    "..(' '):rep(ssprioamount).."-"
      end
    end

    local counter = 1
    local intlen = intlen
    local prioamount = intlen(table.size(orderly))
    local ssprioamount = intlen(table.size(raffs) and table.size(raffs) or table.size(rdefs))
    for i,j in pairs(orderly) do
      if not limited_around or not (counter > (center+6) or counter < (center-6)) then
        setFgColor(255,147,107) echo"  "
        echoLink("^^", 'svo.prio_swap("'..data[j]..'", "'..balance..'", '..(j+1)..', nil, false, svo.printorder, "'..balance..'", '..(j+1)..')', 'shuffle '..data[j]..' up', true)
        echo(" ")
        setFgColor(148,148,255)
        echoLink("vv", 'svo.prio_swap("'..data[j]..'", "'..balance..'", '..(j-1)..', nil, false, svo.printorder, "'..balance..'", '..(j-1)..')', 'shuffle '..data[j]..' down', true)
        setFgColor(112,112,112)
        -- focus balance can't have 'priority'
        if not conf.serverside or balance == "focus" then
          echo(string.format(" (%s) "..(' '):rep(prioamount - intlen(j)).."%s", j, data[j]))
        else
          -- defs not on defup/keepup won't have a priority
          echo(string.format(" (svo %"..prioamount.."s|%s) %s", j, echoserver(j, raffs, rdefs, balance, ssprioamount), data[j]))
        end
        echo("\n")
        resetFormat()
      end

      counter = counter + 1
    end

    showprompt()
  end

  -- string -> boolean
  -- returns true if the given string in the format of actionname_balance exists
  valid_sync_action = function(name)
    local actionname, balance = name:match("^(%w+)_(%w+)$")
    if not (actionname and balance) then return false, "actionname is in invalid format; it should be as 'actionname_balance'" end

    for _, action in pairs(private_prios[balance]) do
      if action == actionname then
        return true, actionname, balance
      end
    end

    return false, "Don't know of action " .. actionname .. " operating on balance " .. balance
  end

end

signals.saveconfig:connect(function ()
  prio.export("current")
end)

signals.systemstart:connect(function ()
  prio.import("current")
end)
