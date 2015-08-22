-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

pl.dir.makepath(getMudletHomeDir() .. "/svo/pipes")

me.pipes = me.pipes or {}

pipes.valerian = pipes.valerian or
  {lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = "valerian", filledwith2 = "valerian", maxpuffs = 10, maxpuffs2 = 10}
me.pipes.valerian = pipes.valerian

pipes.elm = pipes.elm or
{lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = "elm", filledwith2 = "elm", maxpuffs = 10, maxpuffs2 = 10}
me.pipes.elm = pipes.elm

pipes.skullcap = pipes.skullcap or
{lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = "skullcap", filledwith2 = "skullcap", maxpuffs = 10, maxpuffs2 = 10}
me.pipes.skullcap = pipes.skullcap

pipes.pnames = {"valerian", "skullcap", "elm"}

pipes.expectations = {"valerian", "skullcap", "elm"}

pipes.empties = {}

function lastlit (which)
  for i = 1, #pipes.expectations do
    local v = pipes.expectations[i]
    if v == which then
      table.remove(pipes.expectations, i)
      pipes.expectations[#pipes.expectations+1] = which
      return
    end
  end
end

function pipeout()
  local what = pipes.expectations[1]
  pipes[what].lit = false
  table.remove(pipes.expectations, 1)
  pipes.expectations[#pipes.expectations+1] = what
end

function pipestart()
  local oldvalerianmaxpuffs, oldelmmaxpuffs, oldskullcapmaxpuffs = pipes.valerian.maxpuffs, pipes.elm.maxpuffs, pipes.skullcap.maxpuffs
  local oldvalerianmaxpuffs2, oldelmmaxpuffs2, oldskullcapmaxpuffs2 = pipes.valerian.maxpuffs2, pipes.elm.maxpuffs2, pipes.skullcap.maxpuffs2

  pipes.valerian = {lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = "valerian", filledwith2 = "valerian", maxpuffs = oldvalerianmaxpuffs, maxpuffs2 = oldvalerianmaxpuffs2}
  me.pipes.valerian = pipes.valerian

  pipes.elm = {lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = "elm", filledwith2 = "elm", maxpuffs = oldelmmaxpuffs, maxpuffs2 = oldelmmaxpuffs2}
  me.pipes.elm = pipes.elm

  pipes.skullcap = {lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = "skullcap", filledwith2 = "skullcap", maxpuffs = oldskullcapmaxpuffs, maxpuffs2 = oldskullcapmaxpuffs2}
  me.pipes.skullcap = pipes.skullcap
end

function parseplist()
  local pipenames = {
    ["slippery elm"]                = "elm",
    ["a valerian leaf"]             = "valerian",
    ["a skullcap flower"]           = "skullcap",
    ["a pinch of ground cinnabar"]  = "elm",
    ["a pinch of realgar crystals"] = "valerian",
    ["a pinch of ground malachite"] = "skullcap"
  }

  local short_names = {
    ["slippery elm"]                = "elm",
    ["a valerian leaf"]             = "valerian",
    ["a skullcap flower"]           = "skullcap",
    ["a pinch of ground cinnabar"]  = "cinnabar",
    ["a pinch of realgar crystals"] = "realgar",
    ["a pinch of ground malachite"] = "malachite"
  }

  local id     = tonumber(matches[3])
  local herb   = pipenames[matches[4]]
  local puffs  = tonumber(matches[5])
  local status = matches[2]

  if not (id and herb and puffs and status) then return end

  local filled,lit,arty,puffskey, maxpuffs
  if pipes[herb].id == 0 then
    pipes[herb].id = id
    firstpipe = true
    filled = "filledwith"
    lit = "lit"
    arty = "arty"
    puffskey = "puffs"
    maxpuffs = "maxpuffs"
  else
    pipes[herb].id2 = id
    firstpipe = false
    filled = "filledwith2"
    lit = "lit2"
    arty = "arty2"
    puffskey = "puffs2"
    maxpuffs = "maxpuffs2"
  end

  pipes[herb][arty] = false

  pipes[herb][filled] = short_names[matches[4]]

  if status == "out" then
    pipes[herb][lit] = false
  elseif status == "lit" then
    pipes[herb][lit] = true
   elseif status == "artf" then
    pipes[herb][arty] = true
  end

  pipes[herb][puffskey] = puffs

  -- assume it's a 20 puff pipe if the puffs we have atm is over 10 (bigger than normal)
  if puffs > 10 then
    pipes[herb][maxpuffs] = 20
    echo(" ")
    setFgColor(unpack(getDefaultColorNums))
    echo("(a 20-puff pipe)")
  end

  -- warn if relighting any pipes is on ignore, to make it more obvious - people tended to miss the original line
  if ignore["light"..herb] then
    decho(" "..getDefaultColor().."(")
    setFgColor(unpack(getDefaultColorNums))
    setUnderline(true)
    echoLink("re-enable lighting", 'svo.ignore.light'..herb..' = nil; svo.echof("Re-enabled lighting of the '..pipes[herb].filledwith..' pipe."); if not svo.conf.relight then svo.config.set("relight", "on", true) end', 'Re-lighting the '..pipes[herb].filledwith..' pipe was put on ignore because '..ignore["light"..herb].because..' - click the link to re-enable it', true)
    setUnderline(false)
    decho(getDefaultColor()..")")
  end
end

function parseplistempty()
  local id = tonumber(matches[3])
  local status = matches[2]
  if not (id and status) then return end

  -- save the data, to later assign the pipes to herbs
  pipes.empties[#pipes.empties+1] = {id = id, arty = (status == "artf" and true or false), status = status}
end

function parseplistend()
  -- fill up at least one of each first
  for id = 1, #pipes.pnames do
    local i = pipes.pnames[id]
    if pipes[i] and pipes[i].id == 0 and next(pipes.empties) then
      pipes[i].id = pipes.empties[#pipes.empties].id
      if pipes.empties[#pipes.empties].status == "Lit" then
        pipes[i].lit = true
      else
        pipes[i].lit = false
      end

      if pipes.empties[#pipes.empties].arty then
        pipes[i].arty = true
      end

      pipes.empties[#pipes.empties] = nil
    end
  end

  -- fill up secondary ones
  for id = 1, #pipes.pnames do
    local i = pipes.pnames[id]
    if pipes[i] and pipes[i].id2 == 0 and next(pipes.empties) then
      pipes[i].id2 = pipes.empties[#pipes.empties].id
      if pipes.empties[#pipes.empties].status2 == "Lit" then
        pipes[i].lit2 = true
      else
        pipes[i].lit2 = false
      end

      if pipes.empties[#pipes.empties].arty then
        pipes[i].arty2 = true
      end

      pipes.empties[#pipes.empties] = nil
    end
  end

  pipes.empties = {}
  signals.after_lifevision_processing:unblock(cnrl.checkwarning) -- check for stain lock
  make_gnomes_work()
end

-- assumes that we set some pipe to 0 already. This is used during install only
function pipe_assignid(newid)
  newid = tonumber(newid)
  for id = 1, #pipes.pnames do
    local i = pipes.pnames[id]
    if pipes[i].id == 0 then
      pipes[i].id = newid
      conf[i.."id"] = newid
      pipes[i].lit = false
      send("empty "..newid, false)
      raiseEvent("svo config changed", i.."id")
      return i
    elseif pipes[i].id2 == 0 then
      pipes[i].id2 = newid
      conf[i.."id2"] = newid
      pipes[i].lit2 = false
      send("empty "..newid, false)
      raiseEvent("svo config changed", i.."id2")
      return i
    end
  end
end

if lfs.attributes(getMudletHomeDir() .. "/svo/pipes/conf") then
  local ok = pcall(table.load, getMudletHomeDir() .. "/svo/pipes/conf", pipes)
  if ok then
    -- maxpuffs were added later on in the game, so make sure this field exists for upgrading systems
    pipes.elm.maxpuffs         = pipes.elm.maxpuffs or 10
    pipes.skullcap.maxpuffs    = pipes.skullcap.maxpuffs or 10
    pipes.valerian.maxpuffs    = pipes.valerian.maxpuffs or 10

    -- secondary pipes were added later on, so drop it in
    pipes.elm.maxpuffs2        = pipes.elm.maxpuffs2 or 10
    pipes.skullcap.maxpuffs2   = pipes.skullcap.maxpuffs2 or 10
    pipes.valerian.maxpuffs2   = pipes.valerian.maxpuffs2 or 10

    pipes.elm.lit2             = pipes.elm.lit2 or false
    pipes.skullcap.lit2        = pipes.skullcap.lit2 or false
    pipes.valerian.lit2        = pipes.valerian.lit2 or false

    pipes.elm.id2              = pipes.elm.id2 or 0
    pipes.skullcap.id2         = pipes.skullcap.id2 or 0
    pipes.valerian.id2         = pipes.valerian.id2 or 0

    pipes.elm.arty2            = pipes.elm.arty2 or false
    pipes.skullcap.arty2       = pipes.skullcap.arty2 or false
    pipes.valerian.arty2       = pipes.valerian.arty2 or false

    pipes.elm.puffs2           = pipes.elm.puffs2 or 0
    pipes.skullcap.puffs2      = pipes.skullcap.puffs2 or 0
    pipes.valerian.puffs2      = pipes.valerian.puffs2 or 0

    pipes.elm.filledwith2      = pipes.elm.filledwith2 or "elm"
    pipes.skullcap.filledwith2 = pipes.skullcap.filledwith2 or "skullcap"
    pipes.valerian.filledwith2 = pipes.valerian.filledwith2 or "valerian"

    me.pipes.elm               = pipes.elm
    me.pipes.skullcap          = pipes.skullcap
    me.pipes.valerian          = pipes.valerian
  end
end

signals.connected:connect(function ()
  if not pipes.valerian.arty then pipes.valerian.lit   = false end
  if not pipes.elm.arty then pipes.elm.lit             = false end
  if not pipes.skullcap.arty then pipes.skullcap.lit   = false end

  if not pipes.valerian.arty2 then pipes.valerian.lit2 = false end
  if not pipes.elm.arty2 then pipes.elm.lit2           = false end
  if not pipes.skullcap.arty2 then pipes.skullcap.lit2 = false end

  if not pipes.valerian.filledwith then pipes.valerian.filledwith   = "valerian" end
  if not pipes.elm.filledwith then pipes.elm.filledwith             = "elm" end
  if not pipes.skullcap.filledwith then pipes.skullcap.filledwith   = "skullcap" end

  if not pipes.valerian.filledwith2 then pipes.valerian.filledwith2 = "valerian" end
  if not pipes.elm.filledwith2 then pipes.elm.filledwith2           = "elm" end
  if not pipes.skullcap.filledwith2 then pipes.skullcap.filledwith2 = "skullcap" end
end)

signals.saveconfig:connect(function ()
  local s,m = table.save(getMudletHomeDir() .. "/svo/pipes/conf", pipes)
  if not s then
    echof("Couldn't save settings; %s", m)
  end
end)

