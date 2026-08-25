function svo.inslowcuringmode()
	return (svo.affl.retardation or svo.affl.aeon) and true or false
end

-- originally from Sidd, improved by Lynara
function svo.boxDisplay(msg, color)
    deselect()
    local colTbl = {}
    if color then
       colTbl = string.split(color, ":")
       for k = 1,2 do
          if colTbl[k] == "" then
             colTbl[k] = nil
          end
       end
       if colTbl[2] then
          bg(colTbl[2])
       end
    end
    colTbl[1] = colTbl[1] or "red"
    fg(colTbl[1])
	local leng = ((2*string.len(msg)) + 11)
	local mes = string.upper(msg)
	echo("\n ")
    echo( string.rep("-", leng+2) )
    echo(" \n|     " .. mes .. " | " .. mes .. "     |\n ")
    echo( string.rep("-", leng+2) )
    echo(" \n")
    resetFormat()
end

function svo.preattack()
  if svo.inslowcuringmode() then return end

  if svo.affl.prone then send'stand' end
end

function mapper_can_move()
  return (svo.bals.balance and svo.bals.equilibrium and svo.bals.rightarm and svo.bals.leftarm) and true or false
end

function svo.echotime(s, sameline)
  if not sameline then moveCursor(0, getLineNumber()-1) end
  moveCursor(#getCurrentLine(), getLineNumber())

  fg("dark_slate_gray")
  insertText(' ('..(s or '?')..'s)')
  deselect()
  resetFormat()
  moveCursorEnd()
end

function svo.echoafftime(s, aff)
  if aff == "bleeding" and svo.conf.gagclot then return end

  if isPrompt() then
    moveCursor(0, getLineNumber()-1)
    moveCursor(#getCurrentLine(), getLineNumber())
  end

  deselect()
  fg("DarkGoldenrod")
  insertText(' ('..s..'s)')
  deselect()
  resetFormat()
  moveCursorEnd()
end

local function docc(...)
  local sendto, method
  if not svo.conf.ccto or svo.conf.ccto == 'pt' then sendto = "pt "
  elseif svo.conf.ccto == 'clt' then sendto = "clt "
  elseif svo.conf.ccto:find("^tell %w+") then sendto = "tell "..svo.conf.ccto:match("^tell (%w+)").." "
  elseif svo.conf.ccto == 'ot' then sendto = "ot "
  elseif svo.conf.ccto == 'army' then sendto = "art "
  elseif svo.conf.ccto == 'team' then sendto = "team "
  elseif svo.conf.ccto == 'echo' then method = svo.echof; sendto = ""
  else sendto = "clan "..svo.conf.ccto.." tell " end

  if not method then
    send(sendto .. string.format(...), false)
  else
    (method)(sendto .. string.format(...))
  end
end

function svo.ccnop(...)
  if svo.inslowcuringmode() then return end

  docc(...)
end

function svo.cc(...)
  if svo.conf.paused or svo.inslowcuringmode() then return end

  docc(...)
end

-- credit to: http://hci.iastate.edu/~rpavlik/downloads/vrjugglua/snapshot/share/vrjugglua/lua/string_ext.lua
function string.ordinalSuffix(n)
  n = math.mod (n, 100)
  local d = math.mod (n, 10)
  if d == 1 and n ~= 11 then
    return "st"
  elseif d == 2 and n ~= 12 then
    return "nd"
  elseif d == 3 and n ~= 13 then
    return "rd"
  else
    return "th"
  end
end

function svo.shipprompt()
--  selectCurrentLine() fg("chartreuse") deselect() resetFormat()

  svo.me.shippromptn = getLineCount()
end

-- shows memory use by Lua objects only
registerAnonymousEventHandler("svo system loaded", function()
  svo.adddefinition("@mem", "string.format('%0.2f', collectgarbage('count')/1024)")
end)

function svo.doubleRunToSend(...)
  local doubleClick = .4
  if not DoubleRunTimer then
    DoubleRunTimer = tempTimer(doubleClick,[[killTimer(DoubleRunTimer)
      DoubleRunTimer = nil
      DoubleRunCounter = nil
    ]])
  end
  if DoubleRunCounter then
    DoubleRunCounter = DoubleRunCounter + 1
  else
    DoubleRunCounter = 0
  end
  if DoubleRunCounter == 1 then
    sendAll({...})
  end
end

-- returns a list of affs that focus can get
function svo.getfocusableaffs()
  return table.n_intersection(svo.keystolist(svo.affl), svo.focuscurables)
end

-- starts the stopwatch which measures how long a balance was missing for
function svo.startbalancewatch(balance)
  svo.watch["bal_"..balance] = svo.watch["bal_"..balance] or createStopWatch()
  startStopWatch(svo.watch["bal_"..balance])
end

function svo.endbalancewatch(balance, sameline)
  if svo.watch["bal_"..balance] then
    local s = stopStopWatch(svo.watch["bal_"..balance])
    svo.stats["last"..balance] = s
    if svo.conf.showbaltimes then svo.echotime(s, sameline) end
  end
end

function svo.countbrokenlimbs()
  local affs = svo.affl

  local c = 0
  if affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm then c = c + 1 end
  if affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm then c = c + 1 end
  if affs.crippledleftleg or affs.mangledleftleg or affs.mutilatedleftleg then c = c + 1 end
  if affs.crippledrightleg or affs.mangledrightleg or affs.mutilatedrightleg then c = c + 1 end

  return c
end

function svo.countonlybrokenlimbs()
  local affs = svo.affl

  local c = 0
  if affs.crippledleftarm then c = c + 1 end
  if affs.crippledrightarm then c = c + 1 end
  if affs.crippledleftleg then c = c + 1 end
  if affs.crippledrightleg then c = c + 1 end
  return c
end

function svo.havefractures()
  local affs = svo.affl

  return affs.crackedribs or affs.skullfractures or affs.torntendons or affs.wristfractures
end