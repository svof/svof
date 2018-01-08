-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.


vecho = function(newline, what)
  decho("<206,222,215>(<214,206,221>svof<206,222,215>)<252,251,254>: <249,244,254>" .. what)
  if newline then echo"\n" end
end

function echos.Eleusis(newline, what)
  decho("<157,60,60>(<55,145,55>svof<157,60,60>)<212,245,112>: <62,245,62>" .. what)
  if newline then echo"\n" end
end

function echosd.Eleusis()
  return "<62,245,62>"
end

function echos.LightGreen(newline, what)
  decho("<255,231,179>(<170,154,118>svof<255,231,179>)<255,241,210>: <255,219,140>" .. what)
  if newline then echo"\n" end
end

function echosd.LightGreen()
  return "<255,219,140>"
end

function echos.Mhaldor(newline, what)
  decho("<157,60,60>(<255,0,0>svof<157,60,60>)<255,65,65>: <255,117,117>" .. what)
  if newline then echo"\n" end
end

function echosd.Mhaldor()
  return "<255,117,117>"
end

function echos.Ashtan(newline, what)
  decho("<80,66,80>(<107,79,125>svof<80,66,80>)<87,85,89>: <159,128,180>" .. what)
  if newline then echo"\n" end
end

function echosd.Ashtan()
  return "<159,128,180>"
end

function echos.Shallam(newline, what)
  decho("<32,128,94>(<53,213,157>svof<32,128,94>)<53,213,157>: <0,171,111>" .. what)
  if newline then echo"\n" end
end

function echosd.Shallam()
  return "<0,171,111>"
end

function echos.Targossas(newline, what)
  decho("<32,128,94>(<53,213,157>svof<32,128,94>)<53,213,157>: <0,171,111>" .. what)
  if newline then echo"\n" end
end

function echosd.Targossas()
  return "<0,171,111>"
end

function echos.Hashan(newline, what)
  decho("<206,222,215>(<170,175,175>svof<206,222,215>)<252,251,254>: <237,244,244>" .. what)
  if newline then echo"\n" end
end

function echosd.Hashan()
  return "<237,244,244>"
end

function echos.Cyrene(newline, what)
  decho("<253,63,73>(<251,0,13>svof<253,63,73>): <253,114,121>" .. what)
  if newline then echo"\n" end
end

function echosd.Cyrene()
  return "<253,114,121>"
end

function echos.default(newline, what)
  decho("<206,222,215>(<214,206,221>svof<206,222,215>)<252,251,254>: <249,244,254>" .. what)
  if newline then echo"\n" end
end

function echosd.default()
  return "<249,244,254>"
end

signals.systemstart:connect(function ()
  vecho = echos[conf.echotype] or echos[conf.org] or echos.default
  getDefaultColor = echosd[conf.echotype] or echosd[conf.org] or echosd.default

  -- create an r,g,b table that we can setFgColor(unpack(getDefaultColorNums)) later
  getDefaultColorNums = {
    ((echosd[conf.echotype] and echosd[conf.echotype]())
      or (echosd[conf.org] and echosd[conf.org]()) or
      echosd.default()
    ):match("<(%d+),(%d+),(%d+)>")}
end)

signals.orgchanged:connect(function ()
  vecho = echos[conf.echotype] or echos[conf.org] or echos.default
  getDefaultColor = echosd[conf.echotype] or echosd[conf.org] or echosd.default

  -- create an r,g,b table that we can setFgColor(unpack(getDefaultColorNums)) later
  getDefaultColorNums = {
    ((echosd[conf.echotype] and echosd[conf.echotype]())
      or (echosd[conf.org] and echosd[conf.org]()) or
      echosd.default()
    ):match("<(%d+),(%d+),(%d+)>")}
end)

function svo.updateloggingconfig()
  if svo.conf.log == "off" then
    svo.debugf = function() end
  elseif svo.conf.log == "file" then
    svo.debugf = function(...)
      if not Logger then return end

      local args = {...}
      if #args < 2 and args[1] and args[1]:find("%", 1, true) then Logger:Log("svof", "not enough args to debugf: "..debug.traceback()) return end
      Logger:Log("svof", string.format(...))
    end
  elseif svo.conf.log == "echo" then
    svo.debugf = function(...)
      local args = {...}
      if #args < 2 and args[1] and args[1]:find("%", 1, true) then echof("not enough args to debugf: "..debug.traceback()) return end
      echof(string.format(...))
    end
  else
    svo.debugf = function(...)
      if not Logger then return end

      local args = {...}
      if #args < 2 and args[1] and args[1]:find("%", 1, true) then Logger:Log("svof", "not enough args to debugf: "..debug.traceback()) return end
      Logger:Log("svof", string.format(...))
    end
  end
end
svo.updateloggingconfig()

function showprompt()
  if conf.singleprompt then clearWindow"bottomprompt" end

  -- https://bugs.launchpad.net/mudlet/+bug/982720 disallows (conf.singleprompt and 'bottomprompt' or 'main')
  -- if conf.paused then
  --   if conf.singleprompt then
  --     decho('bottomprompt', "<255,0,0>(<128,128,128>p<255,0,0>)<0,0,0> ")
  --   else
  --     decho("<255,0,0>(<128,128,128>p<255,0,0>)<0,0,0> ")
  --   end
  -- end

  if not conf.customprompt or affs.blackout or innews then
    moveCursor("svo_prompt",0,getLastLineNumber("svo_prompt")-1)
    selectCurrentLine("svo_prompt")
    copy("svo_prompt")

    if conf.singleprompt then
      clearWindow("bottomprompt")

      if conf.paused then
        cecho("bottomprompt", "<a_red>(<a_darkgrey>p<a_red>)<black> ")
      end
      appendBuffer('bottomprompt')
    else
      if conf.paused then
        local currentline = getLineCount()
        deselect()
        moveCursor("main", 0, currentline)
        setFgColor(255, 0, 0)
        insertText("(")
        moveCursor("main", 1, currentline)
        setFgColor(128, 128, 128)
        insertText("p")
        moveCursor("main", 2, currentline)
        setFgColor(255, 0, 0)
        insertText(")")
        moveCursor("main", 3, currentline)
        setFgColor(0,0,0)
        insertText(" ")
        moveCursorEnd()
        resetFormat()
      end

      appendBuffer()
    end
  else
    if conf.singleprompt then
      cecho('bottomprompt', cp.display() or "")
    else
      cecho(cp.display() or "")
    end
  end
end

local ofs = {} -- original functions
ofs.origdecho = decho
function ofs.windowdecho(text)
  if sk.echofwindow == 'main' then -- workaround for https://github.com/vadi2/mudlet-lua/issues/1
    ofs.origdecho(text)
  else ofs.origdecho(sk.echofwindow, text) end
end

ofs.origecho = echo
function ofs.windowecho(text)
  if sk.echofwindow == 'main' then -- workaround for https://github.com/vadi2/mudlet-lua/issues/1
    ofs.origecho(text)
  else ofs.origecho(sk.echofwindow, text) end
end

function echof(...)
  local t = {...}
  -- see if we want this to go to a window!
  local sfind = string.find
  if t[1] and t[2] and sfind(t[1], "^%w+$") and not sfind(t[1], "%", 1, true) then
    sk.echofwindow = t[1]
    local olddecho, oldecho = decho, echo
    decho, echo = ofs.windowdecho, ofs.windowecho

    moveCursorEnd(t[1])
    vecho(true, string.format(select(2, ...)))

    decho, echo = olddecho, oldecho
  else
    moveCursorEnd("main")
    local successful, s = pcall(string.format, ...)
    if successful then
      vecho(true, s)
    else
      error(s, 2)
      -- echoLink("(e!)", [[echo("The problem was: svo.echof couldn't build the text, because: ]]..tostring(s)..[[")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
    end
  end
end

function echofn(...)
  moveCursorEnd("main")
  vecho(false, string.format(...) or "")
end

function echon(...)
  echo(string.format(...))
end

function itf(...)
  dinsertText(((echosd[conf.echotype] and echosd[conf.echotype]()) or (echosd[conf.org] and echosd[conf.org]()) or echosd.default()) .. string.format(...) or "")
  -- debugf((echosd[conf.echotype] and echosd[conf.echotype]() or echosd.default()) .. string.format(...) or "")
end

local function errorf(...)
   error(string.format(...))
end

-- used in public API to allow $'s
function snd(what, show)
  for _,w in ipairs(string.split(what, "%$")) do
    _G.send(w, show or false)
    if (affs.seriousconcussion or (conf.doubledo and affs.stupidity)) and not sys.sync then _G.send(w, show or false) end
  end
end

-- given a table of keys and values as integers, return the key with highest value
local function getHighestKey(tbl)
  local result
  local highest = -1
  for i,j in pairs(tbl) do
    if j > highest then
      highest = j
      result = i
    end
  end

  return result
end

local function getLowestKey(tbl)
  local result = select(1, next(tbl))
  local lowest = select(2, next(tbl))
  for i,j in pairs(tbl) do
    if j < lowest then
      lowest = j
      result = i
    end
  end

  return result
end

local function getHighestValue(tbl)
  local result
  local highest = 0
  for i,j in pairs(tbl) do
    if j > highest then
      highest = j
      result = i
    end
  end

  return highest
end

local function getBoundary(tbl)
  local result
  local highest, lowest = 0, select(2, next(tbl))
  for i,j in pairs(tbl) do
    if j > highest then
      highest = j
      result = i
    elseif j < lowest then
      lowest = j
    end
  end

  return highest, lowest
end

function oneconcat(tbl)
  assert(type(tbl) == "table", "svo.oneconcat wants a table as an argument.")
  local result = {}
  for i,_ in pairs(tbl) do
    result[#result+1] = i
  end

  return table.concat(result, ", ")
end

function oneconcatwithval(tbl)
  assert(type(tbl) == "table", "svo.oneconcatwithval wants a table as an argument.")
  local result = {}
  local sformat = string.format
  for i,v in pairs(tbl) do
    result[#result+1] = sformat("%s(%s)", i, v)
  end

  return table.concat(result, ", ")
end

function concatand(t)
  assert(type(t) == "table", "svo.concatand: argument must be a table")

  if #t == 0 then return ""
  elseif #t == 1 then return t[1]
  else
    return table.concat(t, ", ", 1, #t-1) .. " and "..t[#t]
  end
end

function concatandf(t, f)
  assert(type(t) == "table", "svo.concatandf: argument must be a table")

  return concatand(pl.tablex.map(f, t))
end

function keystolist(t)
  local r = {}

  for k,v in pairs(t) do
    r[#r+1] = k
  end

  return r
end

-- table -> number
-- given a shallow key-value table of items, returns the length of the biggest string value in it
function longeststring(input)
  local longest, found = 0

  local type = type
  for k,v in pairs(input) do
    if type(v) == "string" then
      found = true
      local length = #v

      if length > longest then longest = length end
    end
  end

  if found then return longest else return nil, "no strings found in the given table" end
end


function safeconcat(t, separator)
  assert(type(t) == "table", "svo.safeconcat: argument must be a table")

  if #t == 0 then return ""
  elseif #t == 1 then return tostring(t[1])
  else
    local temp = {}
    for i = 1, #t do
      temp[#temp+1] = tostring(t[i])
    end
    return table.concat(temp, separator or '')
  end
end

function deleteLineP()
  deleteLine()
  gagline = true -- used for not echoing things on lines that'll be deleted
  sk.onprompt_beforeaction_add("deleteLine", function()
    gagline = false
  end)

  if not conf.shipmode or not svo.me.shippromptn then -- if not on shipmode, or in shipmode but didn't actually see the ship prompt...
    tempLineTrigger(1,1,[[
      if isPrompt() then
        deleteLine()
      end
    ]])
  else
    sk.requested_deletelineP = getLineCount() -- remember when the deletion was requested, to work out if we should delete the prompt or not
    sk.onprompt_beforeaction_add("deleteLineP shipmode", function()
      if svo.conf.shipmode and svo.me.shippromptn and sk.requested_deletelineP+1 == svo.me.shippromptn then
        local from, to = svo.me.shippromptn , getLineCount()
        for i = from, to-1 do
          moveCursor(0, i) deleteLine()
        end
        moveCursorEnd()
         -- wrapLine(to) deleteLine()
        tempLineTrigger(0, 1, [[deleteLine()]]) -- cover the customprompt over after
      end
    end)
  end
end

function deleteAllP(count)
  if not count then deleteLine() end
  tempLineTrigger(count or 1,1,[[
  deleteLine()
  if not isPrompt() then
    svo.deleteAllP()
  end
]])
end

local function containsbyname(t, value)
  assert(type(t) == "table", "svo.containsbyname wants a table!")
  for k, v in pairs(t) do
    if v == value then return k end
  end

  return false
end

local function contains(t, value)
  assert(type(t) == "table", "svo.contains wants a table!")
  for k, v in pairs(t) do
    if v == value then
      return true
    elseif k == value then
      return true
    elseif type(v) == "table" then
      if contains(v, value) then return true end
    end
  end

  return false
end

-- longer priorities take the first order
function svo.syncdelay()
  if not sys.sync then
    return 0
  elseif affs.aeon or affs.retardation then
    return 1
  else return 0 -- failsafe
  end
end

function events(event, ...)
  local name = event:lower()
  if signals[name] then signals[name]:emit(...) end
end

function gevents(parent, key)
  local name = key:gsub("%.",""):lower()
  if signals[name] then signals[name]:emit() end
end

local yes = {"yes", "yep", "yup", "oui", "on", "y", "da"}
local no = {"no", "nope", "non", "off", "n", "net"}
local function convert_string(which)
  if contains(yes, which) or which == true then return true end
  if contains(no, which) or which == false then return false end

  return nil
end
toboolean = convert_string

function convert_boolean(which)
  if which == true then return "on"
  else return "off" end
end

-- this should also cache to prevent a lot of getLines() calls from the tekura function
-- warning, wrapped lines -will- be split up here
function find_until_last_paragraph (pattern, type)
  local t = getLines(lastpromptnumber, getLastLineNumber("main"))

  local find = string.find
  for i = 1, #t do
    local line = t[i]

    if type == "exact" and line == pattern then return true
    elseif type == "pattern" and find(line, pattern) then return true
    elseif type == "substring" and find(line, pattern, 1, true) then return true end
  end

  return false
end
local find_until_last_paragraph = find_until_last_paragraph

-- returns the count of matches from the current line until the start of the paragraph
function count_until_last_paragraph (pattern, type)
  local t = getLines(lastpromptnumber, getLastLineNumber("main"))

  local find, count = string.find, 0
  for i = 1, #t do
    local line = t[i]

    if type == "exact" and line == pattern then count = count + 1
    elseif type == "pattern" and find(line, pattern) then count = count + 1
    elseif type == "substring" and find(line, pattern, 1, true) then count = count + 1 end
  end

  return count
end

-- merge table2 into table1
update = function (t1, t2)
  for k,v in pairs(t2) do
    if type(v) == "table" then
      t1[k] = update(t1[k] or {}, v)
    else
      t1[k] = v
    end
  end
  return t1
end

-- assumes two table are of same length and does not recurse. Returns the value-key list of differences as the values are in t2
basictableindexdiff = function (t1, t2)
  local diff = {}
  -- have to use pairs to cover holes
  for k,v in pairs(t1) do
    if v ~= t2[k] then diff[#diff+1] = v end
  end
  for k,v in pairs(t2) do
    if v ~= t1[k] then diff[#diff+1] = v end
  end

  return diff
end

local function emptyphp(what)
  for _, _ in what:pairs() do
    return false
  end

  return true
end

oldsend = _G.send
local fancy_send_commands = {}

local function fancysend(what, store)
  if conf.batch then sendc(what); sk.systemscommands[what] = true else oldsend(what, false) end

  if (affs.seriousconcussion or (conf.doubledo and affs.stupidity)) and not sys.sync and not sys.sendonceonly then
    if conf.batch then sendc(what); sk.systemscommands[what] = true else oldsend(what, false) end
  end

  if conf.repeatcmd > 0 then
    for i = 1, conf.repeatcmd do
      if conf.batch then sendc(what); sk.systemscommands[what] = true else oldsend(what, false) end
    end
  end

  if not store then return end

  fancy_send_commands[#fancy_send_commands+1] = what
end

local function fancysendall()
  if #fancy_send_commands == 0 then return end

  if conf.commandechotype == "fancynewline" then echo'\n' end
  decho(string.format("<51,0,255>(<242,234,233>%s<51,0,255>)", table.concat(fancy_send_commands, "<102,98,97>|<242,234,233>")))
  fancy_send_commands = {}
end

-- check if we need to adjust parrying on any limbs or not
local function check_sp_satisfied()
  if sps.something_to_parry() then -- have we asked for any limbs to be parried?
    for name, limb in pairs(sp_config.parry_shouldbe) do
      if limb ~= sps.parry_currently[name] then
       sys.sp_satisfied = false; return
      end
    end
  elseif type(sp_config.parry) == "string" and sp_config.parry == "manual" then
    -- check if we need to unparry in manual
    for limb, status in pairs(sps.parry_currently) do
      if status ~= sp_config.parry_shouldbe[limb] then
       sys.sp_satisfied = false; return
      end
    end
  elseif sp_config.priority[1] and not sps.parry_currently[sp_config.priority[1]] then
    sp_config.parry_shouldbe[sp_config.priority[1]] = true
    sys.sp_satisfied = false; return
  end
  sys.sp_satisfied = true
end

sp_limbs = {
  head = true,
  torso = true,
  ["right arm"] = true,
  ["left arm"] = true,
  ["right leg"] = true,
  ["left leg"] = true
}


local yep = function ()
  return "<0,250,0>Yep" .. getDefaultColor()
end

local nope = function ()
  return "<250,0,0>Nope" .. getDefaultColor()
end

local red = function (what)
  return "<250,0,0>" .. what .. getDefaultColor()
end

local green = function (what)
  return "<0,250,0>" .. what .. getDefaultColor()
end

function sk.reverse(a)
  return (a:gsub("().", function (p)
    return a:sub(#a-p+1,#a-p+1);
  end))
end

function sk.anytoshort(exit)
  local t = {
    n = "north",
    e = "east",
    s = "south",
    w = "west",
    ne = "northeast",
    se = "southeast",
    sw = "southwest",
    nw = "northwest",
    u = "up",
    d = "down",
    ["in"] = "in",
    out = "out"
  }
  local rt = {}
  for s,l in pairs(t) do
    rt[l] = s; rt[s] = s
  end

  return rt[exit]
end

-- things line blind/deaf can be either afflictions or defences. This function is called whenever their status as a defence might change, and you have them - hence they need to be changed to a defence now or back
function sk.fix_affs_and_defs()
  if affs.blindaff and ((defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind)
    or (svo.me.class ~= "Apostate" and defc.mindseye)) then
    removeaff("blindaff")
    defences.got("blind")
    echof("blindness is now considered a defence.")
  elseif defc.blind and not ((defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind)
   or (svo.me.class ~= "Apostate" and defc.mindseye)) then
    defences.lost("blind")
    addaff(dict.blindaff)
    echof("blindness is now considered an affliction, will cure it.")
  end

  if affs.deafaff and ((defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf) or defc.mindseye) then
    removeaff("deafaff")
    defences.got("deaf")
    echof("deafness is now considered a defence.")
  elseif defc.deaf and not ((defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf) or defc.mindseye) then
    defences.lost("deaf")
    addaff(dict.deafaff)
    echof("deafness is now considered an affliction, will cure it.")
  end
end

-- rewielding
--[[
basis:
  we re-wield items only we know we had wielded, that we unwielded involuntarily

  received items.update - if it doesn't have an 'l' or an 'r' attribute, then it means we unwielded it, or picked it up, or whatever. So, check if we had it wielded - if we did, then this was unwielded. needs rewielding.

  received items.updateif it does have an 'l' or an 'r' attribute, remember this as wielded - save in mm.me.wielding_left or mm.me.wielding_right.
]]

signals.gmcpcharname:connect(function ()
  sendGMCP("Char.Items.Inv")
  send("\n")
end)

signals.gmcpcharitemslist:connect(function()
  -- catch what is wielded
  local t = gmcp.Char.Items.List
  if t.location ~= "inv" then return end

  me.wielded = {}

  for _, item in pairs(t.items) do
    if item.id and item.attrib then
      local lefthand, righthand = string.find(item.attrib, 'l', 1, true), string.find(item.attrib, 'L', 1, true)

      if (lefthand or righthand) then
        me.wielded[item.id] = deepcopy(item)

        if lefthand and righthand then
          me.wielded[item.id].hand = "both"
        elseif lefthand then
          me.wielded[item.id].hand = "left"
        else
          me.wielded[item.id].hand = "right"
        end
      end
    end
  end

  raiseEvent("svo me.wielded updated")
end)

function ceased_wielding(what)
  for itemid, item in pairs(me.wielded) do
    if item.name and item.name == what then
      me.wielded[itemid] = nil
      raiseEvent("svo me.wielded updated")
      return
    end
  end
end

function sk.checkrewield()
  local s,m = pcall(function()
    if paragraph_length > 1 and not find_until_last_paragraph("You cease to prop up a tall totem pole.", "exact") and not find_until_last_paragraph("You lob", "substring") and not lifevision.l.breath_gone and not find_until_last_paragraph("You begin to wield", "substring") then
      -- we wish to rewield wieldables!
      dict.rewield.rewieldables = deepcopy(sk.rewielddables)
      debugf("dict.rewield.rewieldables - %s", pl.pretty.write(dict.rewield.rewieldables))
      echof("Need to rewield %s%s!", tostring(dict.rewield.rewieldables[1].name), tostring(((dict.rewield.rewieldables[2] and dict.rewield.rewieldables[2].name) and (" and "..dict.rewield.rewieldables[2].name) or "")))
      -- echoLink("(info)", 'printCmdLine([[If the system decided that you\'ve unwielded out of the blue for no reason, copy/paste this in an submit a bug report with: '..pl.pretty.write(gmcp.Char.Items.Update):gsub("\n", " ")..']])', 'Click here if the system decided that you\'ve unwieled for no reason at all')
    end
  end)
  if not s then
    echoLink("(e!)", [[echo("The problem was: ']]..tostring(m)..[['")]], 'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a copy/paste of what you saw.')
  end

  sk.rewielddables = nil
  signals.before_prompt_processing:disconnect(sk.checkrewield)
end

function unwielded(itemid, name)
  sk.rewielddables = sk.rewielddables or {}
  if not (sk.rewielddables[1] and sk.rewielddables[1].id == itemid) then
    sk.rewielddables[#sk.rewielddables+1] = {id = itemid, name = name}
  end

  if conf.autorewield then
    signals.before_prompt_processing:connect(sk.checkrewield)
  end

  me.wielded[itemid] = nil
  raiseEvent("svo me.wielded updated")
end

signals.gmcpcharitemsupdate:connect(
function ()
  local t = gmcp.Char.Items.Update

  if t.location ~= "inv" or type(me.wielded) ~= "table" then return end

  -- unwielded?
  if t.item.id and me.wielded[t.item.id] and t.item.name and (not t.item.attrib or (not string.find(t.item.attrib, 'l', 1, true) and not string.find(t.item.attrib, 'L', 1, true))) then
    unwielded(t.item.id, t.item.name)

  -- wielded? allow for a re-update on the wielding data as well
  elseif t.item.attrib and t.item.id and (string.find(t.item.attrib, 'l', 1, true) or string.find(t.item.attrib, 'L', 1, true)) then
    local lefthand, righthand = string.find(t.item.attrib, 'l', 1, true), string.find(t.item.attrib, 'L', 1, true)

    me.wielded[t.item.id] = deepcopy(t.item)

    if lefthand and righthand then
      me.wielded[t.item.id].hand = "both"
    elseif lefthand then
      me.wielded[t.item.id].hand = "left"
    else
      me.wielded[t.item.id].hand = "right"
    end

    checkaction(dict.rewield.physical)
    if actions.rewield_physical then
      lifevision.add(actions.rewield_physical.p, nil, t.item.id)
    end
    raiseEvent("svo me.wielded updated")
  end
end)

signals.gmcpcharitemsremove:connect(function ()
  local t = gmcp.Char.Items.Remove
  if t.location ~= "inv" or type(me.wielded) ~= "table" then return end
  local itemid = tostring(t.item.id)
  if me.wielded[itemid] then
    unwielded(itemid, me.wielded[itemid].name or "")
  end
end)

signals.gmcpcharitemsremove:connect(function ()
  sk.removed_something = true
  sk.onprompt_beforeaction_add("gmcpcharitemsremove", function ()
    sk.removed_something = nil
  end)
end)


function setdefaultprompt()
  if svo.haveskillset('shindo') then
    config.set("customprompt", [[^1@healthh, ^2@manam, ^5@endurancee, ^4@willpowerw @promptstringorig@affs^6@shin^w-]], false)
  elseif svo.haveskillset('kaido') then
    config.set("customprompt", [[^1@healthh, ^2@manam, ^5@endurancee, ^4@willpowerw @promptstringorig@affs^6@kai^W-]], false)
  else
    config.set("customprompt", [[^1@healthh, ^2@manam, ^5@endurancee, ^4@willpowerw @promptstringorig@affs^W-]], false)
  end
end

signals.enablegmcp:connect(function()
  sendGMCP([[Core.Supports.Add ["IRE.Time 1"] ]])
  sendGMCP("IRE.Time.Request")
end)

function setignore(k,v)
  -- default to true, use unsetignore to clear
  if v == nil then v = true end

  ignore[k] = v
  raiseEvent("svo ignore changed", k)
end

function unsetignore(k)
  ignore[k] = nil
  raiseEvent("svo ignore changed", k)
end

function setserverignore(k)
  serverignore[k] = true
  raiseEvent("svo serverignore changed", k)
end

function unsetserverignore(k)
  serverignore[k] = nil
  raiseEvent("svo serverignore changed", k)
end
