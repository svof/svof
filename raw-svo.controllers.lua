-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local sys, affs, defdefup, defkeepup, signals = svo.sys, svo.affs, svo.defdefup, svo.defkeepup, svo.signals
local conf, sk, me, defs, defc = svo.conf, svo.sk, svo.me, svo.defs, svo.defc
local defences, stats, cnrl, rift = svo.defences, svo.stats, svo.cnrl, svo.rift
local bals, pipes, valid, actions = svo.bals, svo.pipes, svo.valid, svo.actions
local lifevision = svo.lifevision

local oldhealth, oldmana = 0, 0
me.healthchange, me.manachange = 0, 0
local function calculatestatchanges()
  local t = {}

  me.healthchange = 0
  me.manachange = 0
  if oldhealth > stats.currenthealth then
    me.healthchange = stats.currenthealth - oldhealth

    if conf.showchanges then
      if conf.changestype == 'full' then
        t[#t+1] = string.format("<255,0,0>%d<128,128,128> Health", me.healthchange)
      elseif conf.changestype == 'short' then
        t[#t+1] = string.format("<255,0,0>%d<128,128,128>h", me.healthchange)
      elseif conf.changestype == 'fullpercent' then
        t[#t+1] = string.format("<255,0,0>%d<128,128,128> Health, %.1f%%", me.healthchange, 100/stats.maxhealth*me.healthchange*-1)
      elseif conf.changestype == 'shortpercent' then
        t[#t+1] = string.format("<255,0,0>%d<128,128,128>h, %.1f%%", me.healthchange, 100/stats.maxhealth*me.healthchange*-1)
      end
    end

  elseif oldhealth < stats.currenthealth then
    me.healthchange = stats.currenthealth - oldhealth

    if conf.showchanges then
      if conf.changestype == 'full' then
        t[#t+1] = string.format("<0,255,0>+%d<128,128,128> Health", me.healthchange)
      elseif conf.changestype == 'short' then
        t[#t+1] = string.format("<0,255,0>+%d<128,128,128>h", me.healthchange)
      elseif conf.changestype == 'fullpercent' then
        t[#t+1] = string.format("<0,255,0>+%d<128,128,128> Health, %.1f%%", me.healthchange, 100/stats.maxhealth*me.healthchange)
      elseif conf.changestype == 'shortpercent' then
        t[#t+1] = string.format("<0,255,0>+%d<128,128,128>h, %.1f%%", me.healthchange, 100/stats.maxhealth*me.healthchange)
      end
    end
  end

  if oldmana > stats.currentmana then
    me.manachange = stats.currentmana - oldmana

    if conf.showchanges then
      if conf.changestype == 'full' then
        t[#t+1] = string.format("<255,0,0>%d<128,128,128> Mana", me.manachange)
      elseif conf.changestype == 'short' then
        t[#t+1] = string.format("<255,0,0>%d<128,128,128>m", me.manachange)
      elseif conf.changestype == 'fullpercent' then
        t[#t+1] = string.format("<255,0,0>%d<128,128,128> Mana, %.1f%%", me.manachange, 100/stats.maxmana*me.manachange*-1)
      elseif conf.changestype == 'shortpercent' then
        t[#t+1] = string.format("<255,0,0>%d<128,128,128>m, %.1f%%", me.manachange, 100/stats.maxmana*me.manachange*-1)
      end
    end

  elseif oldmana < stats.currentmana then
    me.manachange = stats.currentmana - oldmana

    if conf.showchanges then
      if conf.changestype == 'full' then
        t[#t+1] = string.format("<0,255,0>+%d<128,128,128> Mana", me.manachange)
      elseif conf.changestype == 'short' then
        t[#t+1] = string.format("<0,255,0>+%d<128,128,128>m", me.manachange)
      elseif conf.changestype == 'fullpercent' then
        t[#t+1] = string.format("<0,255,0>+%d<128,128,128> Mana, %.1f%%", me.manachange, 100/stats.maxmana*me.manachange)
      elseif conf.changestype == 'shortpercent' then
        t[#t+1] = string.format("<0,255,0>+%d<128,128,128>m, %.1f%%", me.manachange, 100/stats.maxmana*me.manachange)
      end
    end
  end

  -- update the public old values
  me.oldhealth, me.oldmana = oldhealth, oldmana

  -- update oldhealth, oldmana to current values
  oldhealth, oldmana = stats.currenthealth, stats.currentmana

  -- store away changed for showing later, as the custom prompt that follows overrides
  sk.statchanges = t
end

local blackout_flag
function svo.blackout()
  blackout_flag = true
end

local function checkblackout()
  if blackout_flag and not affs.blackout then
    valid.simpleblackout()
  elseif not blackout_flag and affs.blackout and getCurrentLine() ~= "" then
    if actions.touchtree_misc then
      lifevision.add(actions.touchtree_misc.p, nil, 'blackout')
    else
      svo.checkaction(svo.dict.blackout.waitingfor, true)
      lifevision.add(actions.blackout_waitingfor.p)
    end
  end

  blackout_flag = false
end

function svo.valid.setup_prompt()
  if line == "-" or line:find("^%-%d+%-$") or line == " Vote-" then
    -- bals.balance = true
    -- bals.equilibrium = true
    bals.rightarm = 'unset'
    bals.leftarm = 'unset'
  else
    bals.balance = false
    bals.equilibrium = false
if svo.haveskillset('healing') then
    bals.healing = false
end
    svo.pflags = {}
  end
end

local function check_promptflags()
  local pflags = svo.pflags

  if pflags.b and not defc.blind and not affs.blindaff then
    if ((defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind)) then
      if svo.me.class == 'Apostate' and not defc.mindseye then
        return
      end
      defences.got('blind')
    else
      svo.addaffdict(svo.dict.blindaff)
    end
  elseif not pflags.b and (defc.blind or affs.blindaff) then
    svo.rmaff('blindaff')
    defences.lost('blind')
  end

  if pflags.d and not defc.deaf and not affs.deafaff then
    if ((defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf) or defc.mindseye) then
      defences.got('deaf')
    else
      svo.addaffdict(svo.dict.deafaff)
    end
  elseif not pflags.d and (defc.deaf or affs.deafaff) then
    svo.rmaff('deafaff')
    defences.lost('deaf')
  end

  if pflags.k and not defc.kola then
    defences.got('kola')
  elseif not pflags.k and defc.kola then
    defences.lost('kola')
  end

  if pflags.c and not defc.cloak then
    defences.got('cloak')
  elseif not pflags.c and defc.cloak then
    defences.lost('cloak')
  end

if svo.haveskillset('shindo') then
  stats.shin = line:match("%-(%d+)%-") or line:match("%-(%d+) Vote%-") or 0
end

if svo.haveskillset('kaido') then
  stats.kai = line:match("%-(%d+)%-") or line:match("%-(%d+) Vote%-") or 0
end

if svo.haveskillset('necromancy') then
  if pflags.at then defences.got('blackwind') else defences.lost('blackwind') end
end

if svo.haveskillset('occultism') then
  if pflags.at then defences.got('astralform') else defences.lost('astralform') end
end

if svo.haveskillset('subterfuge') then
  if pflags.at then defences.got('phase') else defences.lost('phase') end
end

  local oldgametarget, oldgametargethp = me.gametarget, me.gametargethp
  me.gametarget, me.gametargethp = line:match("%[(.-)%](%d+)%%")
  if me.gametargethp then me.gametargethp = tonumber(me.gametargethp) end
  if oldgametarget ~= me.gametarget then
    raiseEvent("svo gametarget changed", me.gametarget)
  end
  if oldgametargethp ~= me.gametargethp then
    raiseEvent("svo gametargethp changed", me.gametarget, me.gametargethp)
  end

if svo.haveskillset('weaponmastery') then
  stats.weaponmastery = line:match("k(%d+)")
end

  me.servertime = line:match("-s(%d+:%d+:%d+%.%d+)")
end

function svo.onprompt()
  raiseEvent("svo before the prompt")
  sk.processing_prompt = true
  sk.systemscommands = {}

  svo.promptcount = svo.promptcount + 1

  checkblackout()
  check_promptflags()

  sys.lagcount = 0
  svo.prompt_stats()
  calculatestatchanges()

  local s,m = pcall(signals.before_prompt_processing.emit, signals.before_prompt_processing)
  if not s then
    echoLink("(e!)", [[svo.echof("The problem was: stuff before the actual work failed (]]..tostring(m)..[[)")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
  end

  svo.send_in_the_gnomes()

  if conf.showchanges and not conf.commandecho or (conf.commandecho and conf.commandechotype == 'fancynewline') then
    sk.showstatchanges()
  end

  local processing_status, processing_message = pcall(signals.after_prompt_processing.emit, signals.after_prompt_processing)
  if not processing_status then
    svo.debugf(processing_message)
    echoLink("(e!)", string.format("svo.echof([[The problem was: stuff after the actual work failed (%q)]])", m), 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
  end

  if conf.showchanges and conf.commandecho and conf.commandechotype ~= 'fancynewline' then sk.showstatchanges() end
  if sys.deffing then svo.defupfinish() end

  -- show system commands
  svo.fancysendall()

  -- send off all batched commands
  sk.dosendqueue()

  local currentlinenumber = getLastLineNumber('main')
  svo.lastpromptnumber = currentlinenumber
  -- record the time of the latest prompt we've seen - doing so is okay because we aren't using the current time, but retrieving the already calculated time from Mudlet
  -- using this, we can then find which was the most recent prompt line. Sometimes another line will share the time with the prompt, but the prompt will always be latest
  svo.lastprompttime = getTimestamp(currentlinenumber)
  svo.paragraph_length = 0
  sk.processing_prompt = false
  raiseEvent("svo done with prompt")
end

signals.after_prompt_processing:connect(function ()
  -- svo prompt pipeline - deals with the custom and singleprompts. This is done before onprompt()

  -- move the real prompt over for later use.
  moveCursorEnd()
  if selectString( getCurrentLine(), 1 ) ~= -1 then
    copy()
    moveCursorEnd('svo_prompt')
    paste('svo_prompt')
  end

  -- stats are updated in a pre-emit of before_prompt_processing; available to the customprompt here
  if affs.blackout or svo.innews then return end

  -- replace w/ customprompt if necessary
  if conf.customprompt then
    selectString(line, 1)
    replace("")
  end

  -- prefix an orange '?:' if we don't know the exact stats
  if affs.recklessness or affs.blackout then
    local currentline = getLineCount()
    moveCursor('main', 0, currentline)
    deselect()
    setFgColor(255, 102, 0)
    insertText("?:")
    deselect(); resetFormat()
    moveCursorEnd()
  end

  if sys.sync then
    local currentline = getLineCount()
    deselect()
    moveCursor('main', 0, currentline)
    setFgColor(255, 0, 0)
    insertText("(")
    moveCursor('main', 1, currentline)

    -- you're overriding the system, green
    if svo.sacid then
      setFgColor(0,255,0)
    -- system is doing something, red
    elseif sk.doingstuff_inslowmode() then
      setFgColor(255,0,0)
    -- system isn't doing anything and you aren't overriding, blue
    else
      setFgColor(0,0,255)
    end

    if svo.sacid then
      insertLink('a', 'svo.echof[[You\'re currently overriding the system]]', 'You were overriding the system at this point', true)
    elseif sk.syncdebug then
      insertLink('a', 'svo.echof[['..sk.syncdebug..']]', 'Click to see actions we were considering doing at this point', true)
    else
      insertText('a')
    end

    moveCursor('main', 2, currentline)
    setFgColor(255, 0, 0)
    insertText(")")
    moveCursor('main', 3, currentline)
    setFgColor(0,0,0)
    insertText(" ")
    moveCursorEnd()
    resetFormat()
  end

  if conf.paused then
    moveCursor('main', 0, getLineCount())
    cinsertText("<a_red>(<a_darkgrey>p<a_red>)<black> ")
  end

  if conf.customprompt then
    cecho(svo.cp.display() or "")
  end

  -- then do singleprompt business
  if conf.singleprompt then
    selectString(getCurrentLine(), 1)
    copy()
    clearWindow('bottomprompt')
    svo.bottomprompt:paste()

    if conf.singlepromptblank then
      replace("")
    elseif not conf.singlepromptkeep then
      deleteLine()
    end

    deselect()
  end
end)

signals.gmcpcharname:connect(function()
  svo.innews = nil
  sk.logged_in = true
end)

signals.gmcpcharstatus:connect(function()
  sys.charname = gmcp.Char.Status.name
  me.name = gmcp.Char.Status.name
end)

local old500num = 0
local old500p = false


function svo.prio_makefirst(action, balance)
  svo.assert(action and svo.dict[action], "svo.prio_makefirst: " .. (action and action or 'nil') .. " isn't a valid action.")

  local act = svo.dict[action]

  -- find if it's only one available
  if not balance then
    local count = table.size(act)
    if act.aff then count = count - 1 end
    if act.waitingfor then count = count - 1 end

    svo.assert(count == 1, "svo.prio_makefirst: " .. action .. " uses more than one balance, which one do you want to move?")
    local balance = false
    for k,_ in pairs(act) do
      if k ~= 'aff' and k ~= 'waitingfor' then balance = k end
    end
  end

  svo.assert(act[balance] and act[balance] ~= 'aff' and act[balance] ~= 'waitingfor', "svo.prio_makefirst: " .. action .. " doesn't use the " .. (balance and balance or 'nil') .. " balance.")

  local beforestate = sk.getbeforestateprios()

  -- at this point, we both have the act and balance we want to move up.
  -- logic: move to 500, remember the original val. when we have to move back,
  -- we'll swap it to the original val.
  svo.prio_undofirst()

  old500num = act[balance].spriority
  old500p = act[balance]
  act[balance].spriority = 500

  local afterstate = sk.getafterstateprios()
  sk.notifypriodiffs(beforestate, afterstate)
end

function svo.prio_undofirst()
  if not old500p then return end

  local beforestate = sk.getbeforestateprios()

  old500p.spriority = old500num
  old500p, old500num = false, nil

  local afterstate = sk.getafterstateprios()
  sk.notifypriodiffs(beforestate, afterstate)
end

function svo.prio_slowswap(what, arg3, echoback, callback, ...)
  local sendf; if echoback then sendf = svo.echof else sendf = svo.errorf end
  local what, balance = what:match("(%w+)_(%w+)")
  local balance2
  if not tonumber(arg3) then
    svo.assert(balance and balance2, "What balances do you want to use for swapping?", sendf)
    arg3, balance2 = arg3:match("(%w+)_(%w+)")
  end

  local beforestate = sk.getbeforestateprios()

  if tonumber(arg3) then -- swap to a #
    local name, balance2 = svo.prio.getslowaction(tonumber(arg3))
    if not name then -- see if we have anyone in that # already
      svo.dict[what][balance].spriority = arg3
      if echoback then
        svo.echof("%s is now at %d.", what, arg3)
      end
    else -- if we do have someone at that #, swap them
      svo.dict[what][balance].spriority, svo.dict[name][balance2].spriority =
      svo.dict[name][balance2].spriority, svo.dict[what][balance].spriority
      if echoback then svo.echof("%s is now > %s.", what, name) end
      if echoback then svo.echof("<0,255,0>%s (%s) <255,255,255>> <0,255,0>%s (%s)", what, balance, name, balance2) end
    end
  else -- swap one action_balance with another action_balance
    if svo.dict[what][balance].spriority < svo.dict[arg3][balance2].spriority then
      svo.dict[what][balance].spriority, svo.dict[arg3][balance2].spriority =
      svo.dict[arg3][balance2].spriority, svo.dict[what][balance].spriority
      if echoback then svo.echof("%s is now > %s.", what, arg3) end
      if echoback then svo.echof("<0,255,0>%s (%s) <255,255,255>> <0,255,0>%s (%s)", arg3, balance2, what, balance) end
    elseif echoback then
      svo.echof("%s is already > %s.", what, arg3)
    end
  end

  local afterstate = sk.getafterstateprios()
  sk.notifypriodiffs(beforestate, afterstate)

  if callback and type(callback) == 'function' then callback(...) end
end

function svo.prio_swap(what, balance, arg2, arg3, echoback, callback, ...)
  local sendf; if echoback then sendf = svo.echof else sendf = svo.errorf end
  svo.assert(what and svo.dict[what] and balance and svo.dict[what][balance] and balance ~= 'aff' and balance ~= 'waitingfor', "what item and balance do you want to swap?", sendf)

  local function swaptwo(what, name, balance, ...)
    if svo.dict[what][balance].aspriority < svo.dict[name][balance].aspriority then
      svo.dict[what][balance].aspriority, svo.dict[name][balance].aspriority =
      svo.dict[name][balance].aspriority, svo.dict[what][balance].aspriority
      if echoback then svo.echof("<0,255,0>%s <255,255,255>> <0,255,0>%s%s in %s balance", what, name, svo.getDefaultColor(), balance) end
    elseif svo.dict[what][balance].aspriority > svo.dict[name][balance].aspriority then
      svo.dict[what][balance].aspriority, svo.dict[name][balance].aspriority =
      svo.dict[name][balance].aspriority, svo.dict[what][balance].aspriority
      if echoback then svo.echof("<0,255,0>%s <255,255,255>> <0,255,0>%s%s in %s balance", name, what, svo.getDefaultColor(), balance) end
    end

    if callback and type(callback) == 'function' then callback(...) end
  end

  local beforestate = sk.getbeforestateprios()

  -- we want our 'what' to be at this arg2 number, swap what was there with its previous position
  if not arg3 then

    svo.assert(tonumber(arg2), "what number do you want to swap " .. what .. " with?", sendf)
    local to_num = tonumber(arg2)
    local name = svo.prio.getaction(to_num, balance)

    -- swapping two affs
    if name then
      swaptwo(what, name, balance, ...)

    -- or just setting one aff
    else
      svo.dict[what][balance].aspriority = to_num
      if echoback then
        svo.echof("%s is now at %d.", what, to_num)
      end
    end

    local afterstate = sk.getafterstateprios()
    sk.notifypriodiffs(beforestate, afterstate)

    return
  end

  -- we want to swap two affs
  svo.assert(svo.dict[arg2] and svo.dict[arg2][arg3], "what balance of "..arg2.." do you want to swap with?", sendf)
  swaptwo(what, arg2, arg3, ...)

  local afterstate = sk.getafterstateprios()
  sk.notifypriodiffs(beforestate, afterstate)
end

svo.prompt_stats = function ()
  local s,m = pcall(function()
    if not (gmcp and gmcp.Char and gmcp.Char.Vitals) then
        if not conf.paused then
          conf.paused = true
          echo"\n" svo.echof("Paused the system - please enable GMCP for it in Mudlet settings!") svo.showprompt()
          raiseEvent("svo config changed", 'paused')
        end
      return
    end

    local temp = {
      maxhealth = stats.maxhealth or 0,
      maxmana = stats.maxmana or 0,
    }

    local vitals = gmcp.Char.Vitals
    local sformat = string.format


    stats.currenthealth, stats.maxhealth,
    stats.currentmana, stats.maxmana,
    stats.currentendurance, stats.maxendurance,
    stats.currentwillpower, stats.maxwillpower
     =
        vitals.hp, vitals.maxhp,
        vitals.mp, vitals.maxmp,
        vitals.ep, vitals.maxep,
        vitals.wp, vitals.maxwp

    stats.nextlevel = gmcp.Char.Vitals.nl or 0
    stats.xprank = gmcp.Char.Status.xprank or 0

    stats.hp = sformat("%.1f", (100/stats.maxhealth)*stats.currenthealth)
    stats.mp = sformat("%.1f", (100/stats.maxmana)*stats.currentmana)
    stats.wp = sformat("%.1f", (100/stats.maxwillpower)*stats.currentwillpower)
    stats.ed = sformat("%.1f", (100/stats.maxendurance)*stats.currentendurance)

    for i,j in pairs(stats) do
      stats[i] = tonumber(j) or 0
    end

    if (stats.currentwillpower <= 1000 and not (stats.currenthealth == 0 and stats.currentmana == 0)) or sk.lowwillpower then
      sk.checkwillpower()
    end

    if (affs.blackout and not ((lifevision.l.touchtree_misc and lifevision.l.touchtree_misc.arg == 'blackout') or lifevision.l.blackout_waitingfor)) or (affs.recklessness and not actions.recklessness_focus and not actions.recklessness_herb) then
      local assumestats = conf.assumestats/100
      stats.currenthealth, stats.currentmana =
        math.floor(stats.maxhealth * assumestats), math.floor(stats.maxmana * assumestats)
    end

    -- see what max values changed, update other info accordingly
    if temp.maxhealth ~= stats.maxhealth then
      signals.changed_maxhealth:emit(temp.maxhealth, stats.maxhealth)
    end
    if temp.maxmana ~= stats.maxmana then
      signals.changed_maxmana:emit(temp.maxmana, stats.maxmana)
    end
  end)

  if not s then
    echoLink("(e!)", [[echo("The problem was: prompt vitals function failed - (]]..tostring(m)..[[). Maybe the system isn't installed yet?")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
  end
end


function svo.QQ()
  signals.quit:emit()
end

svo.savesettings = svo.QQ

-- add in blackout only, otherwise go off the prompt - this allows for time tracking
function svo.goteq()
  sys.balancetick = sys.balancetick + 1
  if sys.actiontimeoutid then
    killTimer(sys.actiontimeoutid)
    sys.actiontimeoutid = false
  end

  if sys.misseddisrupt then killTimer(sys.misseddisrupt); sys.misseddisrupt = nil end
  sys.extended_eq = nil

  if affs.blackout and not bals.equilibrium then bals.equilibrium = true; raiseEvent("svo got balance", 'equilibrium') end
end

function svo.gotbalance()
  if affs.blackout then bals.balance = true end
  sys.balancetick = sys.balancetick + 1
  if sys.actiontimeoutid then
    killTimer(sys.actiontimeoutid)
    sys.actiontimeoutid = false
  end

  -- FIXME
  if affs.blackout and not bals.balance then bals.balance = true; raiseEvent("svo got balance", 'balance') end
end

function svo.gotarmbalance()
  sys.balancetick = sys.balancetick + 1
  if sys.actiontimeoutid then
    killTimer(sys.actiontimeoutid)
    sys.actiontimeoutid = false
  end
end

signals["svo lost balance"]:connect(function(balance)
  if balance ~= 'equilibrium' or not conf.noeqtimeout or conf.noeqtimeout == 0 or conf.serverside then return end

  if sys.misseddisrupt then killTimer(sys.misseddisrupt) end
  sys.misseddisrupt = tempTimer(conf.noeqtimeout, function()
    if not bals.equilibrium and not sys.extended_eq and not svo.innews and not affs.disrupt then
      svo.addaffdict(svo.dict.disrupt)
      if not me.passive_eqloss then
        svo.echof("didn't get eq back in %ss - assuming disrupt", tostring(conf.noeqtimeout))
      else
        svo.echof("didn't get eq back in %ss - assuming disrupt and confusion", tostring(conf.noeqtimeout))
        svo.addaffdict(svo.dict.confusion)
      end

      svo.make_gnomes_work()
    end
  end)
end)

signals["svo got balance"]:connect(function(balance)
  if balance ~= 'equilibrium' then return end

  if affs.disrupt then svo.rmaff('disrupt') end
end)

if svo.haveskillset('weaponmastery') then
signals["svo got balance"]:connect(function(balance)
  if balance ~= 'balance' then return end

  sk.didfootingattack = false
end)
end

-- set a flag that we shouldn't assume disrupt on long-eq actions
function svo.extended_eq()
  sys.extended_eq = true
end

function svo.cnrl.update_siphealth()
  if conf.siphealth then sys.siphealth                   = math.floor(stats.maxhealth * (conf.siphealth/100)) end
  if conf.mosshealth then sys.mosshealth                 = math.floor(stats.maxhealth * (conf.mosshealth/100)) end
  if conf.transmuteamount then sys.transmuteamount       = math.floor(stats.maxhealth * (conf.transmuteamount/100)) end
  if conf.corruptedhealthmin then sys.corruptedhealthmin = math.floor(stats.maxhealth * (conf.corruptedhealthmin/100)) end
if svo.haveskillset('devotion') then
  if conf.bloodswornoff then sys.bloodswornoff           = math.floor(stats.maxhealth * (conf.bloodswornoff/100)) end
end
end
signals.changed_maxhealth:connect(cnrl.update_siphealth)

function svo.cnrl.update_sipmana()
  if conf.sipmana then sys.sipmana = math.floor(stats.maxmana * (conf.sipmana/100)) end
  if conf.mossmana then sys.mossmana = math.floor(stats.maxmana * (conf.mossmana/100)) end

  sys.manause = math.floor(stats.maxmana * (conf.manause/100))
end
signals.changed_maxmana:connect(cnrl.update_sipmana)


function svo.cnrl.update_wait()
  sys.wait = svo.wait_tbl[conf.lag].n
end

svo.can_usemana = function()
  return stats.currentmana > sys.manause and
    not svo.doingaction('nomana') -- pseudo-tracking for blackout and recklessness
    and (stats.wp or 0) > 1
end

if svo.haveskillset('healing') then
-- string -> boolean
-- given an affliction, returns true if we've got the available channels open for it
svo.havechannelsfor = function(aff)
  if sk.healingmap[aff] and sk.healingmap[aff]() then
    return true
  end
end
end

svo.cnrl.warnids = {}

-- tbl: {initialmsg = "", prefixwarning = "", startin = 0, duration = 0}
function svo.givewarning(tbl)
  svo.checkaction(svo.dict.givewarning.happened, true)

  if conf.aillusion then
    lifevision.add(actions.givewarning_happened.p, nil, tbl, 1)
  else
    lifevision.add(actions.givewarning_happened.p, nil, tbl)
  end
end
function svo.givewarning_multi(tbl)
  svo.checkaction(svo.dict.givewarning.happened, true)
  lifevision.add(actions.givewarning_happened.p, nil, tbl)
end

svo.prefixwarning = function ()
  local deselect, echo, setFgColor = deselect, echo, setFgColor

  if conf.warningtype == 'right' then
    local currentline = getCurrentLine()
    deselect()
    echo(string.rep(" ", conf.screenwidth - #currentline - #cnrl.warning-3))
    setFgColor(0, 050, 200)
    echo("(")
    setFgColor(128, 128, 128)
    echo(cnrl.warning)
    setFgColor(0, 050, 200)
    echo(")")
    moveCursorEnd()
    resetFormat()
  else
    local currentline = getLineCount()
    deselect()
    moveCursor('main', 0, currentline)
    setFgColor(0, 050, 200)
    insertText("(")
    moveCursor('main', 1, currentline)
    setFgColor(128, 128, 128)
    insertText(cnrl.warning)
    moveCursor('main', 1+#cnrl.warning, currentline)
    setFgColor(0, 050, 200)
    insertText(")")
    moveCursor('main', 2+#cnrl.warning, currentline)
    setFgColor(0,0,0)
    insertText(" ")
    moveCursorEnd()
    resetFormat()
  end
end

svo.cnrl.lockdata = {
  ['soft'] = function () return (affs.slickness and affs.anorexia and affs.asthma) end,
  ['venom'] = function () return (affs.slickness and affs.anorexia and affs.asthma and affs.paralysis) end,
  ['hard'] = function () return (affs.slickness and affs.anorexia and affs.asthma and (affs.impatience or (not svo.can_usemana() or not svo.conf.focus))) end,
  ['dragon'] = function () return (defc.dragonform and affs.slickness and affs.anorexia and affs.asthma and (affs.impatience or (not svo.can_usemana() or not svo.conf.focus)) and affs.recklessness and affs.weakness) end,
  ['stain'] = function() return (affs.stain and affs.slickness and ((affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm) and (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm)) and pipes.valerian.puffs == 0) end,
  ['rift'] = function() return ((affs.asthma and (rift.invcontents.kelp == 0 and rift.invcontents.aurum == 0)) and affs.slickness and ((affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm) and (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm))) end,
  ["rift 2"] = function() return (affs.asthma and affs.slickness and affs.anorexia and (affs.paralysis or (affs.disrupt and not bals.equilibrium)) and ((affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm) and (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm))) end,
  ['slow'] = function () return (affs.asthma and affs.slickness and ((affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm) and (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm)) and (affs.mildconcussion or affs.seriousconcussion) and affs.aeon) end,
  ['true'] = function () return (affs.slickness and affs.anorexia and affs.asthma and affs.paralysis and affs.impatience and affs.disrupt and affs.confusion) end
}

--[[ cnrl.checkwarning gets unblocked whenever we receive an aff that is
      included in any of the locks. If you have a lock, it enables the
      cnrl.checkgreen flag, and unblocks dowarning, which allows powercure
      to run and do it's thing. Post processing, cnrl.dolockwarning is run,
      notifying the user on the prompt of any locks (and if any of them
      are in the process of being cured, highlight the lock name in green).

      When we don't have a lock, checkwarning disables itself, the flag,
      and dowarning]]

cnrl.warnings = {}
cnrl.checkwarning = function ()
  cnrl.warnings = {}
  me.locks = {}
  local t = cnrl.warnings
  for lock, func in pairs(cnrl.lockdata) do
    if func() then t[#t+1] = lock; me.locks[lock] = true end
  end

  if not cnrl.checkgreen and #t > 0 then
    signals.after_prompt_processing:unblock(cnrl.dolockwarning)
    cnrl.checkgreen = true
  elseif cnrl.checkgreen and #t == 0 then
    cnrl.checkgreen = false
    signals.after_lifevision_processing:block(cnrl.checkwarning)
    signals.after_prompt_processing:block(cnrl.dolockwarning)
  end
end
signals.after_lifevision_processing:connect(cnrl.checkwarning)
signals.after_lifevision_processing:block(cnrl.checkwarning)

cnrl.dolockwarning = function ()
  local t = cnrl.warnings
  if #t == 1 then
    cecho("<red>(<grey>lock: <orange>" .. t[1].."<red>)")
  elseif #t > 1 then
    cecho("<red>(<grey>locks: <orange>" .. svo.concatand(t).."<red>)")
  else
    -- no more warnings? stop checking for them. Failsafe, we should never get here normally.
    cnrl.checkgreen = false
    signals.after_lifevision_processing:block(cnrl.checkwarning)
    signals.after_prompt_processing:block(cnrl.dolockwarning)
  end
end
signals.after_prompt_processing:connect(cnrl.dolockwarning)
signals.after_prompt_processing:block(cnrl.dolockwarning)

function svo.cnrl.processcommand(what)
  if not sys.sync or conf.send_bypass then return end

  if conf.blockcommands
  -- and the system is doing something right now...
  and sk.doingstuff_inslowmode()
  -- and this command right here is from you, not the system. Ignore commands starting with 'curing'
  -- though, as those are for serverside and aren't affected
  and not sk.gnomes_are_working and not what:lower():find("^curing") then
    denyCurrentSend()
    if math.random(1,5) == 1 then
      svo.echof("denying <79,92,88>%s%s. Lemme finish!", what, svo.getDefaultColor())
    elseif math.random(1,10) == 1 then
      svo.echof("denying <79,92,88>%s%s. Use tsc to toggle deny mode.", what, svo.getDefaultColor())
    else
      svo.echof("denying <79,92,88>%s%s.", what, svo.getDefaultColor()) end
    return
  elseif not conf.blockcommands and not sk.gnomes_are_working then -- override mode, command from you, not the system

    -- kill old timer first
    if not svo.sacid then svo.echof("pausing curing for your commands.") end

    if svo.sacid then killTimer(svo.sacid) end
    svo.sacid = tempTimer(svo.syncdelay() + getNetworkLatency() + conf.sacdelay, function ()
      svo.sacid = false
      if sys.sync then svo.echof("resuming curing.") end
      svo.make_gnomes_work()
    end)
  end

  -- retardation detection: works by setting a timer off a command, if the timer isn't already set
  -- then when the sluggish msg is seen, the timer is cleared.
  -- amnesia screws with it by hiding the sluggish msg itself!
  if not sk.sluggishtimer and not affs.amnesia and what ~= "" and not what:lower():find("^curing") then
    sk.sawsluggish = getLastLineNumber('main')
    local time = sys.wait + svo.syncdelay() + getNetworkLatency()
    sk.sluggishtimer = tempTimer(time, function ()
      if type(sk.sawsluggish) == 'number' and sk.sawsluggish ~= getLastLineNumber('main') and (affs.retardation or svo.affsp.retardation) then
        if affs.retardation then echo"\n" svo.echof("Retardation seems to have went away.") end
        svo.rmaff('retardation')
      end

      sk.sluggishtimer = nil
    end)
  end
end

signals.sysdatasendrequest:connect(cnrl.processcommand)
signals.sysdatasendrequest:block(cnrl.processcommand)

-- parse things for acceptance. ideas to prevent looping: either debug.traceback() (very slow it turned out), or block/unblock handler when doing sys actions (solution used)
function svo.cnrl.processusercommand(what, now)
  -- remove spaces, as some people may use spaces, ie "bedevil " instead of just 'bedevil' which then confuses tracking
  what = what:trim()

  -- if this is a system command done outside of a cnrl.processusercommand block because of batching, catch it
  if sk.systemscommands[what] then svo.debugf("igboring %s, it's actually a system command", what) return end

  -- debugf("sys.input_to_actions: %s", pl.pretty.write(pl.tablex.keys(sys.input_to_actions)))
  -- debugf("sk.systemscommands: %s", pl.pretty.write(sk.systemscommands))

  if not svo.innews and (what == 'qq' or what == 'quit') then
    svo.QQ()
    svo.echof("Going into empty defs mode so pre-cache doesn't take anything out, and stuffing away all riftables...")
    defs.switch('empty')
    svo.inra()
  elseif not svo.innews and (what == 'ir' or what == "info rift") then
    me.parsingrift = 'all'
  elseif not svo.innews and (what == "ir herb" or what == "ir plant") then -- missing info rift variants
    me.parsingrift = 'herbs'
  elseif not svo.innews and (what == "ir mineral") then
    me.parsingrift = 'minerals'

  elseif sys.input_to_actions[what] then
    local function dostuff()
      svo.killaction(sys.input_to_actions[what])
      local oldsend, oldsendc, oldsendAll = _G.send, svo.sendc, _G.sendAll
      _G.send = function() end
      svo.sendc = function() end
      _G.sendAll = function() end
      local s,m = pcall(svo.doaction, sys.input_to_actions[what])
      if not s then
        echoLink("(e!)", [[svo.echof("The problem was: re-mapping commands to system actions failed: (]]..tostring(m)..[[)")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
      end
      _G.send = oldsend
      svo.sendc = oldsendc
      _G.sendAll = oldsendAll
    end

    -- when 'now' is given, put it into queue right away - this is useful for capturing the game curing command
    if now then dostuff() else tempTimer(0, dostuff) end
  end
end
signals.sysdatasendrequest:connect(cnrl.processusercommand)

-- limited_around: don't show the full list, but only 13 elements around the center one
function svo.printorder(balance, limited_around)
  -- translate the obvious 'balance' to 'physical'
  if balance == 'balance' then balance = 'physical' end
  local sendf = svo.errorf
  svo.assert(type(balance) == 'string', "svo.printorder: what balance do you want to print for?", sendf)

  -- get into table...
  local data = svo.make_prio_table(balance)
  local orderly = {}

  -- get a sorted list of just the prios
  for i,_ in pairs(data) do
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

  svo.echof("%s balance priority list (<112,112,112>clear gaps%s):", balance:title(), svo.getDefaultColor())
  if selectString("clear gaps", 1) ~= -1 then
    setLink("svo.prio.cleargaps('"..balance.."', true)", "Clear all gaps in the "..balance.." balance")
  end

  if not limited_around then
    svo.echof("Stuff at the top will be cured first, if it's possible to cure it.")
  end

  local list = svo.prio.getsortedlist(balance)
  local temp_affs, temp_defs = sk.splitdefs(balance, list)
  local raffs, rdefs = {}, {}
  for index, aff in pairs(temp_affs) do raffs[aff] = index end
  for index, def in pairs(temp_defs) do rdefs[def] = index end

  if limited_around then
    svo.echofn("(")
    setFgColor(unpack(svo.getDefaultColorNums))
    setUnderline(true)
    echoLink("...", "svo.printorder('"..balance.."')", "Click to view the full "..balance.." priority list", true)
    setUnderline(false)
    echo(")\n")
  end

  local function echoserver(j, raffs, rdefs, balance, ssprioamount)
    if raffs[data[j]] then
      return string.format("ss aff %"..ssprioamount..'s', (raffs[data[j]] <= 25 and raffs[data[j]] or '25'))
    elseif rdefs[data[j]] then
      return string.format("ss def %"..ssprioamount..'s', (rdefs[data[j]] <= 25 and rdefs[data[j]] or '25'))
    elseif svo.dict[data[j]][balance].def then
      return "ss def"..(' '):rep(ssprioamount).."-"
    elseif svo.dict[data[j]][balance].aff then
      return "ss aff"..(' '):rep(ssprioamount).."-"
    else
      return "ss    "..(' '):rep(ssprioamount).."-"
    end
  end

  local counter = 1
  local intlen = svo.intlen
  local prioamount = intlen(table.size(orderly))
  local ssprioamount = intlen(table.size(raffs) and table.size(raffs) or table.size(rdefs))
  for _,j in pairs(orderly) do
    if not limited_around or not (counter > (center+6) or counter < (center-6)) then
      setFgColor(255,147,107) echo"  "
      echoLink("^^", 'svo.prio_swap("'..data[j]..'", "'..balance..'", '..(j+1)..', nil, false, svo.printorder, "'..balance..'", '..(j+1)..')', 'shuffle '..data[j]..' up', true)
      echo(" ")
      setFgColor(148,148,255)
      echoLink('vv', 'svo.prio_swap("'..data[j]..'", "'..balance..'", '..(j-1)..', nil, false, svo.printorder, "'..balance..'", '..(j-1)..')', 'shuffle '..data[j]..' down', true)
      setFgColor(112,112,112)
      -- focus balance can't have 'priority'
      if not conf.serverside or balance == 'focus' then
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

  svo.showprompt()
end

function svo.printordersync(limited_around)
  -- step 1: get into table...
  local data = svo.make_sync_prio_table("%s (%s)")
  local orderly = {}

  for i,_ in pairs(data) do
    orderly[#orderly+1] = i
  end

  table.sort(orderly, function(a,b) return a>b end)

  svo.echof("aeon/retardation priority list (clear gaps):")
  if selectString("clear gaps", 1) ~= -1 then
    setFgColor(112,112,112)
    setLink("svo.prio.cleargaps('slowcuring', true)", "Clear all gaps in the aeon/retardation priority")
    resetFormat()
  end

  -- locate where the center of the list is, if we need it
  local center
  if limited_around then
    local counter = 1
    for _, j in pairs(orderly) do
      if j == limited_around then center = counter break end
      counter = counter +1
    end
  end

  if not limited_around then
    svo.echof("Stuff at the top will be cured first, if it's possible to cure it.")
  end

  if limited_around then
    svo.echofn("(")
    setFgColor(unpack(svo.getDefaultColorNums))
    setUnderline(true)
    echoLink("...", "svo.printordersync()", "Click to view the full aeon/retardation priority list", true)
    setUnderline(false)
    echo(")\n")
  end

  local counter = 1
  for _,j in pairs(orderly) do
    if not limited_around or not (counter > (center+6) or counter < (center-6)) then
      setFgColor(255,147,107) echo"  "
      echoLink("^^", 'svo.prio_slowswap("'..string.format("%s_%s", string.match(data[j], "(%w+) %((%w+)%)"))..'", '..(j+1)..', false, svo.printordersync, '..(j+1)..')', 'shuffle '..data[j]..' up', true)
      echo(" ")
      setFgColor(148,148,255)
      echoLink('vv', 'svo.prio_slowswap("'..string.format("%s_%s", string.match(data[j], "(%w+) %((%w+)%)"))..'", '..(j-1)..', false, svo.printordersync, '..(j-1)..')', 'shuffle '..data[j]..' up', true)
      setFgColor(112,112,112)
      echo(" (" .. j..") "..data[j])
      echo("\n")
      resetFormat()
    end

    counter = counter + 1
  end

  svo.showprompt()
end

function svo.sk.check_fullstats()
  if stats.currenthealth >= stats.maxhealth and stats.currentmana >= stats.maxmana and not affs.recklessness then
    sk.gettingfullstats = false
    signals.after_prompt_processing:disconnect(sk.check_fullstats)
    tempTimer(0, function() svo.echof("We're fully healed up now.") svo.showprompt() end)
    raiseEvent("svo got fullstats")

    if sk.fullstatsunignorehp then
      sk.fullstatsunignorehp = nil
      svo.serverignore.healhealth = true
    end

    if sk.fullstatsunignoremp then
      sk.fullstatsunignoremp = nil
      svo.serverignore.healmana = true
    end

    if type(sk.fullstatscallback) == 'function' then
      local s,m = pcall(sk.fullstatscallback)
      if not s then svo.echof("Your fullstats function had a problem:\n  %s", m) end
    elseif type(sk.fullstatscallback) == 'string' then
      local s,m = pcall(loadstring(sk.fullstatscallback))
      if not s then svo.echof("Your fullstats code had a problem:\n  %s", m) end
    end
    sk.fullstatscallback = nil
  end
end


function svo.fullstats(newstatus, callback, echoback)
  if newstatus then
    if stats.currenthealth >= stats.maxhealth and stats.currentmana >= stats.maxmana then
      if echoback then svo.echof("We're already completely healthy.") end
      raiseEvent("svo got fullstats")

      if newstatus and type(callback) == 'function' then
        local s,m = pcall(callback)
        if not s then svo.echof("Your fullstats function had a problem:\n  %s", m) end
      elseif newstatus and type(callback) == 'string' then
        local s,m = pcall(loadstring(callback))
        if not s then svo.echof("Your fullstats code had a problem:\n  %s", m) end
      end
      return
    else

      sk.gettingfullstats = true

      -- if serverside is on, take healhealth off ignore (if it's there) and let it sip up
      if conf.serverside then
        if svo.serverignore.healhealth then
          sk.fullstatsunignorehp = true
          svo.serverignore.healhealth = nil
        end

        if svo.serverignore.healmana then
          sk.fullstatsunignoremp = true
          svo.serverignore.healmana = nil
        end
      end

      signals.after_prompt_processing:connect(sk.check_fullstats)
      sk.fullstatscallback = callback
      if echoback then svo.echof("Healing up to full stats.") end
      raiseEvent("svo started fullstats")
      svo.make_gnomes_work()
    end
  elseif not newstatus then
    sk.gettingfullstats = false
    signals.after_prompt_processing:disconnect(sk.check_fullstats)
    if echoback then svo.echof("Resumed normal health/mana healing.") end
    raiseEvent("svo stopped fullstats")
  end
end

svo.prompttrigger = function (name, func)
  svo.assert(name, "svo.prompttrigger: the name needs to be provided")
  svo.assert(type(func) == 'function' or type(func) == 'nil', "svo.prompttrigger: the second argument needs to be a Lua function or nil")

  sk.onprompt_beforeaction_add(name, func)
end

svo.aiprompt = function (name, func)
  sk.onprompt_beforelifevision_add(name, func)
end

function svo.lyre_step()
  if not (bals.balance and bals.equilibrium) then svo.echof("Don't have balance+eq.") return end

  if not conf.lyre then svo.config.set('lyre', 'on', true) end

  if sys.sync then sk.gnomes_are_working = true end
  svo.conf.paused = false
  raiseEvent("svo config changed", 'paused')

  svo.conf.lyre_step = true
  svo.make_gnomes_work()

  if not actions.lyre_physical then
    svo.doaction(svo.dict.lyre.physical)
  end
  svo.conf.lyre_step = false

  if sys.sync then sk.gnomes_are_working = false end
end

-- capture the incoming values for gmcp balance and eq
signals.gmcpcharvitals:connect(function()
  svo.newbals.balance     = gmcp.Char.Vitals.bal == '1' and true or false
  svo.newbals.equilibrium = gmcp.Char.Vitals.eq == '1' and true or false
end)

-- feed the curing systems curing command through the system, so it can track actions
-- don't raise a systadasendrequest because that would trigger command deny/override
function svo.curingcommand(command)
  sk.sawcuringcommand = true
  cnrl.processusercommand(command:lower(), true)
  svo.prompttrigger("clear curing command", function() sk.sawcuringcommand = false end)

  if conf.gagservercuring then deleteLine() end
end

-- same as curingcommand, but for actions via queue
function svo.queuecommand(command)
  sk.sawqueueingcommand = true
  cnrl.processusercommand(command:lower(), true)

  svo.prompttrigger("clear queueing command", function() sk.sawqueueingcommand = false end)
end
