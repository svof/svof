-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local sk, me, sys = svo.sk, svo.me, svo.sys
local bals = svo.bals

function sk.getactiondo(i)
  local action = me.doqueue[i]
  if not action then return '' end

  if type(action) == 'table' then
    return tostring(action.what)
  else
    return tostring(action)
  end
end

sk.dometatable = {
  __tostring = function (self)
    return self.what
  end
}

function svo.dofirst(what, echoback, show)
  if type(show) == 'nil' then
    table.insert(me.doqueue, 1, what)
  else
    local t = {what = what, show = show}
    setmetatable(t, sk.dometatable)
    table.insert(me.doqueue, 1, t)
  end

  if echoback then svo.echof("Will do \"%s\" first.", tostring(what)) end
  -- spur the queue into doing work right away, unless this came from a trigger - in which case the prompt will make the stuff work anyhow
  if not debug.traceback():find('Trigger', 1, true) then svo.make_gnomes_work() end
  raiseEvent("svo do changed")
end
function svo.dofreefirst(what, echoback)
  table.insert(me.dofreequeue, 1, what)
  if echoback then svo.echof("Will do \"%s\" first in dofree.", tostring(what)) end
  if not debug.traceback():find('Trigger', 1, true) then svo.make_gnomes_work() end
  raiseEvent("svo dofree changed")
end

function svo.doadd(what, echoback, show)
  if type(show) == 'nil' then
    me.doqueue[#me.doqueue+1] = what
  else
    local t = {what = what, show = show}
    setmetatable(t, sk.dometatable)
    me.doqueue[#me.doqueue+1] = t
  end

  if echoback then svo.echof("Added '%s' to the do queue.", tostring(what)) end
  if not debug.traceback():find('Trigger', 1, true) then svo.make_gnomes_work() end
  raiseEvent("svo do changed")
end

function svo.doaddfree(what, echoback)
  me.dofreequeue[#me.dofreequeue+1] = what
  if echoback then svo.echof("Added '%s' to the dofree queue.", tostring(me.dofreequeue[#me.dofreequeue])) end
  if not debug.traceback():find('Trigger', 1, true) then svo.make_gnomes_work() end
  raiseEvent("svo dofree changed")
end

function svo.donext()
  sys.balancetick = sys.balancetick + 1
  if sys.actiontimeoutid then
    killTimer(sys.actiontimeoutid)
    sys.actiontimeoutid = false
  end
  if not debug.traceback():find('Trigger', 1, true) then svo.make_gnomes_work() end
end

function svo.dor (what, echoback, show)
  if not what or what == 'off' then
    if me.doqueue.repeating or what == 'off' then
      me.doqueue = {repeating = false}
      if echoback then svo.echof("Do-Repeat %s.", svo.red('disabled')) end
    else
      me.doqueue.repeating = true
      if echoback and #me.doqueue > 0 then
        svo.echof("Do-Repeat %s; will repeat the first command (%s) in the queue%s.", svo.green('enabled'), sk.getactiondo(1), (me.dopaused and ", but the do queue is currently paused" or ""))
      elseif echoback then
        svo.echof("Do-Repeat %s; will repeat the first command (which is nothing right now) in the queue%s.", svo.green('enabled'), (me.dopaused and ", but the do queue is currently paused" or ""))
      end
    end
  else
    me.doqueue.repeating = true
    if type(show) == 'nil' then
      me.doqueue[1] = what
    else
      me.doqueue[1] = {what = what, show = show}
    end

    if echoback then svo.echof("Do-Repeat %s; will repeat %s forever%s.", svo.green('enabled'), sk.getactiondo(1), (me.dopaused and ", but the do queue is currently paused" or "")) end
  end
  if not debug.traceback():find('Trigger', 1, true) then svo.make_gnomes_work() end
  raiseEvent("svo do changed")
end

function sk.check_do()
  if not bals.balance or not bals.equilibrium or not bals.rightarm or not bals.leftarm or svo.doworking or me.dopaused then return end

  if #me.doqueue == 0 then return end

  svo.doworking = true

  local action = me.doqueue[1]
  local show
  if type(action) == 'table' then
    show = action.show
    action = action.what
  end

  if type(action) == 'string' then
    for _,w in ipairs(string.split(action, "%$")) do
      if type(show) == 'nil' then
        pcall(expandAlias, w)
      else
        pcall(expandAlias, w, show)
      end
    end
  else
    local s,m = pcall(action)
    if not s then svo.echof("Your do queue %s had a problem:\n  %s", tostring(action), m) end
  end

  if not me.doqueue.repeating then
    table.remove(me.doqueue, 1)
    raiseEvent("svo do changed")
  end

  svo.doworking = false

  return true
end

svo.signals.systemstart:connect(function () svo.addbalanceful("svo check do", sk.check_do) end)

function svo.check_dofree()
  if not bals.balance or not bals.equilibrium or not bals.rightarm or not bals.leftarm or svo.dofreeworking then return end

  if #me.dofreequeue == 0 then return end

  svo.dofreeworking = true

  for _, action in ipairs(me.dofreequeue) do
    if type(action) == 'string' then
      for _,w in ipairs(string.split(action, "%$")) do
        expandAlias(w, false)
      end
    else
      local s,m = pcall(action)
      if not s then svo.echof("Your dofree queue %s had a problem:\n  %s", tostring(action), m) end
    end
  end

  me.dofreequeue = {}
  raiseEvent("svo dofree changed")

  svo.dofreeworking = false
end

svo.signals.systemstart:connect(function () svo.addbalanceless("svo check dofree", svo.check_dofree) end)

function svo.undo(what, echoback)
  if what == 'all' then return end

  if #me.doqueue == 0 then
    if echoback then svo.echof("The do queue is empty.") end
  return end

  if what then
    for i in ipairs(me.doqueue) do
      local action = sk.getactiondo(i)
      if type(action) == 'table' then
        action = action.what
      end

      if action == what then
        table.remove(me.doqueue, i)
        if echoback then svo.echof("Removed \"%s\" from the do queue.", action) return end
      end
    end

    if echoback then svo.echof("Don't have \"%s\" in the do queue.", what) end
  else
    local action = sk.getactiondo(1)
    if type(action) == 'table' then
      action = action.what
    end

    if echoback then svo.echof("Removed \"%s\" from the do queue.", action) end
  end
  raiseEvent("svo do changed")
end

function svo.undofree(echoback, what)
  if #me.dofreequeue == 0 then
    if echoback then svo.echof("The dofree queue is empty.") end
  return end

  if what then
    for i,v in ipairs(me.dofreequeue) do
      if v == what then
        table.remove(me.dofreequeue, i)
        if echoback then svo.echof("Removed \"%s\" from the dofree queue.", v) return end
      end
    end

    if echoback then svo.echof("Don't have \"%s\" in the dofree queue.", what) end
  else
    what = table.remove(me.dofreequeue, 1)
    if echoback then svo.echof("Removed \"%s\" from the dofree queue.", what) end
  end
  raiseEvent("svo dofree changed")
end

function svo.undoall(echoback)
  me.doqueue = {}
  if echoback then svo.echof("Do queue completely cleared.") end
  raiseEvent("svo do changed")
end

function svo.undoallfree(echoback)
  me.dofreequeue = {}
  if echoback then svo.echof("Dofree queue completely cleared.") end
  raiseEvent("svo dofree changed")
end

function svo.doshow()
  svo.echof("Actions left in the dofree queue (%d): %s", #me.dofreequeue, svo.safeconcat(me.dofreequeue, ", "))
  svo.echof("Actions left in the do queue (%d): %s", #me.doqueue, svo.safeconcat(me.doqueue, ", "))
  if me.dorepeat then svo.echof("Do-Repeat is enabled.") end
end

